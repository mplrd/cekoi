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
        // La carte qui était à l'écran quand le chrono est tombé.
        //
        // Au-dessus de la liste et non dedans : elle n'a pas été tranchée,
        // elle ne se corrige donc pas et ne compte pas. La mêler aux lignes
        // corrigeables laisserait croire le contraire.
        if (game.cardAtBuzzer case final auBuzzer?)
          _AtBuzzer(text: auBuzzer.text),
        Expanded(
          // Plus de « Aucune carte vue pendant ce tour ».
          //
          // Le message était devenu inatteignable, et faux avant de l'être :
          // un récapitulatif sans ligne veut dire que le tour est tombé au
          // chrono sans qu'on tranche, donc qu'une carte était à l'écran — le
          // bloc du dessus vient de la nommer. C'est le cas du narrateur bloqué
          // sur sa première carte, celui où l'écran doit être le plus clair, et
          // il annonçait justement qu'il n'y avait rien à voir.
          child: ListView(
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

/// La carte affichée quand le chrono est tombé (R3.5, R3.6).
///
/// Elle existait déjà dans le paquet, mais nulle part à l'écran : le
/// récapitulatif ne listait que les cartes tranchées, et celle-ci
/// disparaissait sans un mot pour ressortir deux tours plus tard. En partie
/// réelle, cinq cartes par manche subissaient ce sort, et la table en
/// concluait — logiquement — que l'application remettait en jeu des cartes
/// déjà trouvées. Le paquet était juste ; c'est l'écran qui mentait par
/// omission.
class _AtBuzzer extends StatelessWidget {
  const _AtBuzzer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.groundSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.main, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.timer_off_outlined,
                    size: 18,
                    color: AppColors.main,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.turnSummaryAtBuzzer,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.main,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.turnSummaryAtBuzzerHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.ink.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
