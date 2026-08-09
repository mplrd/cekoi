import 'package:cekoi/domain/engine/game_engine.dart';
import 'package:cekoi/domain/engine/game_event.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/rules/round.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// Joue un tour entier : [found] cartes trouvées, puis le chrono expire et le
/// récapitulatif est validé. Si le paquet se vide avant, le chrono qui expire
/// est simplement sans effet — le tour est déjà terminé (R4.1).
GameState playTurn(GameState state, {int found = 0}) => state.apply([
  const GameEvent.turnStarted(),
  for (var i = 0; i < found; i++) const GameEvent.cardFound(),
  const GameEvent.ticked(Duration(minutes: 10)),
  const GameEvent.turnConfirmed(),
]);

void main() {
  group("R4.1 — la manche s'arrête sur la dernière carte trouvée", () {
    test("cas limite 1 : le paquet se vide alors qu'il reste du temps", () {
      final state = testGame().apply([
        const GameEvent.turnStarted(),
        const GameEvent.ticked(Duration(seconds: 40)),
        for (var i = 0; i < 6; i++) const GameEvent.cardFound(),
      ]);

      expect(state.pile, isEmpty);
      expect(
        state.phase,
        GamePhase.turnSummary,
        reason: 'La manche se termine immédiatement, sans attendre le chrono',
      );
      expect(state.remaining, const Duration(seconds: 20));
    });

    test('le temps restant est perdu, pas reporté', () {
      final state = testGame()
          .apply([
            const GameEvent.turnStarted(),
            const GameEvent.ticked(Duration(seconds: 40)),
            for (var i = 0; i < 6; i++) const GameEvent.cardFound(),
            const GameEvent.turnConfirmed(),
          ])
          .apply([const GameEvent.nextRoundStarted()]);

      expect(state.remaining, const Duration(seconds: 60));
    });

    test('la validation du récap clôt la manche et affiche les scores', () {
      final state = testGame().apply([
        const GameEvent.turnStarted(),
        for (var i = 0; i < 6; i++) const GameEvent.cardFound(),
        const GameEvent.turnConfirmed(),
      ]);

      expect(state.phase, GamePhase.roundSummary);
      expect(
        state.roundIndex,
        0,
        reason: 'La manche suivante pas encore ouverte',
      );
    });
  });

  group('R4.2 — toutes les cartes sont remises en jeu et remélangées', () {
    test('la manche suivante rejoue le paquet entier', () {
      final state = testGame().apply([
        const GameEvent.turnStarted(),
        for (var i = 0; i < 6; i++) const GameEvent.cardFound(),
        const GameEvent.turnConfirmed(),
        const GameEvent.nextRoundStarted(),
      ]);

      expect(state.pile, hasLength(6));
      expect(state.pile.toSet(), state.deck.map((c) => c.id).toSet());
      expect(state.round, Round.oneWord);
      expect(state.phase, GamePhase.turnIntro);
    });

    test("l'ordre du paquet change d'une manche à l'autre", () {
      // Le test doit partir d'une vraie partie, pas de la fixture : celle-ci
      // construit un paquet volontairement non mélangé, et comparer la manche
      // 2 à un paquet non mélangé prouve seulement qu'elle est mélangée tout
      // court. Ici les deux manches passent par le même mélange, et c'est
      // bien la graine dérivée du numéro de manche qui les distingue.
      final first = startGame(
        config: const GameConfig(
          mode: Audience.family,
          deckIds: ['deck'],
          turnDuration: Duration(seconds: 60),
          roundCount: 3,
        ),
        players: [
          for (final id in ['team-1-1', 'team-1-2', 'team-2-1', 'team-2-2'])
            testPlayer(id),
        ],
        teams: [testTeam('team-1', 2), testTeam('team-2', 2)],
        deck: testCards(12),
        seed: 4,
      );
      final pileOfRoundOne = [...first.pile];

      final second = first.apply([
        const GameEvent.turnStarted(),
        for (var i = 0; i < 12; i++) const GameEvent.cardFound(),
        const GameEvent.turnConfirmed(),
        const GameEvent.nextRoundStarted(),
      ]);

      expect(second.pile.toSet(), pileOfRoundOne.toSet());
      expect(
        second.pile,
        isNot(pileOfRoundOne),
        reason:
            'Sans graine dérivée du numéro de manche, les trois manches '
            'rejoueraient le paquet dans le même ordre — ce qui se voit à '
            "l'œil nu en partie",
      );
    });

    test('le remélange est déterministe à graine égale', () {
      List<String> pileOfRoundTwo(int seed) =>
          testGame(cardCount: 12, seed: seed).apply([
            const GameEvent.turnStarted(),
            for (var i = 0; i < 12; i++) const GameEvent.cardFound(),
            const GameEvent.turnConfirmed(),
            const GameEvent.nextRoundStarted(),
          ]).pile;

      expect(pileOfRoundTwo(5), pileOfRoundTwo(5));
      expect(pileOfRoundTwo(5), isNot(pileOfRoundTwo(6)));
    });
  });

  group("R4.3 — l'équipe suivante ouvre la manche", () {
    test("l'équipe qui vide le paquet n'enchaîne pas deux tours", () {
      // Sans cette règle, l'équipe qui termine la manche rejouerait
      // immédiatement à l'ouverture de la suivante.
      final state = testGame().apply([
        const GameEvent.turnStarted(),
        for (var i = 0; i < 6; i++) const GameEvent.cardFound(),
        const GameEvent.turnConfirmed(),
        const GameEvent.nextRoundStarted(),
      ]);

      expect(state.activeTeam.id, 'team-2');
      expect(state.turn!.teamId, 'team-2');
    });

    test('les tours alternent au sein de la manche', () {
      var state = testGame(cardCount: 12);
      final order = <String>[];

      for (var i = 0; i < 4; i++) {
        order.add(state.turn!.teamId);
        state = playTurn(state);
      }

      expect(order, ['team-1', 'team-2', 'team-1', 'team-2']);
    });
  });

  group('R3.1 — la rotation du narrateur est interne à chaque équipe', () {
    test('cas limite 6 : une équipe de 2 et une de 5 tournent séparément', () {
      var state = testGame(cardCount: 12, teamSizes: [2, 5]);
      final narrators = <String>[];

      for (var i = 0; i < 6; i++) {
        narrators.add(state.turn!.narratorId);
        state = playTurn(state);
      }

      expect(narrators, [
        'team-1-1', 'team-2-1', //
        'team-1-2', 'team-2-2', //
        'team-1-1', 'team-2-3', //
      ]);
    });

    test('le narrateur avance même quand le tour ne rapporte rien', () {
      final state = playTurn(testGame(cardCount: 12));

      expect(state.turn!.teamId, 'team-2');
      expect(
        state.teams.first.currentNarratorId,
        'team-1-2',
        reason: "Le curseur de l'équipe 1 a avancé pour son prochain tour",
      );
    });
  });

  group('R4.4 — scores intermédiaires entre deux manches', () {
    test('le détail par manche et le cumul sont disponibles', () {
      var state = testGame(cardCount: 12, roundCount: 2);
      state = playTurn(state, found: 5); // team-1
      state = playTurn(state, found: 7); // team-2, vide le paquet
      expect(state.phase, GamePhase.roundSummary);

      expect(state.scoresByRound[Round.freeDescription], {
        'team-1': 5,
        'team-2': 7,
      });
      expect(state.scores, {'team-1': 5, 'team-2': 7});

      state = state.apply([const GameEvent.nextRoundStarted()]);
      state = playTurn(state, found: 4); // team-1 ouvre (R4.3)
      state = playTurn(state, found: 8); // team-2 vide le paquet

      expect(state.scoresByRound[Round.mime], {'team-1': 4, 'team-2': 8});
      expect(
        state.scores,
        {'team-1': 9, 'team-2': 15},
        reason: 'R5.1 — le total est le cumul des manches',
      );
    });

    test('une manche non jouée ne figure pas au détail', () {
      final state = testGame(cardCount: 12);

      expect(state.scoresByRound, isEmpty);
      expect(state.scores, {'team-1': 0, 'team-2': 0});
    });
  });

  group('R2.2 — la partie tient le nombre de manches configuré', () {
    test('une partie en deux manches joue la 1 puis la 3', () {
      var state = testGame(cardCount: 6, roundCount: 2);
      expect(state.round, Round.freeDescription);

      state = playTurn(state, found: 6).apply([
        const GameEvent.nextRoundStarted(),
      ]);

      expect(state.round, Round.mime);
    });

    test('la partie se termine après la dernière manche', () {
      var state = testGame(cardCount: 6, roundCount: 2);
      state = playTurn(state, found: 6); // team-1 vide la manche 1
      state = state.apply([const GameEvent.nextRoundStarted()]);
      state = playTurn(state, found: 4); // team-2 ouvre la manche 3
      state = playTurn(state, found: 2); // team-1 la termine

      expect(state.scores, {'team-1': 8, 'team-2': 4});
      expect(state.phase, GamePhase.finished);
      expect(state.isOver, isTrue);
      expect(
        state.apply([const GameEvent.nextRoundStarted()]),
        state,
        reason: "Il n'y a plus de manche à ouvrir",
      );
    });
  });

  group('R5 — fin de partie', () {
    test('R5.2 — la meilleure équipe gagne', () {
      var state = testGame(cardCount: 6, roundCount: 2);
      state = playTurn(state, found: 2); // team-1
      state = playTurn(state, found: 4); // team-2 vide le paquet
      state = state.apply([const GameEvent.nextRoundStarted()]);
      state = playTurn(state, found: 1); // team-1
      state = playTurn(state, found: 5); // team-2

      expect(state.phase, GamePhase.finished);
      expect(state.scores, {'team-1': 3, 'team-2': 9});
      expect(state.winnerIds, ['team-2']);
    });

    test('R5.3 — une égalité en tête ouvre une manche de départage', () {
      var state = testGame(cardCount: 6, roundCount: 2);
      state = playTurn(state, found: 3);
      state = playTurn(state, found: 3);
      state = state.apply([const GameEvent.nextRoundStarted()]);
      state = playTurn(state, found: 3);
      state = playTurn(state, found: 3);

      expect(state.scores, {'team-1': 6, 'team-2': 6});
      expect(state.phase, GamePhase.tieBreak);
      expect(state.tieBreakTeamIds, ['team-1', 'team-2']);
      expect(state.tieBreakCard, isNotNull);
      expect(
        state.winnerIds,
        isEmpty,
        reason:
            "Tant que le départage n'est pas joué, il n'y a pas de "
            'vainqueur',
      );
    });

    test('cas limite 7 : trois équipes à égalité parfaite', () {
      var state = testGame(
        cardCount: 12,
        teamSizes: [2, 2, 2],
        roundCount: 2,
      );
      for (final found in [4, 4, 4]) {
        state = playTurn(state, found: found);
      }
      state = state.apply([const GameEvent.nextRoundStarted()]);
      for (final found in [4, 4, 4]) {
        state = playTurn(state, found: found);
      }

      expect(state.scores.values, everyElement(8));
      expect(state.phase, GamePhase.tieBreak);
      expect(state.tieBreakTeamIds, ['team-1', 'team-2', 'team-3']);
    });

    test('seules les équipes en tête participent au départage', () {
      var state = testGame(
        cardCount: 12,
        teamSizes: [2, 2, 2],
        roundCount: 2,
      );
      state = playTurn(state, found: 5); // team-1
      state = playTurn(state, found: 5); // team-2
      state = playTurn(state, found: 2); // team-3 vide le paquet
      state = state.apply([const GameEvent.nextRoundStarted()]);
      state = playTurn(state, found: 5); // team-1 ouvre
      state = playTurn(state, found: 5); // team-2
      state = playTurn(state, found: 2); // team-3

      expect(state.scores, {'team-1': 10, 'team-2': 10, 'team-3': 4});
      expect(state.tieBreakTeamIds, ['team-1', 'team-2']);
    });

    test('le vainqueur du départage remporte la partie', () {
      final tied = tiedGame();

      final state = tied.apply([
        const GameEvent.tieBreakWon(teamId: 'team-2'),
      ]);

      expect(state.phase, GamePhase.finished);
      expect(state.winnerIds, ['team-2']);
      expect(
        state.scores,
        tied.scores,
        reason: 'Le départage désigne un vainqueur, il ne marque pas de point',
      );
    });

    test('une équipe hors égalité ne peut pas remporter le départage', () {
      var state = testGame(
        cardCount: 12,
        teamSizes: [2, 2, 2],
        roundCount: 2,
      );
      state = playTurn(state, found: 5);
      state = playTurn(state, found: 5);
      state = playTurn(state, found: 2);
      state = state.apply([const GameEvent.nextRoundStarted()]);
      state = playTurn(state, found: 5);
      state = playTurn(state, found: 5);
      state = playTurn(state, found: 2);

      expect(
        state.apply([const GameEvent.tieBreakWon(teamId: 'team-3')]),
        state,
      );
    });

    test('un départage sans vainqueur est rejoué avec une autre carte', () {
      // R5.3 : « répétée jusqu'à départage ».
      final tied = tiedGame();

      final again = tied.apply([const GameEvent.tieBreakRestarted()]);

      expect(again.tieBreakCard, isNot(tied.tieBreakCard));
      expect(again.phase, GamePhase.tieBreak);
    });

    test('relancer le départage hors départage ne change rien', () {
      final playing = testGame().apply([const GameEvent.turnStarted()]);

      expect(playing.apply([const GameEvent.tieBreakRestarted()]), playing);
    });

    test('la carte de départage vient de la réserve, pas du paquet', () {
      // R5.3 : les cartes du paquet ont été vues trois fois, elles ne
      // départageraient plus rien.
      final reserve = testCards(3, prefix: 'reserve');
      final tied = tiedGame().copyWith(tieBreakReserve: reserve);

      expect(tied.tieBreakCard, reserve.first);
      expect(tied.deck, isNot(contains(tied.tieBreakCard)));

      final again = tied.apply([const GameEvent.tieBreakRestarted()]);
      expect(again.tieBreakCard, reserve[1]);
    });

    test('sans réserve, le départage se rabat sur le paquet joué', () {
      // Vivier trop juste : un départage au réflexe vaut mieux que pas de
      // départage du tout.
      final tied = tiedGame();

      expect(tied.tieBreakReserve, isEmpty);
      expect(tied.deck, contains(tied.tieBreakCard));
    });
  });

  group(
    'cas limites 3 et 4 — corrections qui décident de la fin de manche',
    () {
      test('cas 3 : marquer trouvée la dernière carte termine la manche', () {
        // Le tour finit au chrono avec une carte passée encore au paquet. La
        // corriger en « trouvée » vide le paquet : la manche doit se clore, pas
        // se poursuivre avec un paquet vide.
        var state = testGame(cardCount: 2).apply([
          const GameEvent.turnStarted(),
          const GameEvent.cardPassed(),
          const GameEvent.cardFound(),
          const GameEvent.ticked(Duration(minutes: 1)),
        ]);
        expect(state.pile, hasLength(1));
        expect(state.phase, GamePhase.turnSummary);

        final passed = state.pile.single;
        state = state.apply([
          GameEvent.resultCorrected(cardId: passed, outcome: TurnOutcome.found),
        ]);
        expect(state.pile, isEmpty);

        state = state.apply([const GameEvent.turnConfirmed()]);
        expect(state.phase, GamePhase.roundSummary);
      });

      test('cas 4 : annuler la dernière carte trouvée relance la manche', () {
        var state = testGame(cardCount: 2).apply([
          const GameEvent.turnStarted(),
          const GameEvent.cardFound(),
          const GameEvent.cardFound(),
        ]);
        expect(state.pile, isEmpty);
        expect(state.phase, GamePhase.turnSummary);

        final last = state.turn!.results.last.cardId;
        state = state.apply([
          GameEvent.resultCorrected(cardId: last, outcome: TurnOutcome.passed),
          const GameEvent.turnConfirmed(),
        ]);

        expect(state.pile, [last]);
        expect(
          state.phase,
          GamePhase.turnIntro,
          reason: 'La manche reprend avec cette carte, elle ne se clôt pas',
        );
        expect(state.activeTeam.id, 'team-2');
      });
    },
  );
}

/// Une partie terminée sur une égalité parfaite entre deux équipes.
GameState tiedGame() {
  var state = testGame(cardCount: 6, roundCount: 2);
  state = playTurn(state, found: 3);
  state = playTurn(state, found: 3);
  state = state.apply([const GameEvent.nextRoundStarted()]);
  state = playTurn(state, found: 3);
  return playTurn(state, found: 3);
}
