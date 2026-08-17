import 'dart:async';

import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/launch_ad.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/engine/draw.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/setup/game_launch.dart';
import 'package:cekoi/domain/setup/game_setup.dart';
import 'package:cekoi/features/setup/presentation/deck_catalog.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/setup_steps.dart';
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
/// C'est ici que se déclenche l'interstitiel publicitaire, au tap sur
/// *Lancer la partie* : le seul emplacement autorisé, parce qu'il n'interrompt
/// aucun tour chronométré et que le temps mort existe déjà — le groupe
/// s'installe et se passe le téléphone.
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
      step: SetupStep.summary,
      title: l10n.setupSummaryTitle,
      footer: _LaunchButton(catalog: catalog),
      // Le récapitulatif tient dans une carte, comme les catégories et le
      // tableau des scores. En liste nue sur le fond, c'était le seul écran de
      // l'application sans surface : quatre paires libellé/valeur flottant
      // dans le vide.
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
            ),
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
              color: AppColors.inkSoft,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchButton extends ConsumerStatefulWidget {
  const _LaunchButton({required this.catalog});

  final DeckCatalog? catalog;

  @override
  ConsumerState<_LaunchButton> createState() => _LaunchButtonState();
}

class _LaunchButtonState extends ConsumerState<_LaunchButton> {
  /// Le portillon travaille : trois secondes au pire, et le plus souvent rien.
  ///
  /// Sans cet état, le bouton reste inerte le temps du chargement de la pub et
  /// on tape deux fois.
  bool _enCours = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setup = ref.watch(setupControllerProvider);
    final pool = widget.catalog?.cards;

    if (pool == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Aucun tirage ici : seulement un décompte des cartes éligibles. Le paquet
    // définitif est tiré au clic, avec une graine prise à cet instant.
    final available = widget.catalog!.availableCards(
      deckIds: setup.deckIds.toSet(),
      difficulties: setup.difficulties,
      adultOnly: setup.adultOnly,
    );
    final verdict = PoolVerdict(
      available: available,
      requested: setup.resolvedCardCount,
    );

    return PopScope(
      // Le retour est fermé le temps du chargement — trois secondes au pire.
      //
      // Sans ça, un retour pendant l'attente ramène à l'étape précédente et la
      // pub s'affiche par-dessus un écran de configuration, ce que
      // `MONETISATION.md` interdit nommément ; le quota serait en plus
      // consommé pour une pub que personne n'a demandée. C'est la seule chose
      // que l'écran de lancement faisait et qui manquait sans lui.
      canPop: !_enCours,
      child: Column(
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
            onPressed: verdict.isPlayable && setup.canStart && !_enCours
                ? () => unawaited(_launch(pool))
                : null,
            child: _enCours
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(l10n.actionStartGame),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(List<domain.Card> pool) async {
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

    // Le paquet est tiré **avant** la pub : au retour de l'interstitiel, il
    // n'y a plus rien à attendre.
    ref.read(currentGameProvider.notifier).game = game;

    // L'interstitiel se déclenche ici, au tap sur « Lancer la partie », et
    // n'a pas d'écran à lui.
    //
    // Il en a eu un — « Installez-vous, la partie commence » — et c'était un
    // écran de trop : il redisait le nom et la contrainte de la manche que
    // l'annonce du tour affiche juste après, et il s'affichait même quand
    // aucune pub ne sortait, c'est-à-dire presque toujours. Retour de partie :
    // deux écrans pour la même chose entre le récapitulatif et le jeu.
    //
    // La pub, elle, est un plein écran : elle recouvre le récapitulatif sans
    // rien lui demander. Le seul coût est l'attente, plafonnée à trois
    // secondes par le portillon, pendant laquelle le bouton tourne.
    setState(() => _enCours = true);
    await ref.read(interstitialGateProvider).present();
    if (!mounted) return;
    setState(() => _enCours = false);

    // `push` et non `go` : la configuration reste sous la partie, pour que le
    // retour y ramène tant que le premier tour n'a pas commencé.
    unawaited(context.push(AppRoutes.game));
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
