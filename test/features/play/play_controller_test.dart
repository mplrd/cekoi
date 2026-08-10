import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/features/play/presentation/play_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/providers.dart';

/// Une horloge monotone que le test avance à la main.
///
/// Le `Stopwatch` de production suit le temps réel : un test qui l'utiliserait
/// devrait attendre une minute pour vérifier une fin de tour. Ici l'horloge
/// n'avance que sur ordre, et [FakeClock.advance] la fait avancer **en même
/// temps** que les `Timer` de Flutter, sans quoi les deux dériveraient et le
/// chrono compterait deux fois.
class FakeClock {
  Duration _value = Duration.zero;

  Duration read() => _value;

  /// Avance l'horloge et laisse tourner les `Timer` d'autant.
  Future<void> advance(WidgetTester tester, Duration by) async {
    // Par pas de 100 ms, la période du chrono : sauter d'un bloc ferait tirer
    // au `Timer.periodic` tous ses tics en retard sur une horloge déjà arrivée
    // à destination, ce qui masquerait une erreur d'accumulation.
    const step = Duration(milliseconds: 100);
    var left = by;
    while (left > Duration.zero) {
      final slice = left < step ? left : step;
      _value += slice;
      await tester.pump(slice);
      left -= slice;
    }
  }
}

void main() {
  late FakeClock clock;
  late ProviderContainer container;

  /// Dernier ordre reçu par le maintien d'écran, `null` si aucun.
  bool? screenAwake;

  /// Monte le contrôleur sur une partie prête à jouer.
  ///
  /// Un widget est nécessaire : les `Timer` et le cycle de vie ne sont
  /// pilotables que sous le binding de test.
  Future<PlayController> pumpGame(
    WidgetTester tester, {
    GameState? game,
  }) async {
    clock = FakeClock();
    screenAwake = null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monotonicClockProvider.overrideWithValue(clock.read),
          screenAwakeProvider.overrideWithValue(
            fakeScreenAwake(({required enable}) => screenAwake = enable),
          ),
        ],
        child: const SizedBox.shrink(),
      ),
    );

    container = ProviderScope.containerOf(
      tester.element(find.byType(SizedBox)),
    );
    container.read(currentGameProvider.notifier).game = game ?? testGame();
    return container.read(playControllerProvider.notifier);
  }

  GameState partie() => container.read(currentGameProvider)!;

  group('R3.2 — le chrono démarre à la première carte', () {
    testWidgets('le compte à rebours précède le départ', (tester) async {
      final controller = await pumpGame(tester);
      expect(partie().phase, GamePhase.turnIntro);

      controller.startTurn();
      await tester.pump();
      expect(container.read(playControllerProvider), 3);

      await clock.advance(tester, const Duration(seconds: 1));
      expect(container.read(playControllerProvider), 2);

      await clock.advance(tester, const Duration(seconds: 1));
      expect(container.read(playControllerProvider), 1);

      expect(
        partie().phase,
        GamePhase.turnIntro,
        reason: 'Rien ne démarre tant que le décompte tourne',
      );

      await clock.advance(tester, const Duration(seconds: 1));
      expect(container.read(playControllerProvider), isNull);
      expect(partie().phase, GamePhase.playing);
    });

    testWidgets('le temps du compte à rebours ne sort pas du tour', (
      tester,
    ) async {
      // Le chrono part à la première carte, pas à l'arrivée sur l'écran : les
      // trois secondes de décompte ne sont pas du temps de jeu.
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      await clock.advance(tester, const Duration(seconds: 10));

      expect(partie().turn!.elapsed, const Duration(seconds: 10));
    });
  });

  group('le chrono consomme le tour', () {
    testWidgets('le temps restant décroît sans dériver', (tester) async {
      final controller = await pumpGame(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 60)),
      );

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      await clock.advance(tester, const Duration(seconds: 20));

      expect(partie().remaining, const Duration(seconds: 40));
    });

    testWidgets('R3.5 — le tour se termine quand le chrono atteint zéro', (
      tester,
    ) async {
      final controller = await pumpGame(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 30)),
      );

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      await clock.advance(tester, const Duration(seconds: 30));

      expect(partie().phase, GamePhase.turnSummary);
      expect(partie().remaining, Duration.zero);
    });

    testWidgets('plus rien ne tourne une fois le tour terminé', (tester) async {
      // Assertion sur `isTicking` et non sur la stabilité de l'état : le
      // réducteur ignore les `Ticked` hors tour, donc un chrono laissé vivant
      // ne se verrait nulle part — sauf sur la batterie.
      final controller = await pumpGame(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 30)),
      );

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      expect(controller.isTicking, isTrue);

      await clock.advance(tester, const Duration(seconds: 30));
      final aLaFin = partie();

      expect(controller.isTicking, isFalse);
      await clock.advance(tester, const Duration(seconds: 10));
      expect(partie(), aLaFin, reason: 'Aucun événement ne doit plus arriver');
    });

    testWidgets('le chrono ne tourne pas pendant une pause', (tester) async {
      // Même raison : invisible dans l'état, bien réel dans la poche du
      // joueur pendant les cinq minutes où l'application est en arrière-plan.
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      expect(controller.isTicking, isTrue);

      controller.pause();
      await tester.pump();
      expect(controller.isTicking, isFalse);

      controller.requestResume();
      await clock.advance(tester, const Duration(seconds: 3));
      expect(controller.isTicking, isTrue);
    });
  });

  group("l'écran ne s'éteint pas pendant un tour", () {
    testWidgets('allumé pendant le tour, relâché autour', (tester) async {
      // En manche 3 le narrateur mime sans toucher l'écran : sans ce maintien,
      // la veille système coupe l'écran et met le tour en pause tout seul.
      final controller = await pumpGame(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 30)),
      );
      expect(screenAwake, isNot(isTrue), reason: 'rien ne tourne encore');

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      expect(screenAwake, isTrue);

      controller.pause();
      await tester.pump();
      expect(screenAwake, isFalse, reason: 'en pause, la veille reprend');

      controller.requestResume();
      await clock.advance(tester, const Duration(seconds: 3));
      expect(screenAwake, isTrue);

      await clock.advance(tester, const Duration(seconds: 30));
      expect(
        screenAwake,
        isFalse,
        reason: "Le tour fini, l'écran n'a plus de raison de rester allumé",
      );
    });
  });

  group('R3.7 — arrière-plan et reprise', () {
    testWidgets('cas limite 8 — à 1 s de la fin, il reste 1 s au retour', (
      tester,
    ) async {
      final controller = await pumpGame(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 60)),
      );

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      await clock.advance(tester, const Duration(seconds: 59));
      expect(partie().remaining, const Duration(seconds: 1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(partie().isPaused, isTrue);

      // Cinq minutes hors de l'application.
      await clock.advance(tester, const Duration(minutes: 5));
      expect(partie().remaining, const Duration(seconds: 1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await clock.advance(tester, const Duration(seconds: 3));

      expect(partie().isPaused, isFalse);
      expect(
        partie().remaining,
        const Duration(seconds: 1),
        reason: 'Le tour reprend là où il en était, pas ailleurs',
      );
    });

    testWidgets('la reprise passe par le compte à rebours', (tester) async {
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(container.read(playControllerProvider), 3);
      expect(
        partie().isPaused,
        isTrue,
        reason: 'Le jeu ne repart pas avant la fin du décompte',
      );

      await clock.advance(tester, const Duration(seconds: 3));
      expect(partie().isPaused, isFalse);
    });

    testWidgets("l'inactivité iOS met en pause comme l'arrière-plan", (
      tester,
    ) async {
      // Centre de contrôle, bannière d'appel entrant : l'écran est masqué, le
      // narrateur ne peut plus jouer.
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(partie().isPaused, isTrue);
    });
  });

  group('R3.8 — la pause à la main gèle tout', () {
    testWidgets('aucune carte ne se valide en pause', (tester) async {
      // Cas limite 13 : le chrono figé rend l'action gratuite, c'est ce qui la
      // rend tentante.
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      final avant = partie();

      controller.pause();
      await tester.pump();
      controller
        ..found()
        ..passed();
      await tester.pump();

      expect(partie().scores, avant.scores);
      expect(partie().pile, avant.pile);
    });

    testWidgets('revenir au premier plan ne lève pas une pause manuelle', (
      tester,
    ) async {
      // Sinon le joueur qui met en pause pour souffler voit la partie repartir
      // toute seule au premier passage par le sélecteur d'applications.
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      controller.pause();
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await clock.advance(tester, const Duration(seconds: 5));

      expect(partie().isPaused, isTrue);
      expect(container.read(playControllerProvider), isNull);
    });

    testWidgets('la reprise manuelle passe aussi par le compte à rebours', (
      tester,
    ) async {
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      controller.pause();
      await tester.pump();

      controller.requestResume();
      await tester.pump();
      expect(container.read(playControllerProvider), 3);

      await clock.advance(tester, const Duration(seconds: 3));
      expect(partie().isPaused, isFalse);
    });

    testWidgets('une pause en plein décompte le fait repartir de trois', (
      tester,
    ) async {
      // Rendre le téléphone demande le même temps qu'à la première fois.
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      controller.pause();
      await tester.pump();
      controller.requestResume();
      await clock.advance(tester, const Duration(seconds: 2));
      expect(container.read(playControllerProvider), 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(container.read(playControllerProvider), isNull);

      controller.requestResume();
      await tester.pump();
      expect(container.read(playControllerProvider), 3);
    });
  });

  group('les actions de carte', () {
    testWidgets('trouvée marque un point et retire la carte', (tester) async {
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      final carte = partie().currentCardId;

      controller.found();
      await tester.pump();

      expect(partie().pile, isNot(contains(carte)));
      expect(partie().turn!.score, 1);
    });

    testWidgets('aucune action ne passe pendant le compte à rebours', (
      tester,
    ) async {
      // La carte n'est pas encore affichée : un tap à ce moment vient d'un
      // doigt resté sur l'écran, pas d'une réponse.
      final controller = await pumpGame(tester);

      controller.startTurn();
      await tester.pump();
      controller.found();
      await tester.pump();

      expect(partie().phase, GamePhase.turnIntro);
      expect(partie().turn!.results, isEmpty);
    });

    testWidgets('R4.1 — la dernière carte trouvée arrête tout', (tester) async {
      final controller = await pumpGame(
        tester,
        game: testGame(
          cardCount: 12,
          turnDuration: const Duration(seconds: 60),
        ),
      );

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      for (var i = 0; i < 12; i++) {
        controller.found();
        await tester.pump();
      }

      expect(partie().pile, isEmpty);
      expect(partie().phase, GamePhase.turnSummary);

      final aLaFin = partie();
      await clock.advance(tester, const Duration(seconds: 10));
      expect(
        partie(),
        aLaFin,
        reason: 'Le temps restant est perdu, pas consommé en arrière-fond',
      );
    });
  });

  group('R3.6 — le récapitulatif est corrigeable', () {
    testWidgets('corriger une carte recalcule le score et le paquet', (
      tester,
    ) async {
      final controller = await pumpGame(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 30)),
      );

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      final carte = partie().currentCardId!;
      controller.found();
      await clock.advance(tester, const Duration(seconds: 30));

      expect(partie().phase, GamePhase.turnSummary);
      expect(partie().turn!.score, 1);

      controller.correctResult(carte, TurnOutcome.passed);
      await tester.pump();

      expect(partie().turn!.score, 0);
      expect(partie().pile, contains(carte));
    });
  });
}
