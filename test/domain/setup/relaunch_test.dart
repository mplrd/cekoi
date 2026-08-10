import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/setup/game_launch.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// Une partie terminée, avec de l'histoire derrière elle.
///
/// Elle s'arrête sur la **seconde** équipe et à la dernière manche : partir
/// d'un état déjà neutre rendrait vraies sans rien prouver les assertions sur
/// la remise à zéro.
GameState _finishedGame() {
  final game = testGame(cardCount: 12);
  return game.copyWith(
    phase: GamePhase.finished,
    roundIndex: game.rounds.length - 1,
    activeTeamIndex: 1,
    pile: const [],
    turn: null,
    teams: [
      for (final team in game.teams) team.copyWith(name: 'Les ${team.id}'),
    ],
    history: [
      PlayedTurn(
        round: game.rounds.first,
        teamId: 'team-1',
        results: [
          for (final card in game.deck.take(4))
            CardResult(cardId: card.id, outcome: TurnOutcome.found),
        ],
      ),
    ],
  );
}

void main() {
  group('rejouer avec les mêmes réglages', () {
    test('la configuration est reprise à l’identique', () {
      final previous = _finishedGame();

      final game = relaunchGame(
        previous: previous,
        pool: testCards(40, prefix: 'neuve'),
        seed: 9,
      ).game!;

      expect(game.config, previous.config);
      expect(
        game.teams,
        previous.teams,
        reason: 'Mêmes équipes, mêmes noms, mêmes couleurs',
      );
    });

    test('le paquet est retiré, pas recopié', () {
      // Rejouer le même paquet retirerait tout l'intérêt : les joueurs le
      // connaissent déjà par cœur, c'est le ressort du jeu (R1).
      final previous = _finishedGame();

      final game = relaunchGame(
        previous: previous,
        pool: testCards(40, prefix: 'neuve'),
        seed: 9,
      ).game!;

      expect(
        game.deck.map((c) => c.id),
        isNot(previous.deck.map((c) => c.id)),
      );
    });

    test('rien de la partie précédente ne survit', () {
      // Un historique ou un score qui traînerait ferait démarrer la nouvelle
      // partie avec des points déjà acquis.
      final previous = _finishedGame();
      expect(previous.scoreOf('team-1'), 4, reason: 'point de départ');

      final game = relaunchGame(
        previous: previous,
        pool: testCards(40, prefix: 'neuve'),
        seed: 9,
      ).game!;

      expect(game.history, isEmpty);
      expect(game.scoreOf('team-1'), 0);
      expect(game.roundIndex, 0);
      expect(game.phase, GamePhase.turnIntro);
    });

    test('la première équipe rouvre la partie', () {
      // La partie précédente s'est arrêtée sur la seconde équipe : hériter de
      // son curseur ferait commencer la nouvelle au milieu de la table.
      final previous = _finishedGame();
      expect(previous.activeTeamIndex, 1, reason: 'point de départ');

      final game = relaunchGame(
        previous: previous,
        pool: testCards(40, prefix: 'neuve'),
        seed: 9,
      ).game!;

      expect(game.activeTeamIndex, 0);
      expect(game.turn!.teamId, previous.teams.first.id);
    });

    test('la partie repart de la première manche', () {
      // La précédente s'est terminée sur le mime : reprendre son index ferait
      // démarrer la nouvelle par la manche la plus dure (R2.1).
      final previous = _finishedGame();
      expect(previous.roundIndex, 2, reason: 'point de départ');

      final game = relaunchGame(
        previous: previous,
        pool: testCards(40, prefix: 'neuve'),
        seed: 9,
      ).game!;

      expect(game.round, game.rounds.first);
      expect(game.rounds, hasLength(3));
    });

    test('un vivier devenu trop maigre refuse, sans planter', () {
      // Les catégories ont pu changer entre-temps — une catégorie premium
      // expirée, une custom supprimée.
      final outcome = relaunchGame(
        previous: _finishedGame(),
        pool: testCards(5, prefix: 'maigre'),
        seed: 9,
      );

      expect(outcome.isLaunched, isFalse);
      expect(outcome.draw.available, 5);
    });

    test('les difficultés figées de la partie sont réappliquées', () {
      // R7.7 : le profil a pu restreindre les difficultés, et « les mêmes
      // réglages » veut dire ceux-là, pas ceux du profil tel qu'il est
      // aujourd'hui.
      final previous = _finishedGame();
      final restreinte = previous.copyWith(
        config: previous.config.copyWith(
          difficulties: const {Difficulty.easy},
        ),
      );

      final game = relaunchGame(
        previous: restreinte,
        pool: [
          ...testCards(20, prefix: 'facile', difficulty: Difficulty.easy),
          ...testCards(20, prefix: 'dure', difficulty: Difficulty.hard),
        ],
        seed: 9,
      ).game!;

      expect(
        {for (final card in game.deck) card.difficulty},
        {Difficulty.easy},
      );
    });
  });
}
