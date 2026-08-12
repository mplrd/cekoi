import 'dart:async';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/app/theme/app_theme.dart';
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
          // Deux modes, pas trois. Le choix du vivier (tout le paquet, ou les
          // seules cartes adultes) se pose **derrière** cette carte : c'est un
          // réglage de Sans filtre, pas un mode de plus à comparer sur
          // l'écran d'entrée.
          _ModeCard(
            title: l10n.modeAdult,
            description: l10n.modeAdultDescription,
            icon: Icons.local_bar,
            onTap: () => unawaited(_chooseAdult(context, ref)),
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

  /// Sans filtre : la confirmation d'âge (R7.3) et le choix du vivier (R7.1)
  /// tiennent dans la même question.
  ///
  /// Les deux réponses valent « oui, j'ai 18 ans » — elles ne se distinguent
  /// que par ce qu'elles mettent dans le paquet. Fusionner les deux évite
  /// d'enchaîner deux boîtes de dialogue pour une seule décision, et garde la
  /// confirmation explicite : le corps de la question dit ce qu'on répond en
  /// choisissant. Rien n'est stocké, R7.3 l'interdit.
  ///
  /// Rend `true` pour *rien d'autre*, `false` pour tout le paquet, et `null`
  /// si la question est abandonnée — d'où le `bool?` plutôt qu'un `bool` :
  /// « annuler » n'est pas « tout le paquet ».
  Future<void> _chooseAdult(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final adultOnly = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adultConfirmTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.adultConfirmBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              _PoolOption(
                title: l10n.adultPoolAll,
                description: l10n.adultPoolAllDescription,
                onTap: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: 12),
              _PoolOption(
                title: l10n.adultPoolOnly,
                description: l10n.adultPoolOnlyDescription,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
        ],
      ),
    );

    if (adultOnly == null) return;
    if (!context.mounted) return;
    _choose(context, ref, Audience.adult, adultOnly: adultOnly);
  }
}

/// Une des deux réponses à la question d'âge : ce qu'on met dans le paquet.
///
/// Même traitement secondaire que partout ailleurs — fond blanc, liseré
/// corail —, pour que ces deux-là se lisent comme des actions et non comme du
/// texte cliquable perdu dans une boîte de dialogue.
class _PoolOption extends StatelessWidget {
  const _PoolOption({
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radius)),
        side: BorderSide(color: AppColors.main, width: 3),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(
          Radius.circular(AppTheme.radius),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTheme.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
