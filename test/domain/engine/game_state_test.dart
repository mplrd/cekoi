import 'dart:convert';

import 'package:cekoi/domain/engine/game_engine.dart';
import 'package:cekoi/domain/engine/game_event.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

const _config = GameConfig(
  mode: Audience.family,
  deckIds: ['deck'],
  turnDuration: Duration(seconds: 60),
);

GameState start({
  List<Team>? teams,
  List<Card>? deck,
  int seed = 3,
}) => startGame(
  config: _config,
  teams: teams ?? [testTeam('team-1'), testTeam('team-2')],
  deck: deck ?? testCards(12),
  seed: seed,
);

void main() {
  group("startGame — garde-fous à l'ouverture d'une partie", () {
    test('une seule équipe est refusée (R8.5)', () {
      expect(() => start(teams: [testTeam('team-1')]), throwsArgumentError);
    });

    test('moins de 12 cartes est refusé (R6.2)', () {
      expect(() => start(deck: testCards(11)), throwsArgumentError);
      expect(start(deck: testCards(12)).pile, hasLength(12));
    });

    test('un paquet contenant deux fois la même carte est refusé', () {
      // Les deux lignes seraient retirées ensemble à la première trouvée : le
      // paquet se viderait plus vite que le compte affiché.
      final duplicated = testCards(12)..add(testCards(1).first);

      expect(() => start(deck: duplicated), throwsArgumentError);
    });

    test('une durée de tour hors des bornes de R6 est refusée', () {
      // startGame valide déjà équipes et cartes ; laisser passer un chrono de
      // 5 secondes serait une asymétrie difficile à justifier.
      expect(
        () => startGame(
          config: _config.copyWith(turnDuration: const Duration(seconds: 5)),
          teams: [testTeam('team-1'), testTeam('team-2')],
          deck: testCards(12),
          seed: 1,
        ),
        throwsArgumentError,
      );
      expect(
        GameConfig.isTurnDurationAllowed(const Duration(seconds: 15)),
        isTrue,
      );
      expect(
        GameConfig.isTurnDurationAllowed(const Duration(seconds: 180)),
        isTrue,
      );
      expect(
        GameConfig.isTurnDurationAllowed(const Duration(seconds: 181)),
        isFalse,
      );
    });

    test("une partie valide ouvre sur l'annonce du premier tour", () {
      final state = start();

      expect(state.phase, GamePhase.turnIntro);
      expect(state.roundIndex, 0);
      expect(state.rounds, hasLength(3));
      expect(state.activeTeam.id, 'team-1');
      expect(state.turn!.elapsed, Duration.zero);
      expect(state.history, isEmpty);
      expect(state.scores, {'team-1': 0, 'team-2': 0});
    });

    test('le paquet est mélangé, et le mélange dépend de la graine', () {
      final deck = testCards(12);
      final ordered = [for (final card in deck) card.id];

      expect(start(deck: deck, seed: 3).pile, isNot(ordered));
      expect(start(deck: deck, seed: 3).pile, start(deck: deck, seed: 3).pile);
      expect(
        start(deck: deck, seed: 3).pile,
        isNot(start(deck: deck, seed: 4).pile),
      );
      expect(start(deck: deck).pile.toSet(), ordered.toSet());
    });
  });

  group("R3.5, R3.6 — la carte à l'écran quand le chrono tombe", () {
    /// Le tour de 12 cartes, dont on en trouve [trouvees] avant le buzzer.
    (GameState, Card?) turnCutByTimer(int trouvees) {
      var state = reduce(start(), const GameEvent.turnStarted());
      for (var i = 0; i < trouvees; i++) {
        state = reduce(state, const GameEvent.cardFound());
      }
      final aLEcran = state.currentCard;
      return (
        reduce(state, const GameEvent.ticked(Duration(seconds: 60))),
        aLEcran,
      );
    }

    test('elle est nommable une fois le tour tombé', () {
      final (state, aLEcran) = turnCutByTimer(2);

      expect(state.phase, GamePhase.turnSummary);
      expect(aLEcran, isNotNull);
      expect(state.cardAtBuzzer, aLEcran);
    });

    test("elle n'est pas comptée : elle n'a jamais été tranchée", () {
      final (state, aLEcran) = turnCutByTimer(2);

      expect(state.turn!.score, 2, reason: 'les deux trouvées, pas la sienne');
      expect(
        state.turn!.results.map((r) => r.cardId),
        isNot(contains(aLEcran!.id)),
      );
    });

    test('elle retourne dans le paquet et ressortira plus tard', () {
      // C'est ce comportement, juste mais muet, qui a fait croire à un bug en
      // partie réelle : la carte devinée à la seconde près disparaissait sans
      // un mot et revenait deux tours plus tard.
      final (state, aLEcran) = turnCutByTimer(2);
      final suivant = reduce(state, const GameEvent.turnConfirmed());

      expect(suivant.pile, contains(aLEcran!.id));
    });

    test("un tour qui vide le paquet n'a pas de carte au buzzer", () {
      var state = reduce(start(), const GameEvent.turnStarted());
      for (var i = 0; i < 12; i++) {
        state = reduce(state, const GameEvent.cardFound());
      }

      expect(state.phase, GamePhase.turnSummary);
      expect(state.pile, isEmpty);
      expect(
        state.cardAtBuzzer,
        isNull,
        reason: "la dernière carte vient d'être trouvée, l'écran était vide",
      );
      expect(state.turnEndedOnTime, isFalse);
    });

    test(
      "une carte déjà tranchée dans ce tour n'est pas annoncée deux fois",
      () {
        // Manche 2 : la carte passée retourne au fond (R4.6) et remonte en
        // tête dès que ce qui la précédait est tranché — donc en fin de
        // manche, quand les tours tombent justement au chrono. Elle a déjà sa
        // ligne au récapitulatif, corrigeable ; l'annoncer aussi au buzzer
        // donnerait deux récits contradictoires de la même carte.
        var state = startGame(
          config: _config,
          teams: [testTeam('team-1'), testTeam('team-2')],
          deck: testCards(12),
          seed: 3,
        ).copyWith(roundIndex: 1);
        state = state.copyWith(
          turn: state.turn!.copyWith(round: state.rounds[1]),
        );
        state = reduce(state, const GameEvent.turnStarted());

        final passee = state.currentCard!;
        state = reduce(state, const GameEvent.cardPassed());
        // On tranche tout le reste : la carte passée revient en tête.
        for (var i = 0; i < 11; i++) {
          state = reduce(state, const GameEvent.cardFound());
        }

        expect(state.currentCardId, passee.id, reason: 'elle est bien revenue');
        expect(state.turn!.resultFor(passee.id), isNotNull);

        state = reduce(state, const GameEvent.ticked(Duration(seconds: 60)));

        expect(state.phase, GamePhase.turnSummary);
        expect(
          state.cardAtBuzzer,
          isNull,
          reason: "sa ligne « Passée » raconte déjà l'histoire, et se corrige",
        );
      },
    );

    test("entre deux manches, aucun tour ne s'est terminé au chrono", () {
      // `turn` est nul entre la validation d'un tour et l'ouverture du
      // suivant : c'est le seul état où la question se pose sans qu'il y ait
      // de tour, et y répondre « oui » n'aurait aucun sens.
      var state = reduce(start(), const GameEvent.turnStarted());
      for (var i = 0; i < 12; i++) {
        state = reduce(state, const GameEvent.cardFound());
      }
      state = reduce(state, const GameEvent.turnConfirmed());

      expect(state.phase, GamePhase.roundSummary);
      expect(state.turn, isNull);
      expect(state.turnEndedOnTime, isFalse);
      expect(state.cardAtBuzzer, isNull);
    });

    test("pendant le tour, il n'y a rien à annoncer", () {
      final state = reduce(start(), const GameEvent.turnStarted());

      expect(state.phase, GamePhase.playing);
      expect(state.cardAtBuzzer, isNull);
      expect(state.turnEndedOnTime, isFalse);
    });

    test('un tour tombé sans avoir rien trouvé la nomme quand même', () {
      // Le cas du narrateur qui bloque sur la première carte : le
      // récapitulatif est vide, et c'est justement là que le silence est le
      // plus déroutant.
      final (state, aLEcran) = turnCutByTimer(0);

      expect(state.turn!.results, isEmpty);
      expect(state.cardAtBuzzer, aLEcran);
      expect(state.cardAtBuzzer, isNotNull);
    });
  });

  group('R9.1 — un état de partie est sérialisable', () {
    test('un aller-retour JSON rend un état identique', () {
      // La reprise de partie du lot 4 en dépend. Le vérifier maintenant évite
      // de découvrir trop tard qu'un champ de l'état n'est pas persistable.
      final state = testGame(cardCount: 12).apply([
        const GameEvent.turnStarted(),
        const GameEvent.cardFound(),
        const GameEvent.cardPassed(),
        const GameEvent.ticked(Duration(seconds: 12)),
        const GameEvent.paused(),
        const GameEvent.resumed(),
        const GameEvent.ticked(Duration(minutes: 1)),
        const GameEvent.turnConfirmed(),
        const GameEvent.turnStarted(),
        const GameEvent.cardFound(),
      ]);

      final restored = GameState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );

      expect(restored, state);
      expect(restored.history.single.elapsed, const Duration(seconds: 60));
      expect(restored.scores, state.scores);
    });
  });
}
