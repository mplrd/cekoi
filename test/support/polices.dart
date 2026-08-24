import 'dart:io';

import 'package:flutter/services.dart';

/// Les quatre graisses que le thème demande à Roboto.
///
/// En charger une partie seulement serait le pire des deux mondes : les
/// libellés de cette graisse-là resteraient en Ahem pendant que le reste est
/// composé, et la mesure mélangerait les deux.
const _roboto = [
  'roboto-regular.ttf',
  'roboto-medium.ttf',
  'roboto-bold.ttf',
  'roboto-black.ttf',
];

/// Charge les vraies polices dans le binding de test.
///
/// Sans ça, `flutter test` compose tout en **Ahem** : chaque glyphe est un
/// carré plein de la taille de la police. La mise en page reste juste, mais
/// toute mesure de **largeur** est fausse — « 36 » y réclame deux fois la
/// taille du corps, là où Roboto en demande à peu près la moitié. Un test de
/// géométrie qui tourne en Ahem invente donc des débordements qui n'existent
/// pas, et c'est arrivé.
///
/// Rend `null` quand tout est chargé, et sinon **ce qui manque**. Le banc
/// d'aperçus s'en passe ; un test de mesure, lui, doit refuser de conclure —
/// voir `exigerLesVraiesPolices`. La première version rendait un booléen : la
/// CI a rougi sur trois fichiers avec « polices introuvables » et rien pour
/// distinguer un `FLUTTER_ROOT` absent d'un dossier d'artefacts incomplet.
Future<String?> chargerLesVraiesPolices() async {
  final racine = Platform.environment['FLUTTER_ROOT'];
  if (racine == null || racine.isEmpty) {
    return "FLUTTER_ROOT est absent de l'environnement du test";
  }

  final dossier = Directory('$racine/bin/cache/artifacts/material_fonts');
  if (!dossier.existsSync()) {
    return "le dossier d'artefacts ${dossier.path} n'existe pas";
  }

  // On lit le dossier plutôt que de construire les chemins.
  //
  // La casse des noms de cette archive n'est garantie nulle part, et Windows
  // ne la distingue pas : un chemin écrit à la main y ouvre le fichier quelle
  // que soit sa casse, et échoue sur un système qui la respecte. Chercher
  // « roboto-regular.ttf » a donc marché ici et rougi sur la CI.
  final parNom = {
    for (final e in dossier.listSync().whereType<File>())
      _nomDe(e.path).toLowerCase(): e,
  };

  final manquants = [
    for (final nom in _roboto)
      if (!parNom.containsKey(nom)) nom,
  ];
  if (manquants.isNotEmpty) {
    return 'dans ${dossier.path}, il manque ${manquants.join(", ")} ; '
        'le dossier contient ${_contenu(parNom)}';
  }

  Future<void> charger(String famille, List<String> fichiers) async {
    final loader = FontLoader(famille);
    for (final nom in fichiers) {
      final fichier = parNom[nom];
      if (fichier != null) {
        loader.addFont(
          Future.value(fichier.readAsBytesSync().buffer.asByteData()),
        );
      }
    }
    await loader.load();
  }

  await charger('Roboto', _roboto);
  // « FlutterTest » est la famille par défaut du binding. Un `TextStyle`
  // déclaré sans `fontFamily` — ceux des thèmes de boutons — y retombe : sans
  // la remplacer, ces libellés-là restent en Ahem pendant que tout le reste
  // est composé.
  await charger('FlutterTest', _roboto);

  // Les icônes ne portent aucune mesure de largeur : leur absence n'invalide
  // rien, là où celle de Roboto invalide tout.
  const icones = 'materialicons-regular.otf';
  if (parNom.containsKey(icones)) {
    await charger('MaterialIcons', const [icones]);
  }

  return null;
}

/// Le nom de fichier seul. `File.uri` s'occupe du séparateur du système,
/// ce qu'une coupe à la main ne fait pas.
String _nomDe(String chemin) => File(chemin).uri.pathSegments.last;

/// Ce que le dossier contient vraiment, pour que le message dise l'écart au
/// lieu de le laisser deviner.
String _contenu(Map<String, File> parNom) {
  final noms = parNom.values.map((e) => _nomDe(e.path)).toList()..sort();
  return noms.isEmpty ? 'rien' : noms.join(', ');
}
