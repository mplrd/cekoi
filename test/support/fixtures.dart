import 'package:cekoi/domain/engine/game_engine.dart';
import 'package:cekoi/domain/engine/game_event.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/domain/entities/player.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:cekoi/domain/rules/round.dart';
import 'package:cekoi/domain/text/text_normalization.dart';

/// Fabriques partagées par les tests du moteur.
///
/// Les identifiants de carte suivent la convention du contenu officiel
/// (`<deckId>:<slug>`) : deux catégories contenant la même entrée produisent
/// donc des identifiants distincts, ce qui est précisément le cas que le
/// dédoublonnage de R6.4 doit attraper.
Card testCard(
  String text, {
  Difficulty difficulty = Difficulty.medium,
  Audience audience = Audience.family,
  String deckId = 'deck',
}) => Card(
  id: '$deckId:${normalizeCardText(text).replaceAll(' ', '-')}',
  deckId: deckId,
  text: text,
  audience: audience,
  difficulty: difficulty,
  origin: DeckOrigin.official,
);

/// [count] cartes de textes distincts, toutes de la même difficulté.
List<Card> testCards(
  int count, {
  String prefix = 'carte',
  Difficulty difficulty = Difficulty.medium,
  Audience audience = Audience.family,
  String deckId = 'deck',
}) => [
  for (var i = 0; i < count; i++)
    testCard(
      '$prefix $i',
      difficulty: difficulty,
      audience: audience,
      deckId: deckId,
    ),
];

/// Un vivier confortable dans les trois difficultés, pour les tests qui
/// portent sur l'équilibrage et non sur la pénurie.
List<Card> richPool({int perDifficulty = 100}) => [
  ...testCards(perDifficulty, prefix: 'facile', difficulty: Difficulty.easy),
  ...testCards(perDifficulty, prefix: 'moyen', difficulty: Difficulty.medium),
  ...testCards(perDifficulty, prefix: 'dur', difficulty: Difficulty.hard),
];

Deck testDeck(
  String id, {
  MinAge minAge = MinAge.six,
  Audience audience = Audience.family,
  bool isPremium = false,
}) => Deck(
  id: id,
  name: id,
  audience: audience,
  minAge: minAge,
  origin: DeckOrigin.official,
  isPremium: isPremium,
);

Player testPlayer(String id, {bool isChild = false}) =>
    Player(id: id, name: id, isChild: isChild);

/// Une équipe de joueurs nommés `<id>-1`, `<id>-2`, etc.
Team testTeam(String id, int size) => Team(
  id: id,
  name: id,
  playerIds: [for (var i = 1; i <= size; i++) '$id-$i'],
);

int countOf(List<Card> cards, Difficulty difficulty) =>
    cards.where((c) => c.difficulty == difficulty).length;

/// Une partie prête à jouer, au premier écran de tour.
///
/// Le paquet est délibérément **non mélangé** : il suit l'ordre de création
/// des cartes, de sorte qu'un test puisse raisonner sur « la première carte »
/// sans dépendre d'une graine. Le mélange, lui, est couvert par les tests de
/// `startGame` et de la remise en jeu entre deux manches (R4.2).
GameState testGame({
  int cardCount = 6,
  List<int> teamSizes = const [2, 2],
  int roundCount = 3,
  Duration turnDuration = const Duration(seconds: 60),
  int seed = 1,
}) {
  final deck = testCards(cardCount, prefix: 'c');
  final teams = [
    for (var i = 0; i < teamSizes.length; i++)
      testTeam('team-${i + 1}', teamSizes[i]),
  ];
  final rounds = Round.sequenceFor(roundCount);

  return GameState(
    config: GameConfig(
      mode: Audience.family,
      deckIds: const ['deck'],
      turnDuration: turnDuration,
      roundCount: roundCount,
      cardCount: cardCount,
    ),
    players: [
      for (final team in teams)
        for (final id in team.playerIds) testPlayer(id),
    ],
    teams: teams,
    deck: deck,
    rounds: rounds,
    pile: [for (final card in deck) card.id],
    phase: GamePhase.turnIntro,
    turn: PlayedTurn(
      round: rounds.first,
      teamId: teams.first.id,
      narratorId: teams.first.currentNarratorId,
    ),
    seed: seed,
  );
}

extension GameStateTestX on GameState {
  /// Applique une suite d'événements, comme le ferait l'interface.
  GameState apply(List<GameEvent> events) => events.fold(this, reduce);
}
