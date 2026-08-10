import 'package:cekoi/domain/entities/team.dart';

/// Nombre minimum d'équipes (R8.5).
const int minimumTeamCount = 2;

/// Construit les équipes à partir de leurs seuls noms (R8.3).
///
/// Les noms viennent de l'appelant : ils sont affichés, donc ils sortent de
/// l'ARB, jamais du domaine. Un nom vide n'est pas traité ici — l'appelant a
/// substitué son « Équipe N » avant d'arriver, parce que ce libellé est lui
/// aussi de la présentation.
///
/// Les identifiants et les couleurs suivent le rang, ce qui rend la
/// composition entièrement déterminée par la liste reçue.
List<Team> teamsFromNames(List<String> names) {
  if (names.length < minimumTeamCount) {
    throw ArgumentError.value(
      names.length,
      'names',
      'Une partie demande au moins $minimumTeamCount équipes (R8.5)',
    );
  }

  return [
    for (var i = 0; i < names.length; i++)
      Team(id: 'team-${i + 1}', name: names[i], colorId: i),
  ];
}
