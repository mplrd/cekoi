import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Le texte d'une carte, composé à la plus grande taille dont le repli tient.
///
/// `FittedBox` seul ne suffit pas, et c'est contre-intuitif : il mesure son
/// enfant **sans borne de largeur**. Le paragraphe n'a donc jamais de raison de
/// replier — il se compose sur une ligne unique, aussi longue qu'il faut, et
/// c'est cette ligne-là que `scaleDown` écrase. Mesuré le 26 août sur un 360 :
/// « Chat » sortait à 60 px, mais une phrase de quarante caractères à 15,5 et
/// une de soixante à 10,2, toujours sur une seule ligne, dans une carte haute
/// et vide.
///
/// Donner la largeur au texte suffit à le faire replier, mais pas à bien
/// l'afficher : les coupures sont alors calculées à 60 px — sept lignes de deux
/// mots — puis le bloc entier est réduit, ce qui donne une colonne étroite au
/// milieu d'une carte large. Mesuré aussi : 26,6 px sur 123 px de large, là où
/// la carte en offre 272.
///
/// On cherche donc la **taille**, pas l'échelle : la plus grande dont le repli
/// tient dans la boîte, par dichotomie. Jusqu'à dix mises en page de paragraphe
/// par construction — une pour la taille demandée, une pour le plancher, sept
/// pour la recherche, une pour le mot le plus large. C'est pour ça que
/// `_CardZone` est passée en `const` avec deux `select` : sans ça, l'écran de
/// jeu la reconstruisait dix fois par seconde au rythme du chrono, et cette
/// dizaine de mesures avec.
///
/// Le `math.max` couvre le seul cas où replier ne peut rien : un mot unique
/// plus large que la boîte. La saisie d'une carte personnalisée l'autorise
/// encore — soixante caractères sans une espace — et un mot n'a aucun point de
/// coupure. On compose alors à la largeur du mot et `scaleDown` réduit, ce qui
/// donne le comportement d'avant : illisible, mais entier. Rogner serait pire.
///
/// **À ne pas poser là où l'on mesure des intrinsèques** — même réserve que
/// `TexteQuiTient` : le `LayoutBuilder` ne sait pas répondre à une mesure
/// spéculative et lève.
class TexteDeCarte extends StatelessWidget {
  const TexteDeCarte(this.texte, {required this.style, super.key});

  final String texte;

  /// La mesure et le rendu partent du **même** style, sans quoi la première
  /// décide pour un texte que le second n'affiche pas.
  final TextStyle? style;

  /// En dessous, ce n'est plus une carte qu'on lit à bout de bras. La borne
  /// n'est pas une garantie de lisibilité : c'est le plancher sous lequel la
  /// recherche cesse de chercher, et `scaleDown` reprend la main.
  static const double tailleMinimale = 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final echelle = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);

        // Le style à mesurer est celui que `Text` composera, pas celui qu'on
        // reçoit : `Text` fusionne d'abord le `DefaultTextStyle` ambiant. Les
        // deux appelants passent un style de `textTheme`, que la géométrie
        // Material pose déjà en `inherit: false` — la fusion ne fait donc rien
        // pour eux, et `Text` prend la même branche. Elle protège l'appelant
        // qui passerait un style héritant, et c'est tout ce qu'elle fait.
        final ambiant = DefaultTextStyle.of(context);
        final effectif = ambiant.style.merge(style).copyWith(inherit: false);
        final demandee = effectif.fontSize;

        // `Text` lit le comportement de hauteur à deux endroits ; la mesure
        // doit lire les mêmes, sinon elle décide pour un texte que le rendu
        // n'affiche pas.
        final hauteurDeLigne =
            ambiant.textHeightBehavior ??
            DefaultTextHeightBehavior.maybeOf(context);

        double hauteurA(double taille, double largeur) {
          final peintre = TextPainter(
            text: TextSpan(
              text: texte,
              style: effectif.copyWith(fontSize: taille),
            ),
            textDirection: direction,
            textScaler: echelle,
            textAlign: TextAlign.center,
            textHeightBehavior: hauteurDeLigne,
          )..layout(maxWidth: largeur);
          final hauteur = peintre.height;
          peintre.dispose();
          return hauteur;
        }

        double motLePlusLarge(double taille) {
          final peintre = TextPainter(
            text: TextSpan(
              text: texte,
              style: effectif.copyWith(fontSize: taille),
            ),
            textDirection: direction,
            textScaler: echelle,
            textHeightBehavior: hauteurDeLigne,
          )..layout();
          final large = peintre.minIntrinsicWidth;
          peintre.dispose();
          return large;
        }

        // Une largeur non bornée n'arrive pas dans le jeu — la carte est
        // toujours posée dans une boîte — mais un `Row` ou un défilement
        // horizontal en donnerait une, et `SizedBox(width: infinity)` lève.
        //
        // Une **hauteur** non bornée saute la recherche un peu plus bas : sans
        // plafond, la taille demandée tient toujours, et le texte replie
        // sur autant de lignes qu'il faut. C'est le bon comportement dans un
        // défilement vertical, et c'est celui qu'on obtient sans rien faire.
        final cible = contraintes.hasBoundedWidth
            ? contraintes.maxWidth
            : motLePlusLarge(demandee ?? 14);

        var taille = demandee;
        if (taille != null &&
            contraintes.hasBoundedHeight &&
            hauteurA(taille, cible) > contraintes.maxHeight) {
          // Dichotomie entre le plancher et la taille demandée. La hauteur
          // décroît avec la taille, donc l'invariant tient : `bas` tient
          // toujours, `haut` ne tient jamais.
          //
          // Le `math.min` garde le plancher sous le plafond : un appelant qui
          // demanderait 12 px verrait sinon son texte composé à 16, plus gros
          // que ce qu'il a demandé. Inatteignable avec les deux appelants
          // d'aujourd'hui — 60 et 45 — mais une borne qui inverse l'ordre de
          // ses bornes est un piège qui attend.
          var bas = math.min(tailleMinimale, taille);
          var haut = taille;
          if (hauteurA(bas, cible) <= contraintes.maxHeight) {
            for (var i = 0; i < 7; i++) {
              final milieu = (bas + haut) / 2;
              if (hauteurA(milieu, cible) <= contraintes.maxHeight) {
                bas = milieu;
              } else {
                haut = milieu;
              }
            }
            taille = bas;
          } else {
            // Même au plancher le repli ne tient pas : on compose au plancher
            // et `scaleDown` finit le travail plutôt que de laisser déborder.
            taille = tailleMinimale;
          }
        }

        // Le mot le plus large se mesure **à la taille retenue**, et non à
        // celle qu'on demandait : « Retrouver » réclame 278,7 px à 60 px de
        // corps — plus que la carte n'en offre — mais 181 à la taille de 39 que
        // le repli permet. Mesurer avant de choisir faisait donc élargir la
        // boîte pour rien, et `scaleDown` reprenait 2,4 % au passage.
        final largeur = math.max(
          cible,
          motLePlusLarge(taille ?? demandee ?? 14),
        );

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: largeur,
            child: Text(
              texte,
              textAlign: TextAlign.center,
              style: taille == null
                  ? effectif
                  : effectif.copyWith(fontSize: taille),
            ),
          ),
        );
      },
    );
  }
}
