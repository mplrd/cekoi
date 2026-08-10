import 'package:cekoi/domain/engine/game_event.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  const minute = Duration(seconds: 60);

  group("R3.2 — le chrono démarre à l'affichage de la première carte", () {
    test('la partie ouvre sur un écran de tour, chrono à zéro', () {
      final state = testGame();

      expect(state.phase, GamePhase.turnIntro);
      expect(state.turn!.elapsed, Duration.zero);
      expect(state.remaining, minute);
      expect(state.currentCardId, state.pile.first);
    });

    test('un tick avant le départ du tour ne consomme pas de temps', () {
      // Le compte à rebours de 3 s se joue avant que le chrono ne parte : un
      // tick qui arriverait pendant grignoterait le temps du narrateur.
      final state = testGame().apply([const GameEvent.ticked(minute)]);

      expect(state.remaining, minute);
      expect(state.phase, GamePhase.turnIntro);
    });

    test('le tour démarré passe en jeu sans avoir consommé de temps', () {
      final state = testGame().apply([const GameEvent.turnStarted()]);

      expect(state.phase, GamePhase.playing);
      expect(state.remaining, minute);
    });
  });

  group('R3.3 — les deux actions du narrateur', () {
    test('trouvé retire la carte du paquet et marque un point', () {
      final game = testGame().apply([const GameEvent.turnStarted()]);
      final first = game.currentCardId;

      final state = game.apply([const GameEvent.cardFound()]);

      expect(state.pile, isNot(contains(first)));
      expect(state.pile, hasLength(5));
      expect(state.scoreOf('team-1'), 1);
      expect(state.currentCardId, isNot(first));
    });

    test('passer renvoie la carte au fond du paquet, sans pénalité', () {
      final game = testGame().apply([const GameEvent.turnStarted()]);
      final first = game.currentCardId;

      final state = game.apply([const GameEvent.cardPassed()]);

      expect(state.pile, hasLength(6), reason: 'La carte reste en jeu');
      expect(state.pile.last, first, reason: 'Elle repart au fond du paquet');
      expect(state.scoreOf('team-1'), 0);
    });

    test('une carte passée ressort si le paquet fait le tour complet', () {
      final game = testGame().apply([const GameEvent.turnStarted()]);
      final first = game.currentCardId;

      final state = game.apply([
        for (var i = 0; i < 6; i++) const GameEvent.cardPassed(),
      ]);

      expect(state.currentCardId, first);
    });

    test("une carte passée puis trouvée n'apparaît qu'une fois au récap", () {
      final game = testGame(cardCount: 2).apply([
        const GameEvent.turnStarted(),
      ]);
      final first = game.currentCardId;

      // Passée, le paquet tourne, on la retrouve et cette fois elle est
      // trouvée : le récapitulatif doit montrer une ligne, pas deux.
      final state = game.apply([
        const GameEvent.cardPassed(),
        const GameEvent.cardPassed(),
        const GameEvent.cardFound(),
      ]);

      final lines = state.turn!.results.where((r) => r.cardId == first);
      expect(lines, hasLength(1));
      expect(lines.single.outcome, TurnOutcome.found);
      expect(state.scoreOf('team-1'), 1);
    });

    test('R3.6 — une carte passée garde sa ligne, même revenue en tête', () {
      // Le paquet fait le tour complet : la carte affichée quand le chrono
      // tombe est celle qu'on a passée en premier. Elle a été tranchée, donc
      // elle a sa ligne — sans quoi une carte passée à tort deviendrait
      // incorrigible.
      final state = testGame(cardCount: 3);
      final premiere = state.pile.first;

      final apres = state.apply([
        const GameEvent.turnStarted(),
        const GameEvent.cardPassed(),
        const GameEvent.cardPassed(),
        const GameEvent.cardPassed(),
        const GameEvent.ticked(Duration(minutes: 10)),
      ]);

      expect(
        apres.phase,
        GamePhase.turnSummary,
        reason: 'point de départ : le chrono est bien tombé',
      );
      expect(apres.pile.first, premiere);
      expect(apres.turn!.resultFor(premiere)?.outcome, TurnOutcome.passed);
    });
  });

  group('R3.4 — passer est indisponible sur la dernière carte', () {
    test("canPass devient faux quand il ne reste qu'une carte", () {
      // Cas limite 2.
      var state = testGame(cardCount: 2).apply([
        const GameEvent.turnStarted(),
      ]);
      expect(state.canPass, isTrue);

      state = state.apply([const GameEvent.cardFound()]);

      expect(state.pile, hasLength(1));
      expect(
        state.canPass,
        isFalse,
        reason:
            'Passer la dernière carte la ferait revenir aussitôt, le '
            'tour ne pourrait plus avancer',
      );
    });

    test("l'événement passer reste sans effet sur la dernière carte", () {
      final state = testGame(cardCount: 2).apply([
        const GameEvent.turnStarted(),
        const GameEvent.cardFound(),
      ]);

      expect(state.apply([const GameEvent.cardPassed()]), state);
    });

    test('canPass est faux hors du jeu', () {
      expect(testGame().canPass, isFalse, reason: 'En intro de tour');
    });
  });

  group("R3.9 — passer n'existe pas en manche 1", () {
    test('cas limite 6 : passer en description libre est refusé', () {
      final game = testGame(
        roundIndex: 0,
      ).apply([const GameEvent.turnStarted()]);
      expect(game.canPass, isFalse);

      final state = game.apply([const GameEvent.cardPassed()]);

      expect(
        state,
        game,
        reason:
            'Ni le paquet ni le récapitulatif ne bougent : rien ne doit '
            "trahir qu'une action a été reçue",
      );
      expect(state.turn!.results, isEmpty);
    });

    test('la même action est acceptée en manche 2', () {
      // Le pendant du test précédent. Sans lui, supprimer *toute* la logique
      // de passage laisserait le premier au vert.
      final game = testGame(
        roundIndex: 1,
      ).apply([const GameEvent.turnStarted()]);
      final first = game.currentCardId;

      final state = game.apply([const GameEvent.cardPassed()]);

      expect(state.canPass, isTrue);
      expect(state.pile.last, first);
      expect(state.turn!.results, hasLength(1));
    });

    test('la manche 3 autorise aussi de passer', () {
      final game = testGame(
        roundIndex: 2,
      ).apply([const GameEvent.turnStarted()]);

      expect(game.canPass, isTrue);
      expect(game.apply([const GameEvent.cardPassed()]), isNot(game));
    });

    test('trouvé reste disponible en manche 1', () {
      // R3.9 retire une action, pas les deux : une garde trop large rendrait
      // la première manche injouable.
      final game = testGame(
        roundIndex: 0,
      ).apply([const GameEvent.turnStarted()]);

      final state = game.apply([const GameEvent.cardFound()]);

      expect(state.pile, hasLength(5));
      expect(state.scoreOf('team-1'), 1);
    });

    test('corriger une carte en « pas trouvée » reste possible (R3.6)', () {
      // `passed` au récapitulatif veut dire « pas trouvée » : c'est
      // l'annulation d'un tap de trop, pas un contournement de R3.9.
      var state = testGame(cardCount: 2, roundIndex: 0).apply([
        const GameEvent.turnStarted(),
        const GameEvent.cardFound(),
        const GameEvent.cardFound(),
      ]);
      expect(state.phase, GamePhase.turnSummary);

      final last = state.turn!.results.last.cardId;
      state = state.apply([
        GameEvent.resultCorrected(cardId: last, outcome: TurnOutcome.passed),
      ]);

      expect(state.pile, [last]);
      expect(state.scoreOf('team-1'), 1);
    });
  });

  group('R3.5 — fin du tour', () {
    test('le tour se termine quand le chrono atteint zéro', () {
      final state = testGame().apply([
        const GameEvent.turnStarted(),
        const GameEvent.ticked(minute),
      ]);

      expect(state.phase, GamePhase.turnSummary);
      expect(state.remaining, Duration.zero);
    });

    test('un tick au-delà de la durée ne rend pas un temps négatif', () {
      final state = testGame().apply([
        const GameEvent.turnStarted(),
        const GameEvent.ticked(Duration(seconds: 75)),
      ]);

      expect(state.turn!.elapsed, minute);
      expect(state.remaining, Duration.zero);
    });

    test('le tour se termine quand le paquet est vide', () {
      final state = testGame(cardCount: 2).apply([
        const GameEvent.turnStarted(),
        const GameEvent.cardFound(),
        const GameEvent.cardFound(),
      ]);

      expect(state.pile, isEmpty);
      expect(state.phase, GamePhase.turnSummary);
    });

    test('les actions du narrateur sont ignorées hors du jeu', () {
      final intro = testGame();

      expect(intro.apply([const GameEvent.cardFound()]), intro);
      expect(intro.apply([const GameEvent.cardPassed()]), intro);
    });

    test('un tour terminé ne peut pas être redémarré', () {
      // Sans la garde de phase, un « démarrer » reçu sur le récapitulatif
      // repasserait en jeu avec le paquet dans son état de fin de tour.
      final summary = testGame().apply([
        const GameEvent.turnStarted(),
        const GameEvent.ticked(Duration(minutes: 1)),
      ]);
      expect(summary.phase, GamePhase.turnSummary);

      expect(summary.apply([const GameEvent.turnStarted()]), summary);
    });

    test('un temps écoulé aberrant ne rend jamais un restant négatif', () {
      // Un état relu du disque peut porter n'importe quoi : le calcul du
      // temps restant est le dernier rempart avant l'affichage.
      final game = testGame();
      final corrupted = game.copyWith(
        turn: game.turn!.copyWith(elapsed: const Duration(minutes: 5)),
      );

      expect(corrupted.remaining, Duration.zero);
    });
  });

  group('R3.7 — mise en arrière-plan pendant un tour', () {
    test('les ticks reçus en pause ne consomment pas de temps', () {
      // Cas limite 8 : arrière-plan à 1 s de la fin, il doit rester 1 s.
      var state = testGame().apply([
        const GameEvent.turnStarted(),
        const GameEvent.ticked(Duration(seconds: 59)),
      ]);
      expect(state.remaining, const Duration(seconds: 1));

      state = state.apply([
        const GameEvent.paused(),
        const GameEvent.ticked(Duration(minutes: 2)),
        const GameEvent.ticked(Duration(minutes: 5)),
      ]);

      expect(state.remaining, const Duration(seconds: 1));
      expect(
        state.phase,
        GamePhase.playing,
        reason: 'Un tour ne peut pas expirer pendant que le jeu est en pause',
      );
    });

    test('la reprise repart du temps restant', () {
      final state = testGame().apply([
        const GameEvent.turnStarted(),
        const GameEvent.ticked(Duration(seconds: 59)),
        const GameEvent.paused(),
        const GameEvent.ticked(Duration(minutes: 2)),
        const GameEvent.resumed(),
        const GameEvent.ticked(Duration(milliseconds: 59500)),
      ]);

      expect(state.turn!.isPaused, isFalse);
      expect(state.remaining, const Duration(milliseconds: 500));
    });

    test('mettre en pause hors du jeu ne change rien', () {
      final intro = testGame();

      expect(intro.apply([const GameEvent.paused()]), intro);
      expect(intro.apply([const GameEvent.resumed()]), intro);
    });

    test('un tick en retard ne fait pas remonter le chrono', () {
      // Après une reprise, un tick émis avant la pause peut encore arriver.
      // Le voir rallonger le temps du narrateur serait pire que de l'ignorer.
      final state = testGame().apply([
        const GameEvent.turnStarted(),
        const GameEvent.ticked(Duration(seconds: 30)),
        const GameEvent.ticked(Duration(seconds: 10)),
      ]);

      expect(state.remaining, const Duration(seconds: 30));
    });
  });

  group('R3.8 — une pause gèle le tour entièrement', () {
    GameState pausedGame() => testGame().apply([
      const GameEvent.turnStarted(),
      const GameEvent.paused(),
    ]);

    test('cas limite 13 : « Trouvé » en pause ne rapporte rien', () {
      // Le chrono est arrêté : sans cette règle, valider une carte est un
      // point gratuit, et rien n'empêche d'en valider dix.
      final paused = pausedGame();

      final after = paused.apply([
        const GameEvent.cardFound(),
        const GameEvent.cardFound(),
        const GameEvent.cardFound(),
      ]);

      expect(after, paused);
      expect(after.scoreOf('team-1'), 0);
      expect(after.pile, hasLength(6));
    });

    test('« Passer » en pause ne bouge pas le paquet', () {
      final paused = pausedGame();

      expect(paused.apply([const GameEvent.cardPassed()]), paused);
    });

    test('canAct et canPass tombent à faux pendant la pause', () {
      final paused = pausedGame();

      expect(paused.isPaused, isTrue);
      expect(paused.canAct, isFalse);
      expect(paused.canPass, isFalse);
    });

    test('la reprise rend la main au narrateur', () {
      final resumed = pausedGame().apply([const GameEvent.resumed()]);

      expect(resumed.canAct, isTrue);
      expect(resumed.apply([const GameEvent.cardFound()]).scoreOf('team-1'), 1);
    });

    test('un tour ne peut pas se terminer pendant une pause', () {
      // Ni le chrono ni le paquet ne peuvent l'achever : c'est ce qui garantit
      // qu'aucun tour figé ne rejoint jamais l'historique.
      final paused = testGame(cardCount: 2).apply([
        const GameEvent.turnStarted(),
        const GameEvent.cardFound(),
        const GameEvent.paused(),
      ]);

      final after = paused.apply([
        const GameEvent.ticked(Duration(minutes: 10)),
        const GameEvent.cardFound(),
      ]);

      expect(after.phase, GamePhase.playing);
      expect(after.pile, hasLength(1));
    });
  });

  group('cas limite 5 — un tour entier sans aucune carte trouvée', () {
    test('le paquet est intact en fin de tour, sans boucle infinie', () {
      final game = testGame().apply([const GameEvent.turnStarted()]);
      final before = [...game.pile];

      final state = game.apply([
        for (var i = 0; i < 6; i++) const GameEvent.cardPassed(),
        const GameEvent.ticked(minute),
      ]);

      expect(state.pile, before);
      expect(state.scoreOf('team-1'), 0);
      expect(state.turn!.results, hasLength(6));
      expect(
        state.turn!.results.every((r) => r.outcome == TurnOutcome.passed),
        isTrue,
      );
      expect(state.phase, GamePhase.turnSummary);
    });
  });

  group('R3.6 — le récapitulatif de fin de tour est corrigeable', () {
    /// Un tour joué jusqu'au chrono : une carte trouvée, une passée.
    GameState playedTurn() => testGame().apply([
      const GameEvent.turnStarted(),
      const GameEvent.cardFound(),
      const GameEvent.cardPassed(),
      const GameEvent.ticked(minute),
    ]);

    test('corriger passé en trouvé retire la carte et ajoute un point', () {
      final state = playedTurn();
      final passed = state.turn!.results.last.cardId;
      expect(state.pile, contains(passed));

      final corrected = state.apply([
        GameEvent.resultCorrected(cardId: passed, outcome: TurnOutcome.found),
      ]);

      expect(corrected.pile, isNot(contains(passed)));
      expect(corrected.scoreOf('team-1'), 2);
    });

    test('corriger trouvé en passé remet la carte au paquet', () {
      final state = playedTurn();
      final found = state.turn!.results.first.cardId;
      expect(state.pile, isNot(contains(found)));

      final corrected = state.apply([
        GameEvent.resultCorrected(cardId: found, outcome: TurnOutcome.passed),
      ]);

      expect(corrected.pile, contains(found));
      expect(corrected.pile.last, found, reason: 'Elle repart au fond');
      expect(corrected.scoreOf('team-1'), 0);
    });

    test('deux corrections successives rendent le paquet à son contenu', () {
      // Le geste le plus fréquent en usage réel : on corrige, puis on se rend
      // compte qu'on avait raison la première fois.
      //
      // Le score revient exactement à sa valeur, et le paquet à son contenu —
      // mais pas forcément à son ordre : une carte remise au paquet repart au
      // fond, comme une carte passée. C'est assumé, et c'est pour cela que
      // l'assertion porte sur l'ensemble et non sur la liste.
      final state = playedTurn();
      final found = state.turn!.results.first.cardId;

      final corrected = state.apply([
        GameEvent.resultCorrected(cardId: found, outcome: TurnOutcome.passed),
        GameEvent.resultCorrected(cardId: found, outcome: TurnOutcome.found),
      ]);

      expect(corrected.scoreOf('team-1'), 1);
      expect(corrected.pile.toSet(), state.pile.toSet());
      expect(corrected.turn!.results, state.turn!.results);
    });

    test('une carte corrigée en « passée » repart au fond du paquet', () {
      // Deux cartes passées dans l'ordre, la première n'est donc plus en
      // queue. La corriger deux fois la ramène en queue : le paquet garde son
      // contenu, pas son ordre.
      final state = testGame().apply([
        const GameEvent.turnStarted(),
        const GameEvent.cardPassed(),
        const GameEvent.cardPassed(),
        const GameEvent.ticked(Duration(minutes: 1)),
      ]);
      final first = state.turn!.results.first.cardId;
      expect(state.pile.last, isNot(first));

      final corrected = state.apply([
        GameEvent.resultCorrected(cardId: first, outcome: TurnOutcome.found),
        GameEvent.resultCorrected(cardId: first, outcome: TurnOutcome.passed),
      ]);

      expect(corrected.pile.toSet(), state.pile.toSet());
      expect(corrected.pile.last, first);
    });

    test('corriger vers le même résultat ne change rien', () {
      final state = playedTurn();
      final found = state.turn!.results.first.cardId;

      expect(
        state.apply([
          GameEvent.resultCorrected(cardId: found, outcome: TurnOutcome.found),
        ]),
        state,
      );
    });

    test("corriger une carte qui n'a pas été vue ne change rien", () {
      final state = playedTurn();

      expect(
        state.apply([
          const GameEvent.resultCorrected(
            cardId: 'deck:jamais-vue',
            outcome: TurnOutcome.found,
          ),
        ]),
        state,
      );
    });

    test('une correction reçue en plein jeu est ignorée', () {
      final playing = testGame().apply([
        const GameEvent.turnStarted(),
        const GameEvent.cardFound(),
      ]);
      final found = playing.turn!.results.first.cardId;

      expect(
        playing.apply([
          GameEvent.resultCorrected(cardId: found, outcome: TurnOutcome.passed),
        ]),
        playing,
      );
    });
  });
}
