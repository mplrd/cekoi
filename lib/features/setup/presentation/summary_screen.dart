import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/domain/engine/draw.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/setup/game_launch.dart';
import 'package:cekoi/domain/setup/game_setup.dart';
import 'package:cekoi/features/setup/presentation/deck_catalog.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_scaffold.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Les noms d'équipe par défaut, « Équipe 1 », « Équipe 2 »… (R8.3).
///
/// Ils vivent ici et non dans le domaine, qui ne fabrique aucun libellé : c'est
/// la présentation qui comble les noms laissés vides, au moment de construire
/// les équipes.
List<String> fallbackTeamNames(GameSetup setup, AppLocalizations l10n) => [
  for (var i = 0; i < setup.teamCount; i++) l10n.teamDefaultName(i + 1),
];

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
            ),
          ),
          _SummaryRow(
            label: l10n.summaryTeams,
            value: [
              for (final team in setup.teamsNamed(
                fallbackTeamNames(setup, l10n),
              ))
                team.name,
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

    // Aucun tirage ici : seulement un décompte des cartes éligibles. Le paquet
    // définitif est tiré au clic, avec une graine prise à cet instant.
    final available = catalog!.availableCards(
      deckIds: setup.deckIds.toSet(),
      difficulties: setup.difficulties,
    );
    final verdict = PoolVerdict(
      available: available,
      requested: setup.resolvedCardCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!verdict.isPlayable)
          _Notice(
            text: l10n.launchImpossible(
              available,
              GameConfig.minimumCardCount,
            ),
            isError: true,
          ),
        if (verdict.mustWarnShortage)
          _Notice(text: l10n.launchTruncated(available)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: verdict.isPlayable && setup.canStart
              ? () => _launch(context, ref, pool)
              : null,
          child: Text(l10n.actionStartGame),
        ),
      ],
    );
  }

  void _launch(BuildContext context, WidgetRef ref, List<domain.Card> pool) {
    final setup = ref.read(setupControllerProvider);
    final outcome = launchGame(
      setup: setup,
      teams: setup.teamsNamed(
        fallbackTeamNames(setup, AppLocalizations.of(context)),
      ),
      pool: pool,
      seed: ref.read(seedSourceProvider)(),
    );

    final game = outcome.game;
    if (game == null) {
      // Inatteignable tant que le bouton est grisé au bon moment. Mais un
      // bouton qui ne fait rien sans un mot est le pire des états si cet
      // invariant bouge : mieux vaut dire pourquoi.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).launchImpossible(
              outcome.draw.available,
              GameConfig.minimumCardCount,
            ),
          ),
        ),
      );
      return;
    }

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
