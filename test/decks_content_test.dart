import 'dart:convert';
import 'dart:io';

import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/domain/text/text_normalization.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrôle du contenu livré dans `assets/decks/`.
///
/// C'est ici que vit la seule règle de dédoublonnage du projet. Le script
/// d'import est en Python et ne normalise **rien** volontairement : R6.4
/// dédoublonne sur un texte normalisé — casse, accents, ligatures, élisions,
/// ponctuation — et cette normalisation est du code Dart, testé, utilisé par le
/// tirage. La réimplémenter côté import en ferait deux versions qui
/// divergeraient, et c'est précisément le genre d'écart qui ne se voit qu'en
/// partie.
///
/// Ce test attrape en prime les doublons introduits à la main, qu'un script
/// d'import ne verrait jamais.
void main() {
  final decks = Directory('assets/decks');

  List<Map<String, dynamic>> loadDecks() => [
    for (final file in decks.listSync())
      if (file is File && file.path.endsWith('.json'))
        {
          'file': file.path,
          ...jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        },
  ];

  test('le dossier des decks existe et contient du contenu', () {
    expect(decks.existsSync(), isTrue);
    expect(
      loadDecks(),
      isNotEmpty,
      reason: 'Sans deck lu, tout ce fichier passerait sans rien vérifier',
    );
  });

  test(
    'R6.4 — aucun doublon de texte normalisé, toutes catégories confondues',
    () {
      // Deux catégories peuvent contenir la même entrée écrite différemment.
      // Le tirage la dédoublonne, mais une carte livrée deux fois est une carte
      // qui n'existe qu'une fois : le volume annoncé au joueur serait faux.
      final vus = <String, String>{};
      final doublons = <String>[];

      for (final deck in loadDecks()) {
        for (final card in deck['cards'] as List<dynamic>) {
          final texte = (card as Map<String, dynamic>)['text'] as String;
          final cle = normalizeCardText(texte);
          final precedent = vus[cle];

          if (precedent != null) {
            doublons.add('« $texte » (${deck['id']}) ↔ $precedent');
          } else {
            vus[cle] = '« $texte » (${deck['id']})';
          }
        }
      }

      expect(doublons, isEmpty, reason: doublons.join('\n'));
    },
  );

  test('chaque carte porte un texte et une difficulté valides', () {
    final fautes = <String>[];

    for (final deck in loadDecks()) {
      for (final card in deck['cards'] as List<dynamic>) {
        final map = card as Map<String, dynamic>;
        final texte = map['text'];
        final difficulte = map['difficulty'];

        if (texte is! String || texte.trim().isEmpty) {
          fautes.add('${deck['id']} : carte sans texte');
        }
        if (difficulte != null &&
            !Difficulty.values.any((d) => d.value == difficulte)) {
          fautes.add('${deck['id']} : difficulté $difficulte hors bornes');
        }
      }
    }

    expect(fautes, isEmpty, reason: fautes.join('\n'));
  });

  test('les métadonnées de chaque deck sont exploitables par le seeder', () {
    final fautes = <String>[];

    for (final deck in loadDecks()) {
      if ((deck['id'] as String?)?.isEmpty ?? true) {
        fautes.add('${deck['file']} : identifiant manquant');
      }
      if ((deck['name'] as String?)?.isEmpty ?? true) {
        fautes.add('${deck['id']} : nom manquant');
      }
      if (!Audience.values.any((a) => a.name == deck['audience'])) {
        fautes.add('${deck['id']} : public « ${deck['audience']} » inconnu');
      }
      if (!MinAge.values.any((a) => a.years == deck['minAge'])) {
        fautes.add('${deck['id']} : âge minimum ${deck['minAge']} inconnu');
      }
    }

    expect(fautes, isEmpty, reason: fautes.join('\n'));
  });

  test('deux decks ne partagent pas le même identifiant', () {
    // Le seeder écrase par identifiant : deux fichiers homonymes en feraient
    // disparaître un en silence.
    final ids = [for (final deck in loadDecks()) deck['id']];

    expect(ids.toSet(), hasLength(ids.length));
  });
}
