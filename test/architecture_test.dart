import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou de la règle d'or n°1 : `lib/domain/` est du Dart pur.
///
/// Cette contrainte est ce qui rend le moteur testable en millisecondes et ce
/// qui rendra le multi-device de la v2 réalisable sans réécriture. Elle se
/// perd en silence dès qu'on veut « juste une Color » dans une entité, d'où ce
/// test plutôt qu'une consigne dans un document.
void main() {
  test("aucun fichier de lib/domain/ n'importe package:flutter", () {
    final domain = Directory('lib/domain');
    expect(
      domain.existsSync(),
      isTrue,
      reason: 'lib/domain/ doit exister — vérifie le répertoire de travail',
    );

    final offenders = <String>[];

    for (final entity in domain.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (RegExp(r'''^\s*import\s+['"]package:flutter/''').hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1} → ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          "Le domaine doit rester du Dart pur. Si tu as besoin d'une couleur "
          "ou d'une icône, stocke un identifiant et convertis en "
          'présentation.\n${offenders.join('\n')}',
    );
  });
}
