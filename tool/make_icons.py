#!/usr/bin/env python3
"""Fabrique les images d'icône à partir du dessin détouré.

    python tool/make_icons.py
    dart run flutter_launcher_icons   # propage le premier plan aux densités

Deux fichiers, parce que les deux consommateurs n'ont pas les mêmes attentes :

* `assets/branding/logo_foreground.png` — le premier plan de l'icône
  adaptative. **Sans marge** : `mipmap-anydpi-v26/ic_launcher.xml` applique
  déjà le retrait de 16 % de l'icône adaptative, et en ajouter une seconde
  rapetisse le dessin d'un tiers sans que rien ne le signale.

* `android/.../drawable-xxxhdpi/splash_icon.png` — l'icône de l'écran de
  démarrage d'Android 12, qui consomme le drawable **brut**, sans retrait.
  Elle porte donc sa marge elle-même : le système n'affiche de façon garantie
  que les deux tiers centraux (160 dp sur 240).

Le problème que ça corrige
--------------------------

`logo_foreground.png` était le logo **à fond perdu**, fond corail compris —
ses quatre coins étaient opaques. Sur l'icône du lanceur, ça passait : le fond
de l'icône adaptative est ce même corail, la jointure ne se voyait pas. Mais
`windowSplashScreenAnimatedIcon` s'en sert tel quel, et le système en masque
le pourtour : le dessin y perdait la bulle, la carte « 1 » et les jambes du
coureur, et le carré corail devenait un disque corail posé sur le corail du
fond.

Aucun rééchantillonnage ici : on n'ajoute que du vide. Redimensionner aurait
fait deux interpolations successives, la nôtre puis celle de
`flutter_launcher_icons` qui décline ensuite chaque densité. Une seule vaut
mieux, et c'est la sienne.
"""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
SOURCE = RACINE / "assets" / "branding" / "logo_mark.png"
PREMIER_PLAN = RACINE / "assets" / "branding" / "logo_foreground.png"
SPLASH = (
    RACINE
    / "android"
    / "app"
    / "src"
    / "main"
    / "res"
    / "drawable-xxxhdpi"
    / "splash_icon.png"
)

# La part du canevas que le dessin peut occuper sans risquer le masque du
# système, pour l'écran de démarrage d'Android 12 : 160 dp sur 240.
ZONE_SURE = 2 / 3


class FormatInattendu(Exception):
    """Le PNG d'entrée n'est pas de la forme que ce script sait lire."""


def lire_png(chemin: Path) -> tuple[int, int, list[bytes]]:
    """Décode un PNG RVBA 8 bits non entrelacé en lignes de pixels."""
    data = chemin.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise FormatInattendu(f"{chemin} n'est pas un PNG")

    pos, idat = 8, b""
    largeur = hauteur = couleur = 0
    profondeur = entrelace = 0
    while pos < len(data):
        (taille,) = struct.unpack(">I", data[pos : pos + 4])
        nom = data[pos + 4 : pos + 8]
        corps = data[pos + 8 : pos + 8 + taille]
        if nom == b"IHDR":
            largeur, hauteur, profondeur, couleur = struct.unpack(">IIBB", corps[:10])
            entrelace = corps[12]
        elif nom == b"IDAT":
            idat += corps
        pos += 12 + taille

    if profondeur != 8:
        raise FormatInattendu(f"{chemin} : {profondeur} bits par canal, il en faut 8")
    if couleur != 6:
        raise FormatInattendu(
            f"{chemin} : il faut un PNG RVBA — le dessin doit être détouré"
        )
    if entrelace:
        # Sans ce contrôle, un PNG entrelacé se décoderait en bouillie, et le
        # script écrirait tranquillement une icône illisible.
        raise FormatInattendu(f"{chemin} est entrelacé, ce que ce script ne lit pas")

    brut = zlib.decompress(idat)
    pas = largeur * 4
    lignes: list[bytes] = []
    precedente = bytearray(pas)
    pos = 0
    for _ in range(hauteur):
        filtre, pos = brut[pos], pos + 1
        ligne = bytearray(brut[pos : pos + pas])
        pos += pas
        for i in range(pas):
            a = ligne[i - 4] if i >= 4 else 0
            b = precedente[i]
            c = precedente[i - 4] if i >= 4 else 0
            if filtre == 1:
                ligne[i] = (ligne[i] + a) & 0xFF
            elif filtre == 2:
                ligne[i] = (ligne[i] + b) & 0xFF
            elif filtre == 3:
                ligne[i] = (ligne[i] + (a + b) // 2) & 0xFF
            elif filtre == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                ligne[i] = (ligne[i] + pr) & 0xFF
        lignes.append(bytes(ligne))
        precedente = ligne
    return largeur, hauteur, lignes


def ecrire_png(chemin: Path, largeur: int, hauteur: int, lignes: list[bytes]) -> None:
    def bloc(nom: bytes, corps: bytes) -> bytes:
        return (
            struct.pack(">I", len(corps))
            + nom
            + corps
            + struct.pack(">I", zlib.crc32(nom + corps) & 0xFFFFFFFF)
        )

    # Filtre 0 sur chaque ligne : le canevas est très majoritairement
    # transparent, zlib s'en sort mieux que n'importe quel prédicteur.
    donnees = b"".join(b"\x00" + ligne for ligne in lignes)
    chemin.parent.mkdir(parents=True, exist_ok=True)
    chemin.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + bloc(b"IHDR", struct.pack(">IIBBBBB", largeur, hauteur, 8, 6, 0, 0, 0))
        + bloc(b"IDAT", zlib.compress(donnees, 9))
        + bloc(b"IEND", b"")
    )


def centrer(
    largeur: int, hauteur: int, lignes: list[bytes], cote: int
) -> list[bytes]:
    """Pose le dessin au centre d'un carré transparent de [cote] pixels."""
    if cote < largeur or cote < hauteur:
        raise FormatInattendu(f"canevas de {cote} px trop petit pour le dessin")

    marge_g = (cote - largeur) // 2
    marge_h = (cote - hauteur) // 2
    vide = bytes(cote * 4)
    gauche = bytes(marge_g * 4)
    droite = bytes((cote - largeur - marge_g) * 4)

    return (
        [vide] * marge_h
        + [gauche + ligne + droite for ligne in lignes]
        + [vide] * (cote - hauteur - marge_h)
    )


def main() -> int:
    largeur, hauteur, lignes = lire_png(SOURCE)
    grand = max(largeur, hauteur)
    print(f"{SOURCE.name} : {largeur}x{hauteur}")

    # Le premier plan : le dessin au plus près des bords, la marge viendra du
    # retrait de 16 % de l'icône adaptative.
    ecrire_png(PREMIER_PLAN, grand, grand, centrer(largeur, hauteur, lignes, grand))
    print(
        f"{PREMIER_PLAN.name} : {grand}x{grand} — "
        f"dessin sur {hauteur / grand:.0%} de la hauteur, sans marge"
    )

    # Le splash : la marge des deux tiers, portée par l'image elle-même.
    cote = round(grand / ZONE_SURE)
    ecrire_png(SPLASH, cote, cote, centrer(largeur, hauteur, lignes, cote))
    print(
        f"{SPLASH.name} : {cote}x{cote} — "
        f"dessin sur {hauteur / cote:.0%} de la hauteur, marge du masque comprise"
    )

    print("\nÀ enchaîner : dart run flutter_launcher_icons")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except FormatInattendu as erreur:
        print(f"Erreur : {erreur}", file=sys.stderr)
        sys.exit(1)
