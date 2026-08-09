/// Normalisation des textes de carte.
///
/// Vit dans le domaine parce que la détection de doublons du tirage (R6.4) en
/// dépend, et parce que `slugify`, côté données, doit s'appuyer sur exactement
/// la même translittération. Deux implémentations séparées finiraient par
/// diverger sur `œ` ou sur l'élision, et produiraient des identifiants
/// incohérents avec la détection de doublons.
library;

const Map<String, String> _diacritics = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  // Ligatures : développées en deux lettres, jamais réduites à une seule —
  // « Œuf » doit se normaliser comme « Oeuf ».
  'œ': 'oe', 'æ': 'ae',
};

/// Minuscule, sans accents ni ligatures.
String stripDiacritics(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }
  return buffer.toString();
}

/// Forme comparable d'un texte de carte, pour la détection de doublons (R6.4).
///
/// Casse, accents, ligatures, apostrophes et ponctuation sont neutralisés.
/// Les **articles sont conservés** : R6.4 parle de « la même entrée », et les
/// retirer fusionnerait « La Poste » avec « Poste », qui sont deux cartes
/// légitimement distinctes. L'élision est traitée en remplaçant l'apostrophe
/// par une espace, de sorte que « L'ours » et « l’ours » se rejoignent.
String normalizeCardText(String input) {
  return stripDiacritics(input)
      // Les deux apostrophes, droite et typographique.
      .replaceAll(RegExp("['’]"), ' ')
      .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(' +'), ' ')
      .trim();
}
