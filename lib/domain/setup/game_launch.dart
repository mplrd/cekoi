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

/// Rejoue avec les mêmes réglages : même configuration, mêmes équipes, paquet
/// **retiré** (`SPEC.md`, fin de partie).
///
/// C'est le cas d'usage le plus fréquent d'après la spec, et il saute toute la
/// configuration. Le paquet, lui, ne se recopie pas : les joueurs viennent de
/// le voir trois fois, le rejouer viderait la partie de son ressort (R1).
///
/// Les réglages repris sont ceux **figés dans la partie**, pas ceux du profil
/// tel qu'il serait aujourd'hui : un profil est de la donnée, il a pu changer
/// entre deux versions de l'application (R7.5).
LaunchOutcome relaunchGame({
  required GameState previous,
  required List<Card> pool,
  required int seed,
}) {
  final config = previous.config;

  return launchGame(
    setup: GameSetup(
      mode: config.mode,
      deckIds: config.deckIds,
      difficulties: config.difficulties,
      turnDuration: config.turnDuration,
      roundCount: config.roundCount,
      cardCount: config.cardCount,
      profileId: config.profileId,
      players: previous.players,
      teamCount: previous.teams.length,
      // Les curseurs de narrateur repartent de zéro : hériter de celui d'une
      // partie finie ferait commencer la suivante par un joueur au hasard.
      teams: [
        for (final team in previous.teams) team.copyWith(narratorIndex: 0),
      ],
    ),
    pool: pool,
    seed: seed,
  );
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
