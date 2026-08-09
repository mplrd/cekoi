import 'dart:convert';

import 'package:cekoi/domain/engine/game_engine.dart';
import 'package:cekoi/domain/engine/game_event.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/entities/player.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

const _config = GameConfig(
  mode: Audience.family,
  deckIds: ['deck'],
  turnDuration: Duration(seconds: 60),
  roundCount: 3,
);

GameState start({
  List<Team>? teams,
  List<Player>? players,
  List<Card>? deck,
  int seed = 3,
}) {
  final resolved = teams ?? [testTeam('team-1', 2), testTeam('team-2', 2)];
  return startGame(
    config: _config,
    players:
        players ??
        [
          for (final team in resolved)
            for (final id in team.playerIds) testPlayer(id),
        ],
    teams: resolved,
    deck: deck ?? testCards(12),
    seed: seed,
  );
}

void main() {
  group("startGame — garde-fous à l'ouverture d'une partie", () {
    test('une seule équipe est refusée (R8.5)', () {
      expect(
        () => start(teams: [testTeam('team-1', 4)]),
        throwsArgumentError,
      );
    });

    test("une équipe d'un seul joueur est refusée (R8.5)", () {
      expect(
        () => start(teams: [testTeam('team-1', 2), testTeam('team-2', 1)]),
        throwsArgumentError,
      );
    });

    test('moins de 12 cartes est refusé (R6.2)', () {
      expect(() => start(deck: testCards(11)), throwsArgumentError);
      expect(start(deck: testCards(12)).pile, hasLength(12));
    });

    test('une équipe qui référence un joueur inconnu est refusée', () {
      // Le curseur de narrateur désignerait un identifiant sans joueur, et la
      // partie planterait au premier tour de cette équipe.
      expect(
        () => start(players: [testPlayer('team-1-1'), testPlayer('team-1-2')]),
        throwsArgumentError,
      );
    });

    test("une partie valide ouvre sur l'annonce du premier tour", () {
      final state = start();

      expect(state.phase, GamePhase.turnIntro);
      expect(state.roundIndex, 0);
      expect(state.rounds, hasLength(3));
      expect(state.activeTeam.id, 'team-1');
      expect(state.turn!.narratorId, 'team-1-1');
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
