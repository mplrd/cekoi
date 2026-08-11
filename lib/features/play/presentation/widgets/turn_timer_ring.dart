import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Le temps restant, en très grand, dans un anneau de progression.
///
/// C'est le seul signal visuel que le narrateur perçoit sans quitter la carte
/// des yeux, donc celui qui doit rester lisible en toutes circonstances.
///
/// L'anneau porte la **couleur de la manche** — c'est là que se lit « on est à
/// la deux ou à la trois ? », sans repeindre l'écran entier. Le nombre, lui,
/// reste toujours dans l'encre sombre : une manche a un accent clair (le
/// corail), et un nombre de cette teinte sur le fond pastel serait illisible
/// précisément là où il compte.
///
/// Sous [urgentBelow], le disque se remplit de rouge et le nombre passe en
/// blanc. Le renversement se voit du coin de l'œil, ce qu'un simple changement
/// de teinte ne fait pas.
class TurnTimerRing extends StatelessWidget {
  const TurnTimerRing({
    required this.remaining,
    required this.total,
    required this.accent,
    super.key,
  });

  /// Sous ce seuil, l'anneau se renverse (`SPEC.md`).
  static const Duration urgentBelow = Duration(seconds: 10);

  static const double _diameter = 132;

  final Duration remaining;
  final Duration total;

  /// La couleur de la manche en cours.
  final Color accent;

  bool get isUrgent => remaining <= urgentBelow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Arrondi vers le haut : afficher 0 alors qu'il reste 400 ms ferait
    // croire à un bug quand la dernière carte tombe juste après.
    final seconds = (remaining.inMilliseconds / 1000).ceil();

    final chiffre = isUrgent ? Colors.white : AppColors.ink;

    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: isUrgent ? AppColors.urgent : AppColors.card,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.expand(),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: total > Duration.zero
                  ? remaining.inMilliseconds / total.inMilliseconds
                  : 0,
              strokeWidth: 10,
              backgroundColor: isUrgent
                  ? Colors.white.withValues(alpha: 0.3)
                  : AppColors.ink.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                isUrgent ? Colors.white : accent,
              ),
            ),
          ),
          Text(
            l10n.gameSecondsLeft(seconds),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: chiffre,
              // Les chiffres ne doivent pas se décaler à chaque seconde.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
