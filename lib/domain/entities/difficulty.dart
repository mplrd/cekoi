/// Difficulté d'une carte, de 1 à 3.
///
/// Pilote l'équilibrage du tirage (R6.3) et les restrictions des profils de
/// partie (R7.5).
enum Difficulty {
  easy(1),
  medium(2),
  hard(3);

  const Difficulty(this.value);

  /// Valeur stockée en base et dans les JSON de `assets/decks/`.
  final int value;

  static Difficulty fromValue(int value) => switch (value) {
    1 => Difficulty.easy,
    2 => Difficulty.medium,
    3 => Difficulty.hard,
    _ => throw ArgumentError.value(value, 'value', 'Difficulté hors de 1..3'),
  };

  /// Répartition visée par le tirage équilibré (R6.3).
  ///
  /// Elle n'est qu'une cible : si le vivier ne permet pas de l'atteindre, le
  /// tirage complète avec ce qui existe plutôt que d'échouer.
  static const Map<Difficulty, double> targetDistribution = {
    Difficulty.easy: 0.3,
    Difficulty.medium: 0.5,
    Difficulty.hard: 0.2,
  };
}
