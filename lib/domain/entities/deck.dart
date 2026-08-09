import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'deck.freezed.dart';
part 'deck.g.dart';

/// Une catégorie de cartes.
///
/// Officielle ou créée par le joueur : seule [origin] les distingue, les tables
/// et les requêtes sont identiques.
@freezed
abstract class Deck with _$Deck {
  const factory Deck({
    /// Slug stable pour l'officiel (`celebrites-fr`), UUID pour le custom.
    required String id,
    required String name,
    required Audience audience,
    required MinAge minAge,
    required DeckOrigin origin,

    /// Incrémenté à chaque modification du JSON livré. Pilote le re-seed.
    @Default(1) int contentVersion,
    String? description,
    String? icon,

    /// Déblocable par pub récompensée. Toujours faux pour le contenu custom.
    @Default(false) bool isPremium,
    @Default(0) int sortOrder,
  }) = _Deck;

  const Deck._();

  factory Deck.fromJson(Map<String, dynamic> json) => _$DeckFromJson(json);

  /// Vrai si cette catégorie peut être tirée dans le mode de jeu donné (R7.1).
  bool isDrawableIn(Audience mode) => mode.drawableAudiences.contains(audience);
}
