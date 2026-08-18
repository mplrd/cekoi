import 'dart:math' as math;

import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/features/play/presentation/widgets/action_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le rapport de contraste WCAG entre deux couleurs opaques.
double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// La couleur de la zone au sommet du battement.
Color _sommet(Color fond) =>
    Color.lerp(fond, ActionZone.pulseTarget(fond), ActionZone.pulseAmount)!;

void main() {
  group('R3.6 bis — le battement ne se paie pas en lisibilité', () {
    // Le reste de l'application tient 4,5:1, vérifié par `theme_test.dart`.
    // La zone qui bat est la seule exception, et elle est assumée : son
    // libellé est du grand texte au sens WCAG — 22 points en `w800` — dont le
    // seuil est 3:1. Ce qui suit est la barrière qui empêche d'aller plus
    // loin sans s'en apercevoir.

    test('au sommet, le libellé blanc tient sur la zone principale', () {
      expect(
        _contraste(_sommet(AppColors.deep), Colors.white),
        greaterThanOrEqualTo(3),
        reason:
            'un battement plus ample rendrait le libellé illisible : '
            'à 0,5 le contraste tombe à 2,9:1',
      );
    });

    test("au sommet, l'encre tient sur l'action secondaire", () {
      expect(
        _contraste(_sommet(AppColors.card), AppColors.ink),
        greaterThanOrEqualTo(4.5),
        reason:
            'le blanc teinté de corail reste très clair : aucune raison '
            "de s'y contenter du seuil du grand texte",
      );
    });

    test('la zone bat vers sa propre famille, jamais vers le rouge', () {
      // Le premier essai battait vers `urgent`, et le mélange des deux donnait
      // un brun sale sur le teal des actions.
      expect(ActionZone.pulseTarget(AppColors.deep), AppColors.secondary);
      expect(ActionZone.pulseTarget(AppColors.card), AppColors.main);

      for (final fond in [AppColors.deep, AppColors.card]) {
        expect(ActionZone.pulseTarget(fond), isNot(AppColors.urgent));
      }
    });

    test('le sommet reste une couleur distincte du repos', () {
      // Un battement qui ne déplace rien serait invisible — c'est ce qui a
      // motivé toute la reprise.
      for (final fond in [AppColors.deep, AppColors.card]) {
        expect(_sommet(fond), isNot(fond));
      }
    });
  });
}
