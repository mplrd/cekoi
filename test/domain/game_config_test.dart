import 'package:cekoi/domain/engine/team_builder.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/rules/round.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R6.1 — nombre de cartes en mode auto', () {
    test('vaut 12 × équipes, arrondi au multiple de 4 supérieur', () {
      expect(GameConfig.autoCardCount(2), 24);
      expect(GameConfig.autoCardCount(3), 36);
      expect(GameConfig.autoCardCount(4), 48);
    });

    test('est borné à 80 par le haut', () {
      // 12 × 7 = 84, au-dessus de la borne haute
      expect(GameConfig.autoCardCount(7), 80);
      expect(GameConfig.autoCardCount(40), 80);
    });

    test('le plancher de 16 ne peut plus être atteint', () {
      // Depuis que le calcul part des équipes (R8.2), le minimum de deux en
      // donne déjà 24 : la borne basse de R6.1 ne mord plus. Ce test dit
      // qu'elle est inatteignable plutôt que de faire croire qu'elle est
      // exercée — c'est le facteur, s'il baissait un jour, qui la réveillerait.
      expect(GameConfig.autoCardCount(minimumTeamCount), 24);
      expect(
        GameConfig.autoCardCount(minimumTeamCount),
        greaterThan(16),
        reason: 'aucun nombre d’équipes valide ne descend jusqu’au plancher',
      );
    });

    test('un nombre explicite prend le pas sur le calcul auto', () {
      const config = GameConfig(
        mode: Audience.family,
        deckIds: ['animaux'],
        turnDuration: Duration(seconds: 60),
        cardCount: 48,
      );

      expect(config.resolvedCardCount(2), 48);
    });

    test('cardCount nul déclenche le calcul auto', () {
      const config = GameConfig(
        mode: Audience.family,
        deckIds: ['animaux'],
        turnDuration: Duration(seconds: 60),
      );

      expect(config.resolvedCardCount(3), GameConfig.autoCardCount(3));
    });
  });

  group('R2.2 — une partie, ce sont les trois manches', () {
    test("la séquence est fixe et dans l'ordre canonique", () {
      expect(Round.sequence, [
        Round.freeDescription,
        Round.oneWord,
        Round.mime,
      ]);
    });
  });

  group("R3.9 — passer n'existe qu'à partir de la manche 2", () {
    test('la description libre ne le permet pas', () {
      expect(Round.freeDescription.allowsPass, isFalse);
    });

    test('les deux manches contraintes le permettent', () {
      expect(Round.oneWord.allowsPass, isTrue);
      expect(Round.mime.allowsPass, isTrue);
    });
  });

  group('R7.1 — vivier tiré selon le mode', () {
    test('le mode famille ne tire que du contenu famille', () {
      expect(Audience.family.drawableAudiences, {Audience.family});
    });

    test('le mode adultes tire aussi dans le contenu famille', () {
      expect(Audience.adult.drawableAudiences, {
        Audience.family,
        Audience.adult,
      });
    });
  });
}
