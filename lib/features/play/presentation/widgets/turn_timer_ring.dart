import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Le temps restant, en très grand, dans un anneau de progression.
///
/// C'est le seul signal visuel que le narrateur perçoit sans quitter la carte
/// des yeux, donc celui qui doit rester lisible en toutes circonstances.
///
/// Ses couleurs viennent de l'écran, pas du thème : depuis que chaque manche a
/// son fond, une couleur fixe se noyait dedans — le rouge de l'urgence était
/// invisible sur le rouge de la manche 3, précisément quand il compte le plus.
/// L'urgence se marque donc par un **renversement** : l'anneau se remplit de
/// l'encre de la manche et le nombre passe en négatif dessus. Le contraste est
/// le même quel que soit le fond.
class TurnTimerRing extends StatelessWidget {
  const TurnTimerRing({
    required this.remaining,
    required this.total,
    required this.ink,
    required this.ground,
    super.key,
  });

  /// Sous ce seuil, l'anneau se renverse (`SPEC.md`).
  static const Duration urgentBelow = Duration(seconds: 10);

  static const double _diameter = 132;

  final Duration remaining;
  final Duration total;

  /// L'encre de la manche en cours.
  final Color ink;

  /// Le fond de la manche, sur lequel le nombre se détache une fois renversé.
  final Color ground;

  bool get isUrgent => remaining <= urgentBelow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Arrondi vers le haut : afficher 0 alors qu'il reste 400 ms ferait
    // croire à un bug quand la dernière carte tombe juste après.
    final seconds = (remaining.inMilliseconds / 1000).ceil();

    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isUrgent)
            DecoratedBox(
              decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
              child: const SizedBox.expand(),
            ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: total > Duration.zero
                  ? remaining.inMilliseconds / total.inMilliseconds
                  : 0,
              strokeWidth: 10,
              backgroundColor: ink.withValues(alpha: 0.22),
              valueColor: AlwaysStoppedAnimation<Color>(
                isUrgent ? ground : ink,
              ),
            ),
          ),
          Text(
            l10n.gameSecondsLeft(seconds),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isUrgent ? ground : ink,
              // Les chiffres ne doivent pas se décaler à chaque seconde.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
