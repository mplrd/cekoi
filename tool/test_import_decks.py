"""Corpus de livraisons malformées, écrit avant le parser.

La roadmap l'exige : l'import doit **échouer bruyamment** sur une ligne
inexploitable plutôt que de l'ignorer. Une carte perdue sans message est
invisible jusqu'à ce qu'un joueur la cherche dans le jeu.

Lancer : `python -m unittest discover -s tool`
"""

import tempfile
import unittest
from pathlib import Path

from import_decks import (
    ImportError_,
    parse_csv,
    slugify,
    split_by_category,
    workbook_to_csv,
)


def csv_of(*lines: str) -> str:
    return "\n".join(lines) + "\n"


class ColonnesEtEnTetes(unittest.TestCase):
    def test_en_tete_minimal(self):
        cards = parse_csv(csv_of("texte,difficulte", "Éléphant,1"))

        self.assertEqual(cards, [{"text": "Éléphant", "difficulty": 1}])

    def test_accents_et_casse_des_en_tetes(self):
        # Sheets rend ce que l'autrice a tapé : « Texte », « Difficulté »…
        cards = parse_csv(csv_of("Texte , Difficulté ,Note", "Girafe,2,"))

        self.assertEqual(cards, [{"text": "Girafe", "difficulty": 2}])

    def test_colonnes_dans_le_desordre(self):
        cards = parse_csv(csv_of("note,difficulte,texte", ",3,Narval"))

        self.assertEqual(cards, [{"text": "Narval", "difficulty": 3}])

    def test_colonne_inconnue_ignoree(self):
        # Une colonne de travail ajoutée par l'autrice ne doit pas bloquer.
        cards = parse_csv(csv_of("texte,difficulte,idée", "Tatou,3,à revoir"))

        self.assertEqual(cards, [{"text": "Tatou", "difficulty": 3}])

    def test_sans_colonne_texte(self):
        with self.assertRaises(ImportError_) as e:
            parse_csv(csv_of("difficulte,note", "1,"))

        self.assertIn("texte", str(e.exception))

    def test_fichier_vide(self):
        with self.assertRaises(ImportError_):
            parse_csv("")


class SeparateursEtEncodage(unittest.TestCase):
    def test_point_virgule(self):
        # Export Sheets en locale française.
        cards = parse_csv(csv_of("texte;difficulte", "Loutre;2"))

        self.assertEqual(cards, [{"text": "Loutre", "difficulty": 2}])

    def test_tabulation(self):
        cards = parse_csv(csv_of("texte\tdifficulte", "Axolotl\t3"))

        self.assertEqual(cards, [{"text": "Axolotl", "difficulty": 3}])

    def test_bom_en_tete_de_fichier(self):
        # Sheets préfixe volontiers ses exports d'un BOM ; sans traitement, la
        # première colonne s'appelle « ﻿texte » et rien ne correspond.
        cards = parse_csv("﻿texte,difficulte\nHérisson,1\n")

        self.assertEqual(cards, [{"text": "Hérisson", "difficulty": 1}])

    def test_fins_de_ligne_windows(self):
        cards = parse_csv("texte,difficulte\r\nPingouin,1\r\n")

        self.assertEqual(cards, [{"text": "Pingouin", "difficulty": 1}])


class TexteDesCartes(unittest.TestCase):
    def test_espaces_de_bord_manges(self):
        cards = parse_csv(csv_of("texte,difficulte", "  Coccinelle  ,1"))

        self.assertEqual(cards[0]["text"], "Coccinelle")

    def test_espace_insecable_normalise(self):
        # Copier-coller depuis un traitement de texte en sème partout.
        cards = parse_csv(csv_of("texte,difficulte", "Chauve souris,2"))

        self.assertEqual(cards[0]["text"], "Chauve souris")

    def test_guillemets_typographiques_conserves(self):
        # Ils font partie du texte affiché, on n'y touche pas.
        cards = parse_csv(csv_of("texte,difficulte", "L’Everest,2"))

        self.assertEqual(cards[0]["text"], "L’Everest")

    def test_ligne_vide_ignoree(self):
        # Une ligne vide n'est pas une carte perdue : c'est de la mise en page.
        cards = parse_csv(csv_of("texte,difficulte", "Girafe,1", "", "Tatou,3"))

        self.assertEqual(len(cards), 2)

    def test_texte_vide_refuse(self):
        with self.assertRaises(ImportError_) as e:
            parse_csv(csv_of("texte,difficulte", "Girafe,1", " ,2"))

        self.assertIn("ligne 3", str(e.exception))

    def test_texte_trop_long_refuse(self):
        # 30 caractères pour un mot, 60 pour une situation, dit CONTENU.md.
        # Au-delà, la carte devient illisible à bout de bras.
        long = "A" * 80
        with self.assertRaises(ImportError_) as e:
            parse_csv(csv_of("texte,difficulte", f"{long},1"))

        self.assertIn("ligne 2", str(e.exception))


class Difficulte(unittest.TestCase):
    def test_valeur_par_defaut(self):
        # CONTENU.md : en hésitation, 2. Une colonne absente vaut hésitation.
        cards = parse_csv(csv_of("texte", "Escargot"))

        self.assertEqual(cards[0]["difficulty"], 2)

    def test_cellule_vide_vaut_le_defaut(self):
        cards = parse_csv(csv_of("texte,difficulte", "Escargot,"))

        self.assertEqual(cards[0]["difficulty"], 2)

    def test_hors_bornes_refuse(self):
        with self.assertRaises(ImportError_) as e:
            parse_csv(csv_of("texte,difficulte", "Girafe,4"))

        self.assertIn("ligne 2", str(e.exception))

    def test_non_numerique_refuse(self):
        # « facile » est devenu un niveau valide ; il faut donc un mot que
        # personne n'écrirait dans cette colonne pour tester le refus.
        with self.assertRaises(ImportError_) as e:
            parse_csv(csv_of("texte,difficulte", "Girafe,pastèque"))

        self.assertIn("ligne 2", str(e.exception))


class Doublons(unittest.TestCase):
    def test_texte_identique_refuse(self):
        with self.assertRaises(ImportError_) as e:
            parse_csv(csv_of("texte,difficulte", "Girafe,1", "Girafe,2"))

        self.assertIn("ligne 3", str(e.exception))

    def test_doublon_a_l_espace_pres_refuse(self):
        with self.assertRaises(ImportError_) as e:
            parse_csv(csv_of("texte,difficulte", "Girafe,1", " Girafe ,2"))

        self.assertIn("ligne 3", str(e.exception))

    def test_casse_differente_laissee_au_test_dart(self):
        # Python ne normalise pas : la normalisation de R6.4 vit dans le
        # moteur, et la réimplémenter ici la ferait diverger. Un test Dart
        # relit tous les JSON produits et attrape ce cas en CI.
        cards = parse_csv(csv_of("texte,difficulte", "Girafe,1", "girafe,2"))

        self.assertEqual(len(cards), 2)


class PlusieursCategoriesDansUnFichier(unittest.TestCase):
    """Une feuille unique couvrant plusieurs catégories.

    C'est la forme la plus probable d'une livraison de plusieurs centaines de
    cartes : une seule feuille, une colonne pour dire de quelle catégorie
    relève chaque ligne.
    """

    def test_la_categorie_est_lue_quand_la_colonne_existe(self):
        cards = parse_csv(
            csv_of(
                "categorie,texte,difficulte",
                "Animaux,Girafe,1",
                "Métiers,Boulanger,2",
            )
        )

        self.assertEqual(cards[0]["category"], "Animaux")
        self.assertEqual(cards[1]["category"], "Métiers")

    def test_sans_colonne_categorie_aucune_n_est_inventee(self):
        cards = parse_csv(csv_of("texte,difficulte", "Girafe,1"))

        self.assertNotIn("category", cards[0])

    def test_regroupement_par_categorie(self):
        cards = parse_csv(
            csv_of(
                "categorie,texte",
                "Animaux,Girafe",
                "Métiers,Boulanger",
                "Animaux,Tatou",
            )
        )

        groupes = split_by_category(cards)

        self.assertEqual(list(groupes), ["Animaux", "Métiers"])
        self.assertEqual(len(groupes["Animaux"]), 2)
        self.assertNotIn("category", groupes["Animaux"][0])

    def test_categorie_vide_refusee(self):
        # Une ligne sans catégorie dans une feuille qui en a une n'irait nulle
        # part : elle serait perdue en silence.
        with self.assertRaises(ImportError_) as e:
            parse_csv(csv_of("categorie,texte", "Animaux,Girafe", ",Tatou"))

        self.assertIn("ligne 3", str(e.exception))

    def test_doublon_dans_deux_categories_refuse(self):
        # R6.4 : le tirage n'en garderait qu'une, et le volume annoncé au
        # joueur serait faux.
        with self.assertRaises(ImportError_) as e:
            parse_csv(
                csv_of(
                    "categorie,texte",
                    "Animaux,Girafe",
                    "Savane,Girafe",
                )
            )

        self.assertIn("ligne 3", str(e.exception))


class Identifiants(unittest.TestCase):
    def test_slug_de_categorie(self):
        self.assertEqual(slugify("Métiers & professions"), "metiers-professions")
        self.assertEqual(slugify("Le trac"), "le-trac")

    def test_slug_stable_a_la_casse_et_aux_espaces(self):
        self.assertEqual(slugify("  ANIMAUX  "), slugify("animaux"))


class ToutesLesErreursDUnCoup(unittest.TestCase):
    def test_le_rapport_liste_chaque_ligne_fautive(self):
        # S'arrêter à la première erreur ferait relancer l'import autant de
        # fois qu'il y a de fautes, sur des fichiers de plusieurs centaines de
        # lignes.
        with self.assertRaises(ImportError_) as e:
            parse_csv(
                csv_of(
                    "texte,difficulte",
                    ",1",
                    "Girafe,9",
                    "Tatou,bof",
                )
            )

        rapport = str(e.exception)
        self.assertIn("ligne 2", rapport)
        self.assertIn("ligne 3", rapport)
        self.assertIn("ligne 4", rapport)


class NiveauxEcritsEnToutesLettres(unittest.TestCase):
    """La feuille livre « 🟢 Facile », pas « 1 »."""

    def test_libelle_avec_pastille_de_couleur(self):
        cartes = parse_csv(
            csv_of(
                "texte;difficulte",
                "Chocolat;🟢 Facile",
                "Phare;🟡 Moyen",
                "Huissier;🔴 Expert",
            )
        )

        self.assertEqual([c["difficulty"] for c in cartes], [1, 2, 3])

    def test_libelle_sans_pastille_ni_accent(self):
        cartes = parse_csv(
            csv_of("texte,difficulte", "Chat,FACILE", "Trac,difficile")
        )

        self.assertEqual([c["difficulty"] for c in cartes], [1, 3])

    def test_mot_inconnu_reste_refuse(self):
        # Tolérer les libellés connus ne doit pas faire passer n'importe quoi
        # pour un niveau : une colonne mal placée serait avalée en silence.
        with self.assertRaises(ImportError_) as e:
            parse_csv(csv_of("texte,difficulte", "Chat,pastèque"))

        self.assertIn("pastèque", str(e.exception))


class LectureDUnClasseur(unittest.TestCase):
    """La livraison arrive en .xlsx, un onglet par catégorie."""

    def setUp(self):
        try:
            import openpyxl  # noqa: F401
        except ModuleNotFoundError:
            self.skipTest("openpyxl absent")

    def _classeur(self, feuilles: dict[str, list[tuple]]) -> Path:
        import openpyxl

        wb = openpyxl.Workbook()
        wb.remove(wb.active)
        for nom, lignes in feuilles.items():
            ws = wb.create_sheet(nom)
            for ligne in lignes:
                ws.append(list(ligne))

        chemin = Path(self.enterContext(tempfile.TemporaryDirectory()))
        fichier = chemin / "livraison.xlsx"
        wb.save(fichier)
        return fichier

    def test_une_feuille_devient_une_categorie(self):
        fichier = self._classeur(
            {
                "Animaux": [("Girafe", "🟢 Facile"), ("Tatou", "🔴 Expert")],
                "Métiers": [("Pompier", "🟢 Facile")],
            }
        )

        cartes = parse_csv(workbook_to_csv(fichier))

        self.assertEqual(
            [(c["text"], c["category"], c["difficulty"]) for c in cartes],
            [
                ("Girafe", "Animaux", 1),
                ("Tatou", "Animaux", 3),
                ("Pompier", "Métiers", 1),
            ],
        )

    def test_premiere_ligne_lue_comme_une_carte(self):
        # Le classeur n'a pas d'en-tête : la prendre pour un titre mangerait
        # une carte par catégorie, en silence.
        fichier = self._classeur({"Animaux": [("Girafe", "🟢 Facile")]})

        cartes = parse_csv(workbook_to_csv(fichier))

        self.assertEqual([c["text"] for c in cartes], ["Girafe"])

    def test_colonne_de_niveau_absente_vaut_le_defaut(self):
        # Le mode adultes ne note aucune difficulté : il tire dans tout le
        # vivier (R7.1), le niveau n'y trie rien.
        fichier = self._classeur({"Tabou": [("Panne au lit",)]})

        cartes = parse_csv(workbook_to_csv(fichier))

        self.assertEqual(cartes[0]["difficulty"], 2)

    def test_lignes_et_colonnes_de_travail_ignorees(self):
        # Une feuille traîne des colonnes vides sur toute sa largeur et des
        # lignes de mise en page : ni les unes ni les autres ne sont des
        # cartes, et les signaler noierait les vraies fautes.
        fichier = self._classeur(
            {
                "Honte": [
                    ("Péter en public", None, None, None),
                    (None, None, None, None),
                    ("Chuter en public", None, None, None),
                ]
            }
        )

        cartes = parse_csv(workbook_to_csv(fichier))

        self.assertEqual(
            [c["text"] for c in cartes], ["Péter en public", "Chuter en public"]
        )


if __name__ == "__main__":
    unittest.main()
