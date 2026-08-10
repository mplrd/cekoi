/// Les trois manches, dans leur ordre canonique (R2.1).
///
/// L'ordre n'est jamais modifiable : c'est la montée en contrainte qui fait le
/// jeu, les joueurs mémorisant progressivement le même paquet.
enum Round {
  /// Manche 1 — description libre, sauf les mots de la carte. Ni geste, ni
  /// bruitage, et on ne passe pas (R3.9).
  freeDescription(1),

  /// Manche 2 — un seul mot, sans concertation : seule la première proposition
  /// compte. Ni geste, ni bruitage.
  oneWord(2),

  /// Manche 3 — mimes, gestes et bruitages, mais aucun mot.
  mime(3);

  const Round(this.number);

  final int number;

  /// Les manches d'une partie (R2.2).
  ///
  /// Toujours les trois : le nombre de manches n'est pas un réglage, en retirer
  /// une viderait le jeu de son ressort.
  static const List<Round> sequence = [freeDescription, oneWord, mime];

  /// *Passer* n'existe qu'à partir de la manche 2 (R3.9).
  ///
  /// En description libre, aucune carte n'est infaisable — seulement plus
  /// longue. Passer y trierait le paquet à bon compte.
  bool get allowsPass => this != Round.freeDescription;
}
