import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/engine/draw.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/rules/game_profiles.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deck_catalog.g.dart';

/// Le contenu disponible dans un mode, tel que l'écran de sélection en a
/// besoin : les catégories, leur volume, et la disponibilité de chaque profil.
class DeckCatalog {
  const DeckCatalog({
    required this.mode,
    required this.decks,
    required this.cards,
    required this.cardCountsByDeck,
    required this.profiles,
  });

  final Audience mode;
  final List<Deck> decks;

  /// Le vivier complet du mode. Gardé en mémoire parce que le compteur de
  /// l'écran doit se recalculer à chaque case cochée, et qu'une requête par
  /// tap serait absurde pour quelques centaines de cartes.
  final List<Card> cards;

  final Map<String, int> cardCountsByDeck;

  /// Les profils du mode, jouables ou non — R7.8 veut qu'ils restent tous
  /// affichés, les indisponibles avec leur raison.
  final List<ProfileAvailability> profiles;

  /// Cartes réellement tirables pour une sélection donnée.
  ///
  /// Passe par [eligibleCards], celui du tirage : le compteur affiché doit
  /// être celui que la partie obtiendra, doublons de R6.4 déduits.
  int availableCards({
    required Set<String> deckIds,
    required Set<Difficulty> difficulties,
    bool adultOnly = false,
  }) => eligibleCards(
    pool: [
      for (final card in cards)
        if (deckIds.contains(card.deckId)) card,
    ],
    mode: mode,
    allowedDifficulties: difficulties,
    adultOnly: adultOnly,
  ).length;
}

/// Charge le contenu d'un mode, une fois le seeding terminé.
@riverpod
Future<DeckCatalog> deckCatalog(Ref ref, Audience mode) async {
  // Le seeding remplit la base au premier lancement : interroger avant lui
  // rendrait un catalogue vide, et l'écran annoncerait « aucune catégorie ».
  await ref.watch(deckSeedingProvider.future);

  final repository = ref.watch(deckRepositoryProvider);
  final decks = await repository.byMode(mode);
  final cards = await repository.cardsForMode(mode);

  return DeckCatalog(
    mode: mode,
    decks: decks,
    cards: cards,
    cardCountsByDeck: await repository.cardCountsByDeck(mode),
    profiles: evaluateProfiles(
      profiles: [
        for (final profile in builtInProfiles)
          if (profile.mode == mode) profile,
      ],
      decks: decks,
      cards: cards,
    ),
  );
}
