import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'polices.dart';

/// Outils de mesure pour les tests de mise en page.
///
/// Un débordement de `RenderFlex` remonte comme exception et se voit avec
/// `expect(tester.takeException(), isNull)`. Mais tout ne déborde pas
/// bruyamment : un texte trop large pour sa boîte est simplement **rogné**, et
/// l'écran reste vert. C'est le pire des deux, parce qu'il ne se découvre
/// qu'en regardant l'écran avec le bon réglage système.
///
/// Ce que ces outils **ne** voient **pas**, et qu'il faut donc couvrir
/// autrement : un enfant peint hors de son parent. `RenderTable` écrête sa
/// propre boîte et peint ses cellules par-dessus ; les cellules, elles,
/// obtiennent la place qu'elles demandent, donc `aucunTexteRogne` les trouve
/// saines. Le tableau des scores a son propre contrôle pour ça.

/// Pose une taille d'écran et un agrandissement de texte pour un test.
///
/// Le réglage système s'applique en entier. Un seul endroit y touche, et
/// encore : le titre des étapes de configuration est **ramené** dans la
/// largeur quand un de ses mots n'y tient plus, et seulement d'autant qu'il
/// faut. Ce n'est pas une question de lisibilité — un mot plus large que
/// l'écran est coupé quoi qu'il arrive.
void poserEcran(
  WidgetTester tester, {
  required Size taille,
  double echelleTexte = 1,
}) {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  tester.platformDispatcher.textScaleFactorTestValue = echelleTexte;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Un demi-pixel de marge : les intrinsèques et la mise en page n'arrondissent
/// pas toujours pareil, et un écart sous le pixel ne se voit pas.
const _epsilon = 0.5;

/// Mesurer en Ahem ne mesure rien.
///
/// La police de secours de `flutter test` rend chaque glyphe comme un carré de
/// la taille du corps. Mesuré : « 36 » réclame 45,9 px en Roboto à 39,6 points
/// de corps, et 79,2 px en Ahem — un rapport de 1,7. Une assertion de largeur
/// qui tourne dessus invente donc des débordements, et l'a fait le 24 août sur
/// ce fichier même : le tableau des scores y paraissait rogné à taille de
/// texte normale, alors que son seuil réel est ×1,6. `tool/apercus/` chargeait
/// les vraies polices depuis toujours, et son commentaire disait pourquoi.
///
/// Réserve à garder en tête : le thème prend la police **de la plateforme**.
/// Ces mesures valent donc pour Roboto, c'est-à-dire pour Android. iOS pousse
/// l'agrandissement plus loin — AX5 vaut ×3,1 — et n'a jamais été exercé.
Future<void> exigerLesVraiesPolices() async {
  final charge = await chargerLesVraiesPolices();
  if (!charge) {
    fail(
      'Les polices Roboto sont introuvables : aucune mesure de largeur ne '
      'veut rien dire en Ahem. Vérifier FLUTTER_ROOT et '
      r'$FLUTTER_ROOT/bin/cache/artifacts/material_fonts.',
    );
  }
}

/// Vérifie qu'aucun texte n'est coupé sans que le code l'ait demandé.
///
/// Trois mesures, parce qu'un texte se perd de trois façons :
///
/// * **en largeur** — sa boîte est plus étroite que son mot insécable le plus
///   large, celui qu'il ne peut pas replier ;
/// * **en hauteur** — sa boîte est plus courte que ce que le texte demande à
///   cette largeur, donc les dernières lignes tombent ;
/// * **jusqu'à disparaître** — un texte qui déclare `ellipsis` a le droit de
///   céder, mais pas de tomber à zéro : il ne resterait alors rien, pas même
///   les points de suspension qui disent qu'il manque quelque chose.
///
/// Les deux premières ignorent les textes qui déclarent `ellipsis` ou `fade` :
/// là, la coupe est un choix, et elle laisse une marque visible. C'est toute
/// la différence entre céder et disparaître.
void aucunTexteRogne(WidgetTester tester) {
  final rognes = <String>[];

  for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
    final texte = p.text.toPlainText();
    final delibere =
        p.overflow == TextOverflow.ellipsis || p.overflow == TextOverflow.fade;

    if (delibere) {
      if (p.size.width <= 0) {
        rognes.add('« $texte » : sa boîte fait 0 px, il ne reste rien du tout');
      }
      continue;
    }

    final insecable = p.getMinIntrinsicWidth(double.infinity);
    if (p.size.width + _epsilon < insecable) {
      rognes.add(
        '« $texte » : ${p.size.width.toStringAsFixed(1)} px de large pour '
        '${insecable.toStringAsFixed(1)} px nécessaires',
      );
      continue;
    }

    final voulue = p.getMaxIntrinsicHeight(p.size.width);
    if (p.size.height + _epsilon < voulue) {
      rognes.add(
        '« $texte » : ${p.size.height.toStringAsFixed(1)} px de haut pour '
        '${voulue.toStringAsFixed(1)} px nécessaires à cette largeur',
      );
    }
  }

  expect(
    rognes,
    isEmpty,
    reason:
        'Des textes sont rognés sans le déclarer :\n  ${rognes.join('\n  ')}',
  );
}

/// Vérifie qu'une cible reste réellement atteignable.
///
/// « Tenir » ne veut pas dire qu'aucun bandeau ne raye l'écran : ça veut dire
/// qu'on peut encore taper dessus. Une action poussée sous le bord par un
/// en-tête qui a grossi est perdue, même si rien n'a levé d'exception.
///
/// Le test du toucher cherche **la cible** dans le chemin, et non un chemin
/// non vide : `RenderView` s'y ajoute toujours, si bien qu'un tap au milieu
/// d'un écran vide rend vingt-huit entrées. La première version de cette
/// fonction se contentait de ça, ne pouvait donc pas échouer, et laissait
/// passer un bouton entièrement recouvert.
Future<void> resteAtteignable(WidgetTester tester, Finder cible) async {
  expect(cible, findsOneWidget, reason: "la cible a disparu de l'écran");
  await tester.ensureVisible(cible);
  await tester.pump();

  final rect = tester.getRect(cible);
  final ecran = tester.view.physicalSize / tester.view.devicePixelRatio;

  expect(
    rect.top >= 0 &&
        rect.bottom <= ecran.height + _epsilon &&
        rect.left >= 0 &&
        rect.right <= ecran.width + _epsilon,
    isTrue,
    reason:
        "la cible est hors de l'écran : $rect dans "
        '${ecran.width.toStringAsFixed(0)}×${ecran.height.toStringAsFixed(0)}',
  );

  final vise = tester.renderObject(cible);
  final chemin = tester.hitTestOnBinding(rect.center).path;
  expect(
    chemin.any((entree) => identical(entree.target, vise)),
    isTrue,
    reason: 'la cible est visible, mais quelque chose la recouvre',
  );
}
