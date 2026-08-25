"""L'identité gravée dans un binaire doit être vraie, ou absente.

Deux choses se cassent en silence ici, et aucune ne fait rougir la
compilation :

  - un `--dart-define` renommé d'un seul côté. Dart ne se plaint pas d'un nom
    qu'il ne trouve pas : `String.fromEnvironment` rend la chaîne vide, et
    l'application affiche « non identifié » comme si le build venait d'ailleurs.
    Le test croise donc les deux fichiers.
  - un arbre de travail sale. Le binaire n'est alors pas le commit qu'il
    affiche, et un signalement renverrait vers du code que personne ne peut
    relire.

Lancer : `python -m unittest discover -s tool -t tool`
"""

import re
import tempfile
import unittest
from datetime import date
from pathlib import Path
from unittest import mock

from marque import (
    COMPTAGE,
    DEFINES,
    Marque,
    MarqueIndisponible,
    branche_courante,
    marque,
    options,
    version_du_pubspec,
)

DEPOT = Path(__file__).resolve().parent.parent
BUILD_INFO = DEPOT / "lib/app/build_info.dart"
GRADLE = DEPOT / "android/app/build.gradle.kts"


def faux_git(*, empreinte="050e30a", commits="128", sale=False):
    """Un git qui répond ce qu'on lui dit, pour ne pas dépendre du vrai dépôt."""

    def lancer(*arguments: str) -> str:
        if arguments[:2] == ("rev-parse", "--short"):
            return empreinte + "\n"
        if arguments[:1] == ("status",):
            return " M lib/app/build_info.dart\n" if sale else "\n"
        if arguments[:2] == ("rev-list", "--count"):
            return commits + "\n"
        raise AssertionError(f"appel git inattendu : {arguments}")

    return lancer


class VersionDuPubspec(unittest.TestCase):
    def _pubspec(self, contenu: str) -> Path:
        dossier = tempfile.TemporaryDirectory()
        self.addCleanup(dossier.cleanup)
        chemin = Path(dossier.name) / "pubspec.yaml"
        chemin.write_text(contenu, encoding="utf-8")
        return chemin

    def test_retire_le_numero_de_build(self):
        chemin = self._pubspec("name: cekoi\nversion: 1.0.0+1\n")
        self.assertEqual(version_du_pubspec(chemin), "1.0.0")

    def test_accepte_une_version_sans_numero(self):
        chemin = self._pubspec("version: 2.3.4\n")
        self.assertEqual(version_du_pubspec(chemin), "2.3.4")

    def test_refuse_un_pubspec_sans_version(self):
        chemin = self._pubspec("name: cekoi\n")
        with self.assertRaises(MarqueIndisponible):
            version_du_pubspec(chemin)

    def test_le_vrai_pubspec_du_depot_se_lit(self):
        # Le format d'une ligne YAML n'est pas contractuel : si `version:`
        # devient un bloc, le reste de ce fichier passerait sur du vide.
        self.assertRegex(version_du_pubspec(DEPOT / "pubspec.yaml"), r"^\d+\.\d+\.\d+$")


class Empreinte(unittest.TestCase):
    def test_un_arbre_propre_donne_le_commit_nu(self):
        m = marque(DEPOT, git=faux_git(), aujourdhui=date(2026, 8, 24))
        self.assertEqual(m.commit, "050e30a")
        self.assertEqual(m.numero, "128")
        self.assertEqual(m.date, "2026-08-24")

    def test_un_arbre_sale_le_dit(self):
        m = marque(DEPOT, git=faux_git(sale=True), aujourdhui=date(2026, 8, 24))
        self.assertEqual(m.commit, "050e30a-sale")

    def test_sans_commit_on_refuse_d_identifier(self):
        with self.assertRaises(MarqueIndisponible):
            marque(DEPOT, git=faux_git(empreinte=""))

    def test_git_absent_du_path_reste_une_MarqueIndisponible(self):
        # `FileNotFoundError` traverserait les `except MarqueIndisponible` de
        # `main()` et de `fumee.py` : on obtiendrait une trace Python à la
        # place du message que ce module existe pour afficher. La même leçon
        # est déjà écrite dans `fumee.py` à propos d'`adb`.
        with mock.patch("marque.subprocess.run", side_effect=FileNotFoundError("git")):
            with self.assertRaises(MarqueIndisponible):
                marque(DEPOT)


class LeVraiGit(unittest.TestCase):
    """Le seul cas qui exerce `_git_reel` : ailleurs, tout est simulé."""

    def test_le_depot_rend_une_identite_plausible(self):
        identite = marque(DEPOT, aujourdhui=date(2026, 8, 25))
        self.assertRegex(identite.numero, r"^\d+$")
        self.assertRegex(identite.commit, r"^[0-9a-f]{7,}(-sale)?$")

    def test_la_branche_se_lit(self):
        # Ni le nom ni sa présence ne sont contractuels — la CI travaille sur
        # un HEAD détaché. C'est le type qui compte.
        self.assertIsInstance(branche_courante(DEPOT), str)


class Branche(unittest.TestCase):
    def test_un_head_detache_ne_rend_aucune_branche(self):
        self.assertEqual(branche_courante(DEPOT, git=lambda *_: "HEAD\n"), "")

    def test_une_branche_est_rendue_telle_quelle(self):
        self.assertEqual(
            branche_courante(DEPOT, git=lambda *_: "feature/x\n"), "feature/x"
        )


class Options(unittest.TestCase):
    def test_les_quatre_valeurs_partent_au_compilateur(self):
        m = Marque(version="1.0.0", numero="128", commit="050e30a", date="2026-08-24")
        self.assertEqual(
            options(m),
            [
                "--dart-define=CEKOI_VERSION=1.0.0",
                "--dart-define=CEKOI_BUILD=128",
                "--dart-define=CEKOI_COMMIT=050e30a",
                "--dart-define=CEKOI_DATE=2026-08-24",
            ],
        )


class LesDeuxCotesDuJoint(unittest.TestCase):
    """Le seul endroit où le Python et le Dart doivent s'accorder."""

    def _noms_lus_par_dart(self) -> set[str]:
        source = BUILD_INFO.read_text(encoding="utf-8")
        # Pas de parenthèse fermante exigée après le nom : un `defaultValue:`
        # parfaitement légitime, ou une coupe de `dart format` sur deux lignes,
        # ferait rougir ces tests avec un diagnostic faux.
        return set(re.findall(r"String\.fromEnvironment\(\s*'([^']+)'", source))

    def test_l_instrument_voit_quelque_chose(self):
        # Sans ça, un motif qui cesse de correspondre rend l'ensemble vide, et
        # `test_tout_ce_que_dart_lit_est_injecte` passe au vert sur du néant.
        self.assertEqual(len(self._noms_lus_par_dart()), len(DEFINES))

    def test_tout_ce_que_l_outil_injecte_est_lu(self):
        self.assertEqual(set(DEFINES) - self._noms_lus_par_dart(), set())

    def test_tout_ce_que_dart_lit_est_injecte(self):
        self.assertEqual(self._noms_lus_par_dart() - set(DEFINES), set())


class LeCompteEstFaitDesDeuxCotes(unittest.TestCase):
    """Gradle grave le numéro dans le paquet, ce module l'injecte dans l'écran.

    Deux commandes, un seul résultat attendu. Si elles divergent, l'application
    annonce un numéro que le paquet ne porte pas — et c'est le champ qu'on lit
    justement pour comprendre un refus d'installation.
    """

    def test_gradle_lance_exactement_la_meme_commande(self):
        attendue = 'commandLine("git", ' + ", ".join(f'"{a}"' for a in COMPTAGE) + ")"
        self.assertIn(attendue, GRADLE.read_text(encoding="utf-8"))

    def test_l_outil_lance_bien_celle_la(self):
        appels = []

        def espion(*arguments: str) -> str:
            appels.append(arguments)
            return "7\n" if arguments == COMPTAGE else "050e30a\n"

        marque(DEPOT, git=espion, aujourdhui=date(2026, 8, 25))
        self.assertIn(COMPTAGE, appels)


if __name__ == "__main__":
    unittest.main()
