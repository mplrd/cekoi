import 'dart:io';

import 'package:flutter/services.dart';

/// Charge les vraies polices dans le binding de test.
///
/// Sans ça, `flutter test` compose tout en **Ahem** : chaque glyphe est un
/// carré plein de la taille de la police. La mise en page reste juste, mais
/// toute mesure de **largeur** est fausse — « 36 » y réclame deux fois la
/// taille du corps, là où Roboto en demande à peu près la moitié. Un test de
/// géométrie qui tourne en Ahem invente donc des débordements qui n'existent
/// pas, et c'est arrivé.
///
/// Rend `false` quand les artefacts ne sont pas là plutôt que d'échouer : le
/// banc d'aperçus veut bien s'en passer. **Un test de mesure, lui, doit
/// refuser de conclure** — voir `aucunTexteRogne`.
Future<bool> chargerLesVraiesPolices() async {
  final racine = Platform.environment['FLUTTER_ROOT'];
  if (racine == null) return false;

  final dossier = Directory('$racine/bin/cache/artifacts/material_fonts');
  if (!dossier.existsSync()) return false;

  Future<bool> charger(String famille, List<String> fichiers) async {
    final loader = FontLoader(famille);
    var trouve = false;
    for (final nom in fichiers) {
      final fichier = File('${dossier.path}/$nom');
      if (fichier.existsSync()) {
        trouve = true;
        loader.addFont(
          Future.value(fichier.readAsBytesSync().buffer.asByteData()),
        );
      }
    }
    if (trouve) await loader.load();
    return trouve;
  }

  const roboto = [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ];

  // « FlutterTest » est la famille par défaut du binding. Un `TextStyle`
  // déclaré sans `fontFamily` — ceux des thèmes de boutons — y retombe : sans
  // la remplacer, ces libellés-là restent en Ahem pendant que tout le reste
  // est composé, ce qui est le pire des deux mondes pour une mesure.
  final ok = await charger('Roboto', roboto);
  await charger('FlutterTest', roboto);
  await charger('MaterialIcons', ['materialicons-regular.otf']);
  return ok;
}
