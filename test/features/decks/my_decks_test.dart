import 'package:cekoi/app/router.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/features/decks/presentation/my_decks_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late AppLocalizations l10n;
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<void> installOfficial(String id) => db
      .into(db.decks)
      .insert(
        DecksCompanion.insert(
          id: id,
          name: id,
          audience: Audience.family,
          minAge: MinAge.six.years,
          origin: DeckOrigin.official,
        ),
      );

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
  Future<void> createDeck(
    WidgetTester tester,
    String name, {
    bool adult = false,
  }) async {
    await tester.tap(find.text(l10n.actionCreateDeck));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    if (adult) {
      await tester.tap(find.text(l10n.modeAdult));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(l10n.actionSave));
    await tester.pumpAndSettle();
  }

  group("l'écran vide", () {
    testWidgets('explique à quoi servent les catégories', (tester) async {
      await pumpScreen(tester);

      expect(find.text(l10n.myDecksEmpty), findsOneWidget);
      expect(find.text(l10n.myDecksEmptyHint), findsOneWidget);
    });

    testWidgets('les catégories officielles ne s’y affichent pas', (
      tester,
    ) async {
      // « Mes catégories » ne montre que ce que le joueur a écrit : le contenu
      // officiel se gère par le seeding et n'est pas éditable.
      await installOfficial('animaux');
      await pumpScreen(tester);

      expect(find.text('animaux'), findsNothing);
      expect(find.text(l10n.myDecksEmpty), findsOneWidget);
    });
  });

  group('créer une catégorie', () {
    testWidgets('elle apparaît dans la liste avec son mode', (tester) async {
      await pumpScreen(tester);

      await createDeck(tester, 'Blagues de tonton', adult: true);

      expect(find.text('Blagues de tonton'), findsOneWidget);
      expect(find.textContaining(l10n.modeAdult), findsOneWidget);
      expect(find.textContaining(l10n.cardCount(0)), findsOneWidget);
    });

    testWidgets('un nom vide est refusé sans fermer la boîte', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text(l10n.actionCreateDeck));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      expect(find.text(l10n.deckNameRequired), findsOneWidget);
      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'La boîte reste ouverte pour corriger, elle ne se referme pas',
      );
    });

    testWidgets('annuler ne crée rien', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text(l10n.actionCreateDeck));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Vacances');
      await tester.tap(find.text(l10n.actionCancel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.myDecksEmpty), findsOneWidget);
    });
  });

  group('renommer et supprimer', () {
    testWidgets('renommer change le nom affiché', (tester) async {
      await pumpScreen(tester);
      await createDeck(tester, 'Vacances');

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionRenameDeck));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Souvenirs');
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      expect(find.text('Souvenirs'), findsOneWidget);
      expect(find.text('Vacances'), findsNothing);
    });

    testWidgets('supprimer demande confirmation et annonce la perte', (
      tester,
    ) async {
      // `SPEC.md` : suppression avec confirmation. Elle dit ce qui est perdu
      // plutôt qu'un « êtes-vous sûr » creux.
      await pumpScreen(tester);
      await createDeck(tester, 'Vacances');

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionDeleteDeck));
      await tester.pumpAndSettle();

      expect(find.text(l10n.deleteDeckTitle('Vacances')), findsOneWidget);
      expect(find.text(l10n.deleteDeckBody(0)), findsOneWidget);

      await tester.tap(find.text(l10n.actionCancel));
      await tester.pumpAndSettle();
      expect(
        find.text('Vacances'),
        findsOneWidget,
        reason: 'Annuler ne supprime rien',
      );
    });

    testWidgets('confirmer supprime la catégorie', (tester) async {
      await pumpScreen(tester);
      await createDeck(tester, 'Vacances');

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionDeleteDeck));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionDelete));
      await tester.pumpAndSettle();

      expect(find.text(l10n.myDecksEmpty), findsOneWidget);
    });
  });
}
