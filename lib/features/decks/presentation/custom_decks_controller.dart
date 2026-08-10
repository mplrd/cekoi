import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/decks/deck_exchange.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'custom_decks_controller.g.dart';

/// Les catégories écrites par le joueur, et ce qu'on en fait.
///
/// Chaque écriture relit la base ensuite : c'est une poignée de lignes, et
/// tenir une copie en mémoire à jour à la main finirait par diverger de ce qui
/// est réellement stocké — sur une suppression en cascade, typiquement.
@riverpod
class CustomDecks extends _$CustomDecks {
  @override
  Future<List<Deck>> build() => ref.watch(deckRepositoryProvider).customDecks();

  Future<Deck> create({
    required String name,
    required Audience audience,
  }) async {
    final deck = await ref
        .read(deckRepositoryProvider)
        .createCustomDeck(name: name, audience: audience);
    ref.invalidateSelf();
    return deck;
  }

  Future<void> rename(String deckId, String name) async {
    await ref.read(deckRepositoryProvider).renameCustomDeck(deckId, name);
    ref.invalidateSelf();
  }

  Future<void> delete(String deckId) async {
    await ref.read(deckRepositoryProvider).deleteCustomDeck(deckId);
    ref.invalidateSelf();
  }

  /// Crée une catégorie à partir d'un fichier déjà lu et validé.
  ///
  /// Les doublons ont été écartés à la lecture (R6.4) : ce qui arrive ici est
  /// propre, et une carte refusée en base signalerait un défaut, pas une
  /// saisie maladroite.
  Future<Deck> importDeck(DeckExchange exchange) async {
    final repository = ref.read(deckRepositoryProvider);
    final deck = await repository.createCustomDeck(
      name: exchange.name,
      audience: exchange.audience,
    );

    for (final card in exchange.cards) {
      await repository.addCustomCard(
        deckId: deck.id,
        text: card.text,
        difficulty: card.difficulty,
      );
    }

    ref.invalidateSelf();
    return deck;
  }
}

/// Les cartes d'une catégorie, et ce qu'on en fait.
@riverpod
class DeckCards extends _$DeckCards {
  @override
  Future<List<domain.Card>> build(String deckId) =>
      ref.watch(deckRepositoryProvider).cardsOfDeck(deckId);

  /// Ajoute une carte, ou rend `false` si elle y est déjà (R6.4).
  ///
  /// Un refus n'est pas une situation exceptionnelle : saisir deux fois la
  /// même carte est une maladresse quotidienne, et faire remonter une
  /// exception jusqu'à l'écran pour ça serait disproportionné.
  Future<bool> add(
    String text, {
    Difficulty difficulty = Difficulty.medium,
  }) async {
    final repository = ref.read(deckRepositoryProvider);
    if (await repository.customDeckContains(deckId, text)) return false;

    await repository.addCustomCard(
      deckId: deckId,
      text: text,
      difficulty: difficulty,
    );
    ref.invalidateSelf();
    return true;
  }

  /// Nommé `edit` et non `update` : `AsyncNotifier` porte déjà un `update`.
  Future<void> edit(
    String cardId, {
    String? text,
    Difficulty? difficulty,
  }) async {
    await ref
        .read(deckRepositoryProvider)
        .updateCustomCard(cardId, text: text, difficulty: difficulty);
    ref.invalidateSelf();
  }

  Future<void> delete(String cardId) async {
    await ref.read(deckRepositoryProvider).deleteCustomCard(cardId);
    ref.invalidateSelf();
  }
}
