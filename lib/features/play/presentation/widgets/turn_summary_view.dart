import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/features/play/presentation/play_controller.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Le récapitulatif de fin de tour, corrigeable ligne par ligne (R3.6).
///
/// Indispensable en usage réel : dans le feu de l'action on valide une carte
/// pour une autre, et sans correction le score est faux jusqu'au podium. La
/// correction recalcule le paquet autant que le score — annuler la dernière
/// carte trouvée d'une manche la fait redémarrer (cas limites 3 et 4).
class TurnSummaryView extends ConsumerWidget {
  const TurnSummaryView({required this.game, super.key});

  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final turn = game.turn;
    final results = turn?.results ?? const <CardResult>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.turnSummaryTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.gameTeamScore(
                  game.activeTeam.name,
                  game.scoreOf(game.activeTeam.id),
                ),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.team(game.activeTeam.colorId),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.turnSummaryScore(turn?.score ?? 0),
                style: theme.textTheme.titleLarge,
              ),
              if (results.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.turnSummaryHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(child: Text(l10n.turnSummaryEmpty))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final result in results)
                      _ResultTile(
                        text: game.cardById(result.cardId)?.text ?? '',
                        outcome: result.outcome,
                        onToggle: () => ref
                            .read(playControllerProvider.notifier)
                            .correctResult(result.cardId, _opposite(result)),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: FilledButton(
            onPressed: ref.read(playControllerProvider.notifier).confirmTurn,
            child: Text(l10n.actionConfirmTurn),
          ),
        ),
      ],
    );
  }

  TurnOutcome _opposite(CardResult result) =>
      result.outcome == TurnOutcome.found
      ? TurnOutcome.passed
      : TurnOutcome.found;
}

/// Une ligne du récapitulatif : la carte, son sort, et un tap pour l'inverser.
class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.text,
    required this.outcome,
    required this.onToggle,
  });

  final String text;
  final TurnOutcome outcome;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final found = outcome == TurnOutcome.found;

    return ListTile(
      onTap: onToggle,
      leading: Icon(
        found ? Icons.check_circle : Icons.redo,
        color: found ? AppColors.found : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(text, style: theme.textTheme.titleMedium),
      trailing: Text(
        found ? l10n.outcomeFound : l10n.outcomePassed,
        style: theme.textTheme.labelMedium?.copyWith(
          color: found ? AppColors.found : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
