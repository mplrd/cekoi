import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/features/play/presentation/play_controller.dart';
import 'package:cekoi/features/play/presentation/widgets/action_zone.dart';
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
    // Le fond est celui du thème, comme partout : l'encre est donc l'encre
    // du jeu, et les lignes sont des cartes blanches posées dessus.
    const encre = AppColors.ink;

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
                  fontWeight: FontWeight.w800,
                  color: encre,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.gameTeamScore(
                  game.activeTeam.name,
                  game.scoreOf(game.activeTeam.id),
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: encre.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.turnSummaryScore(turn?.score ?? 0),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: encre,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (results.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.turnSummaryHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: encre.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    l10n.turnSummaryEmpty,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: encre.withValues(alpha: 0.85),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final result in results)
                      _ResultTile(
                        text: game.cardById(result.cardId)?.text ?? '',
                        outcome: result.outcome,
                        // En manche 1 on ne passe pas (R3.9) : une carte non
                        // devinée n'est pas « passée », elle n'a pas été
                        // trouvée. Le mot que l'écran de jeu vient d'exclure
                        // ne doit pas revenir au récapitulatif.
                        allowsPass: game.round.allowsPass,
                        onToggle: () => ref
                            .read(playControllerProvider.notifier)
                            .correctResult(result.cardId, _opposite(result)),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ActionZone(
            label: l10n.actionConfirmTurn,
            background: AppColors.deep,
            foreground: Colors.white,
            onPressed: ref.read(playControllerProvider.notifier).confirmTurn,
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
    required this.allowsPass,
    required this.onToggle,
  });

  final String text;
  final TurnOutcome outcome;

  /// La manche autorise-t-elle à passer (R3.9) — ce qui décide du mot, pas du
  /// sort de la carte : le domaine ne connaît que `found` et `passed`.
  final bool allowsPass;

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final found = outcome == TurnOutcome.found;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: ListTile(
          onTap: onToggle,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          leading: Icon(
            found ? Icons.check_circle : Icons.redo,
            color: found
                ? AppColors.deep
                : AppColors.ink.withValues(alpha: 0.45),
          ),
          title: Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Text(
            found
                ? l10n.outcomeFound
                : (allowsPass ? l10n.outcomePassed : l10n.outcomeMissed),
            style: theme.textTheme.labelLarge?.copyWith(
              color: found
                  ? AppColors.deep
                  : AppColors.ink.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
