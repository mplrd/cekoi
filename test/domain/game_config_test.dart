import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/rules/round.dart';
import 'package:cekoi/domain/setup/game_setup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R6.1 — le paquet compte 30 cartes par défaut', () {
    test('sans rien préciser, une partie part sur 30 cartes', () {
      const config = GameConfig(
        mode: Audience.family,
        deckIds: ['animaux'],
        turnDuration: Duration(seconds: 60),
      );

      expect(config.cardCount, 30);
    });

    test('le volume ne dépend pas du nombre d équipes', () {
      // Le mode *auto* calculait `12 × équipes` : la valeur bougeait sous les
      // yeux du joueur quand il revenait changer le nombre d'équipes à l'étape
      // suivante. Ce test dit que ce couplage a disparu.
      final deux = setupForMode(Audience.family).withTeamCount(2);
      final cinq = setupForMode(Audience.family).withTeamCount(5);

      expect(deux.resolvedCardCount, cinq.resolvedCardCount);
      expect(deux.resolvedCardCount, GameConfig.defaultCardCount);
    });

    test('les deux modes partent sur le même volume', () {
      expect(
        setupForMode(Audience.adult).cardCount,
        setupForMode(Audience.family).cardCount,
      );
    });

    test('un nombre sous le minimum de R6.2 est refusé', () {
      expect(
        () => setupForMode(
          Audience.family,
        ).withCardCount(GameConfig.minimumCardCount - 1),
        throwsArgumentError,
      );
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
