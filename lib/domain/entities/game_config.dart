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

  /// `null` signifie *auto*.
  static const Map<Audience, int?> defaultCardCount = {
    Audience.family: null,
    Audience.adult: 32,
  };

  /// Cartes par équipe du mode *auto* (R6.1).
  ///
  /// Le facteur vaut `5 × 2,4 joueurs par équipe` : la durée d'une partie suit
  /// le nombre de tours à jouer, donc le nombre d'équipes, bien plus que
  /// l'effectif exact autour de la table — que l'application ne connaît plus
  /// (R8.2).
  static const int cardsPerTeam = 12;

  /// Calcul du mode *auto* : `12 × équipes`, arrondi au multiple de 4
  /// supérieur, borné à [16, 80] (R6.1).
  ///
  /// C'est le réglage qui donne des parties de 30 à 40 minutes. Le plancher
  /// n'est plus atteignable depuis que le calcul part des équipes — deux, au
  /// minimum, en donnent déjà 24. Il reste comme garde si le facteur bouge.
  static int autoCardCount(int teamCount) {
    final raw = cardsPerTeam * teamCount;
    final rounded = ((raw + 3) ~/ 4) * 4;
    return rounded.clamp(16, 80);
  }

  /// Nombre de cartes effectif pour un nombre d'équipes donné.
  int resolvedCardCount(int teamCount) => cardCount ?? autoCardCount(teamCount);
}
