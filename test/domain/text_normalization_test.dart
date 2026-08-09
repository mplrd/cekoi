import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/text/text_normalization.dart';
import 'package:flutter_test/flutter_test.dart';

Card cardWith(String text) => Card(
  id: 'test:$text',
  deckId: 'test',
  text: text,
  audience: Audience.family,
  difficulty: Difficulty.easy,
  origin: DeckOrigin.official,
);

void main() {
  group('R6.4 — deux écritures de la même entrée se rejoignent', () {
    test('la casse est neutralisée', () {
      expect(normalizeCardText('Le trac'), normalizeCardText('le trac'));
    });

    test('les accents sont neutralisés', () {
      expect(normalizeCardText('Éléphant'), normalizeCardText('elephant'));
    });

    test('les ligatures sont développées, pas réduites', () {
      expect(normalizeCardText('Œuf'), normalizeCardText('Oeuf'));
      expect(normalizeCardText('Nævus'), normalizeCardText('Naevus'));
    });

    test("l'élision est traitée, apostrophe droite ou typographique", () {
      expect(normalizeCardText("L'ours"), normalizeCardText('L’ours'));
      expect(normalizeCardText("L'ours"), 'l ours');
    });

    test('la ponctuation et les espaces surnuméraires sont neutralisés', () {
      expect(
        normalizeCardText('  Chauve-souris !  '),
        normalizeCardText('chauve souris'),
      );
    });
  });

  group('ce que la normalisation ne doit PAS fusionner', () {
    test("l'article fait partie de l'entrée", () {
      // R6.4 parle de « la même entrée ». Retirer les articles fusionnerait
      // deux cartes légitimement distinctes.
      expect(
        normalizeCardText('La Poste'),
        isNot(normalizeCardText('Poste')),
      );
      expect(
        normalizeCardText('Le Monde'),
        isNot(normalizeCardText('Monde')),
      );
    });

    test('deux cartes différentes restent différentes', () {
      expect(
        normalizeCardText('Éléphant'),
        isNot(normalizeCardText('Éléphante')),
      );
    });
  });

  test('Card.normalizedText utilise la même normalisation', () {
    expect(cardWith('Œuf').normalizedText, normalizeCardText('Oeuf'));
    expect(cardWith("L'ours").normalizedText, normalizeCardText('L’ours'));
  });
}
