import 'dart:async';

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
class ActionZone extends StatefulWidget {
  const ActionZone({
    required this.label,
    required this.onPressed,
    this.background,
    this.foreground,
    this.secondaire = false,
    this.urgent = false,
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

  /// La fin du tour est imminente : la zone bat.
  ///
  /// Le narrateur ne regarde pas l'anneau du chrono — il tient le téléphone à
  /// bout de bras et lit la carte. C'est la zone qu'il tape qui doit lui dire
  /// que le temps tombe, parce que c'est elle qu'il a sous les yeux.
  final bool urgent;

  @override
  State<ActionZone> createState() => _ActionZoneState();
}

class _ActionZoneState extends State<ActionZone>
    with SingleTickerProviderStateMixin {
  /// Un battement par demi-seconde : assez lent pour ne pas vibrer à l'œil,
  /// assez rapide pour se voir du coin de l'œil sans regarder.
  static const Duration _battement = Duration(milliseconds: 500);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _battement,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ActionZone old) {
    super.didUpdateWidget(old);
    if (old.urgent != widget.urgent) _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _sync() {
    if (widget.urgent) {
      // Le `TickerFuture` d'un cycle sans fin ne se résout jamais : rien à
      // attendre, et l'attendre bloquerait.
      unawaited(_pulse.repeat(reverse: true));
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actif = widget.onPressed != null;
    // Accessibilité : « réduire les animations » coupe le battement, pas
    // l'information. Le liseret reste, fixe et à pleine intensité — supprimer
    // le signal rendrait la fin de tour à nouveau invisible pour ceux qui ont
    // justement besoin qu'elle ne les surprenne pas.
    final sansMouvement = MediaQuery.disableAnimationsOf(context);

    // L'action secondaire est blanche, cernée du corail de la marque.
    //
    // Elle était dans le vert du personnage : deux pastels voisins, elle ne se
    // détachait pas du fond. Le blanc tranche franchement, et le liseret coloré
    // dit que c'est une action — ce qu'un aplat blanc seul ne dirait pas.
    final fond =
        widget.background ??
        (widget.secondaire ? AppColors.card : theme.colorScheme.primary);
    final encre =
        widget.foreground ??
        (widget.secondaire ? AppColors.ink : theme.colorScheme.onPrimary);

    final couleur = actif ? fond : fond.withValues(alpha: 0.35);
    final texte = actif ? encre : encre.withValues(alpha: 0.4);
    final liseret = widget.secondaire && widget.background == null
        ? Border.all(
            color: AppColors.main.withValues(alpha: actif ? 1 : 0.35),
            width: 3,
          )
        : null;

    return Semantics(
      button: true,
      enabled: actif,
      label: widget.label,
      excludeSemantics: true,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(
                  preAcceptSlopTolerance: ActionZone._slop,
                  postAcceptSlopTolerance: ActionZone._slop,
                ),
                (recognizer) => recognizer.onTap = widget.onPressed,
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
          child: AnimatedBuilder(
            animation: _pulse,
            // L'enfant ne dépend pas du battement : il est construit une fois
            // et repassé tel quel. Sans ça on reconstruirait le texte à chaque
            // image, sur l'écran qui se rafraîchit déjà dix fois par seconde.
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: texte,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            builder: (context, child) {
              final t = sansMouvement ? 1.0 : _pulse.value;
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: couleur,
                  // Le liseret d'urgence prime sur celui du traitement
                  // secondaire : ils occupent le même bord, et c'est la fin du
                  // tour qui compte à cet instant.
                  border: widget.urgent
                      ? Border.all(
                          color: AppColors.urgent.withValues(
                            alpha: 0.35 + 0.65 * t,
                          ),
                          width: 3 + 3 * t,
                        )
                      : liseret,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppTheme.radius),
                  ),
                ),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}
