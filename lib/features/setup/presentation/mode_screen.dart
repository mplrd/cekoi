import 'dart:async';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/setup_steps.dart';
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
          _ModeCard(
            title: l10n.modeFamily,
            description: l10n.modeFamilyDescription,
            icon: Icons.family_restroom,
            onTap: () => _choose(context, ref, Audience.family),
          ),
          const SizedBox(height: 20),
          _ModeCard(
            title: l10n.modeAdult,
            description: l10n.modeAdultDescription,
            icon: Icons.local_bar,
            onTap: () => unawaited(_chooseAdult(context, ref)),
          ),
          const SizedBox(height: 20),
          // Sans filtre **uniquement** : le paquet perd ses cartes tout public
          // (R7.1). Une carte à part plutôt qu'une case à cocher ailleurs —
          // c'est un choix de contenu, il se fait au même endroit et au même
          // moment que les deux autres.
          _ModeCard(
            title: l10n.modeAdultOnly,
            description: l10n.modeAdultOnlyDescription,
            icon: Icons.local_fire_department,
            onTap: () => unawaited(
              _chooseAdult(context, ref, adultOnly: true),
            ),
          ),
        ],
      ),
    );
  }

  void _choose(
    BuildContext context,
    WidgetRef ref,
    Audience mode, {
    bool adultOnly = false,
  }) {
    ref.read(setupControllerProvider.notifier).chooseMode(mode);
    ref.read(setupControllerProvider.notifier).setAdultOnly(actif: adultOnly);

    // Toujours vers les catégories, quel que soit le mode.
    //
    // C'est l'écran des catégories qui s'efface lui-même quand son mode le
    // saute (R7.10), une fois son travail fait — il est le seul à savoir
    // quand le catalogue a répondu, et le seul à pouvoir montrer une erreur si
    // la base répond mal. Trancher ici obligerait à recopier sa sélection, et
    // ferait disparaître l'écran du chemin de retour que R7.10 promet.
    unawaited(context.push(AppRoutes.setupDecks));
  }

  /// Le mode adultes passe par une confirmation d'âge simple, non bloquante
  /// et non stockée : R7.3 interdit d'en faire une donnée personnelle.
  Future<void> _chooseAdult(
    BuildContext context,
    WidgetRef ref, {
    bool adultOnly = false,
  }) async {
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

    if (confirmed ?? false) {
      if (!context.mounted) return;
      _choose(context, ref, Audience.adult, adultOnly: adultOnly);
    }
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
