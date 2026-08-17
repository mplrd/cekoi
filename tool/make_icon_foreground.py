"""Fabrique le premier plan des icônes à partir du dessin détouré.

    python tool/make_icon_foreground.py

Puis, pour propager aux ressources Android et iOS :

    dart run flutter_launcher_icons

Le problème que ça corrige
--------------------------

`assets/branding/logo_foreground.png` était le logo **à fond perdu**, fond
corail compris — ses quatre coins sont opaques. Or les deux endroits qui le
consomment n'en montrent que le disque central :

* le lanceur masque une icône adaptative, souvent en cercle, et n'en garde de
  façon garantie que les deux tiers centraux (72 dp sur 108) ;
* depuis Android 12, l'écran de démarrage du système fait de même avec
  `windowSplashScreenAnimatedIcon` (160 dp sur 240).

Le dessin y perdait donc la bulle, la carte « 1 » et les jambes du coureur, et
son carré corail devenait un disque corail posé sur le corail du fond.

Ce que fait ce script
---------------------

Il pose `logo_mark.png` — le dessin **détourné**, sans fond — au centre d'un
canevas transparent assez grand pour qu'il occupe ces deux tiers.

Aucun rééchantillonnage : on n'ajoute que du vide. Redimensionner ici aurait
fait deux interpolations successives, la nôtre puis celle de
`flutter_launcher_icons` qui décline ensuite chaque densité. Une seule vaut
mieux, et c'est la sienne.
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

BRANDING = Path(__file__).resolve().parent.parent / "assets" / "branding"
SOURCE = BRANDING / "logo_mark.png"
CIBLE = BRANDING / "logo_foreground.png"

# La part du canevas que le dessin peut occuper sans risquer le masque.
# 72/108 pour l'icône adaptative, 160/240 pour le splash d'Android 12 : le même
# nombre des deux côtés, ce qui permet un seul fichier pour les deux usages.
ZONE_SURE = 2 / 3


def lire_png(chemin: Path) -> tuple[int, int, list[bytes]]:
    """Décode un PNG RVBA 8 bits en lignes de pixels."""
    data = chemin.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{chemin} n'est pas un PNG"

    pos, idat = 8, b""
    largeur = hauteur = couleur = 0
    while pos < len(data):
        (taille,) = struct.unpack(">I", data[pos : pos + 4])
        nom = data[pos + 4 : pos + 8]
        corps = data[pos + 8 : pos + 8 + taille]
        if nom == b"IHDR":
            largeur, hauteur, profondeur, couleur = struct.unpack(">IIBB", corps[:10])
            assert profondeur == 8, "profondeur autre que 8 bits non gérée"
        elif nom == b"IDAT":
            idat += corps
        pos += 12 + taille

    assert couleur == 6, "il faut un PNG RVBA — le dessin doit être détouré"

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
    # transparent, zlib s'en occupe mieux que n'importe quel prédicteur.
    donnees = b"".join(b"\x00" + ligne for ligne in lignes)
    chemin.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + bloc(b"IHDR", struct.pack(">IIBBBBB", largeur, hauteur, 8, 6, 0, 0, 0))
        + bloc(b"IDAT", zlib.compress(donnees, 9))
        + bloc(b"IEND", b"")
    )


def main() -> None:
    largeur, hauteur, lignes = lire_png(SOURCE)

    # Le canevas se déduit du plus grand côté du dessin : c'est lui qui touche
    # le bord de la zone sûre.
    cote = round(max(largeur, hauteur) / ZONE_SURE)
    if cote % 2:
        cote += 1

    marge_g = (cote - largeur) // 2
    marge_h = (cote - hauteur) // 2
    vide = bytes(cote * 4)
    creux = bytes(marge_g * 4)

    sortie = [vide] * marge_h
    for ligne in lignes:
        reste = bytes((cote - largeur - marge_g) * 4)
        sortie.append(creux + ligne + reste)
    sortie += [vide] * (cote - hauteur - marge_h)

    ecrire_png(CIBLE, cote, cote, sortie)

    print(f"{SOURCE.name} : {largeur}x{hauteur}")
    print(f"{CIBLE.name} : {cote}x{cote}")
    print(
        f"le dessin occupe {largeur / cote:.0%} de la largeur "
        f"et {hauteur / cote:.0%} de la hauteur"
    )
    print("\nÀ enchaîner : dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()
