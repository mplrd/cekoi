#!/usr/bin/env python3
"""Ce qui identifie un binaire, calculé au moment de le construire.

Un APK ne porte aucune trace de son origine. `versionName` vient de
`pubspec.yaml` et vaut `1.0.0` sur tous les builds depuis le premier ; le
`versionCode` valait `1` de la même façon jusqu'à ce que Gradle le calcule.
Résultat : la seule manière d'établir ce qu'un téléphone exécutait était de le
brancher et de comparer une empreinte SHA-256. Ça marche pour une personne, pas
pour douze testeurs qui écrivent « ça plante » — et le 24 août, la question
« quelle version as-tu ? » n'avait aucune réponse possible.

Ce module calcule les quatre valeurs que `lib/app/build_info.dart` lit à la
compilation, et les rend sous forme d'options `--dart-define`. Il est appelé
par `tool/fumee.py`, qui est le chemin de livraison d'un APK.

    python tool/marque.py            # affiche les options a passer a flutter
    python tool/marque.py --json     # la meme chose, exploitable par un script

**L'arbre sale est signalé, pas ignoré.** Un binaire construit sur des
modifications non validées n'est pas le commit qu'il affiche : son empreinte
est alors suffixée `-sale`. Sans ça, un signalement renverrait vers du code que
personne ne peut relire.

Un build qui ne passe pas par ici n'a pas ces valeurs, et l'application le dit
plutôt que d'inventer une identité. Le `versionCode`, lui, est calculé par
`android/app/build.gradle.kts` à partir du même nombre de commits : tout build
Android en porte un, y compris tapé à la main.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass, asdict
from datetime import date
from pathlib import Path

DEPOT = Path(__file__).resolve().parent.parent

# Les noms lus par `String.fromEnvironment` dans lib/app/build_info.dart. Un
# renommage d'un seul côté ne casse rien à la compilation : le champ devient
# simplement vide, et l'application affiche « non identifié » sans qu'aucune
# erreur ne remonte. C'est `test_marque.py` qui tient les deux bouts.
DEFINES = {
    "CEKOI_VERSION": "version",
    "CEKOI_BUILD": "numero",
    "CEKOI_COMMIT": "commit",
    "CEKOI_DATE": "date",
}


# La commande qui donne le numéro de build.
#
# Écrite ici et **relue** par `test_marque.py` dans
# `android/app/build.gradle.kts`, qui doit lancer exactement la même : Gradle
# grave le résultat dans le `versionCode` du paquet, ce module l'injecte dans
# l'application. Les deux se contrediraient sans bruit — l'écran des réglages
# annoncerait un numéro que le paquet ne porte pas, et c'est précisément le
# champ qu'on lit pour comprendre un refus d'installation.
COMPTAGE = ("rev-list", "--count", "HEAD")


class MarqueIndisponible(RuntimeError):
    """Le dépôt ne permet pas d'identifier ce build."""


@dataclass(frozen=True)
class Marque:
    """L'identité d'un binaire, telle qu'elle sera lisible dans l'application."""

    version: str
    numero: str
    commit: str
    date: str


def _git_reel(depot: Path):
    def lancer(*arguments: str) -> str:
        # `OSError` et pas seulement le code de retour : un `git` absent du
        # PATH lève `FileNotFoundError`, qui n'est pas une `MarqueIndisponible`
        # et traverserait donc les `except` de `main()` et de `fumee.py`. On
        # obtiendrait une trace Python à la place du message que ce module
        # existe pour afficher — la leçon est déjà écrite dans `fumee.py` à
        # propos d'`adb`, elle n'avait pas été reportée ici.
        try:
            fini = subprocess.run(
                ["git", *arguments],
                cwd=depot,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
        except OSError as souci:
            raise MarqueIndisponible(f"git n'a pas pu être lancé : {souci}") from souci

        if fini.returncode != 0:
            raise MarqueIndisponible(
                "git " + " ".join(arguments) + " a échoué : " + fini.stderr.strip()
            )
        return fini.stdout

    return lancer


def version_du_pubspec(pubspec: Path) -> str:
    """Le nom de version, sans le `+N` qui le suit.

    Ce `+N` est le numéro de build de Flutter, et il vaut `1` depuis toujours.
    C'est précisément ce que Gradle remplace : le reprendre ici afficherait
    dans l'application un numéro que le paquet installé ne porte pas.
    """
    for ligne in pubspec.read_text(encoding="utf-8").splitlines():
        if ligne.startswith("version:"):
            return ligne.split(":", 1)[1].strip().split("+", 1)[0]
    raise MarqueIndisponible(f"aucune ligne « version: » dans {pubspec}")


def marque(depot: Path = DEPOT, *, git=None, aujourdhui: date | None = None) -> Marque:
    """L'identité à graver dans le prochain build."""
    lancer = git or _git_reel(depot)

    empreinte = lancer("rev-parse", "--short", "HEAD").strip()
    if not empreinte:
        raise MarqueIndisponible("aucun commit : git n'a rendu aucune empreinte")

    if lancer("status", "--porcelain").strip():
        empreinte += "-sale"

    return Marque(
        version=version_du_pubspec(depot / "pubspec.yaml"),
        numero=lancer(*COMPTAGE).strip(),
        commit=empreinte,
        date=(aujourdhui or date.today()).isoformat(),
    )


# Les branches d'où un artefact se livre sans risque.
#
# Le `versionCode` est un compte de commits : il ne monte que le long d'une
# même lignée. Livrer depuis une branche de travail (212), puis depuis
# `develop` qui ne l'a pas encore intégrée (208), fait refuser la seconde
# installation par tous les appareils qui ont reçu la première — « Application
# non installée », sans autre explication.
LIGNEES_SURES = ("develop", "main")


def branche_courante(depot: Path = DEPOT, *, git=None) -> str:
    """La branche sur laquelle HEAD se trouve, ou `''` si HEAD est détaché."""
    lancer = git or _git_reel(depot)
    nom = lancer("rev-parse", "--abbrev-ref", "HEAD").strip()
    return "" if nom == "HEAD" else nom


def options(m: Marque) -> list[str]:
    """Les options `--dart-define` correspondantes, dans l'ordre des noms."""
    valeurs = asdict(m)
    return [f"--dart-define={nom}={valeurs[champ]}" for nom, champ in DEFINES.items()]


def main(argv: list[str] | None = None) -> int:
    analyseur = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    analyseur.add_argument(
        "--json",
        action="store_true",
        help="rendre l'identité en JSON plutôt que les options flutter",
    )
    arguments = analyseur.parse_args(argv)

    try:
        m = marque()
    except MarqueIndisponible as souci:
        print(f"[ÉCHEC] build non identifiable : {souci}", file=sys.stderr)
        return 1

    if arguments.json:
        print(json.dumps(asdict(m), ensure_ascii=False))
    else:
        print(" ".join(options(m)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
