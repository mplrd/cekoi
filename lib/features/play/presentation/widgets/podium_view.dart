import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/setup/game_launch.dart';
import 'package:cekoi/features/play/presentation/widgets/score_table.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Le podium, et les deux façons d'enchaîner (`SPEC.md`).
///
/// « Rejouer avec les mêmes réglages » saute toute la configuration : c'est le
/// cas d'usage le plus fréquent, on remet une partie sans que personne ne
/// retouche à quoi que ce soit.
class PodiumView extends ConsumerStatefulWidget {
  const PodiumView({required this.game, super.key});

  final GameState game;

  @override
  ConsumerState<PodiumView> createState() => _PodiumViewState();
}

class _PodiumViewState extends ConsumerState<PodiumView> {
  bool _replaying = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final game = widget.game;

    final vainqueurs = [
      for (final team in game.teams)
        if (game.winnerIds.contains(team.id)) team,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
            children: [
              Text(
                l10n.podiumTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final team in vainqueurs)
                Text(
                  l10n.podiumWinner(team.name),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.team(team.colorId),
                  ),
                ),
              const SizedBox(height: 32),
              ScoreTable(game: game),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: _replaying ? null : _replay,
                child: Text(l10n.actionReplaySameSettings),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  ref.read(currentGameProvider.notifier).game = null;
                  context.go(AppRoutes.setupMode);
                },
                child: Text(l10n.actionNewGame),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Retire un paquet neuf et relance, sans repasser par la configuration.
  ///
  /// Le vivier est relu : entre deux parties, une catégorie custom a pu être
  /// supprimée. S'il ne suffit plus, on le dit au lieu de ne rien faire.
  Future<void> _replay() async {
    setState(() => _replaying = true);

    final outcome = relaunchGame(
      previous: widget.game,
      pool: await ref
          .read(deckRepositoryProvider)
          .cardsForMode(widget.game.config.mode),
      seed: ref.read(seedSourceProvider)(),
    );

    if (!mounted) return;
    setState(() => _replaying = false);

    final game = outcome.game;
    if (game == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).replayImpossible)),
      );
      return;
    }

    ref.read(currentGameProvider.notifier).game = game;
  }
}
