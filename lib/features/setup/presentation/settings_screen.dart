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
            // Pas de pastille en automatique : l'interrupteur juste dessous
            // porte déjà le mot, et « Auto » écrit deux fois de suite sur la
            // même ligne ressemble à un bug d'affichage.
            value: setup.cardCount == null
                ? null
                : l10n.cardCount(setup.cardCount!),
            // Le nombre d'équipes se règle à l'étape suivante : annoncer un
            // total ici reviendrait à le calculer sur deux équipes, et à
            // mentir à qui en prendra trois. L'indice dit le taux de R6.1,
            // vrai quel que soit le nombre d'équipes ; le récapitulatif, lui,
            // donne le total une fois les équipes connues.
            hint: setup.cardCount == null
                ? l10n.valueAutoExplained(GameConfig.cardsPerTeam)
                : null,
            child: _CardCount(
              value: setup.cardCount,
              onChanged: controller.setCardCount,
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
    this.hint,
  });

  final String label;

  /// La valeur courante, à côté de son libellé : c'est elle qu'on lit en
  /// poussant le curseur, pas la graduation. `null` quand un autre contrôle
  /// l'annonce déjà.
  final String? value;
  final Widget child;
  final String? hint;

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
          if (hint != null)
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.inkSoft,
              ),
            ),
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

/// Le nombre de cartes : un interrupteur *Auto*, et le curseur s'il est coupé.
///
/// R6.1 fixe le volume à douze cartes par équipe, ce qui reste le bon choix
/// dans la quasi-totalité des parties — d'où l'automatique en tête, et un
/// curseur qui n'apparaît que si on le refuse.
class _CardCount extends StatelessWidget {
  const _CardCount({required this.value, required this.onChanged});

  /// `null` vaut automatique.
  final int? value;
  final ValueChanged<int?> onChanged;

  /// Au-delà, le paquet dépasse ce qu'une tablée finit en trois manches.
  static const int _max = 80;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auto = value == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.valueAuto,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.ink,
                ),
              ),
            ),
            Switch(
              value: auto,
              onChanged: (actif) =>
                  onChanged(actif ? null : GameConfig.manualCardCountStart),
            ),
          ],
        ),
        if (!auto)
          _Slider(
            value: value!.toDouble(),
            min: GameConfig.minimumCardCount.toDouble(),
            max: _max.toDouble(),
            pas: 4,
            onChanged: (count) => onChanged(count.round()),
          ),
      ],
    );
  }
}
