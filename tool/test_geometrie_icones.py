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
appareil, deux secondes de calcul.

Lancer : `python -m unittest discover -s tool -t tool`
"""

import unittest
from pathlib import Path

from make_icons import (
    PREMIER_PLAN,
    RAYON_PREMIER_PLAN,
    RAYON_SPLASH,
    SOURCE,
    SPLASH,
    canevas_pour,
    lire_png,
    rayon_maximal,
    recadrer,
)

RES = Path(__file__).resolve().parent.parent / "android/app/src/main/res"

# Les fichiers que `make_icons.py` écrit lui-même.
SOURCES = [
    (SPLASH, RAYON_SPLASH),
    (PREMIER_PLAN, RAYON_PREMIER_PLAN),
]

# `flutter_launcher_icons` décline ensuite le premier plan à chaque densité, et
# son rééchantillonnage déplace le bord opaque d'une fraction de pixel. Mesuré
# sur les cinq : entre −0,30 et +0,24 px. Un pixel de tolérance laisse quatre
# fois cette marge, et ne laisse rien passer de ce qui compte — une vraie
# régression de géométrie se compte en pourcents du côté, pas en fractions de
# pixel.
TOLERANCE_EN_PIXELS = 1.0


def rayon_relatif(chemin: Path) -> tuple[int, float]:
    largeur, hauteur, lignes = lire_png(chemin)
    assert largeur == hauteur, f"{chemin.name} n'est pas carré"
    return largeur, rayon_maximal(largeur, hauteur, lignes) / largeur


class DessinDansLeCercle(unittest.TestCase):
    """Le rayon, pas la boîte : c'est un cercle que le système découpe."""

    def test_les_fichiers_produits_sont_exactement_ce_que_le_script_recalcule(self):
        """Le seul contrôle qui rattache les sorties à `logo_mark.png`.

        Comparer le rayon à sa cible ne dit rien de deux choses : qu'un dessin
        **rétréci** passerait aussi bien — un canevas vide donne un rayon de
        zéro, donc « inférieur ou égal » —, et que le fichier versionné
        descend bien de la source d'aujourd'hui. Rejouer le calcul et comparer
        les pixels ferme les deux d'un coup.
        """
        largeur, hauteur, lignes = recadrer(*lire_png(SOURCE))
        for chemin, cible in SOURCES:
            cote, attendu = canevas_pour(largeur, hauteur, lignes, cible)
            obtenu_l, obtenu_h, obtenu = lire_png(chemin)
            self.assertEqual(
                (obtenu_l, obtenu_h),
                (cote, cote),
                msg=(
                    f"{chemin.name} fait {obtenu_l}x{obtenu_h}, le script en "
                    f"calcule {cote}x{cote}. Relancer "
                    "`python tool/make_icons.py`."
                ),
            )
            self.assertEqual(
                obtenu,
                attendu,
                msg=(
                    f"{chemin.name} ne correspond plus à {SOURCE.name}. "
                    "Relancer `python tool/make_icons.py`, puis "
                    "`dart run flutter_launcher_icons`."
                ),
            )

    def test_chaque_densite_de_l_icone_du_lanceur_tient(self):
        """Le cas « une correction appliquée à un fichier sur cinq ».

        Le premier plan est décliné en cinq densités par
        `flutter_launcher_icons`, et le test précédent ne regarde que la
        source. Régénérer celle-ci sans relancer la propagation laisserait
        quatre fichiers en arrière, et l'icône ne serait fausse que sur les
        téléphones qui piochent dans ces densités-là.
        """
        densites = sorted(RES.glob("drawable-*/ic_launcher_foreground.png"))
        self.assertEqual(len(densites), 5, msg="il en manque une, ou il y en a trop")
        for chemin in densites:
            cote, obtenu = rayon_relatif(chemin)
            marge = TOLERANCE_EN_PIXELS / cote
            ou = f"{chemin.parent.name}/{chemin.name}"
            self.assertLessEqual(
                obtenu,
                RAYON_PREMIER_PLAN + marge,
                msg=(
                    f"{ou} : rayon à {obtenu:.4f} du côté pour "
                    f"{RAYON_PREMIER_PLAN:.4f} permis. Relancer "
                    "`dart run flutter_launcher_icons`."
                ),
            )
            self.assertGreaterEqual(
                obtenu,
                RAYON_PREMIER_PLAN - marge,
                msg=(
                    f"{ou} : rayon à {obtenu:.4f}, nettement en deçà de "
                    f"{RAYON_PREMIER_PLAN:.4f}. Cette densité ne descend pas "
                    "du même dessin que les autres."
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

        La cible est la **zone sûre** de 66 dp — 33 dp de rayon —, et non le
        couperet du masque circulaire, qui est à 36. Entre les deux, ce qui
        reste visible dépend de la forme du masque du lanceur ; c'est
        l'arbitrage rendu le 24 août. Si quelqu'un touche au retrait sans
        toucher au script, ce test le rappelle.
        """
        xml = (RES / "mipmap-anydpi-v26/ic_launcher.xml").read_text(encoding="utf-8")
        self.assertIn('android:inset="16%"', xml)
        self.assertAlmostEqual(RAYON_PREMIER_PLAN, 33 / (108 * 0.68), places=6)
        self.assertLess(
            RAYON_PREMIER_PLAN,
            36 / (108 * 0.68),
            msg="la cible doit rester la zone sûre, pas le couperet",
        )


if __name__ == "__main__":
    unittest.main()
