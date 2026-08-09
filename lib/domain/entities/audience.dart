/// Public visé par une carte ou une catégorie.
///
/// Le mode de jeu choisi en début de partie détermine le vivier tiré (R7.1) :
/// le mode Famille ne tire que du [Audience.family], le mode Entre adultes tire
/// dans les deux — un apéro entre adultes ne s'interdit pas les cartes tout
/// public.
enum Audience {
  family,
  adult;

  /// Les publics dans lesquels ce mode de jeu a le droit de tirer (R7.1).
  Set<Audience> get drawableAudiences => switch (this) {
    Audience.family => const {Audience.family},
    Audience.adult => const {Audience.family, Audience.adult},
  };
}
