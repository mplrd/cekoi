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
