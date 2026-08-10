import 'package:cekoi/app/router.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/features/decks/presentation/deck_cards_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late AppLocalizations l10n;
  late AppDatabase db;
  late ProviderContainer container;
  late String deckId;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

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

    final deck = await container
        .read(deckRepositoryProvider)
        .createCustomDeck(name: 'Vacances', audience: Audience.family);
    deckId = deck.id;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: AppRoutes.deckCards(deckId),
            routes: [
              GoRoute(
                path: AppRoutes.deckCards(deckId),
                builder: (_, _) => DeckCardsScreen(deckId: deckId),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Saisit une carte et valide au clavier, comme en usage réel.
  Future<void> typeCard(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  group('saisie en rafale', () {
    testWidgets('la carte entre et le champ se vide', (tester) async {
      // Quelqu'un qui saisit trente prénoms ne doit pas retoucher l'écran
      // entre deux cartes.
      await pumpScreen(tester);

      await typeCard(tester, 'Le camping');

      expect(find.text('Le camping'), findsOneWidget);
      final champ = tester.widget<TextField>(find.byType(TextField).first);
      expect(champ.controller!.text, isEmpty);
    });

    testWidgets('deux cartes s’enchaînent', (tester) async {
      await pumpScreen(tester);

      await typeCard(tester, 'Le camping');
      await typeCard(tester, 'La plage');

      expect(find.text('Le camping'), findsOneWidget);
      expect(find.text('La plage'), findsOneWidget);
    });

    testWidgets('la difficulté choisie reste pour la carte suivante', (
      tester,
    ) async {
      // On saisit souvent une série de cartes de même niveau : remettre le
      // curseur à « moyen » à chaque fois serait un geste de trop.
      await pumpScreen(tester);

      await tester.tap(find.text(l10n.difficultyHard));
      await tester.pumpAndSettle();
      await typeCard(tester, 'Le vertige');
      await typeCard(tester, 'Un huissier');

      final cards = await container
          .read(deckRepositoryProvider)
          .cardsOfDeck(deckId);
      expect(
        cards.map((c) => c.difficulty),
        everyElement(Difficulty.hard),
      );
    });

    testWidgets('un texte vide n’ajoute rien', (tester) async {
      await pumpScreen(tester);

      await typeCard(tester, '   ');

      expect(find.text(l10n.deckCardsEmpty), findsOneWidget);
    });
  });

  group('R6.4 — le doublon est refusé, sans perdre la saisie', () {
    testWidgets('la carte est refusée et le texte reste corrigeable', (
      tester,
    ) async {
      await pumpScreen(tester);
      await typeCard(tester, 'Le camping');

      await typeCard(tester, 'le  camping');

      expect(find.text(l10n.cardAlreadyThere), findsOneWidget);
      final champ = tester.widget<TextField>(find.byType(TextField).first);
      expect(
        champ.controller!.text,
        'le  camping',
        reason: 'Sur un refus, le texte reste sous les yeux pour être corrigé',
      );
      expect(
        await container.read(deckRepositoryProvider).cardsOfDeck(deckId),
        hasLength(1),
      );
    });

    testWidgets('corriger la saisie efface le refus', (tester) async {
      await pumpScreen(tester);
      await typeCard(tester, 'Le camping');
      await typeCard(tester, 'le camping');
      expect(find.text(l10n.cardAlreadyThere), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'La plage');
      await tester.pumpAndSettle();

      expect(find.text(l10n.cardAlreadyThere), findsNothing);
    });
  });

  group('modifier et supprimer une carte', () {
    testWidgets('modifier garde la carte et change son texte', (tester) async {
      await pumpScreen(tester);
      await typeCard(tester, 'Le campign');

      await tester.tap(find.text('Le campign'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Le camping');
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      expect(find.text('Le camping'), findsOneWidget);
      expect(find.text('Le campign'), findsNothing);
      expect(
        await container.read(deckRepositoryProvider).cardsOfDeck(deckId),
        hasLength(1),
      );
    });

    testWidgets('supprimer demande confirmation', (tester) async {
      await pumpScreen(tester);
      await typeCard(tester, 'Le camping');

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text(l10n.deleteCardTitle('Le camping')), findsOneWidget);

      await tester.tap(find.text(l10n.actionCancel));
      await tester.pumpAndSettle();
      expect(find.text('Le camping'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionDelete));
      await tester.pumpAndSettle();

      expect(find.text(l10n.deckCardsEmpty), findsOneWidget);
    });
  });
}
