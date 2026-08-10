"""Corpus de livraisons malformées, écrit avant le parser.

La roadmap l'exige : l'import doit **échouer bruyamment** sur une ligne
inexploitable plutôt que de l'ignorer. Une carte perdue sans message est
invisible jusqu'à ce qu'un joueur la cherche dans le jeu.

Lancer : `python -m unittest discover -s tool`
"""

import unittest

from import_decks import ImportError_, parse_csv


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
        # 30 caractères environ, dit CONTENU.md. Au-delà, la carte devient
        # illisible à bout de bras.
        long = "A" * 60
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
        with self.assertRaises(ImportError_) as e:
            parse_csv(csv_of("texte,difficulte", "Girafe,facile"))

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
                    "Tatou,facile",
                )
            )

        rapport = str(e.exception)
        self.assertIn("ligne 2", rapport)
        self.assertIn("ligne 3", rapport)
        self.assertIn("ligne 4", rapport)


if __name__ == "__main__":
    unittest.main()
