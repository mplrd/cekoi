import 'package:cekoi/domain/text/text_normalization.dart';

/// Transforme un texte de carte en fragment d'identifiant.
///
/// S'appuie sur la même translittération que la détection de doublons du
/// domaine : sans ça, `œ` ou une apostrophe produiraient un identifiant
/// incohérent avec la comparaison de textes.
///
/// **Le slug n'est qu'une valeur par défaut.** Un identifiant dérivé du texte
/// change quand le texte change ; pour qu'une carte garde son identité à
/// travers une correction de faute de frappe, le JSON doit porter un champ
/// `id` explicite, qui prime sur ce slug.
String slugify(String input) {
  return stripDiacritics(
    input,
  ).replaceAll(RegExp('[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}
