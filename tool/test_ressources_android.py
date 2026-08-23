"""Les variantes de configuration Android ne doivent pas diverger en silence.

Trois fois en une journée, le même défaut : une correction appliquée à un
fichier sur deux. Le dernier en date a envoyé un écran de démarrage rogné sur
un téléphone pendant six jours, invisible en journée parce que la variante
claire, elle, avait été corrigée — le défaut ne sortait qu'au basculement
automatique en thème sombre.

Rien ne pouvait l'attraper. `flutter analyze` ne lit pas `android/res`, et le
banc d'aperçus de `tool/apercus/` rend l'arbre de widgets Flutter : le splash
d'Android 12 est dessiné par le système, dans une fenêtre qui existe avant la
première frame, à partir d'un XML que le processus Dart ne lit jamais.

Ces assertions-ci ne demandent ni appareil ni build, et tiennent en une
seconde. Bibliothèque standard uniquement.

Lancer : `python -m unittest discover -s tool -t tool`
"""

import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

RES = Path(__file__).resolve().parent.parent / "android/app/src/main/res"

# Les couples de variantes qui doivent rester alignés. Le thème parent est le
# seul point sur lequel ils ont le droit de differer : l'application n'a qu'un
# seul visage, clair, quel que soit le réglage du système.
COUPLES = [
    ("values", "values-night"),
    ("values-v31", "values-night-v31"),
]


def styles(dossier: str) -> dict[str, dict[str, str]]:
    """Les styles d'un `styles.xml`, sous forme {style: {attribut: valeur}}."""
    racine = ET.parse(RES / dossier / "styles.xml").getroot()
    return {
        style.get("name"): {
            item.get("name"): (item.text or "").strip() for item in style.findall("item")
        }
        for style in racine.findall("style")
    }


def parents(dossier: str) -> dict[str, str]:
    racine = ET.parse(RES / dossier / "styles.xml").getroot()
    return {style.get("name"): style.get("parent") for style in racine.findall("style")}


class VariantesAlignees(unittest.TestCase):
    """Le défaut du 17 août : `values-v31` corrigé, `values-night-v31` oublié."""

    def test_les_memes_styles_de_part_et_d_autre(self):
        for clair, sombre in COUPLES:
            self.assertEqual(
                set(styles(clair)), set(styles(sombre)), msg=f"{clair} / {sombre}"
            )

    def test_les_memes_attributs_avec_les_memes_valeurs(self):
        for clair, sombre in COUPLES:
            for nom, attributs in styles(clair).items():
                self.assertEqual(
                    attributs,
                    styles(sombre)[nom],
                    msg=(
                        f"{nom} diverge entre {clair} et {sombre}. Seul le thème "
                        "parent a le droit de differer."
                    ),
                )

    def test_seul_le_parent_differe(self):
        """La divergence autorisée est bien là, et elle est la seule."""
        for clair, sombre in COUPLES:
            for nom, parent in parents(clair).items():
                self.assertIn("Light", parent, msg=f"{clair}/{nom}")
                self.assertIn("Black", parents(sombre)[nom], msg=f"{sombre}/{nom}")


class ReferencesResolues(unittest.TestCase):
    """Un `@drawable` ou un `@color` qui ne résout pas ne se voit qu'au build."""

    def references(self):
        for dossier in RES.glob("values*"):
            fichier = dossier / "styles.xml"
            if not fichier.exists():
                continue
            for style in ET.parse(fichier).getroot().findall("style"):
                for item in style.findall("item"):
                    valeur = (item.text or "").strip()
                    if valeur.startswith("@drawable/") or valeur.startswith("@color/"):
                        yield fichier, valeur

    def test_chaque_reference_existe(self):
        couleurs = {
            couleur.get("name")
            for fichier in RES.glob("values*/colors.xml")
            for couleur in ET.parse(fichier).getroot().findall("color")
        }
        for fichier, valeur in self.references():
            genre, nom = valeur[1:].split("/", 1)
            if genre == "color":
                self.assertIn(nom, couleurs, msg=f"{fichier} → {valeur}")
            else:
                trouve = list(RES.glob(f"drawable*/{nom}.*"))
                self.assertTrue(trouve, msg=f"{fichier} → {valeur} : aucun fichier")


class IconeDeDemarrage(unittest.TestCase):
    """`splash_icon` est le drawable que le système consomme **brut**.

    Contrairement à `ic_launcher_foreground`, que `mipmap-anydpi-v26/ic_launcher.xml`
    enveloppe dans un retrait de 16 %, celui-ci doit porter sa marge lui-même.
    """

    def test_il_existe_et_n_est_pas_confondu_avec_l_icone_du_lanceur(self):
        self.assertTrue(list(RES.glob("drawable*/splash_icon.png")))
        for dossier in ("values-v31", "values-night-v31"):
            icone = styles(dossier)["LaunchTheme"][
                "android:windowSplashScreenAnimatedIcon"
            ]
            self.assertEqual(
                icone,
                "@drawable/splash_icon",
                msg=(
                    f"{dossier} : `ic_launcher_foreground` n'a pas de marge et se "
                    "fait rogner par le masque du système."
                ),
            )


if __name__ == "__main__":
    unittest.main()
