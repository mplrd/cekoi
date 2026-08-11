import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
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

    /// Nombre de cartes du paquet (R6.1).
    ///
    /// Toujours une valeur : le mode *auto* qui se déduisait du nombre
    /// d'équipes a disparu au retour de terrain d'août 2026.
    @Default(GameConfig.defaultCardCount) int cardCount,

    /// Sans filtre, mais **rien que** les cartes réservées aux grands (R7.1).
    @Default(false) bool adultOnly,

    /// Profil de départ, `null` dès que le joueur personnalise sa sélection
    /// (R7.6).
    String? profileId,

    /// Difficultés autorisées au tirage (R7.7).
    ///
    /// Figées ici plutôt que redéduites du profil : « Rejouer avec les mêmes
    /// réglages » retire un paquet, et devrait sinon retrouver un profil qui
    /// peut avoir changé entre deux versions de l'application.
    @Default({Difficulty.easy, Difficulty.medium, Difficulty.hard})
    Set<Difficulty> difficulties,
  }) = _GameConfig;

  const GameConfig._();

  factory GameConfig.fromJson(Map<String, dynamic> json) =>
      _$GameConfigFromJson(json);

  /// Nombre minimum de cartes pour qu'une partie puisse démarrer (R6.2).
  static const int minimumCardCount = 12;

  /// Bornes de la durée de tour en mode libre (R6).
  ///
  /// En dessous de 15 secondes le narrateur n'a le temps de rien ; au-dessus
  /// de 3 minutes le tour s'éternise pour ceux qui regardent.
  static const Duration minimumTurnDuration = Duration(seconds: 15);
  static const Duration maximumTurnDuration = Duration(seconds: 180);

  static bool isTurnDurationAllowed(Duration duration) =>
      duration >= minimumTurnDuration && duration <= maximumTurnDuration;

  /// Le volume proposé quand on refuse l'automatique.
  ///
  /// Les réglages se font au curseur depuis les retours d'août 2026 : il n'y a
  /// plus de rangée de valeurs prédéfinies, et la liste des durées a disparu
  /// avec elle. Celle-ci survit pour un seul usage — le point de départ du
  /// curseur quand on coupe *Auto*, qui ne doit pas être le minimum de R6.2.
  static const int manualCardCountStart = 24;

  /// Défauts par mode (table de R6). Ils doivent permettre de traverser
  /// l'écran de réglages sans y toucher dans la majorité des cas.
  static const Map<Audience, Duration> defaultTurnDuration = {
    Audience.family: Duration(seconds: 60),
    Audience.adult: Duration(seconds: 45),
  };

  /// Le paquet par défaut, dans les deux modes (R6.1).
  ///
  /// Un nombre rond, qui ne dépend pas du nombre d'équipes : personne ne sait
  /// dire ce qu'un mode *auto* va donner avant de le voir, et sa valeur
  /// bougeait sous les yeux du joueur quand il revenait changer le nombre
  /// d'équipes à l'étape suivante.
  static const int defaultCardCount = 30;

  /// Le paquet le plus long qu'une tablée finit en trois manches (R6.1).
  static const int maximumCardCount = 80;
}
