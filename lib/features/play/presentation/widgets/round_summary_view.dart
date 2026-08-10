import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/features/play/presentation/play_controller.dart';
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
              Text(
                l10n.roundSummaryTitle(game.round.number),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ScoreTable(game: game),
              const SizedBox(height: 32),
              Text(
                l10n.roundSummaryNext(next.label(l10n)),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                next.rule(l10n),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: FilledButton(
            onPressed: ref.read(playControllerProvider.notifier).startNextRound,
            child: Text(l10n.actionNextRound),
          ),
        ),
      ],
    );
  }
}
