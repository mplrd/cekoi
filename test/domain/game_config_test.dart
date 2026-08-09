import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/rules/round.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R6.1 — nombre de cartes en mode auto', () {
    test('vaut 5 × joueurs arrondi au multiple de 4 supérieur', () {
      // 5 × 5 = 25 → 28
      expect(GameConfig.autoCardCount(5), 28);
      // 5 × 8 = 40, déjà multiple de 4
      expect(GameConfig.autoCardCount(8), 40);
      // 5 × 7 = 35 → 36
      expect(GameConfig.autoCardCount(7), 36);
    });

    test('est borné à [16, 80]', () {
      // 5 × 2 = 10, sous la borne basse
      expect(GameConfig.autoCardCount(2), 16);
      // 5 × 40 = 200, au-dessus de la borne haute
      expect(GameConfig.autoCardCount(40), 80);
    });

    test('un nombre explicite prend le pas sur le calcul auto', () {
      const config = GameConfig(
        mode: Audience.family,
        deckIds: ['animaux'],
        turnDuration: Duration(seconds: 60),
        roundCount: 3,
        cardCount: 48,
      );

      expect(config.resolvedCardCount(4), 48);
    });

    test('cardCount nul déclenche le calcul auto', () {
      const config = GameConfig(
        mode: Audience.family,
        deckIds: ['animaux'],
        turnDuration: Duration(seconds: 60),
        roundCount: 3,
      );

      expect(config.resolvedCardCount(6), GameConfig.autoCardCount(6));
    });
  });

  group('R2.2 — séquence des manches', () {
    test("trois manches se jouent dans l'ordre canonique", () {
      expect(Round.sequenceFor(3), [
        Round.freeDescription,
        Round.oneWord,
        Round.mime,
      ]);
    });

    test('deux manches retirent « un seul mot », pas le mime', () {
      expect(Round.sequenceFor(2), [Round.freeDescription, Round.mime]);
    });

    test('tout autre nombre de manches est refusé', () {
      expect(() => Round.sequenceFor(1), throwsArgumentError);
      expect(() => Round.sequenceFor(4), throwsArgumentError);
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
