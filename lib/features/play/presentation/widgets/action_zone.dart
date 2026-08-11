import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/app/theme/app_theme.dart';
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
    this.secondaire = false,
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

  /// Traitement secondaire : blanc cerné de corail, plutôt que le teal plein
  /// des actions principales.
  final bool secondaire;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actif = onPressed != null;

    // L'action secondaire est blanche, cernée du corail de la marque.
    //
    // Elle était dans le vert du personnage : deux pastels voisins, elle ne se
    // détachait pas du fond. Le blanc tranche franchement, et le liseret coloré
    // dit que c'est une action — ce qu'un aplat blanc seul ne dirait pas.
    final fond =
        background ?? (secondaire ? AppColors.card : theme.colorScheme.primary);
    final encre =
        foreground ??
        (secondaire ? AppColors.ink : theme.colorScheme.onPrimary);

    final couleur = actif ? fond : fond.withValues(alpha: 0.35);
    final texte = actif ? encre : encre.withValues(alpha: 0.4);
    final liseret = secondaire && background == null
        ? Border.all(
            color: AppColors.main.withValues(alpha: actif ? 1 : 0.35),
            width: 3,
          )
        : null;

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
        // Une hauteur plancher, et non seulement l'espace qu'on lui laisse.
        //
        // En plein jeu la zone est dans un `Expanded` et remplit la moitié de
        // l'écran ; ailleurs — « C'est parti », « Valider le tour », « Manche
        // suivante », « Rejouer » — elle se posait dans un `Padding` et
        // retombait sur la hauteur de son texte. Elle ressemblait alors à un
        // lien, pas à l'action qui fait avancer la partie.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTheme.minTouchTarget,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: couleur,
              border: liseret,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppTheme.radius),
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: texte,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
