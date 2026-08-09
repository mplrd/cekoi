/// Provenance d'une catégorie ou d'une carte.
///
/// C'est la seule distinction entre le contenu livré avec l'application et
/// celui créé par le joueur : les tables sont identiques par ailleurs. Le
/// seeding ne touche jamais aux lignes [DeckOrigin.custom], quoi qu'il arrive.
enum DeckOrigin {
  official,
  custom;

  static DeckOrigin fromName(String name) => switch (name) {
    'official' => DeckOrigin.official,
    'custom' => DeckOrigin.custom,
    _ => throw ArgumentError.value(name, 'name', 'origin inconnue'),
  };
}
