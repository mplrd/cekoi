import 'package:cekoi/domain/engine/game_event.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/team_builder.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:cekoi/domain/rules/round.dart';

/// Ouvre une partie sur l'annonce du premier tour.
///
/// Les garde-fous sont ici plutôt que dans l'interface : une partie mal formée
/// se manifesterait sinon par un plantage au milieu d'un tour, alors qu'ici
/// elle ne peut simplement pas démarrer.
GameState startGame({
  required GameConfig config,
  required List<Team> teams,
  required List<Card> deck,
  required int seed,

  /// Cartes neuves pour le départage (R5.3), fournies par le tirage.
  List<Card> tieBreakReserve = const [],
}) {
  if (!GameConfig.isTurnDurationAllowed(config.turnDuration)) {
    throw ArgumentError.value(
      config.turnDuration,
      'config.turnDuration',
      'La durée du tour tient entre '
          '${GameConfig.minimumTurnDuration.inSeconds} et '
          '${GameConfig.maximumTurnDuration.inSeconds} secondes (R6)',
    );
  }

  if (teams.length < minimumTeamCount) {
    throw ArgumentError.value(
      teams.length,
      'teams',
      'Une partie demande au moins $minimumTeamCount équipes (R8.5)',
    );
  }

  if (deck.length < GameConfig.minimumCardCount) {
    throw ArgumentError.value(
      deck.length,
      'deck',
      'Une partie demande au moins ${GameConfig.minimumCardCount} cartes '
          '(R6.2)',
    );
  }

  final cardIds = {for (final card in deck) card.id};
  if (cardIds.length != deck.length) {
    throw ArgumentError.value(
      deck.length,
      'deck',
      'Deux cartes du paquet portent le même identifiant : elles seraient '
          'retirées ensemble à la première trouvée',
    );
  }

  const rounds = Round.sequence;
  return GameState(
    config: config,
    teams: teams,
    deck: deck,
    rounds: rounds,
    pile: GameState.shufflePileFor(deck: deck, seed: seed, roundIndex: 0),
    phase: GamePhase.turnIntro,
    seed: seed,
    tieBreakReserve: tieBreakReserve,
    turn: PlayedTurn(round: rounds.first, teamId: teams.first.id),
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
  // Une pause gèle le tour entièrement (R3.8) : chrono arrêté, valider une
  // carte serait un point gratuit.
  if (!state.canAct || turn == null || cardId == null) return state;

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

/// Un tour ne peut pas se terminer en pause : R3.8 gèle aussi bien le chrono
/// que les actions de carte, donc aucun chemin n'y mène. Les tours archivés
/// portent toujours `isPaused: false`, sans qu'il faille le forcer ici.
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
  //
  // Corriger vers `passed` reste possible en manche 1, où l'action *Passer*
  // n'existe pourtant pas (R3.9) : ici, `passed` veut dire « pas trouvée »,
  // c'est l'annulation d'un tap de trop. R3.9 interdit d'écarter une carte
  // pendant le tour, pas de corriger une erreur une fois le chrono arrêté.
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

  final nextTeamIndex = (state.activeTeamIndex + 1) % state.teams.length;
  final committed = state.copyWith(
    history: [...state.history, turn],
    turn: null,
    activeTeamIndex: nextTeamIndex,
  );

  // Le paquet restant est rebattu avant de changer de mains (R4.7) : l'équipe
  // suivante ne doit pas le reprendre dans l'ordre où la précédente vient d'y
  // buter. Le nombre de tours déjà joués fait varier la graine.
  if (state.pile.isNotEmpty) {
    return _openTurn(
      committed.copyWith(
        pile: GameState.reshuffleRemaining(
          pile: state.pile,
          seed: state.seed,
          roundIndex: state.roundIndex,
          turnIndex: committed.history.length,
        ),
      ),
    );
  }

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
GameState _openTurn(GameState state) => state.copyWith(
  phase: GamePhase.turnIntro,
  turn: PlayedTurn(round: state.round, teamId: state.activeTeam.id),
);

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
