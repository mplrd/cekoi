import 'package:cekoi/domain/entities/audience.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_config.freezed.dart';
part 'game_config.g.dart';

/// Réglages figés au lancement d'une partie (R6).
///
/// Le mode ne change jamais en cours de partie (R7.2), et le paquet est tiré à
/// partir de cette configuration puis figé : modifier une catégorie en cours de
/// route ne doit pas altérer une partie déjà lancée.
@freezed
abstract class GameConfig with _$GameConfig {
  const factory GameConfig({
    required Audience mode,
    required List<String> deckIds,
    required Duration turnDuration,
    required int roundCount,

    /// Nombre de cartes demandé. `null` signifie *auto* — voir [autoCardCount].
    int? cardCount,

    /// Profil de départ, `null` dès que le joueur personnalise sa sélection
    /// (R7.6).
    String? profileId,
  }) = _GameConfig;

  const GameConfig._();

  factory GameConfig.fromJson(Map<String, dynamic> json) =>
      _$GameConfigFromJson(json);

  /// Nombre minimum de cartes pour qu'une partie puisse démarrer (R6.2).
  static const int minimumCardCount = 12;

  /// Calcul du mode *auto* : `5 × joueurs`, arrondi au multiple de 4 supérieur,
  /// borné à [16, 80] (R6.1).
  ///
  /// C'est le réglage qui donne des parties de 30 à 40 minutes.
  static int autoCardCount(int playerCount) {
    final raw = 5 * playerCount;
    final rounded = ((raw + 3) ~/ 4) * 4;
    return rounded.clamp(16, 80);
  }

  /// Nombre de cartes effectif pour un effectif donné.
  int resolvedCardCount(int playerCount) =>
      cardCount ?? autoCardCount(playerCount);
}
