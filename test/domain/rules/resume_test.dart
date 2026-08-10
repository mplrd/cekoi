import 'package:cekoi/domain/rules/resume.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un instant fixe : le domaine ne lit pas l'horloge, elle entre en paramètre.
final DateTime _now = DateTime.utc(2026, 8, 10, 14);

void main() {
  group('R9.2 — une partie abandonnée expire au bout de 24 h', () {
    test('une partie de tout à l’heure se reprend', () {
      expect(
        isResumable(
          savedAt: _now.subtract(const Duration(minutes: 20)),
          now: _now,
        ),
        isTrue,
      );
    });

    test('la veille au soir se reprend encore', () {
      // Le cas qui compte : on joue le samedi soir, on rouvre le dimanche
      // matin. Une fenêtre plus courte perdrait la partie la plus probable.
      expect(
        isResumable(
          savedAt: _now.subtract(const Duration(hours: 14)),
          now: _now,
        ),
        isTrue,
      );
    });

    test('à 24 h pile, elle se reprend encore', () {
      expect(
        isResumable(savedAt: _now.subtract(resumeWindow), now: _now),
        isTrue,
      );
    });

    test('une seconde plus tard, elle est oubliée', () {
      expect(
        isResumable(
          savedAt: _now.subtract(resumeWindow + const Duration(seconds: 1)),
          now: _now,
        ),
        isFalse,
      );
    });

    test('une sauvegarde datée du futur ne bloque pas la reprise', () {
      // Changement d'heure, fuseau, horloge réglée à la main : refuser de
      // reprendre parce que la date paraît future serait absurde.
      expect(
        isResumable(
          savedAt: _now.add(const Duration(hours: 2)),
          now: _now,
        ),
        isTrue,
      );
    });
  });
}
