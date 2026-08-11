import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Une zone d'action de l'écran de jeu — *Trouvé !* ou *Je passe…*.
///
/// Ressemble à un bouton, mais **ne se laisse pas annuler par un doigt qui
/// bouge**. Un `TapGestureRecognizer` ordinaire rejette le tap dès que le
/// pointeur dérive de 18 pixels avant que le geste soit accepté ; or on tape
/// ici à bout de bras, sans regarder l'écran, souvent debout — le pouce roule
/// de vingt à quarante pixels sans qu'on s'en aperçoive, et l'action est
/// perdue en silence. Retour de partie : « j'ai des taps sur Trouvé qui
/// passent pas ».
///
/// La tolérance monte donc à [_slop]. Elle reste finie : un geste qui part
/// franchement ailleurs n'est pas un tap, et doit continuer à être ignoré.
class ActionZone extends StatelessWidget {
  const ActionZone({
    required this.label,
    required this.onPressed,
    this.background,
    this.foreground,
    this.outlined = false,
    super.key,
  });

  /// Assez large pour absorber un pouce qui roule, assez court pour qu'un
  /// geste traversant l'écran reste un glissement et non un tap.
  static const double _slop = 64;

  final String label;

  /// `null` désactive la zone, comme sur un bouton ordinaire.
  final VoidCallback? onPressed;

  final Color? background;
  final Color? foreground;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actif = onPressed != null;

    final fond = outlined
        ? Colors.transparent
        : (background ?? theme.colorScheme.primary);
    final encre =
        foreground ??
        (outlined ? theme.colorScheme.onSurface : theme.colorScheme.onPrimary);

    // Sur le fond coloré d'une manche, un contour tiré du thème disparaît :
    // la bordure et le texte prennent la même encre que le reste de l'écran.
    final couleur = actif
        ? fond
        : (outlined ? Colors.transparent : encre.withValues(alpha: 0.15));
    final texte = actif ? encre : encre.withValues(alpha: 0.4);

    return Semantics(
      button: true,
      enabled: actif,
      label: label,
      excludeSemantics: true,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(
                  preAcceptSlopTolerance: _slop,
                  postAcceptSlopTolerance: _slop,
                ),
                (recognizer) => recognizer.onTap = onPressed,
              ),
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: outlined
                ? Border.all(color: texte.withValues(alpha: 0.55), width: 2)
                : null,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: texte,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
