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

/// Couvre `import` et `export`, guillemets simples ou doubles.
final RegExp _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
);

bool _isAllowed(String target) =>
    _allowedDartLibraries.contains(target) ||
    _allowedPackagePrefixes.any(target.startsWith);

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
        final match = _directive.firstMatch(lines[i]);
        if (match == null) continue;

        final target = match.group(1)!;

        // Un chemin sans schéma est un import relatif au sein du domaine.
        final allowed = _isAllowed(target) || !target.contains(':');

        if (!allowed) {
          offenders.add('${entity.path}:${i + 1} → ${lines[i].trim()}');
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
    ];

    for (final line in violations) {
      final match = _directive.firstMatch(line);
      expect(match, isNotNull, reason: 'Non détecté : $line');
      expect(
        _isAllowed(match!.group(1)!),
        isFalse,
        reason: 'Aurait dû être refusé : $line',
      );
    }
  });
}
