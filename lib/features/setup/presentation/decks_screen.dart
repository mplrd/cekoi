import 'package:cekoi/app/router.dart';
import 'package:cekoi/domain/engine/draw.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/rules/game_profiles.dart';
import 'package:cekoi/domain/setup/game_setup.dart';
import 'package:cekoi/features/setup/presentation/deck_catalog.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/setup_steps.dart';
import 'package:cekoi/features/setup/presentation/widgets/deck_icon.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_scaffold.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Libellé et tranche d'âge d'un profil.
///
/// Indexés par identifiant : le domaine ne porte aucun texte affichable. Un
/// profil ajouté en donnée retombe sur son identifiant plutôt que de faire
/// planter l'écran — visible en test, sans conséquence en production.
({String name, String ageRange}) profileLabels(
  AppLocalizations l10n,
  String profileId,
) => switch (profileId) {
  'minis' => (name: l10n.profileMinis, ageRange: l10n.profileAgeRange(6, 9)),
  'ados' => (name: l10n.profileAdos, ageRange: l10n.profileAgeRange(10, 14)),
  'mix' => (name: l10n.profileMix, ageRange: l10n.profileAllAges),
  _ => (name: profileId, ageRange: ''),
};

String? profileUnavailabilityLabel(
  AppLocalizations l10n,
  ProfileUnavailability? reason,
) => switch (reason) {
  ProfileUnavailability.noEligibleDeck => l10n.profileUnavailableNoDeck,
  ProfileUnavailability.notEnoughCards => l10n.profileUnavailableNotEnough,
  null => null,
};

/// Étape 2 — profils d'abord, grille ensuite (R7.5 à R7.9).
class DecksScreen extends ConsumerStatefulWidget {
  const DecksScreen({super.key});

  @override
  ConsumerState<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends ConsumerState<DecksScreen> {
  /// Le mode dont la présélection a déjà eu lieu (R7.9).
  ///
  /// Retenu pour ne présélectionner qu'à la **première** arrivée dans un mode :
  /// décocher une catégorie est une décision, et la voir revenir seule au
  /// retour sur l'écran serait pire que la sélection vide qu'on corrige ici.
  Audience? _preselectionne;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setup = ref.watch(setupControllerProvider);
    final catalog = ref.watch(deckCatalogProvider(setup.mode));
    final loaded = switch (catalog) {
      AsyncData<DeckCatalog>(:final value) => value,
      _ => null,
    };

    // Le catalogue arrive après le premier rendu, et modifier l'état pendant
    // une construction est interdit : d'où le report d'une frame.
    if (loaded != null && _preselectionne != setup.mode) {
      _preselectionne = setup.mode;
      final ids = [for (final deck in loaded.decks) deck.id];
      if (setup.deckIds.isEmpty && ids.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(setupControllerProvider.notifier).selectAllDecks(ids);
        });
      }
    }

    return SetupScaffold(
      step: SetupStep.decks,
      title: l10n.setupDecksTitle,
      // Pas de compteur ni de bouton tant que le contenu n'est pas là : ils
      // annonceraient zéro carte, ce qui ressemble à une erreur.
      footer: loaded == null
          ? null
          : _SelectionFooter(setup: setup, catalog: loaded),
      child: switch (catalog) {
        AsyncError<DeckCatalog>() => Center(child: Text(l10n.errorGeneric)),
        AsyncData<DeckCatalog>(:final value) => _Content(
          setup: setup,
          catalog: value,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.setup, required this.catalog});

  final GameSetup setup;
  final DeckCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (catalog.decks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.setupNoDeck, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      children: [
        for (final availability in catalog.profiles) ...[
          _ProfileCard(
            availability: availability,
            isSelected: setup.profileId == availability.profile.id,
            onTap: availability.isPlayable
                ? () => ref
                      .read(setupControllerProvider.notifier)
                      .chooseProfile(availability.profile, catalog.decks)
                : null,
          ),
          const SizedBox(height: 12),
        ],
        // La grille est repliée : cocher les catégories une par une est la
        // corvée que les profils existent pour éviter (SPEC).
        _CustomizeSection(setup: setup, catalog: catalog),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.availability,
    required this.isSelected,
    required this.onTap,
  });

  final ProfileAvailability availability;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labels = profileLabels(l10n, availability.profile.id);
    final reason = profileUnavailabilityLabel(
      l10n,
      availability.unavailability,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: Opacity(
        // Grisé, pas retiré : R7.8 veut que le joueur comprenne pourquoi un
        // profil n'est pas disponible plutôt qu'il disparaisse en silence.
        opacity: availability.isPlayable ? 1 : 0.5,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labels.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (labels.ageRange.isNotEmpty)
                        Text(
                          labels.ageRange,
                          style: theme.textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        reason ?? l10n.cardCount(availability.availableCards),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: reason == null
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomizeSection extends ConsumerWidget {
  const _CustomizeSection({required this.setup, required this.catalog});

  final GameSetup setup;
  final DeckCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return ExpansionTile(
      title: Text(l10n.setupCustomize),
      // Dépliée d'emblée si le joueur a déjà personnalisé : la replier lui
      // cacherait sa propre sélection.
      initiallyExpanded: setup.isCustomSelection && setup.deckIds.isNotEmpty,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        for (final deck in catalog.decks)
          _DeckTile(
            deck: deck,
            cardCount: catalog.cardCountsByDeck[deck.id] ?? 0,
            isSelected: setup.deckIds.contains(deck.id),
            onChanged: deck.isPremium
                ? null
                : (_) => ref
                      .read(setupControllerProvider.notifier)
                      .toggleDeck(deck.id),
          ),
      ],
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({
    required this.deck,
    required this.cardCount,
    required this.isSelected,
    required this.onChanged,
  });

  final Deck deck;
  final int cardCount;
  final bool isSelected;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final theme = Theme.of(context);

    return CheckboxListTile(
      value: isSelected,
      onChanged: onChanged,
      title: Text(deck.name),
      subtitle: Text(
        [
          l10n.cardCount(cardCount),
          // Le déblocage par pub arrive au lot monétisation ; d'ici là la
          // catégorie est visible et inaccessible, pas cachée.
          if (deck.isPremium) l10n.deckPremium,
          if (deck.origin == DeckOrigin.custom) l10n.deckCustom,
        ].join(' · '),
      ),
      // L'icône de la catégorie plutôt que la case seule : une liste de vingt
      // et une lignes de texte se parcourt mal, et chaque catégorie porte déjà
      // la sienne dans son JSON. Le cadenas d'une catégorie premium prend sa
      // place — c'est l'information qui prime à ce moment-là.
      secondary: deck.isPremium
          ? const Icon(Icons.lock_outline)
          : Icon(
              deckIcon(deck.icon),
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
    );
  }
}

/// Compteur permanent et avertissement de R6.2.
class _SelectionFooter extends StatelessWidget {
  const _SelectionFooter({required this.setup, required this.catalog});

  final GameSetup setup;
  final DeckCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final available = catalog.availableCards(
      deckIds: setup.deckIds.toSet(),
      difficulties: setup.difficulties,
      adultOnly: setup.adultOnly,
    );
    // La demande n'est pas encore connue à cette étape — les joueurs viennent
    // plus loin. Seul le plancher de R6.2 se juge ici.
    final enough = PoolVerdict(
      available: available,
      requested: GameConfig.minimumCardCount,
    ).isPlayable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.setupSelectionSummary(available),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (!enough) ...[
          const SizedBox(height: 4),
          Text(
            l10n.setupNotEnoughCards(GameConfig.minimumCardCount),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: enough
              ? () => context.push(AppRoutes.setupSettings)
              : null,
          child: Text(l10n.actionContinue),
        ),
      ],
    );
  }
}
