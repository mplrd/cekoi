#!/usr/bin/env python3
"""Test de fumée du build de release : l'application démarre-t-elle ?

Pourquoi un script à part, et pas un test Flutter : R8 ne tourne qu'en
release, et rien de ce qu'il casse n'est visible ailleurs. `flutter test`,
`flutter analyze`, `dart format` et le banc d'aperçus travaillent tous sur les
sources ou sur un build de debug ; la CI construit en debug. Le premier build
de release est donc, par construction, le premier à être exercé — et il l'a été
par un humain qui appuie sur l'icône.

Ce que ce script vérifie est volontairement minuscule : l'application se lance
et tient debout quelques secondes. C'est peu, mais c'est exactement la classe
de panne que rien d'autre ne voit — un `InitializationProvider` qui explose au
démarrage du processus tue l'application avant qu'une ligne de Dart ne tourne,
et aucun test ne peut l'apercevoir.

    python tool/fumee.py                 # construit, installe, lance, vérifie
    python tool/fumee.py --apk chemin    # sur un artefact déjà construit
    python tool/fumee.py --pas-de-build  # sur ce qui est déjà installé
"""

from __future__ import annotations

import argparse
import io
import re
import subprocess
import sys
import time

# La console Windows n'est pas en UTF-8 par défaut, et les accents de ce
# script y ressortaient en mojibake — un message d'échec illisible est un
# message d'échec perdu.
for flux in (sys.stdout, sys.stderr):
    if isinstance(flux, io.TextIOWrapper):
        flux.reconfigure(encoding="utf-8", errors="replace")

PAQUET = "com.twoagames.cekoi"
ACTIVITE = f"{PAQUET}/.MainActivity"
APK_PAR_DEFAUT = "build/app/outputs/flutter-apk/app-release.apk"

# Combien de temps on laisse à l'application pour se planter. Le crash qui
# motive ce script arrivait en moins d'une seconde ; dix laissent aussi le
# temps au premier écran de se construire, donc à une exception Dart au
# démarrage de remonter.
SECONDES_DE_SURVIE = 10


def executer(commande: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(
        commande, capture_output=True, text=True, encoding="utf-8", errors="replace", **kwargs
    )


def echouer(message: str) -> None:
    print(f"\n[ÉCHEC] {message}", file=sys.stderr)
    sys.exit(1)


def appareil() -> str:
    resultat = executer(["adb", "devices"])
    if resultat.returncode != 0:
        echouer("adb est introuvable ou refuse de répondre.")
    branches = [
        ligne.split("\t")[0]
        for ligne in resultat.stdout.splitlines()[1:]
        if ligne.strip().endswith("\tdevice")
    ]
    if not branches:
        echouer("aucun appareil Android connecté. Ce test demande un vrai téléphone.")
    if len(branches) > 1:
        echouer(f"plusieurs appareils connectés ({', '.join(branches)}) — n'en laisser qu'un.")
    return branches[0]


def construire() -> None:
    print("Construction du build de release…")
    # Sans capture : un build de release est long, et le silence pendant cinq
    # minutes ressemble trop à un blocage.
    resultat = subprocess.run(["flutter", "build", "apk", "--release"], shell=False)
    if resultat.returncode != 0:
        echouer("le build de release a échoué.")


def installer(serie: str, apk: str) -> None:
    print(f"Installation de {apk}…")
    resultat = executer(["adb", "-s", serie, "install", "-r", apk])
    if resultat.returncode != 0 or "Success" not in resultat.stdout:
        echouer(f"installation impossible :\n{resultat.stdout}\n{resultat.stderr}")


def lancer(serie: str) -> None:
    executer(["adb", "-s", serie, "logcat", "-c"])
    executer(["adb", "-s", serie, "logcat", "-b", "crash", "-c"])
    executer(["adb", "-s", serie, "shell", "am", "force-stop", PAQUET])
    print("Lancement…")
    resultat = executer(["adb", "-s", serie, "shell", "am", "start", "-n", ACTIVITE])
    if "Error" in resultat.stdout or resultat.returncode != 0:
        echouer(f"l'activité n'a pas démarré :\n{resultat.stdout}\n{resultat.stderr}")


def pid(serie: str) -> str:
    return executer(["adb", "-s", serie, "shell", "pidof", PAQUET]).stdout.strip()


def trace_de_crash(serie: str) -> str:
    journal = executer(["adb", "-s", serie, "logcat", "-b", "crash", "-d"]).stdout
    blocs = [b for b in journal.split("FATAL EXCEPTION") if PAQUET in b]
    return ("FATAL EXCEPTION" + blocs[-1]).strip() if blocs else ""


def ecran_allume(serie: str) -> bool:
    sortie = executer(["adb", "-s", serie, "shell", "dumpsys", "display"]).stdout
    return "mScreenState=ON" in sortie


def frames_rendues(serie: str) -> int:
    sortie = executer(
        ["adb", "-s", serie, "shell", "dumpsys", "gfxinfo", PAQUET]
    ).stdout
    trouve = re.search(r"Total frames rendered:\s*(\d+)", sortie)
    return int(trouve.group(1)) if trouve else 0


def activite_au_premier_plan(serie: str) -> bool:
    # Le nom du champ a bougé d'une version d'Android à l'autre —
    # `mResumedActivity`, `ResumedActivity:`, `topResumedActivity=` — et s'être
    # accroché à une seule de ces graphies a fait échouer ce test sur une
    # application parfaitement au premier plan. On accepte les trois, et on se
    # rabat sur la fenêtre qui a le focus, qui ne s'est jamais renommée.
    sortie = executer(
        ["adb", "-s", serie, "shell", "dumpsys", "activity", "activities"]
    ).stdout
    if re.search(rf"ResumedActivity[=:\s].*{re.escape(PAQUET)}", sortie):
        return True
    focus = executer(["adb", "-s", serie, "shell", "dumpsys", "window"]).stdout
    return bool(re.search(rf"mCurrentFocus.*{re.escape(PAQUET)}", focus))


def main() -> None:
    analyseur = argparse.ArgumentParser(description=__doc__)
    analyseur.add_argument("--apk", default=APK_PAR_DEFAUT)
    analyseur.add_argument("--pas-de-build", action="store_true")
    analyseur.add_argument("--pas-d-installation", action="store_true")
    arguments = analyseur.parse_args()

    serie = appareil()
    print(f"Appareil : {serie}")

    if not arguments.pas_de_build:
        construire()
    if not arguments.pas_d_installation:
        installer(serie, arguments.apk)

    lancer(serie)

    depart = time.monotonic()
    while time.monotonic() - depart < SECONDES_DE_SURVIE:
        time.sleep(1)
        if not pid(serie):
            trace = trace_de_crash(serie)
            secondes = round(time.monotonic() - depart, 1)
            echouer(
                f"le processus est mort au bout de {secondes} s.\n\n"
                + (trace or "Aucune trace dans le tampon `crash` — voir `adb logcat`.")
            )

    if trace_de_crash(serie):
        echouer(
            "le processus tient debout mais une exception fatale a été journalisée :\n\n"
            + trace_de_crash(serie)
        )

    # L'écran éteint fausse tout ce qui suit : rien n'est composé, le compteur
    # de frames reste à zéro et l'activité n'est pas « resumed ». Le dire, et
    # non le confondre avec une panne — c'est l'erreur que ce script a commise
    # la première fois qu'il a tourné.
    if not ecran_allume(serie):
        echouer(
            "l'écran du téléphone est éteint : le processus survit, mais ni le "
            "rendu ni le premier plan ne sont vérifiables. Déverrouiller "
            "l'appareil et relancer."
        )

    frames = frames_rendues(serie)
    if frames == 0:
        echouer(
            "le processus vit et l'écran est allumé, mais aucune frame n'a été "
            "rendue — Flutter n'a jamais dessiné. Écran noir."
        )

    if not activite_au_premier_plan(serie):
        echouer(
            "le processus vit, mais l'activité n'est pas au premier plan — "
            "activité jamais reprise, ou recouverte."
        )

    print()
    print(
        f"[OK] L'application démarre, dessine ({frames} frames) et tient "
        f"{SECONDES_DE_SURVIE} s au premier plan."
    )
    print("     Ce test ne dit rien de plus : il reste à jouer une partie.")


if __name__ == "__main__":
    main()
