import 'dart:math';

import 'package:cekoi/domain/engine/draw.dart';
import 'package:cekoi/domain/engine/game_engine.dart';
import 'package:cekoi/domain/engine/game_event.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/team_builder.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/domain/entities/player.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:cekoi/domain/rules/game_profiles.dart';
import 'package:cekoi/domain/rules/round.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// Le contenu installé sur l'appareil.
final List<Deck> _decks = [
  testDeck('animaux'),
  testDeck('metiers', minAge: MinAge.ten),
  testDeck('apero', minAge: MinAge.eighteen, audience: Audience.adult),
];

final List<Card> _cards = [
  for (final deckId in ['animaux', 'metiers', 'apero'])
    for (final difficulty in Difficulty.values)
      ...testCards(
        20,
        prefix: '$deckId ${difficulty.name}',
        difficulty: difficulty,
        audience: deckId == 'apero' ? Audience.adult : Audience.family,
        deckId: deckId,
      ),
];

final List<Player> _players = [
  for (var i = 1; i <= 6; i++) testPlayer('grand-$i'),
  testPlayer('petit-1', isChild: true),
  testPlayer('petit-2', isChild: true),
];

/// Tout ce qu'une partie produit, du choix du profil au podium.
class Session {
  const Session({
    required this.availability,
    required this.teams,
    required this.drawn,
    required this.finalState,
    required this.roundOpeners,
  });

  final ProfileAvailability availability;
  final List<Team> teams;
  final DrawResult drawn;
  final GameState finalState;

  /// L'équipe qui a ouvert chaque manche, pour vérifier R4.3.
  final Map<Round, String> roundOpeners;
}

/// Un joueur simulé, qui ne connaît du moteur que sa phase courante et les
/// événements publics — exactement ce dont disposera l'interface.
GameState driveOneStep(GameState state, Random random) => switch (state.phase) {
  GamePhase.turnIntro => reduce(state, const GameEvent.turnStarted()),
  GamePhase.playing => _playSomeCards(state, random),
  GamePhase.turnSummary => _reviewAndConfirm(state, random),
  GamePhase.roundSummary => reduce(state, const GameEvent.nextRoundStarted()),
  GamePhase.tieBreak => _settleTieBreak(state, random),
  GamePhase.finished => state,
};

GameState _playSomeCards(GameState state, Random random) {
  var next = state;

  // Le téléphone part en arrière-plan de temps en temps : le tour doit
  // reprendre exactement où il en était (R3.7, R3.8).
  if (random.nextInt(6) == 0) {
    next = reduce(next, const GameEvent.paused());
    next = reduce(next, GameEvent.ticked(next.config.turnDuration * 3));
    next = reduce(next, const GameEvent.resumed());
  }

  final actions = 1 + random.nextInt(5);
  for (var i = 0; i < actions && next.phase == GamePhase.playing; i++) {
    final passes = next.canPass && random.nextInt(4) == 0;
    next = reduce(
      next,
      passes ? const GameEvent.cardPassed() : const GameEvent.cardFound(),
    );
  }

  // Le tour n'est pas allé au bout du paquet : le chrono a le dernier mot.
  return next.phase == GamePhase.playing
      ? reduce(next, GameEvent.ticked(next.config.turnDuration))
      : next;
}

/// Le récapitulatif, avec les erreurs de manipulation que R3.6 existe pour
/// rattraper — y compris celles qui décident de la fin de la manche.
GameState _reviewAndConfirm(GameState state, Random random) {
  var next = state;
  final results = next.turn!.results;

  if (results.isNotEmpty && random.nextInt(4) == 0) {
    final line = results[random.nextInt(results.length)];
    next = reduce(
      next,
      GameEvent.resultCorrected(
        cardId: line.cardId,
        outcome: line.outcome == TurnOutcome.found
            ? TurnOutcome.passed
            : TurnOutcome.found,
      ),
    );
  }

  return reduce(next, const GameEvent.turnConfirmed());
}

GameState _settleTieBreak(GameState state, Random random) {
  // « Répétée jusqu'à départage » : personne ne trouve, on relance. Borné
  // pour que le test reste un test et pas une roulette.
  if (state.tieBreakCardIndex < 2 && random.nextBool()) {
    return reduce(state, const GameEvent.tieBreakRestarted());
  }
  return reduce(
    state,
    GameEvent.tieBreakWon(teamId: state.tieBreakTeamIds.first),
  );
}

/// Joue une partie entière depuis une graine, sans jamais toucher à autre
/// chose qu'aux fonctions publiques du domaine.
Session playFullGame(int seed) {
  final random = Random(seed);

  final profile = builtInProfiles.firstWhere((p) => p.id == 'mix');
  final availability = evaluateProfile(
    profile: profile,
    decks: _decks,
    cards: _cards,
  );

  final teams = proposeTeams(
    players: _players,
    teamNames: const ['Les Rouges', 'Les Bleus'],
    random: random,
  );

  final retained = availability.deckIds.toSet();
  final drawn = drawCards(
    pool: [
      for (final card in _cards)
        if (retained.contains(card.deckId)) card,
    ],
    requested: GameConfig.autoCardCount(_players.length),
    mode: profile.mode,
    random: random,
    allowedDifficulties: profile.difficulties,
  );

  var state = startGame(
    config: GameConfig(
      mode: profile.mode,
      deckIds: availability.deckIds,
      turnDuration: profile.turnDuration,
      roundCount: profile.roundCount,
      profileId: profile.id,
    ),
    players: _players,
    teams: teams,
    deck: drawn.cards,
    tieBreakReserve: drawn.tieBreakReserve,
    seed: seed,
  );

  final roundOpeners = <Round, String>{};
  var steps = 0;
  while (!state.isOver) {
    if (state.phase == GamePhase.turnIntro) {
      roundOpeners.putIfAbsent(state.round, () => state.turn!.teamId);
    }
    state = driveOneStep(state, random);
    if (++steps > 2000) {
      fail('La partie ne converge pas : $steps événements sans fin de partie');
    }
  }

  return Session(
    availability: availability,
    teams: teams,
    drawn: drawn,
    finalState: state,
    roundOpeners: roundOpeners,
  );
}

void main() {
  test("une partie entière se déroule sans interface, jusqu'au podium", () {
    final session = playFullGame(2026);
    final state = session.finalState;

    // ── Configuration ───────────────────────────────────────────────────
    expect(session.availability.isPlayable, isTrue);
    expect(
      session.availability.deckIds,
      ['animaux', 'metiers'],
      reason: "« Mix familial » s'arrête à 13 ans, le 18+ reste dehors",
    );
    expect(
      session.teams.map((t) => t.playerIds.length),
      [4, 4],
      reason: 'Huit joueurs en deux équipes (R8.3)',
    );

    // ── Tirage ──────────────────────────────────────────────────────────
    expect(session.drawn.cards, hasLength(40), reason: '5 × 8 joueurs (R6.1)');
    expect(session.drawn.isTruncated, isFalse);
    expect(
      session.drawn.cards.map((c) => c.normalizedText).toSet(),
      hasLength(40),
      reason: 'R6.4 — aucun doublon de texte dans le paquet',
    );
    expect(countOf(session.drawn.cards, Difficulty.easy), 12);
    expect(countOf(session.drawn.cards, Difficulty.medium), 20);
    expect(countOf(session.drawn.cards, Difficulty.hard), 8);

    // ── Déroulé ─────────────────────────────────────────────────────────
    expect(state.phase, GamePhase.finished);
    expect(state.rounds, [Round.freeDescription, Round.oneWord, Round.mime]);

    expect(
      state.scores.values.reduce((a, b) => a + b),
      3 * 40,
      reason:
          "Une manche ne s'achève que le paquet vide, et chaque carte trouvée "
          'vaut un point : les trois manches valent 120 points '
          '(R4.1, R4.2, R5.1)',
    );

    expect(state.scoresByRound.keys, hasLength(3));
    for (final round in state.rounds) {
      expect(
        state.scoresByRound[round]!.values.reduce((a, b) => a + b),
        40,
        reason: 'La manche ${round.number} a fait deviner tout le paquet',
      );
    }

    // R4.3 — chaque manche est ouverte par l'équipe qui suit celle ayant
    // terminé la précédente. Ce n'est pas « une équipe différente de celle
    // qui a ouvert la manche d'avant » : avec deux équipes, la même peut très
    // bien rouvrir deux manches de suite si l'autre les a closes.
    expect(session.roundOpeners, hasLength(3));
    for (var i = 0; i < state.rounds.length - 1; i++) {
      final closer = state.history
          .lastWhere((turn) => turn.round == state.rounds[i])
          .teamId;
      final closerIndex = state.teams.indexWhere((t) => t.id == closer);
      final successor = state.teams[(closerIndex + 1) % state.teams.length].id;

      expect(
        session.roundOpeners[state.rounds[i + 1]],
        successor,
        reason:
            "L'équipe $closer a clos la manche ${state.rounds[i].number}, "
            "c'est donc $successor qui ouvre la suivante",
      );
    }

    // R3.1 — au sein d'une équipe, personne n'a narré nettement plus que ses
    // coéquipiers : la rotation est bien restée interne à chaque équipe.
    for (final team in state.teams) {
      final counts = [
        for (final playerId in team.playerIds)
          state.history.where((t) => t.narratorId == playerId).length,
      ];
      expect(
        counts.reduce(max) - counts.reduce(min),
        lessThanOrEqualTo(1),
        reason: 'Rotation déséquilibrée dans ${team.id} : $counts',
      );
    }

    // R3.8 — aucun tour figé n'a rejoint l'historique : une pause bloque le
    // chrono comme les cartes, donc aucun tour ne peut s'y terminer.
    expect(
      state.history.every((turn) => !turn.isPaused),
      isTrue,
      reason: 'Un tour archivé en pause se sérialiserait tel quel',
    );

    // Chaque carte a été trouvée une fois et une seule par manche, corrections
    // comprises : c'est la seule façon pour une manche de se clore.
    for (final round in state.rounds) {
      final found = [
        for (final turn in state.history)
          if (turn.round == round)
            for (final line in turn.results)
              if (line.outcome == TurnOutcome.found) line.cardId,
      ];
      expect(found.toSet(), hasLength(40), reason: 'Manche ${round.number}');
      expect(found, hasLength(40), reason: 'Aucune carte trouvée deux fois');
    }

    // ── Podium ──────────────────────────────────────────────────────────
    expect(state.winnerIds, hasLength(1), reason: 'R5.2, départage compris');
    expect(
      state.scores[state.winnerIds.single],
      state.scores.values.reduce(max),
    );
  });

  test('deux parties de même graine sont rigoureusement identiques', () {
    // C'est ce qui rendra un bug reproductible depuis un simple journal :
    // la composition des équipes, le tirage et les trois manches en dépendent.
    expect(playFullGame(7).finalState, playFullGame(7).finalState);
  });

  test('deux graines différentes donnent deux parties différentes', () {
    expect(
      playFullGame(7).finalState,
      isNot(playFullGame(8).finalState),
    );
  });
}
