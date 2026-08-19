import 'dart:math' as math;

import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/features/play/presentation/play_controller.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Le départage entre les équipes à égalité en tête (R5.3).
///
/// Une carte, en mime, la première équipe qui trouve gagne. Pas de chrono :
/// c'est un départage au réflexe, et l'arbitre est humain — l'écran ne fait
/// qu'enregistrer qui a trouvé.
class TieBreakView extends ConsumerWidget {
  const TieBreakView({required this.game, super.key});

  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(playControllerProvider.notifier);
    final card = game.tieBreakCard;

    final exAequo = [
      for (final team in game.teams)
        if (game.tieBreakTeamIds.contains(team.id)) team,
    ];

    // Cet écran porte un bouton par équipe à égalité, et R8.1 en promet dix
    // utilisables. Il n'y a aucune autre sortie que ces boutons : un seul
    // d'entre eux sous le bord et R5.3 ne peut plus être tranchée, donc la
    // partie ne peut plus se terminer.
    //
    // Il débordait de 44 px dès dix équipes sur un 360 × 800 courant à taille
    // de texte normale, et de 184 px sur le même écran avec le texte agrandi
    // par le système — mesuré, pas estimé. La colonne à hauteur fixe ne
    // pouvait pas rétrécir au-delà de son `Expanded`, qui tombait à zéro et
    // laissait tout le reste passer sous le bord.
    //
    // Rien n'est épinglé ici, contrairement à l'annonce du tour : les actions
    // sont en nombre variable, on ne peut pas coller dix boutons en bas. Tout
    // défile donc ensemble, et reste centré tant que ça tient — c'est-à-dire
    // dans le cas courant, deux ou trois équipes.
    return LayoutBuilder(
      builder: (context, contraintes) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: contraintes.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.tieBreakTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tieBreakBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink.withValues(alpha: 0.75),
                  ),
                ),
                // La carte prend la place qu'il lui faut, et pas davantage :
                // un `Expanded` est impossible dans un défilement, et c'était
                // lui qui absorbait le débordement jusqu'à ne plus pouvoir.
                //
                // Pas de `Center` ici, et c'est délibéré : un `Align` sans
                // `heightFactor` remplit toute la hauteur qu'on lui autorise,
                // ce qui transformerait le plafond en réservation — 320 px
                // gelés pour une ligne de 52 px sur un 360 × 800, autant de
                // moins pour les boutons. Sans lui, la boîte se règle sur le
                // texte, `FittedBox` centrant déjà ce qu'il rétrécit.
                //
                // Le plafond ne borne donc que les textes très longs, et le
                // `math.max` le garde au-dessus du plancher : sous 240 px de
                // hauteur utile — fenêtrage libre, le portrait étant verrouillé
                // sur téléphone — les deux se croiseraient et `BoxConstraints`
                // lèverait sur des contraintes non normalisées.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 96,
                    maxHeight: math.max(96, contraintes.maxHeight * 0.4),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      card?.text ?? '',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                for (final team in exAequo) ...[
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.team(team.colorId),
                      // L'encre se calcule : le blanc du thème tombait à 2,7:1
                      // sur l'orange, seule couleur d'équipe assez claire pour
                      // le refuser — et c'est le seul écran où elle porte du
                      // texte.
                      foregroundColor: AppColors.onTeam(team.colorId),
                    ),
                    onPressed: () => controller.tieBreakWon(team.id),
                    child: Text(l10n.tieBreakWinner(team.name)),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: controller.restartTieBreak,
                  child: Text(l10n.actionTieBreakRestart),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
