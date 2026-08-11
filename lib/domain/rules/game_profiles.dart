import 'package:cekoi/domain/engine/draw.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_profiles.freezed.dart';
part 'game_profiles.g.dart';

/// Un raccourci de configuration : il présélectionne des catégories, restreint
/// les difficultés et ajuste les réglages, pour lancer une partie sans rien
/// cocher (R7.5).
///
/// Un profil est **de la donnée**, pas du code. En ajouter un — notamment pour
/// le mode Sans filtre — n'implique aucune modification du moteur.
///
/// Le libellé affiché n'est pas ici : il vient de l'ARB, indexé par [id].
@freezed
abstract class GameProfile with _$GameProfile {
  const factory GameProfile({
    required String id,
    required Audience mode,

    /// Ne retient que les catégories dont le `minAge` lui est inférieur ou
    /// égal (R7.4).
    required MinAge maxDeckAge,
    required Set<Difficulty> difficulties,
    required Duration turnDuration,

    /// Le paquet que le profil impose (R7.5). `null` laisse celui en place.
    int? cardCount,
  }) = _GameProfile;

  const GameProfile._();

  factory GameProfile.fromJson(Map<String, dynamic> json) =>
      _$GameProfileFromJson(json);
}

/// Les profils livrés avec l'application (R7.5).
const List<GameProfile> builtInProfiles = [
  GameProfile(
    id: 'minis',
    mode: Audience.family,
    maxDeckAge: MinAge.six,
    difficulties: {Difficulty.easy},
    turnDuration: Duration(seconds: 90),
    // Un paquet plus court : les tours durent 90 s chez les petits, une partie
    // de trente cartes y tiendrait bien plus que quarante minutes.
    cardCount: 24,
  ),
  GameProfile(
    id: 'ados',
    mode: Audience.family,
    maxDeckAge: MinAge.ten,
    difficulties: {Difficulty.easy, Difficulty.medium},
    turnDuration: Duration(seconds: 60),
  ),
  GameProfile(
    id: 'mix',
    mode: Audience.family,
    maxDeckAge: MinAge.thirteen,
    difficulties: {Difficulty.easy, Difficulty.medium, Difficulty.hard},
    turnDuration: Duration(seconds: 60),
  ),
];

/// Pourquoi un profil ne peut pas être lancé (R7.8).
///
/// Les deux cas sont distingués parce qu'ils n'appellent pas le même message :
/// « aucune catégorie pour cet âge » se répare en écrivant du contenu, « pas
/// assez de cartes » en assouplissant le profil.
enum ProfileUnavailability { noEligibleDeck, notEnoughCards }

/// Ce qu'un profil peut réellement jouer, pour l'afficher activé ou non.
class ProfileAvailability {
  const ProfileAvailability({
    required this.profile,
    required this.deckIds,
    required this.availableCards,
  });

  final GameProfile profile;

  /// Les catégories retenues par le filtre d'âge (R7.4).
  final List<String> deckIds;

  /// Cartes réellement tirables : filtrées par mode et par difficulté, et
  /// dédoublonnées comme le fera le tirage.
  final int availableCards;

  bool get isPlayable => availableCards >= GameConfig.minimumCardCount;

  ProfileUnavailability? get unavailability {
    if (isPlayable) return null;
    return deckIds.isEmpty
        ? ProfileUnavailability.noEligibleDeck
        : ProfileUnavailability.notEnoughCards;
  }
}

/// Les catégories qu'un profil présélectionne (R7.1 + R7.4).
///
/// Les catégories premium en sont exclues. L'écran de sélection les verrouille
/// tant qu'elles ne sont pas débloquées : un profil qui en cochait une donnait
/// au joueur des cartes qu'il ne peut ni retirer — la case est grisée — ni
/// avoir payées. Elles ne comptent pas non plus dans le volume qui décide de
/// la jouabilité d'un profil (R7.8), sans quoi il s'annoncerait jouable grâce
/// à des cartes que le tirage ne prendra pas.
///
/// Quand le déblocage existera, c'est ici que la possession se consultera —
/// une catégorie débloquée redeviendra sélectionnable par profil.
List<Deck> decksForProfile(GameProfile profile, List<Deck> decks) => [
  for (final deck in decks)
    if (!deck.isPremium &&
        deck.isDrawableIn(profile.mode) &&
        deck.minAge.isAllowedBy(profile.maxDeckAge))
      deck,
];

/// Évalue un profil sur le contenu réellement installé (R7.8).
///
/// Le décompte passe par [eligibleCards], celui-là même que le tirage
/// utilisera : un profil annoncé jouable dont le tirage ne trouverait pas
/// assez de cartes serait un mensonge à l'écran.
ProfileAvailability evaluateProfile({
  required GameProfile profile,
  required List<Deck> decks,
  required List<Card> cards,
}) {
  final deckIds = [for (final deck in decksForProfile(profile, decks)) deck.id];
  final retained = deckIds.toSet();

  return ProfileAvailability(
    profile: profile,
    deckIds: deckIds,
    availableCards: eligibleCards(
      pool: [
        for (final card in cards)
          if (retained.contains(card.deckId)) card,
      ],
      mode: profile.mode,
      allowedDifficulties: profile.difficulties,
    ).length,
  );
}

/// Évalue tous les profils, **y compris les injouables** : R7.8 demande qu'ils
/// restent affichés avec leur raison, pas qu'ils disparaissent de la liste.
List<ProfileAvailability> evaluateProfiles({
  required List<GameProfile> profiles,
  required List<Deck> decks,
  required List<Card> cards,
}) => [
  for (final profile in profiles)
    evaluateProfile(profile: profile, decks: decks, cards: cards),
];

/// Ce qu'un profil pose sur la configuration : catégories, filtres et
/// réglages, d'un bloc.
///
/// Valeur de transport uniquement. La sélection vivante, celle que le joueur
/// modifie, est `GameSetup` — qui porte aussi les équipes. Cette classe a un
/// temps dupliqué son `toggleDeck` ; deux implémentations d'une même règle
/// finissent toujours par diverger, et c'est la copie morte qui restait testée.
@freezed
abstract class ProfileSelection with _$ProfileSelection {
  const factory ProfileSelection({
    required Audience mode,
    required List<String> deckIds,
    required Set<Difficulty> difficulties,
    required Duration turnDuration,
    String? profileId,
    int? cardCount,
  }) = _ProfileSelection;
}

/// La sélection de départ d'un profil (R7.6).
ProfileSelection selectionFor(GameProfile profile, List<Deck> decks) =>
    ProfileSelection(
      profileId: profile.id,
      mode: profile.mode,
      deckIds: [for (final deck in decksForProfile(profile, decks)) deck.id],
      difficulties: profile.difficulties,
      turnDuration: profile.turnDuration,
      cardCount: profile.cardCount,
    );
