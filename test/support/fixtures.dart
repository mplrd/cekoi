import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/player.dart';
import 'package:cekoi/domain/entities/team.dart';
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
