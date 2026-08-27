import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/configuration.dart';
import '../../support/geometrie.dart';

/// L'étape des équipes, mesurée.
///
/// `setup_flow_test.dart` la traverse déjà, mais en contenu, et sa géométrie
/// s'arrête à ×1,3 — en police Ahem, qui ne mesure rien.
///
/// Ce qui l'a fait écrire : le compteur d'équipes est un `SizedBox(width: 64)`
/// autour d'un nombre. Un nombre n'a **aucun** point de coupure, donc il est
/// écrêté sans exception ni trace. Mesuré avant correction, « 10 » réclamait
/// 66,7 px à ×1,6, 83,4 à ×2 et 129,3 à ×3,1 — à ×3,1, la moitié du zéro
/// disparaissait.
///
/// ×1,6 n'est pas un cas extrême : c'est un cran ordinaire du réglage Android.
/// Et R8.1 promet l'interface utilisable jusqu'à dix équipes — c'est
/// précisément à dix que le nombre passe à deux chiffres.
///
/// **Ce fichier mesure toute la pile, pas seulement l'étape des équipes.** Le
/// routeur garde montées les routes traversées : l'accueil, le mode et les
/// réglages sont encore dans l'arbre quand `aucunTexteRogne` passe. C'est
/// délibéré — c'est comme ça que les défauts de ces trois écrans sont tombés —
/// mais ça veut dire qu'un échec peut nommer « En famille » ou « Nombre de
/// cartes », qui ne sont pas ici. Ces deux étapes n'ont pas de fichier à
/// elles ; le jour où elles en auront un, on pourra restreindre la portée.
void main() {
  late AppLocalizations l10n;
  late AppDatabase db;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await exigerLesVraiesPolices();
  });

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  /// Va jusqu'à l'étape des équipes : mode, catégories, réglages.
  Future<void> allerAuxEquipes(WidgetTester tester) async {
    Future<void> taper(String libelle) async {
      await tester.tap(find.text(libelle));
      await tester.pumpAndSettle();
    }

    await taper(l10n.homePlay);
    await taper(l10n.modeFamily);
    await taper(l10n.actionContinue);
    await taper(l10n.actionContinue);
    expect(find.text(l10n.setupTeamsTitle), findsOneWidget);
  }

  /// Amène le compteur à [cible].
  Future<void> reglerLeCompteur(WidgetTester tester, int cible) async {
    var garde = 0;
    while (find.text('$cible').evaluate().isEmpty) {
      await tester.tap(find.bySemanticsLabel(l10n.teamCountMore));
      await tester.pumpAndSettle();
      if (++garde > 20) fail('le compteur n atteint pas $cible');
    }
  }

  for (final (taille, echelle) in const [
    (Size(360, 800), 1.0),
    // Le cran où le compteur cédait, et le plus banal des trois.
    (Size(360, 800), 1.6),
    (Size(360, 640), 2.0),
    // AX5 sur iOS, qui n'a jamais tourné ailleurs qu'en compilation.
    (Size(360, 640), 3.1),
  ]) {
    final ecran = '${taille.width.toInt()}×${taille.height.toInt()}';

    testWidgets('dix équipes tiennent sur $ecran à ×$echelle', (tester) async {
      await installerCategorie(
        db,
        'animaux',
        facile: 15,
        moyen: 15,
        difficile: 15,
      );
      await monterLaConfiguration(
        tester,
        db,
        taille: taille,
        echelleTexte: echelle,
      );

      await allerAuxEquipes(tester);
      await reglerLeCompteur(tester, 10);

      // Un débordement de `RenderFlex` remonte comme exception de test.
      expect(tester.takeException(), isNull);

      // Le nombre à deux chiffres, celui qui débordait de sa boîte.
      expect(find.text('10'), findsOneWidget);
      aucunTexteRogne(tester);

      // Et les deux flèches restent tapables : sans elles, on ne peut plus
      // redescendre, et R8.1 promet dix équipes utilisables.
      await resteAtteignable(
        tester,
        find.bySemanticsLabel(l10n.teamCountFewer),
      );
      await resteAtteignable(tester, find.bySemanticsLabel(l10n.teamCountMore));
    });
  }

  testWidgets('le nombre reste centré entre ses deux flèches', (tester) async {
    // `TexteQuiTient` n'aligne rien par défaut : le poser sur ce nombre sans
    // `textAlign` le collerait à gauche de sa boîte de 64 px, donc contre la
    // flèche « moins ». À taille de texte normale, c'est-à-dire pour tout le
    // monde, et dans le seul cas où il n'y avait rien à corriger.
    await installerCategorie(
      db,
      'animaux',
      facile: 15,
      moyen: 15,
      difficile: 15,
    );
    await monterLaConfiguration(tester, db, taille: const Size(360, 800));

    await allerAuxEquipes(tester);
    resteCentre(tester, find.text('2'));
  });
}
