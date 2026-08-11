import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/setup_steps.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_scaffold.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Étape 3 — chrono et volume du paquet (R6).
///
/// Les défauts dépendent du mode choisi à l'étape 1 : dans la majorité des
/// cas, cet écran se traverse sans y toucher.
///
/// Le nombre de manches n'y figure pas : une partie, c'est les trois (R2.2).
///
/// Des curseurs, et rien d'autre. Chaque réglage avait une rangée de valeurs
/// prédéfinies **et** un curseur replié dessous : deux commandes pour un même
/// nombre, dont l'une débordait sur deux lignes. Un curseur dit mieux qu'une
/// valeur est continue, et tient sur une ligne quelle que soit la plage.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final setup = ref.watch(setupControllerProvider);
    final controller = ref.read(setupControllerProvider.notifier);

    return SetupScaffold(
      step: SetupStep.settings,
      title: l10n.setupSettingsTitle,
      footer: FilledButton(
        onPressed: () => context.push(AppRoutes.setupTeams),
        child: Text(l10n.actionContinue),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        children: [
          _Setting(
            label: l10n.settingTurnDuration,
            value: l10n.valueSeconds(setup.turnDuration.inSeconds),
            child: _Slider(
              value: setup.turnDuration.inSeconds.toDouble(),
              min: GameConfig.minimumTurnDuration.inSeconds.toDouble(),
              max: GameConfig.maximumTurnDuration.inSeconds.toDouble(),
              pas: 5,
              onChanged: (s) =>
                  controller.setTurnDuration(Duration(seconds: s.round())),
            ),
          ),
          const SizedBox(height: 8),
          _Setting(
            label: l10n.settingCardCount,
            value: l10n.cardCount(setup.cardCount),
            child: _Slider(
              value: setup.cardCount.toDouble(),
              min: GameConfig.minimumCardCount.toDouble(),
              max: GameConfig.maximumCardCount.toDouble(),
              pas: 2,
              onChanged: (count) => controller.setCardCount(count.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Setting extends StatelessWidget {
  const _Setting({
    required this.label,
    required this.value,
    required this.child,
  });

  final String label;

  /// La valeur courante, à côté de son libellé : c'est elle qu'on lit en
  /// poussant le curseur, pas la graduation. `null` quand un autre contrôle
  /// l'annonce déjà.
  final String? value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppTheme.radius),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Text(
                      value!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.deep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

/// Un curseur, aux dimensions du pouce.
class _Slider extends StatelessWidget {
  const _Slider({
    required this.value,
    required this.min,
    required this.max,
    required this.pas,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;

  /// L'écart entre deux crans, dans l'unité du réglage.
  final int pas;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 10,
        inactiveTrackColor: AppColors.card,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 26),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: ((max - min) / pas).round(),
        onChanged: onChanged,
      ),
    );
  }
}
