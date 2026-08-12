import 'dart:async';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/setup_steps.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_choice_card.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_scaffold.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Étape 1 — le mode de contenu (R7.1, R7.2, R7.3).
class ModeScreen extends ConsumerWidget {
  const ModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SetupScaffold(
      step: SetupStep.mode,
      title: l10n.setupModeTitle,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SetupChoiceCard(
            title: l10n.modeFamily,
            description: l10n.modeFamilyDescription,
            icon: Icons.family_restroom,
            onTap: () => _choose(context, ref, Audience.family),
          ),
          const SizedBox(height: 20),
          // Deux modes, pas trois. L'étendue du vivier se choisit à l'étape
          // suivante, sur son propre écran (R7.10) : c'est un réglage de Sans
          // filtre, pas un mode de plus à comparer ici.
          SetupChoiceCard(
            title: l10n.modeAdult,
            description: l10n.modeAdultDescription,
            icon: Icons.local_bar,
            onTap: () => unawaited(_chooseAdult(context, ref)),
          ),
        ],
      ),
    );
  }

  void _choose(BuildContext context, WidgetRef ref, Audience mode) {
    ref.read(setupControllerProvider.notifier).chooseMode(mode);

    // Chaque mode a son étape 2 : les catégories en Famille, l'étendue du
    // vivier en Sans filtre (R7.10). Le rang est le même, l'écran change.
    unawaited(
      context.push(
        mode == Audience.adult ? AppRoutes.setupPool : AppRoutes.setupDecks,
      ),
    );
  }

  /// Le mode adultes passe par une confirmation d'âge simple, non bloquante
  /// et non stockée : R7.3 interdit d'en faire une donnée personnelle.
  ///
  /// Elle ne fait que ça. Ce qu'on met dans le paquet se décide à l'étape
  /// suivante, sur son propre écran — une porte, puis une décision, chacune à
  /// sa place.
  Future<void> _chooseAdult(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adultConfirmTitle),
        content: Text(l10n.adultConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.adultConfirmAccept),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) return;
    if (!context.mounted) return;
    _choose(context, ref, Audience.adult);
  }
}
