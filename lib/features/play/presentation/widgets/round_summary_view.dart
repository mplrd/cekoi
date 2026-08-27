import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/app/widgets/texte_qui_tient.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/features/play/presentation/play_controller.dart';
import 'package:cekoi/features/play/presentation/widgets/action_zone.dart';
import 'package:cekoi/features/play/presentation/widgets/round_labels.dart';
import 'package:cekoi/features/play/presentation/widgets/score_table.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Les scores entre deux manches, avec la contrainte à venir (R4.4).
///
/// Le rappel de la manche suivante n'est pas décoratif : c'est le moment où
/// tout le monde réalise que les cartes qu'on vient de décrire librement vont
/// devoir se mimer.
class RoundSummaryView extends ConsumerWidget {
  const RoundSummaryView({required this.game, super.key});

  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final next = game.rounds[game.roundIndex + 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
            children: [
              // Aligné à gauche par choix — pas de `textAlign` ici, donc.
              // « manche » réclame plus que la largeur de la liste à ×3,1.
              TexteQuiTient(
                l10n.roundSummaryTitle(game.round.number),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 24),
              ScoreTable(game: game),
              const SizedBox(height: 32),
              // La manche à venir dans sa propre couleur : on comprend avant
              // de lire que le décor change.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.round(next),
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.roundSummaryNext(next.label(l10n)),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.onRound(next),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        next.rule(l10n),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.onRound(next).withValues(alpha: .85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ActionZone(
            label: l10n.actionNextRound,
            background: AppColors.deep,
            foreground: Colors.white,
            onPressed: ref.read(playControllerProvider.notifier).startNextRound,
          ),
        ),
      ],
    );
  }
}
