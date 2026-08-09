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
bool _resolvesInsideDomain(File from, String relative) {
  final resolved = Uri.file(
    from.parent.path,
  ).resolve(relative).toFilePath().replaceAll(r'\', '/');
  return resolved.contains('/lib/domain/');
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
