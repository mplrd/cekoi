import 'package:cekoi/domain/engine/team_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R8.5 — une partie exige au moins deux équipes', () {
    test('une seule équipe est refusée', () {
      expect(() => teamsFromNames(['Les rouges']), throwsArgumentError);
    });

    test('aucune équipe est refusée', () {
      expect(() => teamsFromNames([]), throwsArgumentError);
    });

    test('deux équipes passent', () {
      expect(teamsFromNames(['Les rouges', 'Les bleus']), hasLength(2));
    });
  });

  group("R8.1 — aucune limite haute sur le nombre d'équipes", () {
    test('dix équipes se construisent sans broncher', () {
      final teams = teamsFromNames([
        for (var i = 1; i <= 10; i++) 'Équipe $i',
      ]);

      expect(teams, hasLength(10));
      expect(
        teams.map((t) => t.id).toSet(),
        hasLength(10),
        reason: 'Deux équipes de même identifiant partageraient leur score',
      );
    });
  });

  group('R8.3 — une équipe est un nom et une couleur', () {
    test('les noms sont repris dans leur ordre', () {
      final teams = teamsFromNames(['Les rouges', 'Les bleus', 'Les verts']);

      expect(teams.map((t) => t.name), [
        'Les rouges',
        'Les bleus',
        'Les verts',
      ]);
    });

    test('chaque équipe reçoit une couleur distincte', () {
      final teams = teamsFromNames(['A', 'B', 'C']);

      expect(teams.map((t) => t.colorId).toSet(), hasLength(3));
    });

    test('la composition ne dépend que de la liste reçue', () {
      expect(
        teamsFromNames(['A', 'B']),
        teamsFromNames(['A', 'B']),
        reason: "Aucun hasard n'entre dans la construction des équipes",
      );
    });
  });
}
