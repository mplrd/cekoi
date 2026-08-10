import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Le temps restant, en très grand, dans un anneau de progression.
///
/// Les dix dernières secondes passent en rouge : c'est le seul signal visuel
/// que le narrateur perçoit sans quitter la carte des yeux.
class TurnTimerRing extends StatelessWidget {
  const TurnTimerRing({
    required this.remaining,
    required this.total,
    super.key,
  });

  /// Sous ce seuil, l'anneau et le nombre passent en rouge (`SPEC.md`).
  static const Duration urgentBelow = Duration(seconds: 10);

  static const double _diameter = 132;

  final Duration remaining;
  final Duration total;

  bool get isUrgent => remaining <= urgentBelow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = isUrgent ? AppColors.urgent : theme.colorScheme.primary;

    // Arrondi vers le haut : afficher 0 alors qu'il reste 400 ms ferait
    // croire à un bug quand la dernière carte tombe juste après.
    final seconds = (remaining.inMilliseconds / 1000).ceil();

    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: total > Duration.zero
                  ? remaining.inMilliseconds / total.inMilliseconds
                  : 0,
              strokeWidth: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            l10n.gameSecondsLeft(seconds),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              // Les chiffres ne doivent pas se décaler à chaque seconde.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
