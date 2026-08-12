import 'dart:async';

import 'package:cekoi/app/router.dart';
import 'package:cekoi/features/setup/presentation/deck_catalog.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/setup_steps.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_choice_card.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_scaffold.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Étape 2 du mode Sans filtre — l'étendue du vivier (R7.1, R7.10).
///
/// Elle occupe la place que les catégories tiennent en Famille : même rang,
/// même ossature, même façon de choisir. Le mode adultes prend toutes les
/// catégories, il n'y avait donc rien à décider sur cet écran-là — mais il
/// reste une décision de contenu à prendre, et c'est celle-ci.
///
/// L'écran porte aussi la présélection de R7.9 : c'est lui qui, dans ce mode,
/// voit le catalogue arriver.
class PoolScreen extends ConsumerStatefulWidget {
  const PoolScreen({super.key});

  @override
  ConsumerState<PoolScreen> createState() => _PoolScreenState();
}

class _PoolScreenState extends ConsumerState<PoolScreen> {
  /// Vrai dès que la présélection a eu lieu, pour ne la faire qu'à la première
  /// arrivée : revenir sur l'écran ne doit pas défaire une sélection corrigée
  /// entre-temps.
  bool _preselectionne = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setup = ref.watch(setupControllerProvider);
    final catalog = ref.watch(deckCatalogProvider(setup.mode));

    // R7.9 : le mode prend toutes les catégories. Le catalogue arrive après le
    // premier rendu, et écrire dans l'état pendant une construction est
    // interdit — d'où le report d'une frame.
    if (catalog case AsyncData(:final value) when !_preselectionne) {
      _preselectionne = true;
      final ids = [for (final deck in value.decks) deck.id];
      if (setup.deckIds.isEmpty && ids.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(setupControllerProvider.notifier).selectAllDecks(ids);
        });
      }
    }

    return SetupScaffold(
      step: SetupStep.pool,
      title: l10n.setupPoolTitle,
      child: switch (catalog) {
        // Les deux choix ne dépendent pas du catalogue, mais la présélection
        // si : avancer avant qu'il ait répondu partirait avec un paquet vide.
        AsyncError() => Center(child: Text(l10n.errorGeneric)),
        AsyncData() => ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            SetupChoiceCard(
              title: l10n.adultPoolAll,
              description: l10n.adultPoolAllDescription,
              icon: Icons.local_bar,
              onTap: () => _choose(adultOnly: false),
            ),
            const SizedBox(height: 20),
            SetupChoiceCard(
              title: l10n.adultPoolOnly,
              description: l10n.adultPoolOnlyDescription,
              icon: Icons.local_fire_department,
              onTap: () => _choose(adultOnly: true),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  void _choose({required bool adultOnly}) {
    ref.read(setupControllerProvider.notifier).setAdultOnly(actif: adultOnly);
    unawaited(context.push(AppRoutes.setupSettings));
  }
}
