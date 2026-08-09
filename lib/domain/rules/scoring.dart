import 'dart:math';

import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:cekoi/domain/rules/round.dart';

/// Points cumulés par équipe (R5.1).
///
/// Toutes les équipes figurent au résultat, même à zéro : un tableau de scores
/// qui perd une équipe en cours de route est pire qu'un zéro affiché.
Map<String, int> tallyScores({
  required Iterable<PlayedTurn> turns,
  required Iterable<Team> teams,
}) {
  final scores = {for (final team in teams) team.id: 0};
  for (final turn in turns) {
    scores.update(
      turn.teamId,
      (points) => points + turn.score,
      ifAbsent: () => turn.score,
    );
  }
  return scores;
}

/// Détail des points manche par manche, pour l'écran intermédiaire (R4.4).
///
/// Une manche dont aucun tour n'a encore produit de résultat n'apparaît pas :
/// l'annonce du tour à venir crée déjà un tour vide, et le faire figurer
/// afficherait une manche « jouée » avant que personne n'ait touché une carte.
Map<Round, Map<String, int>> tallyScoresByRound({
  required Iterable<PlayedTurn> turns,
  required Iterable<Team> teams,
}) {
  final byRound = <Round, Map<String, int>>{};
  for (final turn in turns) {
    if (turn.isEmpty) continue;
    byRound
        .putIfAbsent(turn.round, () => {for (final team in teams) team.id: 0})
        .update(
          turn.teamId,
          (points) => points + turn.score,
          ifAbsent: () => turn.score,
        );
  }
  return byRound;
}

/// Les équipes en tête (R5.2). Plusieurs en cas d'égalité, ce qui déclenche le
/// départage de R5.3.
///
/// L'ordre suit celui de [scores], donc celui des équipes de la partie.
List<String> leadingTeamIdsOf(Map<String, int> scores) {
  if (scores.isEmpty) return const [];
  final best = scores.values.reduce(max);
  return [
    for (final entry in scores.entries)
      if (entry.value == best) entry.key,
  ];
}
