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

Team testTeam(String id) => Team(id: id, name: id);

int countOf(List<Card> cards, Difficulty difficulty) =>
    cards.where((c) => c.difficulty == difficulty).length;

/// Une partie prête à jouer, au premier écran de tour.
///
/// Le paquet est délibérément **non mélangé** : il suit l'ordre de création
/// des cartes, de sorte qu'un test puisse raisonner sur « la première carte »
/// sans dépendre d'une graine. Le mélange, lui, est couvert par les tests de
/// `startGame` et de la remise en jeu entre deux manches (R4.2).
///
/// [roundIndex] ouvre la partie sur une manche donnée. Il vaut 1 par défaut,
/// c'est-à-dire *un seul mot* : la manche 1 n'offre pas *Passer* (R3.9), et une
/// fixture qui y démarrerait rendrait vraie sans rien prouver toute assertion
/// du genre « le paquet n'a pas bougé ». Les tests qui portent sur la manche 1
/// la demandent explicitement.
GameState testGame({
  int cardCount = 6,
  int teamCount = 2,
  int roundIndex = 1,
  Duration turnDuration = const Duration(seconds: 60),
  int seed = 1,
}) {
  final deck = testCards(cardCount, prefix: 'c');
  final teams = [
    for (var i = 0; i < teamCount; i++) testTeam('team-${i + 1}'),
  ];
  const rounds = Round.sequence;

  return GameState(
    config: GameConfig(
      mode: Audience.family,
      deckIds: const ['deck'],
      turnDuration: turnDuration,
      cardCount: cardCount,
    ),
    teams: teams,
    deck: deck,
    rounds: rounds,
    roundIndex: roundIndex,
    pile: [for (final card in deck) card.id],
    phase: GamePhase.turnIntro,
    turn: PlayedTurn(round: rounds[roundIndex], teamId: teams.first.id),
    seed: seed,
  );
}

extension GameStateTestX on GameState {
  /// Applique une suite d'événements, comme le ferait l'interface.
  GameState apply(List<GameEvent> events) => events.fold(this, reduce);
}
