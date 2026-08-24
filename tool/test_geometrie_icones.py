"""Le dessin des icônes doit tenir dans le cercle que le système découpe.

Le défaut que ces assertions ferment a tenu six jours sans se voir, et il ne
pouvait pas se voir : la forme réellement découpée est décidée par le lanceur
de l'appareil, et celui du téléphone de test est un carré arrondi qui laissait
presque tout passer. Un masque circulaire, lui, décapitait la bulle et
tranchait la carte « 1 ».

La marge était calculée sur la **boîte** du dessin — les deux tiers du côté
pour l'écran de démarrage, rien du tout pour le premier plan de l'icône
adaptative, qui comptait sur le retrait de 16 %. Les deux raisonnements
supposaient un dessin tenant dans le cercle inscrit de sa boîte ; celui de
Cékoi remplit ses coins, et un carré déborde de 41 % du cercle qu'il contient.

Rien d'autre ne l'attrape. `flutter analyze` ne lit pas les PNG, le banc
d'aperçus rend l'arbre de widgets Flutter, et la CI ne regarde aucune image.

Bibliothèque standard uniquement, comme `make_icons.py` : ni Pillow ni
appareil, une seconde de calcul.

Lancer : `python -m unittest discover -s tool -t tool`
"""

import unittest
from pathlib import Path

from make_icons import (
    PREMIER_PLAN,
    RAYON_PREMIER_PLAN,
    RAYON_SPLASH,
    SPLASH,
    lire_png,
    rayon_maximal,
)

RES = Path(__file__).resolve().parent.parent / "android/app/src/main/res"

# Les fichiers que `make_icons.py` écrit lui-même : la garantie y est exacte,
# le script remesure son résultat avant de l'écrire.
SOURCES = [
    (SPLASH, RAYON_SPLASH),
    (PREMIER_PLAN, RAYON_PREMIER_PLAN),
]

# `flutter_launcher_icons` décline ensuite le premier plan à chaque densité, et
# son rééchantillonnage laisse une auréole d'un fragment de pixel au-delà du
# bord opaque. Mesuré : +0,32 % du rayon au pire, en mdpi, soit un sixième de
# pixel. Un pixel de tolérance l'absorbe sans rien laisser passer de ce qui
# compte — une vraie régression de géométrie se compte en pourcents du côté,
# pas en fractions de pixel.
TOLERANCE_EN_PIXELS = 1.0


class DessinDansLeCercle(unittest.TestCase):
    """Le rayon, pas la boîte : c'est un cercle que le système découpe."""

    def rayon_relatif(self, chemin: Path) -> float:
        largeur, hauteur, lignes = lire_png(chemin)
        self.assertEqual(largeur, hauteur, msg=f"{chemin.name} n'est pas carré")
        return rayon_maximal(largeur, hauteur, lignes) / largeur

    def test_les_fichiers_produits_par_le_script_tiennent_exactement(self):
        for chemin, cible in SOURCES:
            obtenu = self.rayon_relatif(chemin)
            self.assertLessEqual(
                obtenu,
                cible,
                msg=(
                    f"{chemin.name} : rayon à {obtenu:.4f} du côté pour "
                    f"{cible:.4f} permis. Relancer `python tool/make_icons.py`."
                ),
            )

    def test_chaque_densite_de_l_icone_du_lanceur_tient(self):
        """Le cas « une correction appliquée à un fichier sur cinq ».

        Le premier plan est décliné en cinq densités par
        `flutter_launcher_icons`. Régénérer la source sans relancer la
        propagation laisse quatre fichiers en arrière, et l'icône n'est fausse
        que sur les téléphones qui piochent dans ces densités-là.
        """
        densites = sorted(RES.glob("drawable-*/ic_launcher_foreground.png"))
        self.assertEqual(len(densites), 5, msg="il en manque une, ou il y en a trop")
        for chemin in densites:
            largeur, hauteur, lignes = lire_png(chemin)
            marge = TOLERANCE_EN_PIXELS / largeur
            obtenu = rayon_maximal(largeur, hauteur, lignes) / largeur
            self.assertLessEqual(
                obtenu,
                RAYON_PREMIER_PLAN + marge,
                msg=(
                    f"{chemin.parent.name}/{chemin.name} : rayon à "
                    f"{obtenu:.4f} du côté pour {RAYON_PREMIER_PLAN:.4f} "
                    f"permis. Relancer `dart run flutter_launcher_icons`."
                ),
            )


class CiblesCoherentes(unittest.TestCase):
    """Les deux cibles viennent de deux mécanismes différents.

    Les confondre est précisément l'erreur qui a produit le défaut : une seule
    constante servait aux deux, alors que l'un des consommateurs applique un
    retrait et pas l'autre.
    """

    def test_le_splash_est_masque_sans_retrait(self):
        """Deux tiers du diamètre, donc un tiers du côté en rayon."""
        self.assertAlmostEqual(RAYON_SPLASH, 1 / 3, places=6)

    def test_le_premier_plan_passe_par_le_retrait_de_l_icone_adaptative(self):
        """`ic_launcher.xml` pose 16 % : l'image tombe sur 73,44 dp des 108.

        Le masque coupe à 36 dp de rayon. Si quelqu'un touche à ce retrait sans
        toucher au script, ce test le rappelle.
        """
        xml = (RES / "mipmap-anydpi-v26/ic_launcher.xml").read_text(encoding="utf-8")
        self.assertIn('android:inset="16%"', xml)
        self.assertAlmostEqual(RAYON_PREMIER_PLAN, 36 / (108 * 0.68), places=6)


if __name__ == "__main__":
    unittest.main()
