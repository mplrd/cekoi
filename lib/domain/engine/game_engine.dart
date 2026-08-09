import 'package:cekoi/domain/engine/game_event.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/team_builder.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/entities/player.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:cekoi/domain/rules/round.dart';

/// Ouvre une partie sur l'annonce du premier tour.
///
/// Les garde-fous sont ici plutôt que dans l'interface : une partie mal formée
/// se manifesterait sinon par un plantage au milieu d'un tour, alors qu'ici
/// elle ne peut simplement pas démarrer.
GameState startGame({
  required GameConfig config,
  required List<Player> players,
  required List<Team> teams,
  required List<Card> deck,
  required int seed,
}) {
  if (teams.length < minimumTeamCount) {
    throw ArgumentError.value(
      teams.length,
      'teams',
      'Une partie demande au moins $minimumTeamCount équipes (R8.5)',
    );
  }

  for (final team in teams) {
    if (team.playerIds.length < minimumTeamSize) {
      throw ArgumentError.value(
        team.id,
        'teams',
        'Chaque équipe compte au moins $minimumTeamSize joueurs (R8.5)',
      );
    }
  }

  if (deck.length < GameConfig.minimumCardCount) {
    throw ArgumentError.value(
      deck.length,
      'deck',
      'Une partie demande au moins ${GameConfig.minimumCardCount} cartes '
          '(R6.2)',
    );
  }

  final known = {for (final player in players) player.id};
  for (final team in teams) {
    for (final id in team.playerIds) {
      if (!known.contains(id)) {
        throw ArgumentError.value(
          id,
          'teams',
          "L'équipe ${team.id} référence un joueur absent de la partie",
        );
      }
    }
  }

  final rounds = Round.sequenceFor(config.roundCount);
  return GameState(
    config: config,
    players: players,
    teams: teams,
    deck: deck,
    rounds: rounds,
    pile: GameState.shufflePileFor(deck: deck, seed: seed, roundIndex: 0),
    phase: GamePhase.turnIntro,
    seed: seed,
    turn: PlayedTurn(
      round: rounds.first,
      teamId: teams.first.id,
      narratorId: teams.first.currentNarratorId,
    ),
  );
}

/// Le réducteur : `(état, événement) -> état`.
///
/// Pur, synchrone et déterministe. Pas de `Future`, pas d'I/O, pas de
/// `DateTime.now()`, pas de `Random` non dérivé de la graine de l'état. C'est
/// ce qui rendra le multi-device peu coûteux : le même réducteur tournera côté
/// serveur et côté clients, et seuls des [GameEvent] circuleront.
///
/// Un événement qui n'a pas de sens dans la phase courante rend l'état
/// inchangé. L'égalité de valeur des états rend cette absence d'effet
/// directement testable : `reduce(state, event) == state`.
GameState reduce(GameState state, GameEvent event) => switch (event) {
  TurnStarted() => _turnStarted(state),
  CardFound() => _cardResolved(state, TurnOutcome.found),
  CardPassed() => _cardResolved(state, TurnOutcome.passed),
  Ticked(:final elapsed) => _ticked(state, elapsed),
  Paused() => _pauseToggled(state, isPaused: true),
  Resumed() => _pauseToggled(state, isPaused: false),
  ResultCorrected(:final cardId, :final outcome) => _resultCorrected(
    state,
    cardId,
    outcome,
  ),
  TurnConfirmed() => _turnConfirmed(state),
  NextRoundStarted() => _nextRoundStarted(state),
  TieBreakWon(:final teamId) => _tieBreakWon(state, teamId),
  TieBreakRestarted() => _tieBreakRestarted(state),
};

GameState _turnStarted(GameState state) => state.phase == GamePhase.turnIntro
    ? state.copyWith(phase: GamePhase.playing)
    : state;

GameState _cardResolved(GameState state, TurnOutcome outcome) {
  final turn = state.turn;
  final cardId = state.currentCardId;
  if (state.phase != GamePhase.playing || turn == null || cardId == null) {
    return state;
  }

  if (outcome == TurnOutcome.passed && !state.canPass) return state;

  final pile = outcome == TurnOutcome.found
      ? state.pile.sublist(1)
      : [...state.pile.skip(1), cardId];

  final next = state.copyWith(
    pile: pile,
    turn: turn.withResult(cardId, outcome),
  );

  // Paquet vide : le tour s'arrête, et avec lui la manche (R3.5, R4.1).
  return pile.isEmpty ? _endTurn(next) : next;
}

GameState _ticked(GameState state, Duration elapsed) {
  final turn = state.turn;
  if (state.phase != GamePhase.playing || turn == null || turn.isPaused) {
    return state;
  }

  final duration = state.config.turnDuration;
  // Le chrono est une source monotone : un tick en retard, arrivé après une
  // reprise, ne doit pas faire remonter le temps affiché.
  var value = elapsed > duration ? duration : elapsed;
  if (value < turn.elapsed) value = turn.elapsed;

  final next = state.copyWith(turn: turn.copyWith(elapsed: value));
  return value >= duration ? _endTurn(next) : next;
}

GameState _pauseToggled(GameState state, {required bool isPaused}) {
  final turn = state.turn;
  if (state.phase != GamePhase.playing || turn == null) return state;
  return state.copyWith(turn: turn.copyWith(isPaused: isPaused));
}

GameState _endTurn(GameState state) =>
    state.copyWith(phase: GamePhase.turnSummary);

GameState _resultCorrected(
  GameState state,
  String cardId,
  TurnOutcome outcome,
) {
  final turn = state.turn;
  if (state.phase != GamePhase.turnSummary || turn == null) return state;

  // Le récapitulatif ne liste que les cartes vues (R3.6) : une carte que le
  // narrateur n'a jamais retournée n'a pas de ligne à corriger.
  final existing = turn.resultFor(cardId);
  if (existing == null || existing.outcome == outcome) return state;

  final pile = outcome == TurnOutcome.found
      ? [
          for (final id in state.pile)
            if (id != cardId) id,
        ]
      : [...state.pile, cardId];

  return state.copyWith(pile: pile, turn: turn.withResult(cardId, outcome));
}

GameState _turnConfirmed(GameState state) {
  final turn = state.turn;
  if (state.phase != GamePhase.turnSummary || turn == null) return state;

  // Le narrateur de l'équipe qui vient de jouer avance, et lui seul : la
  // rotation est interne à chaque équipe (R3.1).
  final teams = [
    for (final team in state.teams)
      if (team.id == turn.teamId) team.withNextNarrator() else team,
  ];

  final nextTeamIndex = (state.activeTeamIndex + 1) % state.teams.length;
  final committed = state.copyWith(
    teams: teams,
    history: [...state.history, turn],
    turn: null,
    activeTeamIndex: nextTeamIndex,
  );

  if (state.pile.isNotEmpty) return _openTurn(committed);

  // Manche terminée. L'équipe suivante ouvrira la prochaine, sans quoi celle
  // qui a vidé le paquet enchaînerait deux tours (R4.3).
  if (!state.isLastRound) {
    return committed.copyWith(phase: GamePhase.roundSummary);
  }
  return _endGame(committed);
}

GameState _nextRoundStarted(GameState state) {
  if (state.phase != GamePhase.roundSummary) return state;

  final roundIndex = state.roundIndex + 1;
  return _openTurn(
    state.copyWith(
      roundIndex: roundIndex,
      // Toutes les cartes reviennent en jeu, remélangées (R4.2).
      pile: GameState.shufflePileFor(
        deck: state.deck,
        seed: state.seed,
        roundIndex: roundIndex,
      ),
    ),
  );
}

/// Ouvre l'annonce du tour de l'équipe active.
GameState _openTurn(GameState state) {
  final team = state.activeTeam;
  return state.copyWith(
    phase: GamePhase.turnIntro,
    turn: PlayedTurn(
      round: state.round,
      teamId: team.id,
      narratorId: team.currentNarratorId,
    ),
  );
}

GameState _endGame(GameState state) {
  final leaders = state.leadingTeamIds;
  if (leaders.length <= 1) return state.copyWith(phase: GamePhase.finished);

  // Égalité en tête : une carte en mime, la première équipe qui trouve gagne
  // (R5.3). Le départage ne rapporte aucun point, il désigne un vainqueur.
  return state.copyWith(
    phase: GamePhase.tieBreak,
    tieBreakTeamIds: leaders,
  );
}

GameState _tieBreakWon(GameState state, String teamId) {
  if (state.phase != GamePhase.tieBreak) return state;
  if (!state.tieBreakTeamIds.contains(teamId)) return state;
  return state.copyWith(
    phase: GamePhase.finished,
    tieBreakWinnerId: teamId,
  );
}

GameState _tieBreakRestarted(GameState state) {
  if (state.phase != GamePhase.tieBreak) return state;
  return state.copyWith(tieBreakCardIndex: state.tieBreakCardIndex + 1);
}
