import 'package:cekoi/app/router.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/setup/game_launch.dart';
import 'package:cekoi/features/play/presentation/current_game.dart';
import 'package:cekoi/features/setup/presentation/deck_catalog.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_scaffold.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Étape 5 — récapitulatif et lancement.
///
/// C'est ici que se déclenchera l'interstitiel publicitaire (lot monétisation)
/// : le seul emplacement autorisé, parce qu'il n'interrompt aucun tour
/// chronométré.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final setup = ref.watch(setupControllerProvider);
    final catalog = switch (ref.watch(deckCatalogProvider(setup.mode))) {
      AsyncData<DeckCatalog>(:final value) => value,
      _ => null,
    };

    final deckNames = [
      for (final deck in catalog?.decks ?? const <Deck>[])
        if (setup.deckIds.contains(deck.id)) deck.name,
    ];

    return SetupScaffold(
      step: 5,
      title: l10n.setupSummaryTitle,
      footer: _LaunchButton(catalog: catalog),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        children: [
          _SummaryRow(
            label: l10n.summaryMode,
            value: switch (setup.mode) {
              Audience.family => l10n.modeFamily,
              Audience.adult => l10n.modeAdult,
            },
          ),
          _SummaryRow(
            label: l10n.summaryDecks,
            value: deckNames.join(', '),
          ),
          _SummaryRow(
            label: l10n.summarySettings,
            value: l10n.summarySettingsValue(
              setup.turnDuration.inSeconds,
              setup.resolvedCardCount,
              setup.roundCount,
            ),
          ),
          _SummaryRow(
            label: l10n.summaryTeams,
            value: [
              for (final team in setup.teams)
                '${team.name} (${team.playerIds.length})',
            ].join(' · '),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _LaunchButton extends ConsumerWidget {
  const _LaunchButton({required this.catalog});

  final DeckCatalog? catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final setup = ref.watch(setupControllerProvider);
    final pool = catalog?.cards;

    if (pool == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Le tirage tourne à chaque construction, mais avec une graine propre au
    // clic : ce qui s'affiche ici est un compte, pas le paquet définitif.
    final available = catalog!.availableCards(
      deckIds: setup.deckIds.toSet(),
      difficulties: setup.difficulties,
    );
    final enough = available >= GameConfig.minimumCardCount;
    final truncated = enough && available < setup.resolvedCardCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!enough)
          _Notice(
            text: l10n.launchImpossible(
              available,
              GameConfig.minimumCardCount,
            ),
            isError: true,
          ),
        // R6.2 : on joue avec ce qui existe, mais on le dit avant de démarrer.
        if (truncated) _Notice(text: l10n.launchTruncated(available)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: enough && setup.canStart
              ? () => _launch(context, ref, pool)
              : null,
          child: Text(l10n.actionStartGame),
        ),
      ],
    );
  }

  void _launch(BuildContext context, WidgetRef ref, List<domain.Card> pool) {
    final outcome = launchGame(
      setup: ref.read(setupControllerProvider),
      pool: pool,
      seed: ref.read(seedSourceProvider)(),
    );

    final game = outcome.game;
    if (game == null) return;

    ref.read(currentGameProvider.notifier).game = game;
    context.go(AppRoutes.game);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isError
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
