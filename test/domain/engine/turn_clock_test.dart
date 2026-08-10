import 'package:cekoi/domain/engine/turn_clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lectures d'une source monotone, en secondes depuis un instant arbitraire.
///
/// Ce que le chrono reçoit en production vient d'un `Stopwatch`, pas de
/// l'horloge système : un utilisateur qui change l'heure de son téléphone
/// pendant un tour ne doit pas faire bondir le temps restant.
Duration at(int seconds) => Duration(seconds: seconds);

void main() {
  group('un tour non commencé', () {
    test("n'a rien consommé, quelle que soit l'heure qu'il est", () {
      const clock = TurnClock();

      expect(clock.isRunning, isFalse);
      expect(clock.elapsedAt(at(0)), Duration.zero);
      expect(clock.elapsedAt(at(3600)), Duration.zero);
    });
  });

  group('R3.2 — le chrono démarre à la première carte', () {
    test('une fois démarré, il suit le temps réel', () {
      final clock = const TurnClock().startedAt(at(100));

      expect(clock.isRunning, isTrue);
      expect(clock.elapsedAt(at(100)), Duration.zero);
      expect(clock.elapsedAt(at(105)), at(5));
    });

    test('démarrer ne dépend pas de la valeur absolue de la source', () {
      // La source monotone compte depuis le lancement de l'application, pas
      // depuis le début du tour : si le tour héritait de cet écart, le premier
      // tour d'une partie ouverte tard serait déjà terminé.
      final tot = const TurnClock().startedAt(at(5)).elapsedAt(at(15));
      final tard = const TurnClock().startedAt(at(9000)).elapsedAt(at(9010));

      expect(tot, tard);
    });
  });

  group('R3.7, R3.8 — une pause gèle le tour', () {
    test('en pause, le temps consommé ne bouge plus', () {
      final clock = const TurnClock().startedAt(at(0)).pausedAt(at(20));

      expect(clock.isRunning, isFalse);
      expect(clock.elapsedAt(at(20)), at(20));
      expect(
        clock.elapsedAt(at(300)),
        at(20),
        reason: 'Cinq minutes en arrière-plan ne consomment pas de tour',
      );
    });

    test('la reprise repart du temps gelé, sans la durée de la pause', () {
      final clock = const TurnClock()
          .startedAt(at(0))
          .pausedAt(at(20))
          .resumedAt(at(200));

      expect(clock.elapsedAt(at(200)), at(20));
      expect(clock.elapsedAt(at(205)), at(25));
    });

    test('cas limite 8 — à 1 s de la fin, il reste 1 s au retour', () {
      // Le cas que R3.7 existe pour couvrir, et celui qui se voit
      // immédiatement en jeu réel.
      const duree = Duration(seconds: 60);
      final clock = const TurnClock()
          .startedAt(at(0))
          .pausedAt(at(59))
          .resumedAt(at(3000));

      expect(duree - clock.elapsedAt(at(3000)), at(1));
    });

    test('les pauses successives se cumulent sans dériver', () {
      final clock = const TurnClock()
          .startedAt(at(0))
          .pausedAt(at(10))
          .resumedAt(at(50))
          .pausedAt(at(60))
          .resumedAt(at(100));

      expect(
        clock.elapsedAt(at(105)),
        at(25),
        reason: '10 s + 10 s puis 5 s de jeu : les 80 s de pause sont hors jeu',
      );
    });
  });

  group('ce que l’interface peut envoyer de travers', () {
    test('mettre en pause deux fois ne consomme rien de plus', () {
      final une = const TurnClock().startedAt(at(0)).pausedAt(at(20));
      final deux = une.pausedAt(at(50));

      expect(deux.elapsedAt(at(50)), at(20));
    });

    test('reprendre un chrono déjà en marche ne le rallonge pas', () {
      // Le cycle de vie peut livrer deux `resumed` de suite ; le second ne doit
      // pas redémarrer le compteur et effacer le temps déjà joué.
      final clock = const TurnClock().startedAt(at(0)).resumedAt(at(30));

      expect(clock.elapsedAt(at(30)), at(30));
      expect(clock.elapsedAt(at(35)), at(35));
    });

    test('une lecture antérieure ne fait pas reculer le temps consommé', () {
      // La source est censée être monotone. Si elle ne l'est pas, le tour ne
      // doit pas rajeunir : le narrateur récupérerait du temps.
      final clock = const TurnClock().startedAt(at(100));

      expect(clock.elapsedAt(at(90)), Duration.zero);
    });
  });
}
