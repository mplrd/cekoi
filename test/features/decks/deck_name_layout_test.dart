import 'package:cekoi/app/router.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/decks/deck_name_length.dart';
import 'package:cekoi/features/decks/presentation/my_decks_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/geometrie.dart';

/// Le nom d'une catégorie ne doit pas manger la liste qui l'affiche.
///
/// Mesuré avant la borne, sur un 360 × 640, avec un nom de trois cents
/// caractères : la ligne montait à 288 px de haut, le même nom en un seul mot
/// était **rogné**, la boîte de suppression occupait l'écran entier, et au
/// maximum d'Android l'entrée « Supprimer » de son menu devenait introuvable —
/// la catégorie n'était alors plus supprimable. Un témoin au nom court, même
/// écran et même réglage, la trouvait sans peine : c'était bien la longueur du
/// nom, et non le menu.
///
/// Le choix de trente est mesuré, pas deviné ; le tableau est dans
/// `deck_name_length.dart`.
void main() {
  late AppLocalizations l10n;
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await exigerLesVraiesPolices();
  });

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size taille = const Size(360, 800),
    double echelleTexte = 1,
  }) async {
    poserEcran(tester, taille: taille, echelleTexte: echelleTexte);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deckSeedingProvider.overrideWith((ref) async => const SeedReport()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: AppRoutes.myDecks,
            routes: [
              GoRoute(
                path: AppRoutes.myDecks,
                builder: (_, _) => const MyDecksScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Crée une catégorie depuis l'écran, comme le joueur le ferait.
  Future<void> createDeck(WidgetTester tester, String name) async {
    await tester.tap(find.text(l10n.actionCreateDeck));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();
  }

  testWidgets('un nom trop long est refusé, pas raboté sous les doigts', (
    tester,
  ) async {
    // Le champ compte mais ne tronque pas — `MaxLengthEnforcement.none`, comme
    // la boîte de correction d'une carte. Raboter à la première frappe
    // empêcherait de corriger le **début** d'un nom hérité trop long.
    const tropLong =
        'Les cartes que ma belle-mère a écrites pendant les vacances de Noël '
        "chez sa sœur à Quimper, et que personne n'a jamais osé lui dire";

    await pumpScreen(tester);
    await tester.tap(find.text(l10n.actionCreateDeck));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), tropLong);
    await tester.pumpAndSettle();

    // Le texte est toujours là, en entier : c'est le joueur qui coupe.
    expect(find.text(tropLong), findsOneWidget);

    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(l10n.deckNameTooLong(maxDeckNameLength)),
      findsOneWidget,
      reason: 'la boîte doit dire pourquoi elle refuse, et rester ouverte',
    );

    // Et une fois raccourci, ça passe.
    await tester.enterText(find.byType(TextField), 'Souvenirs de vacances');
    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();

    expect(find.text('Souvenirs de vacances'), findsOneWidget);
  });

  // Ce que ces trois-là mesurent, c'est le **rendu**, pas la borne : un nom de
  // trente caractères passe avec ou sans elle. Ce qui les fait rougir, c'est de
  // retirer `TexteQuiTient` de la tuile. L'application de la borne, elle, est
  // vérifiée dans `test/data/custom_decks_test.dart`.
  for (final (libelle, taille, echelle, plafond) in [
    ('un écran courant', const Size(360, 800), 1.0, 100.0),
    ('un petit écran', const Size(360, 640), 1.0, 100.0),
    // Le pire réglage d'Android sur le plus petit écran visé. Sans borne, la
    // même ligne montait à 384 px et son texte était rogné.
    ("le maximum d'Android", const Size(360, 640), 2.0, 260.0),
  ]) {
    testWidgets('la ligne reste bornée sur $libelle', (tester) async {
      final nom = 'a' * maxDeckNameLength;

      await pumpScreen(tester, taille: taille, echelleTexte: echelle);
      await createDeck(tester, nom);

      expect(tester.takeException(), isNull);

      final tuile = tester.getRect(find.byType(ListTile).first);
      expect(
        tuile.height,
        lessThanOrEqualTo(plafond),
        reason:
            'la ligne fait ${tuile.height.toStringAsFixed(0)} px de haut sur '
            'un écran de ${taille.height.toInt()}',
      );
      aucunTexteRogne(tester);
    });
  }

  testWidgets('la suppression reste atteignable avec un nom à la borne', (
    tester,
  ) async {
    // Ce qui échouait avec trois cents caractères : le menu s'ouvrait, mais
    // son entrée « Supprimer » était introuvable au maximum d'Android.
    await pumpScreen(
      tester,
      taille: const Size(360, 640),
      echelleTexte: 2,
    );
    await createDeck(tester, 'a' * maxDeckNameLength);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.actionDeleteDeck));
    await tester.pumpAndSettle();

    await resteAtteignable(tester, find.text(l10n.actionDelete));
    await resteAtteignable(tester, find.text(l10n.actionCancel));
    // Le titre porte le nom, et la boîte est étroite : sans le `ellipsis`, il
    // était rogné en silence ici même, à deux lignes de l'assertion qui ne
    // regardait que les boutons.
    aucunTexteRogne(tester);
  });
}
