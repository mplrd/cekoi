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

    /// Nombre de cartes demandé. `null` signifie *auto* — voir [autoCardCount].
    int? cardCount,

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

  /// Valeurs proposées en gros boutons, avant la saisie libre (R6).
  static const List<Duration> turnDurationPresets = [
    Duration(seconds: 30),
    Duration(seconds: 45),
    Duration(seconds: 60),
    Duration(seconds: 90),
  ];

  static const List<int> cardCountPresets = [24, 32, 40, 48];

  /// Défauts par mode (table de R6). Ils doivent permettre de traverser
  /// l'écran de réglages sans y toucher dans la majorité des cas.
  static const Map<Audience, Duration> defaultTurnDuration = {
    Audience.family: Duration(seconds: 60),
    Audience.adult: Duration(seconds: 45),
  };

  /// `null` signifie *auto*.
  static const Map<Audience, int?> defaultCardCount = {
    Audience.family: null,
    Audience.adult: 32,
  };

  /// Calcul du mode *auto* : `12 × équipes`, arrondi au multiple de 4
  /// supérieur, borné à [16, 80] (R6.1).
  ///
  /// C'est le réglage qui donne des parties de 30 à 40 minutes. Le facteur
  /// vaut `5 × 2,4 joueurs par équipe` : la durée d'une partie suit le nombre
  /// de tours à jouer, donc le nombre d'équipes, bien plus que l'effectif
  /// exact autour de la table — que l'application ne connaît plus (R8.2).
  static int autoCardCount(int teamCount) {
    final raw = 12 * teamCount;
    final rounded = ((raw + 3) ~/ 4) * 4;
    return rounded.clamp(16, 80);
  }

  /// Nombre de cartes effectif pour un nombre d'équipes donné.
  int resolvedCardCount(int teamCount) => cardCount ?? autoCardCount(teamCount);
}
