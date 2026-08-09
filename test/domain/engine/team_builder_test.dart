import 'dart:math';

import 'package:cekoi/domain/engine/team_builder.dart';
import 'package:cekoi/domain/entities/player.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

List<Team> propose(
  List<Player> players, {
  int teamCount = 2,
  int seed = 42,
}) => proposeTeams(
  players: players,
  teamNames: [for (var i = 1; i <= teamCount; i++) 'Équipe $i'],
  random: Random(seed),
);

/// [adults] adultes et [children] enfants, aux identifiants distincts.
List<Player> roster({int adults = 0, int children = 0}) => [
  for (var i = 0; i < adults; i++) testPlayer('adulte-$i'),
  for (var i = 0; i < children; i++) testPlayer('enfant-$i', isChild: true),
];

int childrenIn(Team team) =>
    team.playerIds.where((id) => id.startsWith('enfant-')).length;

void main() {
  group('R8.5 — une partie exige deux équipes de deux joueurs', () {
    test('une seule équipe est refusée', () {
      expect(
        () => propose(roster(adults: 8), teamCount: 1),
        throwsArgumentError,
      );
    });

    test('zéro équipe est refusée', () {
      expect(
        () => propose(roster(adults: 8), teamCount: 0),
        throwsArgumentError,
      );
    });

    test('trois joueurs pour deux équipes sont refusés', () {
      // La troisième équipe n'aurait qu'un joueur : personne pour deviner.
      expect(() => propose(roster(adults: 3)), throwsArgumentError);
    });

    test('cinq joueurs pour deux équipes passent, pour trois non', () {
      expect(propose(roster(adults: 5)), hasLength(2));
      expect(
        () => propose(roster(adults: 5), teamCount: 3),
        throwsArgumentError,
      );
    });

    test('deux équipes de deux joueurs pile sont acceptées', () {
      final teams = propose(roster(adults: 4));

      expect(teams, hasLength(2));
      expect(teams.every((t) => t.playerIds.length == 2), isTrue);
    });
  });

  group('R8.3 — répartition aléatoire équilibrée', () {
    test("les effectifs ne diffèrent jamais de plus d'un joueur", () {
      for (var players = 4; players <= 25; players++) {
        for (var teamCount = 2; teamCount * 2 <= players; teamCount++) {
          final teams = propose(
            roster(adults: players),
            teamCount: teamCount,
            seed: players * 100 + teamCount,
          );
          final sizes = teams.map((t) => t.playerIds.length).toList();

          expect(
            sizes.reduce(max) - sizes.reduce(min),
            lessThanOrEqualTo(1),
            reason: '$players joueurs en $teamCount équipes : $sizes',
          );
        }
      }
    });

    test('tous les joueurs sont répartis, sans perte ni doublon', () {
      final players = roster(adults: 7, children: 4);

      final assigned = [
        for (final team in propose(players, teamCount: 3)) ...team.playerIds,
      ];

      expect(assigned, hasLength(11));
      expect(assigned.toSet(), players.map((p) => p.id).toSet());
    });

    test('les enfants sont répartis plutôt que concentrés', () {
      // Quatre enfants et quatre adultes en deux équipes : deux enfants
      // chacune, et ce **quelle que soit la graine**. Un simple mélange de
      // tous les joueurs suivi d'une distribution tournante donnerait
      // régulièrement 3-1 ou 4-0, ce que R8.3 interdit.
      for (var seed = 0; seed < 60; seed++) {
        final teams = propose(
          roster(adults: 4, children: 4),
          seed: seed,
        );

        expect(
          teams.map(childrenIn).toList(),
          [2, 2],
          reason: 'Graine $seed',
        );
      }
    });

    test("un nombre impair d'enfants se répartit au mieux", () {
      for (var seed = 0; seed < 60; seed++) {
        final teams = propose(roster(adults: 5, children: 3), seed: seed);
        final perTeam = teams.map(childrenIn).toList()..sort();

        expect(perTeam, [1, 2], reason: 'Graine $seed');
      }
    });

    test('deux enfants pour quatre équipes atterrissent séparément', () {
      for (var seed = 0; seed < 60; seed++) {
        final teams = propose(
          roster(adults: 10, children: 2),
          teamCount: 4,
          seed: seed,
        );

        expect(
          teams.map(childrenIn).where((n) => n > 0).length,
          2,
          reason: 'Graine $seed : les deux enfants doivent être séparés',
        );
      }
    });

    test('une partie sans enfant reste équilibrée', () {
      final teams = propose(roster(adults: 9), teamCount: 4);

      expect(teams.map((t) => t.playerIds.length).toList()..sort(), [
        2,
        2,
        2,
        3,
      ]);
    });
  });

  group('R8.4 — la proposition est relançable', () {
    test('même graine, même composition', () {
      final players = roster(adults: 6, children: 3);

      expect(
        propose(players, teamCount: 3, seed: 7),
        propose(players, teamCount: 3, seed: 7),
      );
    });

    test('graines différentes, compositions différentes', () {
      final players = roster(adults: 6, children: 3);

      expect(
        propose(players, teamCount: 3, seed: 1),
        isNot(propose(players, teamCount: 3, seed: 2)),
      );
    });

    test("l'ordre de saisie des joueurs n'influence pas le résultat", () {
      // Sans cette garantie, ressaisir les mêmes joueurs dans un autre ordre
      // donnerait une autre composition à graine égale, et la relance ne
      // serait plus reproductible.
      final players = roster(adults: 6, children: 3);
      final reversed = players.reversed.toList();

      expect(
        propose(players, teamCount: 3, seed: 7),
        propose(reversed, teamCount: 3, seed: 7),
      );
    });
  });

  group('forme des équipes proposées', () {
    test(
      'chaque équipe porte son nom, un identifiant unique et une couleur',
      () {
        final teams = propose(roster(adults: 8), teamCount: 3);

        expect(teams.map((t) => t.name), ['Équipe 1', 'Équipe 2', 'Équipe 3']);
        expect(teams.map((t) => t.id).toSet(), hasLength(3));
        expect(teams.map((t) => t.colorId).toSet(), hasLength(3));
      },
    );

    test('le narrateur de départ est le premier joueur de chaque équipe', () {
      final teams = propose(roster(adults: 8), teamCount: 3);

      for (final team in teams) {
        expect(team.narratorIndex, 0);
        expect(team.currentNarratorId, team.playerIds.first);
      }
    });

    test('deux joueurs de même identifiant sont refusés', () {
      // Deux « Papa » saisis par mégarde : sans ce garde-fou, le curseur de
      // narrateur désignerait un joueur ambigu tout le reste de la partie.
      final players = [
        testPlayer('papa'),
        testPlayer('papa'),
        testPlayer('maman'),
        testPlayer('lea'),
      ];

      expect(() => propose(players), throwsArgumentError);
    });
  });
}
