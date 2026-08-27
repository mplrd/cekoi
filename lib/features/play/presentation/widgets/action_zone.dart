import 'dart:async';

import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/app/widgets/texte_qui_tient.dart';
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

  /// De combien le fond se déplace vers [pulseTarget] au sommet du battement.
  ///
  /// Le seul endroit de l'application qui descende sous 4,5:1 de contraste :
  /// au sommet, le libellé blanc sur le teal éclairci rend 4,0:1. C'est tenu
  /// pour du grand texte, qui est ce que la zone porte — 22 points en `w800` —
  /// et `action_zone_test.dart` le vérifie. **Monter cette valeur casse
  /// l'accessibilité** : à 0,5 le même contraste tombe à 2,9:1, sous le seuil.
  static const double pulseAmount = 0.3;

  /// Vers quoi la zone bat.
  ///
  /// Une couleur de la même famille, et jamais [AppColors.urgent] : le teal
  /// des actions principales tiré vers le rouge passe par un brun sale, et à
  /// mi-course c'est exactement là qu'il se trouve.
  ///
  /// Le sens dépend de la zone. Le teal, sombre, s'éclaircit vers la sauge ;
  /// le blanc de l'action secondaire se teinte de corail.
  static Color pulseTarget(Color fond) =>
      fond.computeLuminance() > 0.4 ? AppColors.main : AppColors.secondary;

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

  /// Et non `initState` : `_sync` consulte `MediaQuery`, qui n'est pas encore
  /// disponible à l'initialisation. Appelé aussi quand le réglage
  /// d'accessibilité change en cours de partie.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    // Rien à animer quand le battement est désactivé, ni quand la zone est
    // morte. Sans ce test, l'animation tournerait à vide soixante fois par
    // seconde : « réduire les animations » n'aurait réduit que le rendu, pas
    // le travail.
    if (widget.urgent && widget.onPressed != null && !_sansMouvement) {
      // Le `TickerFuture` d'un cycle sans fin ne se résout jamais : rien à
      // attendre, et l'attendre bloquerait.
      unawaited(_pulse.repeat(reverse: true));
    } else {
      _pulse
        ..stop()
        ..value = _sansMouvement ? 1 : 0;
    }
  }

  bool get _sansMouvement => MediaQuery.disableAnimationsOf(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actif = widget.onPressed != null;

    // Une zone morte ne bat pas.
    //
    // R3.4 désactive *Passer* sur la dernière carte du paquet : sans ce test,
    // c'est elle qui clignerait en rouge vif dans les trois dernières
    // secondes, soit l'élément le plus criard de l'écran, pour demander au
    // narrateur de taper là où rien ne se passe.
    final bat = widget.urgent && actif;

    // Accessibilité : « réduire les animations » coupe le battement, pas
    // l'information. Le liseret reste, fixe et à pleine intensité — supprimer
    // le signal rendrait la fin de tour à nouveau invisible pour ceux qui ont
    // justement besoin qu'elle ne les surprenne pas.

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

    // Calculée une fois par construction et non dans le `builder` : elle ne
    // dépend pas du battement, et le `builder` tourne soixante fois par
    // seconde. Même raison que l'enfant sorti du `AnimatedBuilder` plus bas.
    final sommet = bat ? ActionZone.pulseTarget(couleur) : null;
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
            // L'enfant ne dépend pas du battement : le `builder` le reçoit tel
            // quel au lieu de le reconstruire à chaque image. Il est bien
            // reconstruit dix fois par seconde par l'écran de jeu, ce qui est
            // le rythme du chrono ; ce qu'on évite ici, ce sont les soixante
            // images d'animation qui viendraient par-dessus.
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                // Trouvé en instrumentant la face de carte : à ×2 sur un 360,
                // « Trouvé » réclame 161 px et « passe… » 151 dans une boîte
                // qui en fait 134. Le libellé était rogné sans qu'aucune
                // exception ne le dise, sur les deux zones qu'on tape sans
                // regarder. Replier ne suffit pas — c'est un mot seul qui
                // dépasse —, donc on le ramène, et seulement d'autant qu'il
                // faut.
                //
                // `alignment` ne remplace pas le `textAlign: TextAlign.center`
                // qui était ici avant : le premier place le bloc réduit, le
                // second place les lignes dans leur boîte. Le perdre a suffi à
                // décaler les libellés à gauche dès qu'ils replient, dans un
                // bouton qui fait toute la largeur.
                child: TexteQuiTient(
                  widget.label,
                  alignment: Alignment.center,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: texte,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            builder: (context, child) {
              final t = _sansMouvement ? 1.0 : _pulse.value;
              return DecoratedBox(
                decoration: BoxDecoration(
                  // Le battement se joue sur toute la surface.
                  //
                  // Il a d'abord été un liseret, et c'était deux fautes : à
                  // bout de bras, six pixels de bordure ne se voient pas, et
                  // le rouge d'urgence posé sur le teal des actions était
                  // franchement laid. La moitié basse de l'écran qui
                  // s'éclaircit deux fois par seconde, elle, ne se rate pas.
                  color: bat
                      ? Color.lerp(couleur, sommet, ActionZone.pulseAmount * t)
                      : couleur,
                  border: liseret,
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
