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
/// **Poser un `textAlign` dès que le parent donne plus de largeur que le
/// contenu.** Le widget n'en met aucun, et sous un `CrossAxisAlignment.stretch`
/// ou dans un bouton pleine largeur, un titre centré part alors à gauche —
/// silencieusement, et pour tout le monde, y compris à taille de texte normale
/// où il n'y avait rien à corriger. C'est arrivé à « Je passe… », qui a perdu
/// son centrage en gagnant ce widget : son mot insécable est plus large que sa
/// boîte, le texte se compose donc sur deux lignes et « Je » s'est retrouvée
/// collée à gauche. Un libellé d'un seul tenant, comme « Trouvé ! », y
/// échappe : le `FittedBox` le réduit sans le replier, et [alignment] suffit.
///
/// **À ne pas poser là où l'on mesure des intrinsèques** — le titre d'un
/// `AlertDialog`, une cellule de `Table`, un `IntrinsicHeight`. Le
/// `LayoutBuilder` ci-dessous ne sait pas répondre à une mesure spéculative et
/// lève. Le cas s'est présenté sur la confirmation de suppression d'une carte.
///
/// Il en faut dans `setup/`, `settings/`, `decks/` et `play/` — titres
/// d'étapes, titres de section, étiquette d'identité du build, textes de carte,
/// libellés des zones d'action, titres de fin, noms d'équipe. C'est pour ça que
/// ce widget est dans `app/` : une feature n'en importe pas une autre. La liste
/// exhaustive n'a plus sa place ici, elle se périme à chaque usage ajouté —
/// `grep TexteQuiTient lib/` la donne à jour.
class TexteQuiTient extends StatelessWidget {
  const TexteQuiTient(
    this.texte, {
    this.style,
    this.alignment = Alignment.centerLeft,
    this.textAlign,
    super.key,
  });

  final String texte;

  /// Le style, ou celui du contexte quand il est nul — ce que fait un `Text`
  /// ordinaire. La mesure et le rendu doivent partir du **même** style, sans
  /// quoi la première décide pour un texte que le second n'affiche pas.
  final TextStyle? style;

  /// Le bord auquel le texte reste accroché quand il est réduit.
  final Alignment alignment;

  /// L'alignement du texte **dans sa boîte**, comme sur un `Text` ordinaire.
  ///
  /// Distinct d'[alignment], et les deux sont nécessaires : celui-ci décide de
  /// la position des lignes tant que le texte tient, celui-là de la position du
  /// bloc réduit quand il ne tient plus. Les oublier tous les deux passe
  /// inaperçu sous un parent qui ajuste sa largeur au contenu, et décentre en
  /// silence sous un `CrossAxisAlignment.stretch` — c'est ce qui a failli
  /// arriver au titre du départage et au nom de manche, tous deux centrés.
  final TextAlign? textAlign;

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
          return Text(texte, style: effectif, textAlign: textAlign);
        }

        // Le bloc est composé à la largeur qu'exige son mot le plus large,
        // puis ramené à celle qu'on a : le rapport est exactement celui qui
        // manquait, et le texte garde son repli sur plusieurs lignes.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: SizedBox(
            width: insecable,
            child: Text(texte, style: effectif, textAlign: textAlign),
          ),
        );
      },
    );
  }
}
