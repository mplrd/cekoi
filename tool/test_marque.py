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

from marque import (
    DEFINES,
    Marque,
    MarqueIndisponible,
    marque,
    options,
    version_du_pubspec,
)

DEPOT = Path(__file__).resolve().parent.parent
BUILD_INFO = DEPOT / "lib/app/build_info.dart"


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
        return set(re.findall(r"String\.fromEnvironment\('([^']+)'\)", source))

    def test_tout_ce_que_l_outil_injecte_est_lu(self):
        self.assertEqual(set(DEFINES) - self._noms_lus_par_dart(), set())

    def test_tout_ce_que_dart_lit_est_injecte(self):
        self.assertEqual(self._noms_lus_par_dart() - set(DEFINES), set())


if __name__ == "__main__":
    unittest.main()
