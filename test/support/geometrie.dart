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
  final raison = await chargerLesVraiesPolices();
  if (raison != null) {
    fail(
      'Les polices Roboto ne sont pas chargées, donc aucune mesure de largeur '
      'ne veut rien dire : $raison.',
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

  // Le demi-pixel vaut pour les **quatre** bords. Il ne valait que pour deux,
  // et le 27 août un `top` à -2,8e-14 a fait rougir un test de départage après
  // un simple changement de titre : `ensureVisible` et la mise en page
  // n'arrondissent pas pareil, et treize ordres de grandeur sous le pixel ne
  // sont pas un bouton hors de l'écran. Un vrai débordement se compte en
  // dizaines de pixels.
  expect(
    rect.top >= -_epsilon &&
        rect.bottom <= ecran.height + _epsilon &&
        rect.left >= -_epsilon &&
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

/// Vérifie qu'un texte est réellement centré dans sa boîte.
///
/// Mesuré sur le rendu, et non sur la propriété déclarée : sous un
/// `CrossAxisAlignment.stretch`, la boîte du paragraphe fait toute la largeur
/// que le texte soit centré ou non — `getRect` rend donc la même chose dans les
/// deux cas, et une assertion qui s'y fierait ne pourrait pas échouer.
///
/// Elle est ici et non chez les textes coupés parce que ce fichier est
/// l'outillage de la **mise en page** : `resteAtteignable` y mesure elle aussi
/// un choix, pas un défaut silencieux. Et parce qu'un centrage se perd de la
/// même façon qu'un texte se rogne — sans exception et sans trace :
/// `TexteQuiTient` n'aligne rien par défaut, et le poser sur un titre centré le
/// décale.
///
/// Elle mesure la **dernière** ligne, et seulement elle. Sur les autres, la
/// boîte de sélection inclut l'espace qui a servi de point de coupure : mesuré,
/// une première ligne parfaitement centrée sort à 15,0 px du bord gauche pour
/// 4,1 du droit, soit exactement la largeur d'une espace, et la mesure dirait
/// « décalé » d'un texte qui ne l'est pas. La dernière ligne, elle, se termine
/// sur un glyphe.
///
/// Elle exige aussi que cette ligne soit **plus étroite que la boîte**, sans
/// quoi il n'y a rien à mesurer : les deux marges valent alors zéro, que le
/// texte soit centré ou non. C'est le cas d'un texte sous un parent qui ajuste
/// sa largeur au contenu, et celui du bloc qu'un `FittedBox` compose à la
/// largeur de sa ligne la plus large. Refuser de conclure vaut mieux qu'un vert
/// gratuit.
void resteCentre(WidgetTester tester, Finder cible) {
  final para = tester.renderObject<RenderParagraph>(cible);
  final boites = para.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: para.text.toPlainText().length),
  );
  expect(boites, isNotEmpty, reason: 'le texte ne peint aucun glyphe');

  final boite = boites.last;
  final droite = para.size.width - boite.right;
  expect(
    boite.right - boite.left,
    lessThan(para.size.width - 1),
    reason:
        'la dernière ligne occupe toute la boîte : son centrage est '
        'indécidable, la mesure serait verte quoi qu il arrive',
  );
  expect(
    boite.left,
    closeTo(droite, 1),
    reason:
        'la dernière ligne est à ${boite.left.toStringAsFixed(1)} px du bord '
        'gauche et ${droite.toStringAsFixed(1)} du droit : elle est décalée',
  );
}
