"""Ce que le chemin de livraison refuse de faire, et ce qu'il nomme.

`test_fumee.py` couvre les motifs qui décident si l'application va bien : des
fonctions pures, contre de vrais dumps d'appareil. Ici c'est l'inverse — ce
qui compte est un **enchaînement**, et il se vérifie en remplaçant tout ce qui
touche au monde.

Trois comportements, ajoutés avec l'identification des builds, et tous
invisibles tant qu'ils fonctionnent :

  - refuser de construire ce qu'on ne saura pas désigner ;
  - recopier l'artefact sous un nom qui porte son empreinte, parce que trois
    `app-release.apk` sur un bureau ne se distinguent pas ;
  - prévenir quand le numéro livré peut **descendre** — le `versionCode` est un
    compte de commits, et une branche en retard en rend un plus petit, ce qui
    fait refuser l'installation sur les appareils qui ont reçu le précédent.

Lancer : `python -m unittest discover -s tool -t tool`
"""

import io
import subprocess
import unittest
from contextlib import ExitStack, redirect_stdout
from unittest import mock

import fumee
from marque import Marque, MarqueIndisponible

IDENTITE = Marque(version="1.0.0", numero="212", commit="dc4ecad", date="2026-08-25")


class Construction(unittest.TestCase):
    """Lance `fumee.construire()` avec le monde extérieur remplacé."""

    def construire(self, *, branche="develop", echec_de_marque=None, code=0):
        tampon = io.StringIO()
        with ExitStack() as pile:
            pile.enter_context(
                mock.patch.object(fumee.shutil, "which", return_value="flutter")
            )
            pile.enter_context(
                mock.patch.object(fumee, "marque", side_effect=echec_de_marque)
                if echec_de_marque
                else mock.patch.object(fumee, "marque", return_value=IDENTITE)
            )
            pile.enter_context(
                mock.patch.object(fumee, "branche_courante", return_value=branche)
            )
            self.lancement = pile.enter_context(
                mock.patch.object(
                    fumee.subprocess,
                    "run",
                    return_value=subprocess.CompletedProcess([], code),
                )
            )
            self.copie = pile.enter_context(
                mock.patch.object(fumee.shutil, "copyfile")
            )
            pile.enter_context(redirect_stdout(tampon))
            self.arrete = False
            try:
                fumee.construire()
            except SystemExit:
                self.arrete = True
        return tampon.getvalue()

    def test_sans_identite_on_ne_construit_meme_pas(self):
        self.construire(echec_de_marque=MarqueIndisponible("git introuvable"))

        self.assertTrue(self.arrete)
        # Le point qui compte : rien n'a été construit. Échouer après le build
        # aurait laissé dans `build/` un APK anonyme que quelqu'un finirait par
        # envoyer.
        self.lancement.assert_not_called()

    def test_l_artefact_est_recopie_sous_son_empreinte(self):
        self.construire()

        self.assertFalse(self.arrete)
        _, destination = self.copie.call_args.args
        self.assertEqual(destination.name, "cekoi-dc4ecad.apk")

    def test_depuis_une_branche_de_travail_on_est_prevenu(self):
        sortie = self.construire(branche="feature/identifier-le-build")

        self.assertIn("ATTENTION", sortie)
        self.assertIn("feature/identifier-le-build", sortie)

    def test_un_head_detache_compte_comme_une_branche_de_travail(self):
        self.assertIn("ATTENTION", self.construire(branche=""))

    def test_depuis_develop_on_ne_l_est_pas(self):
        # Sans ce cas, l'avertissement pourrait être inconditionnel — donc du
        # bruit permanent, donc plus lu du tout. C'est exactement ce que
        # `build.gradle.kts` explique à propos de l'avertissement de signature.
        self.assertNotIn("ATTENTION", self.construire(branche="develop"))


if __name__ == "__main__":
    unittest.main()
