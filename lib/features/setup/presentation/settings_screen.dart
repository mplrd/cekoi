import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/widgets/choice_tile.dart';
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
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final setup = ref.watch(setupControllerProvider);
    final controller = ref.read(setupControllerProvider.notifier);

    return SetupScaffold(
      step: 3,
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
            chips: [
              for (final preset in GameConfig.turnDurationPresets)
                _Choice(
                  label: l10n.valueSeconds(preset.inSeconds),
                  isSelected: setup.turnDuration == preset,
                  onSelected: () => controller.setTurnDuration(preset),
                ),
            ],
            freeEntry: _DurationSlider(
              value: setup.turnDuration,
              onChanged: controller.setTurnDuration,
            ),
          ),
          _Setting(
            label: l10n.settingCardCount,
            chips: [
              _Choice(
                label: l10n.valueAuto,
                isSelected: setup.cardCount == null,
                onSelected: () => controller.setCardCount(null),
              ),
              for (final preset in GameConfig.cardCountPresets)
                _Choice(
                  label: '$preset',
                  isSelected: setup.cardCount == preset,
                  onSelected: () => controller.setCardCount(preset),
                ),
            ],
            // Le nombre d'équipes se règle à l'étape suivante : annoncer un
            // total ici reviendrait à le calculer sur deux équipes, et à
            // mentir à qui en prendra trois. L'indice dit le taux de R6.1,
            // vrai quel que soit le nombre d'équipes ; le récapitulatif, lui,
            // donne le total une fois les équipes connues.
            hint: setup.cardCount == null
                ? l10n.valueAutoExplained(GameConfig.cardsPerTeam)
                : null,
            freeEntry: _CardCountSlider(
              value: setup.cardCount ?? setup.resolvedCardCount,
              onChanged: controller.setCardCount,
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice {
  const _Choice({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
}

class _Setting extends StatelessWidget {
  const _Setting({
    required this.label,
    required this.chips,
    this.hint,
    this.freeEntry,
  });

  final String label;
  final List<_Choice> chips;
  final String? hint;

  /// Saisie libre, repliée : elle ne doit pas encombrer le cas courant.
  final Widget? freeEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final choice in chips)
                ChoiceTile(
                  label: choice.label,
                  selected: choice.isSelected,
                  onTap: choice.onSelected,
                ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint!, style: theme.textTheme.bodySmall),
          ],
          ?freeEntry,
        ],
      ),
    );
  }
}

class _DurationSlider extends StatelessWidget {
  const _DurationSlider({required this.value, required this.onChanged});

  final Duration value;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final min = GameConfig.minimumTurnDuration.inSeconds;
    final max = GameConfig.maximumTurnDuration.inSeconds;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(l10n.valueSeconds(value.inSeconds)),
      children: [
        Slider(
          value: value.inSeconds.toDouble().clamp(
            min.toDouble(),
            max.toDouble(),
          ),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min) ~/ 5,
          label: l10n.valueSeconds(value.inSeconds),
          onChanged: (seconds) => onChanged(Duration(seconds: seconds.round())),
        ),
      ],
    );
  }
}

class _CardCountSlider extends StatelessWidget {
  const _CardCountSlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const min = GameConfig.minimumCardCount;
    const max = 80;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(l10n.cardCount(value)),
      children: [
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min) ~/ 4,
          label: '$value',
          onChanged: (count) => onChanged(count.round()),
        ),
      ],
    );
  }
}
