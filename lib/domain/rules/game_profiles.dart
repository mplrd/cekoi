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
/// le mode Entre adultes — n'implique aucune modification du moteur.
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

    /// `null` signifie *auto* : `5 × joueurs`, voir [GameConfig.autoCardCount].
    int? cardCount,
    @Default(3) int roundCount,
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
List<Deck> decksForProfile(GameProfile profile, List<Deck> decks) => [
  for (final deck in decks)
    if (deck.isDrawableIn(profile.mode) &&
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

/// La sélection en cours de construction à l'écran de configuration.
///
/// [profileId] vaut `null` dès que le joueur touche à la sélection : le profil
/// passe en état « personnalisé » (R7.6).
@freezed
abstract class ProfileSelection with _$ProfileSelection {
  const factory ProfileSelection({
    required Audience mode,
    required List<String> deckIds,
    required Set<Difficulty> difficulties,
    required Duration turnDuration,
    required int roundCount,
    String? profileId,
    int? cardCount,
  }) = _ProfileSelection;

  const ProfileSelection._();

  bool get isCustom => profileId == null;

  /// Coche ou décoche une catégorie.
  ///
  /// Le profil cesse alors d'imposer ses filtres — la restriction de
  /// difficulté saute — mais les catégories déjà retenues restent en place
  /// (R7.6). Les réglages, eux, ne sont pas des filtres : le chrono et le
  /// nombre de cartes du profil restent ce que le joueur a sous les yeux.
  ProfileSelection toggleDeck(String deckId) => copyWith(
    deckIds: deckIds.contains(deckId)
        ? [
            for (final id in deckIds)
              if (id != deckId) id,
          ]
        : [...deckIds, deckId],
    profileId: null,
    difficulties: Difficulty.values.toSet(),
  );
}

/// La sélection de départ d'un profil (R7.6).
ProfileSelection selectionFor(GameProfile profile, List<Deck> decks) =>
    ProfileSelection(
      profileId: profile.id,
      mode: profile.mode,
      deckIds: [for (final deck in decksForProfile(profile, decks)) deck.id],
      difficulties: profile.difficulties,
      turnDuration: profile.turnDuration,
      roundCount: profile.roundCount,
      cardCount: profile.cardCount,
    );
