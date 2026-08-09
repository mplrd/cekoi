/// Les trois manches, dans leur ordre canonique (R2.1).
///
/// L'ordre n'est jamais modifiable : c'est la montée en contrainte qui fait le
/// jeu, les joueurs mémorisant progressivement le même paquet.
enum Round {
  /// Manche 1 — description libre, sauf les mots de la carte. Gestes interdits.
  freeDescription(1),

  /// Manche 2 — un seul mot, répétable à volonté. Aucun geste.
  oneWord(2),

  /// Manche 3 — mime. Silence total.
  mime(3);

  const Round(this.number);

  final int number;

  /// Les manches réellement jouées pour un nombre de manches donné (R2.2).
  ///
  /// En deux manches on joue la 1 et la 3 : « un seul mot » est celle qui
  /// bloque le plus les jeunes enfants, c'est donc elle qu'on retire.
  static List<Round> sequenceFor(int roundCount) => switch (roundCount) {
    2 => const [Round.freeDescription, Round.mime],
    3 => const [Round.freeDescription, Round.oneWord, Round.mime],
    _ => throw ArgumentError.value(
      roundCount,
      'roundCount',
      'Le nombre de manches vaut 2 ou 3',
    ),
  };
}
