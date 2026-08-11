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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
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
          Expanded(
            child: Center(
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
          ),
          for (final team in exAequo) ...[
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.team(team.colorId),
                // L'encre se calcule : le blanc du thème tombait à 2,7:1 sur
                // l'orange, seule couleur d'équipe assez claire pour le
                // refuser — et c'est le seul écran où elle porte du texte.
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
    );
  }
}
