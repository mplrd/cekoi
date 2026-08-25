import 'package:flutter/material.dart';

/// Un texte ramené dans sa largeur quand un seul de ses mots n'y tient plus.
///
/// Le repli sur plusieurs lignes ne peut rien pour un mot plus large que la
/// ligne : il n'a pas de point de coupure, donc il se fait rogner — sans
/// exception, sans trace, et seulement chez qui a agrandi le texte dans les
/// réglages du système, c'est-à-dire chez qui en a besoin.
///
/// Borner l'agrandissement à une constante ne suffit pas : le problème est un
/// **rapport**, pas un seuil. Ici on ne réduit que quand ça dépasse, et
/// d'autant qu'il faut — le réglage de l'utilisateur est respecté partout où
/// il tient, et sur un écran plus large rien n'est raboté.
///
/// Deux endroits en ont besoin, et c'est pour ça que ce widget est dans
/// `app/` : le titre des étapes de configuration, et l'étiquette d'identité
/// du build, dont l'empreinte et la date sont des mots insécables. Une feature
/// n'en importe pas une autre.
class TexteQuiTient extends StatelessWidget {
  const TexteQuiTient(
    this.texte, {
    this.style,
    this.alignment = Alignment.centerLeft,
    super.key,
  });

  final String texte;

  /// Le style, ou celui du contexte quand il est nul — ce que fait un `Text`
  /// ordinaire. La mesure et le rendu doivent partir du **même** style, sans
  /// quoi la première décide pour un texte que le second n'affiche pas.
  final TextStyle? style;

  /// Le bord auquel le texte reste accroché quand il est réduit.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final effectif = style ?? DefaultTextStyle.of(context).style;

    return LayoutBuilder(
      builder: (context, contraintes) {
        final peintre = TextPainter(
          text: TextSpan(text: texte, style: effectif),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final insecable = peintre.minIntrinsicWidth;
        peintre.dispose();

        if (insecable <= contraintes.maxWidth) {
          return Text(texte, style: effectif);
        }

        // Le bloc est composé à la largeur qu'exige son mot le plus large,
        // puis ramené à celle qu'on a : le rapport est exactement celui qui
        // manquait, et le texte garde son repli sur plusieurs lignes.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: SizedBox(
            width: insecable,
            child: Text(texte, style: effectif),
          ),
        );
      },
    );
  }
}
