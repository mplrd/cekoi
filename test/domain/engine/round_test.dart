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

/// Vide une manche entière, chaque équipe trouvant [found] cartes par tour.
GameState playRound(GameState state, List<int> found) {
  var current = state;
  for (final count in found) {
    current = playTurn(current, found: count);
  }
  return current;
}

void main() {
  group("R4.1 — la manche s'arrête sur la dernière carte trouvée", () {
    test("cas limite 1 : le paquet se vide alors qu'il reste du temps", () {
      final state = testGame(roundIndex: 0).apply([
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
      final state = testGame(roundIndex: 0)
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
      final state = testGame(roundIndex: 0).apply([
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

  group('R4.5 — une manche dure autant de tours qu il en faut', () {
    test('cas limite 16 : un tour fini paquet non vide relance la manche', () {
      // La manche ne s'arrête pas au bout d'un tour : le paquet fait le tour
      // de la table autant de fois qu'il le faut. Sans ça, les cartes jamais
      // vues sortiraient de la partie et la manche suivante ne rejouerait plus
      // le même paquet — le principe même du jeu (section 1).
      final state = playTurn(testGame(cardCount: 12, roundIndex: 0), found: 3);

      expect(
        state.phase,
        GamePhase.turnIntro,
        reason: 'un nouveau tour s ouvre, pas les scores intermédiaires',
      );
      expect(state.roundIndex, 0, reason: 'toujours la manche 1');
      expect(state.pile, hasLength(9));
      expect(state.turn!.teamId, 'team-2');
    });

    test('on ne passe a la manche suivante que le paquet vide', () {
      // Trois tours pour venir à bout de douze cartes : la manche ne bascule
      // qu'au dernier, quand il ne reste rien.
      var state = testGame(cardCount: 12, roundIndex: 0);

      state = playTurn(state, found: 5);
      expect(state.phase, GamePhase.turnIntro);
      state = playTurn(state, found: 5);
      expect(state.phase, GamePhase.turnIntro);
      expect(state.pile, hasLength(2));

      state = playTurn(state, found: 2);

      expect(state.phase, GamePhase.roundSummary);
      expect(state.pile, isEmpty);
    });
  });

  group('R4.6 — une carte non trouvee reste en jeu', () {
    test('cas limite 15 : la carte affichee au chrono zero repart', () {
      // Elle n'est ni perdue ni comptée : elle reste en tête du paquet pour
      // l'équipe suivante. Rien ne sort du paquet sans avoir été trouvé.
      final state = testGame(cardCount: 6, roundIndex: 0);
      final enCours = state.pile[2];

      final apres = state.apply([
        const GameEvent.turnStarted(),
        const GameEvent.cardFound(),
        const GameEvent.cardFound(),
        const GameEvent.ticked(Duration(minutes: 10)),
      ]);

      expect(
        apres.phase,
        GamePhase.turnSummary,
        reason: 'point de départ : le chrono est bien tombé',
      );
      expect(
        apres.pile.first,
        enCours,
        reason: 'la carte affichée quand le chrono tombe garde sa place',
      );
      expect(apres.pile, hasLength(4));
      expect(
        apres.turn!.results.map((r) => r.cardId),
        isNot(contains(enCours)),
        reason: "elle n'a pas été tranchée : rien à corriger au récapitulatif",
      );
    });

    test('les cartes passees repartent au tour suivant', () {
      // Ce que cette règle ajoute au cas limite 5 (`turn_test.dart`), qui
      // s'arrête à la fin du tour : les cartes passées franchissent le
      // `turnConfirmed` et se retrouvent dans le tour de l'équipe suivante.
      //
      // Leur **ordre**, lui, n'est plus garanti d'un tour à l'autre depuis
      // R4.7 : le paquet restant est rebattu quand le téléphone change de
      // mains. C'est le contenu qui fait la règle ici, pas la disposition —
      // « au fond du paquet » (R3.3) ne vaut que dans le tour.
      final state = testGame(cardCount: 6);
      final avant = [...state.pile];

      final apres = state.apply([
        const GameEvent.turnStarted(),
        const GameEvent.cardPassed(),
        const GameEvent.cardPassed(),
        const GameEvent.ticked(Duration(minutes: 10)),
        const GameEvent.turnConfirmed(),
      ]);

      expect(
        apres.turn!.teamId,
        'team-2',
        reason: 'point de départ : le tour a bien été validé (R4.3)',
      );
      expect(apres.pile.toSet(), avant.toSet());
      expect(
        apres.pile,
        hasLength(6),
        reason: 'aucune carte trouvée : le paquet est entier',
      );
    });
  });

  group('R4.7 — le paquet est rebattu a chaque tour', () {
    test("l'equipe suivante ne reprend pas le paquet dans l'ordre laisse", () {
      // Sans ça, les premières cartes du tour suivant sont exactement celles
      // sur lesquelles l'équipe précédente vient de buter, dans l'ordre où
      // elle a échoué — elle les a vues défiler à l'écran.
      final state = testGame(cardCount: 12);
      final apres = playTurn(state, found: 2);

      expect(apres.pile, hasLength(10));
      expect(
        apres.pile,
        isNot(state.pile.sublist(2)),
        reason: 'le paquet restant doit avoir été rebattu',
      );
      expect(
        apres.pile.toSet(),
        state.pile.sublist(2).toSet(),
        reason: 'rebattre ne remet aucune carte trouvée en jeu',
      );
    });

    test('le numero de tour entre dans la graine', () {
      // Vérifié sur la fonction et non sur une partie : d'un tour à l'autre,
      // le paquet d'entrée a déjà changé, si bien qu'une partie rendrait des
      // ordres différents même avec une graine figée. Seule l'égalité des
      // entrées isole ce que le numéro de tour apporte.
      //
      // Ce qu'il évite : une graine constante applique la même permutation à
      // chaque tour, et un paquet dont rien ne sort — un tour sans aucune
      // trouvée — cycle alors entre un petit nombre de dispositions.
      final paquet = [for (var i = 0; i < 12; i++) 'c-$i'];
      List<String> rebattu(int turnIndex) => GameState.reshuffleRemaining(
        pile: paquet,
        seed: 7,
        roundIndex: 1,
        turnIndex: turnIndex,
      );

      expect(rebattu(0), isNot(rebattu(1)));
      expect(rebattu(1), isNot(rebattu(2)));
      expect(rebattu(2), rebattu(2), reason: 'et reste reproductible');
    });

    test('le reducteur fait varier la graine avec le tour', () {
      // Deux états rigoureusement identiques — même paquet, même graine, même
      // manche — sauf le nombre de tours déjà joués. Si le réducteur ne passe
      // pas ce nombre au rebattage, les deux rendent le même ordre.
      //
      // C'est le seul montage qui attrape la faute : dans une partie normale,
      // le paquet d'entrée diffère déjà d'un tour à l'autre, ce qui suffit à
      // produire des ordres différents même avec une graine figée.
      final base = testGame(cardCount: 12);
      final apresUnTour = playTurn(base);

      GameState pretAValider(GameState s) => s.copyWith(
        phase: GamePhase.turnSummary,
        pile: base.pile,
        turn: PlayedTurn(round: s.round, teamId: s.activeTeam.id),
      );

      final sansHistorique = reduce(
        pretAValider(base),
        const GameEvent.turnConfirmed(),
      );
      final avecHistorique = reduce(
        pretAValider(apresUnTour),
        const GameEvent.turnConfirmed(),
      );

      expect(
        base.pile,
        pretAValider(apresUnTour).pile,
        reason: 'point de départ : les deux partent du même paquet',
      );
      expect(sansHistorique.pile, isNot(avecHistorique.pile));
    });

    test('deux tours de suite ne rendent pas le meme paquet', () {
      var state = testGame(cardCount: 12);
      state = playTurn(state);
      final apresUnTour = [...state.pile];
      state = playTurn(state);

      expect(state.pile, isNot(apresUnTour));
      expect(state.pile.toSet(), apresUnTour.toSet());
    });

    test('le rebattage est determinisme a graine egale', () {
      List<String> pileApresUnTour(int seed) =>
          playTurn(testGame(cardCount: 12, seed: seed), found: 2).pile;

      expect(pileApresUnTour(5), pileApresUnTour(5));
      expect(pileApresUnTour(5), isNot(pileApresUnTour(6)));
    });

    test('la derniere carte trouvee cloture sans rebattre dans le vide', () {
      // Le paquet vide n'a rien à rebattre : la manche s'arrête (R4.1).
      final state = playTurn(testGame(cardCount: 2, roundIndex: 0), found: 2);

      expect(state.pile, isEmpty);
      expect(state.phase, GamePhase.roundSummary);
    });
  });

  group('R4.2 — toutes les cartes sont remises en jeu et remélangées', () {
    test('la manche suivante rejoue le paquet entier', () {
      final state = testGame(roundIndex: 0).apply([
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
        ),
        teams: [testTeam('team-1'), testTeam('team-2')],
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
          testGame(cardCount: 12, seed: seed, roundIndex: 0).apply([
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
      final state = testGame(roundIndex: 0).apply([
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

    test('R3.1 — un tour annonce une équipe, jamais un joueur', () {
      // L'application ne connaît pas les joueurs (R8.2) : le tour ne porte que
      // l'équipe, et c'est elle qui désigne son narrateur à la table.
      final state = playTurn(testGame(cardCount: 12));

      expect(state.turn!.teamId, 'team-2');
      expect(state.teams.map((t) => t.name), ['team-1', 'team-2']);
    });
  });

  group('R4.4 — scores intermédiaires entre deux manches', () {
    test('le détail par manche et le cumul sont disponibles', () {
      var state = testGame(cardCount: 12, roundIndex: 0);
      state = playRound(state, [5, 7]); // team-1 puis team-2, qui vide
      expect(state.phase, GamePhase.roundSummary);

      expect(state.scoresByRound[Round.freeDescription], {
        'team-1': 5,
        'team-2': 7,
      });
      expect(state.scores, {'team-1': 5, 'team-2': 7});

      state = state.apply([const GameEvent.nextRoundStarted()]);
      state = playRound(state, [4, 8]); // team-1 ouvre (R4.3)

      expect(state.scoresByRound[Round.oneWord], {'team-1': 4, 'team-2': 8});
      expect(
        state.scores,
        {'team-1': 9, 'team-2': 15},
        reason: 'R5.1 — le total est le cumul des manches',
      );
    });

    test('une manche non jouée ne figure pas au détail', () {
      final state = testGame(cardCount: 12, roundIndex: 0);

      expect(state.scoresByRound, isEmpty);
      expect(state.scores, {'team-1': 0, 'team-2': 0});
    });
  });

  group('R2.2 — une partie, ce sont les trois manches', () {
    test('la séquence est toujours la même', () {
      final state = testGame(roundIndex: 0);

      expect(state.rounds, [Round.freeDescription, Round.oneWord, Round.mime]);
    });

    test("les manches s'enchaînent dans l'ordre de R2.1", () {
      var state = testGame(roundIndex: 0);
      final played = [state.round];

      for (var i = 0; i < 2; i++) {
        state = playTurn(state, found: 6).apply([
          const GameEvent.nextRoundStarted(),
        ]);
        played.add(state.round);
      }

      expect(played, [Round.freeDescription, Round.oneWord, Round.mime]);
    });

    test('la partie se termine après la troisième manche', () {
      var state = testGame(roundIndex: 0);
      for (var round = 0; round < 3; round++) {
        state = playTurn(state, found: 6);
        if (round < 2) {
          expect(state.phase, GamePhase.roundSummary);
          state = state.apply([const GameEvent.nextRoundStarted()]);
        }
      }

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
      var state = testGame(roundIndex: 0);
      state = playRound(state, [2, 4]); // 2 / 4
      state = state.apply([const GameEvent.nextRoundStarted()]);
      state = playRound(state, [1, 5]); // 3 / 9
      state = state.apply([const GameEvent.nextRoundStarted()]);
      state = playRound(state, [1, 5]); // 4 / 14

      expect(state.phase, GamePhase.finished);
      expect(state.scores, {'team-1': 4, 'team-2': 14});
      expect(state.winnerIds, ['team-2']);
    });

    test('R5.3 — une égalité en tête ouvre une manche de départage', () {
      final state = tiedGame();

      expect(state.scores, {'team-1': 9, 'team-2': 9});
      expect(state.phase, GamePhase.tieBreak);
      expect(state.tieBreakTeamIds, ['team-1', 'team-2']);
      expect(state.tieBreakCard, isNotNull);
      expect(
        state.winnerIds,
        isEmpty,
        reason:
            "Tant que le départage n'est pas joué, il n'y a pas de vainqueur",
      );
    });

    test('cas limite 7 : trois équipes à égalité parfaite', () {
      var state = testGame(cardCount: 12, teamCount: 3, roundIndex: 0);
      for (var round = 0; round < 3; round++) {
        state = playRound(state, [4, 4, 4]);
        if (round < 2) {
          state = state.apply([const GameEvent.nextRoundStarted()]);
        }
      }

      expect(state.scores.values, everyElement(12));
      expect(state.phase, GamePhase.tieBreak);
      expect(state.tieBreakTeamIds, ['team-1', 'team-2', 'team-3']);
    });

    test('seules les équipes en tête participent au départage', () {
      final state = unevenThreeTeamGame();

      expect(state.scores, {'team-1': 15, 'team-2': 15, 'team-3': 6});
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
      final state = unevenThreeTeamGame();

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
  var state = testGame(roundIndex: 0);
  for (var round = 0; round < 3; round++) {
    state = playRound(state, [3, 3]);
    if (round < 2) {
      state = state.apply([const GameEvent.nextRoundStarted()]);
    }
  }
  return state;
}

/// Trois équipes, deux à égalité en tête et une décrochée.
GameState unevenThreeTeamGame() {
  var state = testGame(cardCount: 12, teamCount: 3, roundIndex: 0);
  for (var round = 0; round < 3; round++) {
    state = playRound(state, [5, 5, 2]);
    if (round < 2) {
      state = state.apply([const GameEvent.nextRoundStarted()]);
    }
  }
  return state;
}
