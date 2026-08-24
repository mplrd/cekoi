#!/usr/bin/env python3
"""Fabrique les images d'icône à partir du dessin détouré.

    python tool/make_icons.py
    dart run flutter_launcher_icons   # propage le premier plan aux densités

Deux fichiers, parce que les deux consommateurs n'ont pas les mêmes attentes.
Mais ils masquent tous les deux sur un **cercle**, et c'est ce qui décide de
la marge : elle se calcule sur le rayon du dessin, jamais sur sa boîte.

* `assets/branding/logo_foreground.png` — le premier plan de l'icône
  adaptative, que `mipmap-anydpi-v26/ic_launcher.xml` pose avec un retrait de
  16 %. L'image atterrit donc sur 73,44 dp des 108 de la couche.

  Deux seuils s'y appliquent, et ils ne disent pas la même chose. Le masque
  **circulaire** coupe à 36 dp de rayon, mais tous les masques ne sont pas des
  cercles : un masque cylindre est plus étroit sur un axe. La zone que **tout**
  masque conforme laisse voir est un cercle de 66 dp, soit 33 dp de rayon —
  c'est celle qu'on vise, sur arbitrage du 24 août. Ce qui vit entre 66 et
  72 dp ne dépendrait que de la forme du lanceur, et c'est précisément ce que
  ce correctif existe pour supprimer.

* `android/.../drawable-xxxhdpi/splash_icon.png` — l'icône de l'écran de
  démarrage d'Android 12, qui consomme le drawable **brut**, sans retrait.
  Elle porte toute sa marge elle-même : le système ne montre de façon garantie
  que les deux tiers centraux **en diamètre**, soit `1/3 × côté` en rayon.

Le problème que ça corrige
--------------------------

Deux fois de suite, la marge a été calculée sur le mauvais objet.

D'abord `logo_foreground.png` était le logo **à fond perdu**, fond corail
compris — ses quatre coins étaient opaques. Sur l'icône du lanceur ça passait,
le fond de l'icône adaptative étant ce même corail. Mais
`windowSplashScreenAnimatedIcon` s'en sert tel quel : le dessin y perdait la
bulle, la carte « 1 » et les jambes du coureur, et le carré corail devenait un
disque corail posé sur le corail du fond.

Le correctif d'alors a donné au splash une marge des deux tiers du **côté**,
et laissé le premier plan sans marge du tout — le retrait de 16 % était censé
suffire. Les deux raisonnements supposaient un dessin tenant dans le cercle
inscrit de sa boîte. Le nôtre remplit ses coins : mesuré, son rayon atteignait
0,4035 du côté sur le splash pour 0,3333 permis, et 0,6042 sur le premier plan
pour 0,4902. Rien ne le signalait, parce que la forme réellement découpée est
décidée par l'appareil et que le carré arrondi du téléphone de test laissait
presque tout passer.

D'où la règle appliquée ici : **mesurer le rayon du dessin, et dimensionner le
canevas pour que ce rayon tombe exactement sur le cercle du consommateur.** Le
script vérifie ensuite son propre résultat plutôt que de le supposer.

Aucun rééchantillonnage ici : on n'ajoute que du vide. Redimensionner aurait
fait deux interpolations successives, la nôtre puis celle de
`flutter_launcher_icons` qui décline ensuite chaque densité. Une seule vaut
mieux, et c'est la sienne.

Une nuisance connue de l'étape suivante : `flutter_launcher_icons` réécrit
`android/.../values/colors.xml` et lui retire son saut de ligne final. Le
remettre avant de committer, sinon le diff porte une ligne qui n'a rien à voir
avec le changement.
"""

from __future__ import annotations

import math
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

# Le rayon que le dessin ne doit pas dépasser, en fraction du côté du canevas.
#
# Écran de démarrage : le système ne montre de façon garantie que les deux
# tiers centraux en **diamètre**, donc un tiers en rayon.
RAYON_SPLASH = 1 / 3

# Icône adaptative : `ic_launcher.xml` pose un retrait de 16 %, l'image
# atterrit sur 108 × 0,68 = 73,44 dp. On vise la zone sûre documentée — un
# cercle de 66 dp, donc 33 dp de rayon — et non le couperet du masque
# circulaire, qui est à 36 dp : entre les deux, ce qui reste visible dépend de
# la forme du masque du lanceur.
RAYON_PREMIER_PLAN = 33 / (108 * 0.68)

# En deçà, on considère le pixel transparent. Le dessin est détouré sans
# anticrénelage, donc le seuil ne change rien au résultat — il est là pour que
# la mesure reste juste si un jour le dessin arrive avec un bord adouci.
SEUIL_ALPHA = 8


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


def recadrer(
    largeur: int, hauteur: int, lignes: list[bytes]
) -> tuple[int, int, list[bytes]]:
    """Réduit le dessin à sa boîte opaque.

    Sans ça, tout le reste se mesure depuis le centre du **canevas** source et
    non depuis celui du dessin. Une source ré-exportée avec un peu de marge
    transparente — ce que produit à peu près n'importe quel export depuis le
    SVG — sortirait alors un dessin à la fois décentré et inutilement petit,
    sans que rien ne le signale. Aujourd'hui la marque est détourée au plus
    juste et ce recadrage ne fait rien ; il est là pour le jour où elle ne le
    sera plus.
    """
    gauche, droite, haut, bas = largeur, -1, hauteur, -1
    for y, ligne in enumerate(lignes):
        for x in range(largeur):
            if ligne[x * 4 + 3] > SEUIL_ALPHA:
                gauche = min(gauche, x)
                droite = max(droite, x)
                haut = min(haut, y)
                bas = max(bas, y)

    if droite < 0:
        raise FormatInattendu("le dessin est entièrement transparent")
    if (gauche, haut, droite, bas) == (0, 0, largeur - 1, hauteur - 1):
        return largeur, hauteur, lignes

    print(
        f"  recadré sur sa boîte opaque : "
        f"{largeur}x{hauteur} → {droite - gauche + 1}x{bas - haut + 1}"
    )
    return (
        droite - gauche + 1,
        bas - haut + 1,
        [ligne[gauche * 4 : (droite + 1) * 4] for ligne in lignes[haut : bas + 1]],
    )


def rayon_maximal(largeur: int, hauteur: int, lignes: list[bytes]) -> float:
    """Distance, en pixels, du centre au pixel opaque le plus lointain.

    C'est la seule mesure qui compte : le masque du système est un cercle, et
    la boîte englobante du dessin ne dit rien de ce qui en sort. Un dessin qui
    remplit les coins de sa boîte déborde de 41 % du cercle inscrit.
    """
    cx, cy = (largeur - 1) / 2, (hauteur - 1) / 2
    pire = 0.0
    for y, ligne in enumerate(lignes):
        for x in range(largeur):
            if ligne[x * 4 + 3] > SEUIL_ALPHA:
                rayon = math.hypot(x - cx, y - cy)
                pire = max(pire, rayon)
    return pire


def canevas_pour(
    largeur: int, hauteur: int, lignes: list[bytes], cible: float
) -> tuple[int, list[bytes]]:
    """Le plus petit carré qui fait tenir le dessin dans [cible], et son contenu.

    Le résultat est **remesuré**, et non déduit du calcul : quand le canevas et
    le dessin n'ont pas la même parité, le centrage tombe sur un demi-pixel, ce
    qui suffit à faire déborder un carré calculé au plus juste. C'est
    exactement le genre d'écart qu'on ne voit jamais à l'œil.

    Fonction pure, pour que le test puisse rejouer le calcul et comparer au
    fichier versionné — sinon rien ne rattache l'un à l'autre.
    """
    rayon = rayon_maximal(largeur, hauteur, lignes)
    cote = max(math.ceil(rayon / cible), largeur, hauteur)
    for _ in range(4):
        carre = centrer(largeur, hauteur, lignes, cote)
        if rayon_maximal(cote, cote, carre) / cote <= cible:
            return cote, carre
        cote += 1
    raise FormatInattendu(f"le canevas ne converge pas vers {cible}")


def poser_dans_le_cercle(
    chemin: Path,
    largeur: int,
    hauteur: int,
    lignes: list[bytes],
    cible: float,
) -> None:
    """Écrit le dessin centré sur le carré que [canevas_pour] a calculé."""
    cote, carre = canevas_pour(largeur, hauteur, lignes, cible)
    ecrire_png(chemin, cote, cote, carre)
    print(
        f"{chemin.name} : {cote}x{cote} — dessin sur "
        f"{hauteur / cote:.1%} de la hauteur, rayon à "
        f"{rayon_maximal(cote, cote, carre) / cote:.4f} du côté pour "
        f"{cible:.4f} permis"
    )


def main() -> int:
    brut_l, brut_h, brut = lire_png(SOURCE)
    print(f"{SOURCE.name} : {brut_l}x{brut_h}")
    largeur, hauteur, lignes = recadrer(brut_l, brut_h, brut)
    print(f"  rayon du dessin : {rayon_maximal(largeur, hauteur, lignes):.1f} px")

    poser_dans_le_cercle(PREMIER_PLAN, largeur, hauteur, lignes, RAYON_PREMIER_PLAN)
    poser_dans_le_cercle(SPLASH, largeur, hauteur, lignes, RAYON_SPLASH)

    print("\nÀ enchaîner : dart run flutter_launcher_icons")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except FormatInattendu as erreur:
        print(f"Erreur : {erreur}", file=sys.stderr)
        sys.exit(1)
