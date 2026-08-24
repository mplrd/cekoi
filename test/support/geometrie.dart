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

/// Pose une taille d'écran et un agrandissement de texte pour un test.
///
/// L'application ne borne pas `textScaler` : le réglage système s'applique en
/// entier, et ceux qui l'augmentent sont justement ceux qui en ont besoin.
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
/// ce fichier même : le tableau des scores y paraissait rogné à taille de texte
/// normale, alors qu'il ne l'est qu'à partir de ×1,8. `tool/apercus/` chargeait
/// les vraies polices depuis toujours, et son commentaire disait pourquoi.
///
/// D'où ce garde-fou : les mesures **refusent de conclure** sans les vraies
/// polices, plutôt que de rendre un verdict qui ne veut rien dire. À appeler
/// dans `setUpAll`, avant toute mesure.
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
/// La mesure est le mot **insécable** le plus large : c'est ce qu'un texte ne
/// peut pas replier. Si sa boîte est plus étroite que lui, il est rogné, et
/// rien ne le signale — c'est ainsi qu'un score à deux chiffres perdait son
/// second.
///
/// Les textes qui déclarent `TextOverflow.ellipsis` ou `fade` sont ignorés :
/// là, la coupe est un choix, et elle laisse une marque visible. C'est toute
/// la différence entre céder et disparaître.
void aucunTexteRogne(WidgetTester tester) {
  final rognes = <String>[];

  for (final paragraphe
      in tester.allRenderObjects.whereType<RenderParagraph>()) {
    final delibere =
        paragraphe.overflow == TextOverflow.ellipsis ||
        paragraphe.overflow == TextOverflow.fade;
    if (delibere) continue;

    final insecable = paragraphe.getMinIntrinsicWidth(double.infinity);
    if (paragraphe.size.width + _epsilon < insecable) {
      final texte = paragraphe.text.toPlainText();
      rognes.add(
        '« $texte » : ${paragraphe.size.width.toStringAsFixed(1)} px de large '
        'pour ${insecable.toStringAsFixed(1)} px nécessaires',
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
Future<void> resteAtteignable(WidgetTester tester, Finder cible) async {
  expect(cible, findsOneWidget, reason: "la cible a disparu de l'écran");
  await tester.ensureVisible(cible);

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

  // Et quelque chose doit répondre en son centre : un widget dans l'écran mais
  // recouvert n'est pas atteignable non plus.
  expect(
    tester.hitTestOnBinding(rect.center).path,
    isNotEmpty,
    reason: 'rien ne répond au centre de la cible',
  );
}
