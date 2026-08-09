/// Transforme un texte de carte en fragment d'identifiant stable.
///
/// L'identifiant d'une carte officielle est `<deck_id>:<slug du texte>`.
/// Il doit rester identique d'une version de deck à l'autre, sinon corriger
/// une faute de frappe casserait le lien avec les parties déjà jouées.
String slugify(String input) {
  const accents = 'àâäáãåçèéêëìíîïñòóôöõùúûüýÿ';
  const plain = 'aaaaaaceeeeiiiinooooouuuuyy';

  final lowered = input.toLowerCase().trim();
  final buffer = StringBuffer();

  for (final rune in lowered.runes) {
    final char = String.fromCharCode(rune);
    final index = accents.indexOf(char);
    if (index != -1) {
      buffer.write(plain[index]);
    } else if (char == 'œ') {
      buffer.write('oe');
    } else if (char == 'æ') {
      buffer.write('ae');
    } else {
      buffer.write(char);
    }
  }

  return buffer
      .toString()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
