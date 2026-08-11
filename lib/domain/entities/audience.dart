/// Public visé par une carte ou une catégorie.
///
/// Le mode de jeu choisi en début de partie détermine le vivier tiré (R7.1) :
/// le mode Famille ne tire que du [Audience.family], le mode Sans filtre tire
/// dans les deux — un apéro entre adultes ne s'interdit pas les cartes tout
/// public — sauf si on lui demande explicitement le contraire.
enum Audience {
  family,
  adult;

  /// Les publics dans lesquels ce mode de jeu a le droit de tirer (R7.1).
  ///
  /// [adultOnly] retire le tout public du vivier de Sans filtre : le paquet ne
  /// contient plus que les cartes réservées aux grands. Sans effet en mode
  /// Famille, qui n'a de toute façon pas accès aux cartes adultes.
  Set<Audience> drawablePool({bool adultOnly = false}) => switch (this) {
    Audience.family => const {Audience.family},
    Audience.adult =>
      adultOnly
          ? const {Audience.adult}
          : const {Audience.family, Audience.adult},
  };

  /// Le vivier par défaut du mode, sans restriction (R7.1).
  Set<Audience> get drawableAudiences => drawablePool();
}
