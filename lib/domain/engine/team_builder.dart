import 'dart:math';

import 'package:cekoi/domain/entities/player.dart';
import 'package:cekoi/domain/entities/team.dart';

/// Nombre minimum d'équipes, et de joueurs par équipe (R8.5).
const int minimumTeamCount = 2;
const int minimumTeamSize = 2;

/// Propose une composition d'équipes à partir des joueurs saisis (R8.3).
///
/// Ce n'est qu'une **suggestion** : elle est relançable avec une autre graine
/// et entièrement modifiable ensuite (R8.4).
///
/// Les noms sont fournis par l'appelant plutôt que fabriqués ici : ils sont
/// affichés, donc ils viennent de l'ARB. Le nombre d'équipes s'en déduit, ce
/// qui rend impossible un décalage entre un compte et une liste de noms.
///
/// Deux propriétés sont garanties, et sont l'objet de la règle :
/// - les effectifs ne diffèrent jamais de plus d'un joueur ;
/// - les joueurs marqués *enfant* sont répartis entre les équipes au lieu
///   d'être concentrés dans l'une d'elles.
List<Team> proposeTeams({
  required List<Player> players,
  required List<String> teamNames,
  required Random random,
}) {
  final teamCount = teamNames.length;
  if (teamCount < minimumTeamCount) {
    throw ArgumentError.value(
      teamCount,
      'teamNames',
      'Une partie demande au moins $minimumTeamCount équipes (R8.5)',
    );
  }

  if (players.length < teamCount * minimumTeamSize) {
    throw ArgumentError.value(
      players.length,
      'players',
      'Il faut au moins $minimumTeamSize joueurs par équipe, soit '
          '${teamCount * minimumTeamSize} pour $teamCount équipes (R8.5)',
    );
  }

  final ids = players.map((p) => p.id).toSet();
  if (ids.length != players.length) {
    throw ArgumentError.value(
      players.map((p) => p.id).toList(),
      'players',
      'Deux joueurs portent le même identifiant : le curseur de narrateur '
          'désignerait un joueur ambigu (R3.1)',
    );
  }

  // Tri par identifiant avant tout usage du hasard : la composition ne doit
  // dépendre que de la graine, pas de l'ordre de saisie, sans quoi relancer
  // la proposition ne serait plus reproductible.
  List<Player> shuffled(bool Function(Player) matches) =>
      players.where(matches).toList()
        ..sort((a, b) => a.id.compareTo(b.id))
        ..shuffle(random);

  // Les enfants sont distribués en premier : la distribution tournante les
  // place alors forcément dans des équipes distinctes tant qu'il y en a moins
  // que d'équipes, et à une unité près au-delà. Mélanger tout le monde d'un
  // bloc donnerait régulièrement une équipe qui les concentre.
  final ordered = [
    ...shuffled((p) => p.isChild),
    ...shuffled((p) => !p.isChild),
  ];

  final rosters = List.generate(teamCount, (_) => <String>[]);
  for (var i = 0; i < ordered.length; i++) {
    rosters[i % teamCount].add(ordered[i].id);
  }

  return [
    for (var i = 0; i < teamCount; i++)
      Team(
        id: 'team-${i + 1}',
        name: teamNames[i],
        playerIds: rosters[i],
        colorId: i,
      ),
  ];
}
