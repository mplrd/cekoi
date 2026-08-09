import 'dart:math';

import 'package:cekoi/domain/engine/draw.dart';
import 'package:cekoi/domain/engine/game_engine.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/setup/game_setup.dart';

/// Ce que donne une tentative de lancement.
///
/// Le tirage est rendu même quand la partie ne démarre pas : c'est lui qui
/// porte le nombre de cartes réellement disponibles, donc de quoi expliquer
/// le refus au joueur plutôt que de griser un bouton sans un mot (R6.2).
class LaunchOutcome {
  const LaunchOutcome({required this.draw, this.game});

  final DrawResult draw;

  /// `null` quand le vivier n'atteint pas le minimum de R6.2.
  final GameState? game;

  bool get isLaunched => game != null;
}

/// Tire le paquet et ouvre la partie.
///
/// [pool] est le vivier complet du mode ; le filtrage par catégorie retenue
/// se fait ici, pour que l'appelant n'ait pas à refaire le même tri que
/// l'écran de sélection — deux filtrages, deux occasions de diverger.
LaunchOutcome launchGame({
  required GameSetup setup,
  required List<Card> pool,
  required int seed,
}) {
  final selected = setup.deckIds.toSet();
  final draw = drawCards(
    pool: [
      for (final card in pool)
        if (selected.contains(card.deckId)) card,
    ],
    requested: setup.resolvedCardCount,
    mode: setup.mode,
    random: Random(seed),
    allowedDifficulties: setup.difficulties,
  );

  if (!draw.isPlayable || !setup.canStart) return LaunchOutcome(draw: draw);

  return LaunchOutcome(
    draw: draw,
    game: startGame(
      config: setup.toConfig(),
      players: setup.players,
      teams: setup.teams,
      deck: draw.cards,
      tieBreakReserve: draw.tieBreakReserve,
      seed: seed,
    ),
  );
}
