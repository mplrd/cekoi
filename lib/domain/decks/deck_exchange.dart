import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/text/text_normalization.dart';

/// Une catégorie telle qu'elle circule dans un fichier.
///
/// Le format est **celui de `assets/decks/`**, volontairement : un export
/// s'importe tel quel sur un autre téléphone, et un deck officiel bricolé à la
/// main s'importe aussi. Deux formats jumeaux finiraient par diverger, et
/// celui-ci est déjà écrit, documenté et produit par l'outil d'import.
class DeckExchange {
  const DeckExchange({
    required this.name,
    required this.audience,
    required this.cards,
  });

  final String name;
  final Audience audience;
  final List<ExchangeCard> cards;
}

class ExchangeCard {
  const ExchangeCard({
    required this.text,
    this.difficulty = Difficulty.medium,
  });

  final String text;
  final Difficulty difficulty;
}

/// Un fichier qu'on ne sait pas lire.
///
/// Porte un message destiné au joueur, pas une trace technique : il vient de
/// choisir un fichier dans son téléphone et doit comprendre ce qui cloche.
class DeckExchangeException implements Exception {
  const DeckExchangeException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, dynamic> encodeDeckExchange(DeckExchange deck) => {
  'name': deck.name,
  'audience': deck.audience.name,
  'minAge': 6,
  'contentVersion': 1,
  'cards': [
    for (final card in deck.cards)
      {'text': card.text, 'difficulty': card.difficulty.value},
  ],
};

/// Lit un fichier de catégorie, ou lève avec un message lisible.
///
/// Tolérant sur les cartes, strict sur la structure : une carte aberrante est
/// écartée pour ne pas faire échouer l'import de trois cents autres, mais un
/// fichier sans nom ni carte utilisable n'est pas une catégorie.
DeckExchange parseDeckExchange(Map<String, dynamic> json) {
  final name = (json['name'] as Object?)?.toString().trim() ?? '';
  if (name.isEmpty) {
    throw const DeckExchangeException(
      "Ce fichier n'a pas de nom de catégorie.",
    );
  }

  final audience = _parseAudience(json['audience']);

  final brutes = json['cards'];
  if (brutes is! List) {
    throw const DeckExchangeException(
      'Ce fichier ne contient pas de liste de cartes.',
    );
  }

  final cards = <ExchangeCard>[];
  final vues = <String>{};

  for (final brute in brutes) {
    if (brute is! Map) continue;

    final texte = (brute['text'] as Object?)?.toString().trim() ?? '';
    if (texte.isEmpty) continue;

    // R6.4 : le fichier vient d'ailleurs, rien ne garantit qu'il a été produit
    // par l'application. Deux fois la même carte ferait mentir le compteur, et
    // le tirage n'en garderait qu'une.
    if (!vues.add(normalizeCardText(texte))) continue;

    cards.add(
      ExchangeCard(
        text: texte,
        difficulty: _parseDifficulty(brute['difficulty']),
      ),
    );
  }

  if (cards.isEmpty) {
    throw const DeckExchangeException(
      'Ce fichier ne contient aucune carte lisible.',
    );
  }

  return DeckExchange(name: name, audience: audience, cards: cards);
}

/// Le public, ou **famille** par défaut.
///
/// Un fichier écrit à la main n'en porte pas forcément. Le mode le plus
/// restrictif est aussi le plus sûr, et il se change après import.
Audience _parseAudience(Object? value) {
  if (value == null) return Audience.family;

  for (final audience in Audience.values) {
    if (audience.name == value) return audience;
  }
  throw DeckExchangeException('Mode de contenu inconnu : « $value ».');
}

/// La difficulté, ou moyen si elle est absente ou aberrante (`CONTENU.md`).
Difficulty _parseDifficulty(Object? value) {
  final brute = value is num ? value.toInt() : null;
  for (final difficulty in Difficulty.values) {
    if (difficulty.value == brute) return difficulty;
  }
  return Difficulty.medium;
}
