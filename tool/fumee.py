#!/usr/bin/env python3
"""Test de fumée du build de release : l'application démarre-t-elle vraiment ?

Pourquoi un script à part, et pas un test Flutter : R8 ne tourne qu'en
release, et rien de ce qu'il casse n'est visible ailleurs. `flutter test`,
`flutter analyze`, `dart format` et le banc d'aperçus travaillent tous sur les
sources ou sur un build de debug ; la CI construit les deux mais ne lance
rien. Le premier build de release est donc, par construction, le premier à
être exercé — et il l'a été par un humain qui appuie sur l'icône.

Ce que ce script vérifie est volontairement minuscule, mais il le vérifie
pour de bon :

  - le processus survit, et c'est **le même** processus du début à la fin ;
  - aucune exception fatale native n'est journalisée pour ce pid ;
  - aucune exception Dart non interceptée n'est journalisée ;
  - l'écran est allumé, sans quoi rien de ce qui suit n'a de sens ;
  - `MainActivity` est au premier plan, et non une boîte « ne répond pas » ;
  - le paquet installé est bien un build de release.

Ce dernier point n'est pas cosmétique : sans lui, `--pas-de-build
--pas-d-installation` validerait allègrement un build de debug, c'est-à-dire
un binaire sur lequel R8 n'a jamais tourné, en affichant OK.

    python tool/fumee.py                        # construit, installe, lance
    python tool/fumee.py --apk chemin           # sur un artefact donné
    python tool/fumee.py --pas-de-build         # sans reconstruire
    python tool/fumee.py --pas-d-installation   # sur ce qui est déjà installé

**Ne pas le mettre derrière un tube.** `python tool/fumee.py | tail` rend le
code de sortie de `tail`, c'est-à-dire zéro, quoi qu'ait décidé ce script —
un `[ÉCHEC]` bien affiché et un succès pour qui lit `$?`. C'est exactement le
faux vert que tout le reste de ce fichier existe pour empêcher, et il a été
commis le 24 août. Le rediriger vers un fichier, ou lire sa sortie telle
quelle.
"""

from __future__ import annotations

import argparse
import io
import re
import shutil
import subprocess
import sys
import time

from marque import MarqueIndisponible, marque, options

# La console Windows n'est pas en UTF-8 par défaut, et les accents de ce
# script y ressortaient en mojibake — un message d'échec illisible est un
# message d'échec perdu.
for _flux in (sys.stdout, sys.stderr):
    if isinstance(_flux, io.TextIOWrapper):
        _flux.reconfigure(encoding="utf-8", errors="replace")

PAQUET = "com.twoagames.cekoi"
ACTIVITE = f"{PAQUET}/.MainActivity"
APK_PAR_DEFAUT = "build/app/outputs/flutter-apk/app-release.apk"

# Combien de temps on laisse à l'application pour se planter.
#
# Le crash qui a motivé ce script arrivait en moins d'une seconde. Dix
# secondes laissent en plus au premier écran le temps de se construire, donc
# à une exception Dart au démarrage d'être journalisée — mais **pas** de tuer
# le processus : une exception Dart non interceptée ne fait pas tomber
# l'application, elle sort en `E/flutter` sur le tampon principal. C'est pour
# ça que la survie du processus ne suffit pas, et qu'on lit aussi le journal.
SECONDES_DE_SURVIE = 10

# Ce qu'une exception Dart non interceptée écrit dans le journal.
MOTIFS_DART = ("E/flutter", "Unhandled Exception")

# Le titre des fenêtres système d'erreur contient le nom du paquet : sans les
# exclure, une application figée sur un « Cékoi ne répond pas » passerait le
# contrôle de premier plan.
FENETRES_D_ERREUR = ("Application Error", "Application Not Responding")


def echouer(message: str) -> None:
    sys.stdout.flush()
    print(f"\n[ÉCHEC] {message}", file=sys.stderr)
    sys.exit(1)


def executer(commande: list[str], **kwargs) -> subprocess.CompletedProcess:
    """Lance une commande, sans jamais laisser remonter une trace Python.

    `FileNotFoundError` est attrapée ici plutôt qu'à chaque appel : sans ça,
    un `adb` absent du PATH produisait une trace Python, et le message
    « adb est introuvable » que ce script contenait ne pouvait jamais
    s'afficher.
    """
    try:
        return subprocess.run(
            commande,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            **kwargs,
        )
    except FileNotFoundError:
        echouer(
            f"« {commande[0]} » est introuvable. Vérifier le PATH, et que les "
            "outils de la plateforme Android sont installés."
        )
        raise  # inatteignable, mais le typage ne le sait pas


def adb(serie: str | None, *arguments: str) -> str:
    prefixe = ["adb"] + (["-s", serie] if serie else [])
    return executer([*prefixe, *arguments]).stdout


def appareils_par_etat(sortie: str) -> dict[str, list[str]]:
    """Découpe la sortie d'`adb devices` par état déclaré."""
    branches: dict[str, list[str]] = {}
    for ligne in sortie.splitlines()[1:]:
        if "\t" not in ligne:
            continue
        serie, etat = ligne.strip().split("\t", 1)
        branches.setdefault(etat.strip(), []).append(serie.strip())
    return branches


def appareil() -> str:
    """Le seul appareil connecté, ou un message qui dit lequel des cas c'est."""
    branches = appareils_par_etat(adb(None, "devices"))

    # Distinguer ces cas-là n'est pas du luxe : « unauthorized » est de loin le
    # plus fréquent en vrai — le téléphone est branché et attend qu'on accepte
    # la clé RSA à l'écran —, et l'annoncer comme une absence d'appareil envoie
    # chercher un câble.
    if branches.get("unauthorized"):
        echouer(
            "l'appareil est branché mais n'a pas autorisé ce poste : accepter "
            "la clé RSA sur l'écran du téléphone, puis relancer."
        )
    if branches.get("offline"):
        echouer("l'appareil est vu mais hors ligne. Débrancher, rebrancher.")

    prets = branches.get("device", [])
    if not prets:
        echouer("aucun appareil Android connecté. Ce test demande un vrai téléphone.")
    if len(prets) > 1:
        echouer(
            f"plusieurs appareils connectés ({', '.join(prets)}) — n'en laisser qu'un."
        )
    return prets[0]


def construire() -> None:
    """Construit l'APK de release.

    `shutil.which` et non « flutter » tel quel : sous Windows, l'outil est
    `flutter.BAT`, et `CreateProcess` ne consulte pas `PATHEXT` — il ne
    cherche que le nom exact et `.exe`. Passer « flutter » à `subprocess`
    levait donc un `FileNotFoundError` avant même de toucher au téléphone, ce
    qui rendait le mode par défaut de ce script — celui que `CLAUDE.md`
    déclare obligatoire — inutilisable sur le poste de développement.
    """
    outil = shutil.which("flutter")
    if outil is None:
        echouer("« flutter » est introuvable dans le PATH.")

    # Ce script est le chemin de livraison : ce qui en sort doit pouvoir se
    # nommer. Un APK qu'on donne à quelqu'un sans savoir le désigner ramène le
    # défaut qu'on vient de fermer — « quelle version as-tu ? », sans réponse.
    try:
        options_de_marque = options(marque())
    except MarqueIndisponible as souci:
        echouer(f"build non identifiable, donc non livrable : {souci}")

    print("Construction du build de release…")
    # Sans capture : un build de release est long, et le silence pendant cinq
    # minutes ressemble trop à un blocage.
    commande = [outil, "build", "apk", "--release", *options_de_marque]
    if subprocess.run(commande).returncode != 0:
        echouer("le build de release a échoué.")


def installer(serie: str, apk: str) -> None:
    """Installe l'APK, avec un repli pour les ROM qui bloquent `adb install`.

    MIUI refuse l'installation par USB — `INSTALL_FAILED_USER_RESTRICTED`,
    « Install canceled by user », sans qu'aucun utilisateur n'ait rien annulé —
    tant qu'un réglage enfoui n'est pas activé. Pousser l'APK puis appeler
    `pm install` depuis le shell passe outre : l'installation est alors
    demandée par le shell, et non par le démon adb.

    Le repli n'est tenté que sur ce code d'erreur précis. Sur un appareil qui
    n'a pas cette restriction, il ne sert jamais.
    """
    print(f"Installation de {apk}…")
    resultat = executer(["adb", "-s", serie, "install", "-r", apk])
    if "Success" in resultat.stdout:
        return

    if "USER_RESTRICTED" not in (resultat.stdout + resultat.stderr):
        echouer(f"installation impossible :\n{resultat.stdout}\n{resultat.stderr}")

    print("  (refusée par la ROM, seconde tentative depuis le shell)")
    distant = "/data/local/tmp/cekoi-fumee.apk"
    pousse = executer(["adb", "-s", serie, "push", apk, distant])
    if pousse.returncode != 0:
        echouer(f"impossible de pousser l'APK :\n{pousse.stdout}\n{pousse.stderr}")

    shell = executer(
        ["adb", "-s", serie, "shell", "pm", "install", "--user", "0", "-r", distant]
    )
    adb(serie, "shell", "rm", "-f", distant)
    if "Success" not in shell.stdout:
        echouer(f"installation impossible :\n{shell.stdout}\n{shell.stderr}")


def refuser_un_build_de_debug(serie: str) -> None:
    """Le paquet installé doit être un build de release.

    Sans ce garde-fou, `--pas-de-build --pas-d-installation` validerait un
    build de debug : R8 n'y a jamais tourné, donc le script annoncerait OK sur
    le seul binaire dont ce test ne dit rien. Il n'y a pas
    d'`applicationIdSuffix` en debug, les deux se ressemblent donc jusqu'au
    nom.
    """
    sortie = adb(serie, "shell", "dumpsys", "package", PAQUET)
    if not sortie.strip():
        echouer(f"{PAQUET} n'est pas installé sur cet appareil.")
    if "DEBUGGABLE" in sortie:
        echouer(
            "le paquet installé est un build de DEBUG. R8 n'y a pas tourné : "
            "ce test ne prouverait rien. Installer un APK de release."
        )


def pid_courant(serie: str) -> str:
    return adb(serie, "shell", "pidof", PAQUET).strip().split(" ")[0]


def lancer(serie: str) -> str:
    """Vide les journaux, lance l'activité, et rend le pid du processus."""
    adb(serie, "logcat", "-c")
    adb(serie, "logcat", "-b", "crash", "-c")
    adb(serie, "shell", "am", "force-stop", PAQUET)

    print("Lancement…")
    # `-W` attend que le lancement soit terminé : sans lui, le premier sondage
    # du pid pouvait tomber avant que le processus n'existe.
    sortie = adb(serie, "shell", "am", "start", "-W", "-n", ACTIVITE)
    if "Error" in sortie:
        echouer(f"l'activité n'a pas démarré :\n{sortie}")

    pid = pid_courant(serie)
    if not pid:
        echouer(f"le processus n'existe pas après le lancement :\n{sortie}")
    return pid


def bloc_de_crash(journal: str, pid: str) -> str:
    """Le dernier bloc `FATAL EXCEPTION` **de ce processus**.

    Filtré sur le pid, et pas seulement sur le nom du paquet : `logcat -c` est
    refusé par certaines ROM, et un crash de la veille encore dans le tampon
    ferait alors échouer un build parfaitement sain.
    """
    blocs = [b for b in journal.split("FATAL EXCEPTION") if f"PID: {pid}" in b]
    return ("FATAL EXCEPTION" + blocs[-1]).strip() if blocs else ""


def trace_de_crash(serie: str, pid: str) -> str:
    return bloc_de_crash(adb(serie, "logcat", "-b", "crash", "-d"), pid)


def lignes_dart(journal: str) -> list[str]:
    """Les exceptions Dart non interceptées présentes dans un journal.

    Une exception Dart ne tue pas le processus et n'écrit rien dans le tampon
    `crash` : elle sort en `E/flutter` sur le tampon principal. Un démarrage
    où `main()` explose avant `runApp` laisse donc un processus vivant et une
    fenêtre vide — le genre de panne que la seule survie du processus ne voit
    pas, et que le compteur de frames ne voit pas davantage.
    """
    return [
        ligne
        for ligne in journal.splitlines()
        if any(motif in ligne for motif in MOTIFS_DART)
    ]


def erreurs_dart(serie: str) -> str:
    return "\n".join(lignes_dart(adb(serie, "logcat", "-d"))[:20])


def ecran_est_allume(dump_display: str) -> bool:
    return "mScreenState=ON" in dump_display


def ecran_allume(serie: str) -> bool:
    return ecran_est_allume(adb(serie, "shell", "dumpsys", "display"))


def nombre_de_frames(dump_gfxinfo: str) -> int | None:
    """Le nombre de frames que HWUI a comptées pour ce paquet.

    Rend `None` quand le dump n'a pas de section exploitable, ce qui n'est pas
    la même chose que zéro — l'assimiler à zéro annonçait « rien n'a été
    composé » sur un appareil dont le format de dump diffère.

    **Ce compteur ne prouve pas que Flutter a dessiné.** Flutter rend dans une
    `SurfaceView` dédiée, hors HWUI ; ce que HWUI compte ici, c'est la
    hiérarchie de vues de l'activité et le fond de fenêtre du `LaunchTheme`.
    Une application dont `main()` explose avant `runApp` laisse donc un
    compteur non nul. Il reste utile — à zéro, rien n'a été composé du tout —
    mais c'est `lignes_dart` qui attrape le démarrage raté.
    """
    trouve = re.search(r"Total frames rendered:\s*(\d+)", dump_gfxinfo)
    return int(trouve.group(1)) if trouve else None


def frames_rendues(serie: str) -> int | None:
    return nombre_de_frames(adb(serie, "shell", "dumpsys", "gfxinfo", PAQUET))


def est_au_premier_plan(dump_window: str, dump_activities: str) -> tuple[bool, str]:
    """`MainActivity` est-elle au premier plan — et non une boîte d'erreur ?

    Le nom du champ a bougé d'une version d'Android à l'autre —
    `mResumedActivity`, `ResumedActivity:`, `topResumedActivity=` — et s'être
    accroché à une seule de ces graphies a fait échouer ce test sur une
    application parfaitement au premier plan.

    Le repli sur la fenêtre au focus, lui, demande `MainActivity` et pas
    seulement le nom du paquet : le titre des fenêtres « ne répond pas » et
    « s'est arrêtée » contient le paquet, si bien qu'une application figée au
    démarrage cochait le contrôle.
    """
    for ligne in dump_window.splitlines():
        if "mCurrentFocus" not in ligne or PAQUET not in ligne:
            continue
        for fenetre in FENETRES_D_ERREUR:
            if fenetre in ligne:
                return False, ligne.strip()

    motif = rf"{re.escape(PAQUET)}/[\w.]*MainActivity"
    if re.search(rf"ResumedActivity[=:\s].*{motif}", dump_activities):
        return True, ""
    if re.search(rf"mCurrentFocus.*{motif}", dump_window):
        return True, ""
    return False, "MainActivity n'est ni reprise ni au focus."


def premier_plan(serie: str) -> tuple[bool, str]:
    return est_au_premier_plan(
        adb(serie, "shell", "dumpsys", "window"),
        adb(serie, "shell", "dumpsys", "activity", "activities"),
    )


def main() -> None:
    analyseur = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    analyseur.add_argument("--apk", default=APK_PAR_DEFAUT)
    analyseur.add_argument(
        "--pas-de-build", action="store_true", help="ne pas reconstruire l'APK"
    )
    analyseur.add_argument(
        "--pas-d-installation",
        action="store_true",
        help="vérifier ce qui est déjà installé sur l'appareil",
    )
    arguments = analyseur.parse_args()

    serie = appareil()
    print(f"Appareil : {serie}")

    if not arguments.pas_de_build:
        construire()
    if not arguments.pas_d_installation:
        installer(serie, arguments.apk)

    refuser_un_build_de_debug(serie)
    pid = lancer(serie)
    print(f"Processus : {pid}")

    depart = time.monotonic()
    while time.monotonic() - depart < SECONDES_DE_SURVIE:
        time.sleep(1)
        courant = pid_courant(serie)
        if courant != pid:
            trace = trace_de_crash(serie, pid)
            secondes = round(time.monotonic() - depart, 1)
            mort = "est mort" if not courant else f"est mort et relancé ({courant})"
            echouer(
                f"le processus {mort} au bout de {secondes} s.\n\n"
                + (trace or "Aucune trace dans le tampon `crash` — voir `adb logcat`.")
            )

    trace = trace_de_crash(serie, pid)
    if trace:
        echouer(
            "le processus tient debout mais une exception fatale a été "
            f"journalisée :\n\n{trace}"
        )

    dart = erreurs_dart(serie)
    if dart:
        echouer(
            "le processus vit, mais Dart a journalisé une exception non "
            f"interceptée — l'application a démarré sans fonctionner :\n\n{dart}"
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

    if frames_rendues(serie) == 0:
        echouer(
            "le processus vit et l'écran est allumé, mais rien n'a été composé "
            "pour ce paquet. Écran noir."
        )

    au_premier_plan, pourquoi = premier_plan(serie)
    if not au_premier_plan:
        echouer(f"MainActivity n'est pas au premier plan — {pourquoi}")

    print()
    print(
        f"[OK] MainActivity démarre et tient {SECONDES_DE_SURVIE} s au premier "
        "plan, sans exception native ni Dart."
    )
    print("     Ce test ne dit rien de plus : il reste à jouer une partie.")


if __name__ == "__main__":
    main()
