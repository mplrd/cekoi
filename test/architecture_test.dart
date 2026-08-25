import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou de la règle d'or n°1 : `lib/domain/` est du Dart pur.
///
/// Le test procède par **liste blanche** et non par interdiction de
/// `package:flutter`. Une liste noire se contourne trivialement : `dart:ui`
/// fournit `Color`, `Offset` et `Locale` sans jamais nommer Flutter, un
/// `export` échappe à un filtre sur `import`, et rien n'empêcherait le domaine
/// de remonter vers `data` ou `app`. La liste blanche ferme les trois.
const Set<String> _allowedDartLibraries = {
  'dart:core',
  'dart:async',
  'dart:convert',
  'dart:math',
  'dart:collection',
  'dart:typed_data',
};

const Set<String> _allowedPackagePrefixes = {
  'package:cekoi/domain/',
  'package:freezed_annotation/',
  'package:json_annotation/',
  'package:collection/',
  // characters est du Dart pur, sans dépendance à Flutter : compter des
  // graphèmes est une opération de texte, pas de rendu.
  'package:characters/',
  'package:meta/',
};

/// Repère une directive `import` ou `export`.
final RegExp _directiveStart = RegExp(r'''^\s*(?:import|export)\s+['"]''');

/// Capture **toutes** les URI entre guillemets d'une ligne, et pas seulement
/// la première : un import conditionnel en déclare deux, et c'est la seconde
/// qui fait entrer Flutter dans le domaine.
///
///     import 'shim.dart' if (dart.library.io) 'package:flutter/material.dart';
final RegExp _quotedUri = RegExp('''['"]([^'"]+)['"]''');

bool _isAllowed(String target) =>
    _allowedDartLibraries.contains(target) ||
    _allowedPackagePrefixes.any(target.startsWith);

/// Vrai si [relative], résolu depuis le dossier de [from], reste sous
/// `lib/domain/`.
bool _resolvesInsideDomain(File from, String relative) =>
    _normalize(_resolveFrom(from, relative)).contains('/lib/domain/');

/// Résout [relative] depuis le **dossier** de [from].
///
/// `Uri.directory` et non `Uri.file` : sans la barre finale, le dernier
/// segment est pris pour un fichier et toute la résolution glisse d'un cran,
/// ce qui fait sortir `../../autre_feature/x.dart` de `lib/features/` et le
/// rend invisible au contrôle.
String _resolveFrom(File from, String relative) =>
    Uri.directory(from.parent.path).resolve(relative).toFilePath();

String _normalize(String path) => path.replaceAll(r'\', '/');

/// Capture `lib/features/<nom>/`, que le chemin soit absolu ou relatif à la
/// racine du dépôt — `listSync` rend l'un, la résolution d'un import rend
/// l'autre.
final RegExp _featureOfPath = RegExp('(?:^|/)lib/features/([^/]+)/');
final RegExp _featureOfPackageUri = RegExp('^package:cekoi/features/([^/]+)/');

/// Le nom de la feature à laquelle appartient [path], ou `null` hors de
/// `lib/features/`.
String? _featureOf(String path) =>
    _featureOfPath.firstMatch(_normalize(path))?.group(1);

/// La feature visée par une directive, qu'elle soit écrite en `package:` ou
/// en relatif — `../../play/presentation/x.dart` désigne la même chose.
String? _targetFeature(File from, String target) {
  if (target.contains(':')) {
    return _featureOfPackageUri.firstMatch(target)?.group(1);
  }
  return _featureOf(_resolveFrom(from, target));
}

void main() {
  test('lib/domain/ ne dépend que de Dart pur et de ses annotations', () {
    final domain = Directory('lib/domain');
    expect(
      domain.existsSync(),
      isTrue,
      reason: 'lib/domain/ doit exister — vérifie le répertoire de travail',
    );

    final offenders = <String>[];
    var scanned = 0;

    for (final entity in domain.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      scanned++;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!_directiveStart.hasMatch(lines[i])) continue;

        for (final uri in _quotedUri.allMatches(lines[i])) {
          final target = uri.group(1)!;

          // Un chemin sans schéma est relatif : on le résout réellement plutôt
          // que de supposer qu'il reste dans le domaine. `../../data/...` est
          // sinon accepté, et on dépendrait du lint always_use_package_imports
          // pour l'attraper — deux garde-fous qui ne se savent pas liés.
          final allowed = target.contains(':')
              ? _isAllowed(target)
              : _resolvesInsideDomain(entity, target);

          if (!allowed) {
            offenders.add('${entity.path}:${i + 1} → ${lines[i].trim()}');
          }
        }
      }
    }

    expect(
      scanned,
      greaterThan(0),
      reason: 'Aucun fichier scanné — le test ne prouverait rien',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Le domaine doit rester du Dart pur, sans dépendance vers Flutter, '
          "data, features ou app. Si tu as besoin d'une couleur ou d'une "
          'icône, stocke un identifiant et convertis en présentation. Si une '
          'dépendance est légitime, ajoute-la sciemment à la liste blanche de '
          'ce test.\n${offenders.join('\n')}',
    );
  });

  test("aucune feature n'en importe une autre", () {
    // ARCHITECTURE.md : ce qui est partagé entre deux features remonte dans
    // `domain/`, `data/` ou `app/`. Une feature qui en importe une autre
    // recrée le couplage que le découpage vient défaire, et la seconde ne
    // peut plus être ouverte, testée ni supprimée seule.
    final features = Directory('lib/features');
    expect(features.existsSync(), isTrue);

    final offenders = <String>[];
    var scanned = 0;

    for (final entity in features.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final own = _featureOf(entity.path);
      if (own == null) continue;
      scanned++;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!_directiveStart.hasMatch(lines[i])) continue;

        for (final uri in _quotedUri.allMatches(lines[i])) {
          final target = _targetFeature(entity, uri.group(1)!);
          if (target != null && target != own) {
            offenders.add('${entity.path}:${i + 1} → ${lines[i].trim()}');
          }
        }
      }
    }

    expect(
      scanned,
      greaterThan(0),
      reason: 'Aucun fichier scanné — le test ne prouverait rien',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          "Une feature en importe une autre. Ce qu'elles partagent doit "
          "remonter : dans `domain/` si c'est du Dart pur, dans `data/` si "
          "c'est de la persistance, dans `app/` si c'est de l'état "
          'applicatif tenu par Riverpod.\n${offenders.join('\n')}',
    );
  });

  test('les greffons de plateforme ne sortent pas de services/', () {
    // MONETISATION.md : pub et achats vivent derrière `AdService` et
    // `PurchaseService`. L'intérêt n'est pas le rangement — c'est de pouvoir
    // tourner en test et en développement sans SDK, et de changer de régie
    // sans toucher aux écrans. Un seul import direct dans une feature suffit
    // à perdre les deux, et rien ne le signalerait : le code compilerait, et
    // le test qui monte l'écran échouerait sur une `MissingPluginException`
    // dont la cause est ailleurs.
    //
    // Le son et la vibration ont rejoint la liste pour exactement la même
    // raison, et après le même accident : c'est `GameFeedback` qu'un écran
    // demande, jamais `audioplayers`.
    const forbidden = {
      'package:google_mobile_ads/',
      'package:in_app_purchase/',
      'package:audioplayers/',
      'package:vibration/',
    };
    const allowedUnder = 'lib/services/';

    final offenders = <String>[];
    var scanned = 0;

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (_normalize(entity.path).contains(allowedUnder)) continue;
      scanned++;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!_directiveStart.hasMatch(lines[i])) continue;

        for (final uri in _quotedUri.allMatches(lines[i])) {
          if (forbidden.any(uri.group(1)!.startsWith)) {
            offenders.add('${entity.path}:${i + 1} → ${lines[i].trim()}');
          }
        }
      }
    }

    expect(scanned, greaterThan(0));
    expect(
      offenders,
      isEmpty,
      reason:
          'Un SDK de monétisation est importé hors de `lib/services/`. Ce qui '
          'est nécessaire doit passer par une interface de `services/ads/` ou '
          '`services/purchases/`.\n${offenders.join('\n')}',
    );
  });

  test('le test des features détecte bien une violation', () {
    // Le cas réel qui a motivé ce garde-fou : `setup` importait le provider
    // de partie en cours, qui vivait alors chez `play`.
    final from = File('lib/features/setup/presentation/teams_screen.dart');

    expect(
      _targetFeature(from, 'package:cekoi/features/play/presentation/x.dart'),
      'play',
    );
    expect(
      _targetFeature(from, '../../play/presentation/x.dart'),
      'play',
      reason: 'La forme relative désigne la même chose',
    );
    expect(
      _targetFeature(from, 'package:cekoi/app/current_game.dart'),
      isNull,
      reason: 'Remonter dans app/ est précisément la sortie autorisée',
    );
    expect(
      _targetFeature(from, 'deck_catalog.dart'),
      'setup',
      reason: 'Rester chez soi ne viole rien',
    );
  });

  test('le test lui-même détecte bien une violation', () {
    // Sans ce contrôle, une regex cassée rendrait le test vert en permanence
    // et on ne s'en apercevrait jamais.
    const violations = [
      "import 'package:flutter/material.dart';",
      "import 'dart:ui';",
      "export 'package:flutter/foundation.dart';",
      '  import "package:cekoi/data/db/database.dart";',
      // Import conditionnel : c'est la seconde URI qui est dangereuse.
      "import 'shim.dart' if (dart.library.io) 'package:flutter/material.dart';",
    ];

    for (final line in violations) {
      expect(
        _directiveStart.hasMatch(line),
        isTrue,
        reason: 'Directive non repérée : $line',
      );

      final targets = _quotedUri
          .allMatches(line)
          .map((m) => m.group(1)!)
          .where((t) => t.contains(':'))
          .toList();

      expect(targets, isNotEmpty, reason: 'Aucune URI extraite de : $line');
      expect(
        targets.every(_isAllowed),
        isFalse,
        reason: 'Aurait dû être refusé : $line',
      );
    }
  });
}
