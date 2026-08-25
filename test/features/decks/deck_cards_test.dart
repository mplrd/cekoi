import 'package:cekoi/app/router.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/decks/card_length.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/features/decks/presentation/deck_cards_screen.dart';
import 'package:cekoi/features/decks/presentation/widgets/difficulty_labels.dart';
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

  group('le formulaire se lit de haut en bas et finit par son action', () {
    testWidgets('le bouton Ajouter est sous le champ, et rien après lui', (
      tester,
    ) async {
      // Retour d'usage : un « + » collé au champ laissait douter de ce qui
      // partait. L'ordre visuel est donc la règle, pas un détail.
      await pumpScreen(tester);

      double bas(Finder finder) => tester.getRect(finder).bottom;

      expect(
        bas(find.byType(TextField).first),
        lessThan(bas(find.widgetWithText(FilledButton, l10n.actionAddCard))),
        reason: "Rien ne doit rester sous le bouton d'ajout",
      );
    });

    testWidgets('le niveau se choisit avec le texte, pas après', (
      tester,
    ) async {
      // Retour d'usage d'août 2026 : il fallait ajouter la carte puis la
      // rouvrir pour la classer — deux gestes pour une décision. Le sélecteur
      // est donc *dans* le formulaire, entre le texte et l'action, où il se
      // lit comme celui de la carte en cours d'écriture. En tête d'écran il
      // aurait classé la catégorie, ce qui n'a pas de sens : « Vacances »
      // contient des faciles comme des difficiles.
      await pumpScreen(tester);

      expect(find.byType(SegmentedButton<Difficulty>), findsOneWidget);

      await tester.tap(find.text(Difficulty.hard.label(l10n)));
      await tester.pumpAndSettle();
      await typeCard(tester, 'Le camping');

      final cards = await container
          .read(deckRepositoryProvider)
          .cardsOfDeck(deckId);
      expect(cards.single.difficulty, Difficulty.hard);
    });

    testWidgets('le niveau retenu sert à la carte suivante', (tester) async {
      // On saisit par séries : remettre « moyen » après chaque ajout
      // obligerait à repositionner le sélecteur à chaque carte.
      await pumpScreen(tester);

      await tester.tap(find.text(Difficulty.easy.label(l10n)));
      await tester.pumpAndSettle();
      await typeCard(tester, 'Le chat');
      await typeCard(tester, 'Le chien');

      final cards = await container
          .read(deckRepositoryProvider)
          .cardsOfDeck(deckId);
      expect(
        cards.map((c) => c.difficulty),
        everyElement(Difficulty.easy),
        reason: 'le champ de texte se vide, le niveau non',
      );
    });

    testWidgets('le bouton ajoute la carte, comme la validation clavier', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField).first, 'Le camping');
      await tester.tap(find.widgetWithText(FilledButton, l10n.actionAddCard));
      await tester.pumpAndSettle();

      expect(find.text('Le camping'), findsOneWidget);
    });

    testWidgets('le champ ne laisse pas écrire plus long que la carte', (
      tester,
    ) async {
      // La borne est tenue par le dépôt, qui **lève**. Si le champ la laissait
      // dépasser, le bouton d'ajout ferait remonter une exception au lieu
      // d'ajouter une carte — et le joueur n'aurait rien vu venir. Le champ
      // est donc le premier des deux verrous, pas le seul.
      await pumpScreen(tester);

      await tester.enterText(
        find.byType(TextField).first,
        'a' * (maxCardTextLength + 20),
      );
      await tester.tap(find.widgetWithText(FilledButton, l10n.actionAddCard));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('a' * maxCardTextLength), findsOneWidget);
    });
  });

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

    testWidgets('deux cartes de suite gardent chacune le niveau par défaut', (
      tester,
    ) async {
      // Saisir en rafale ne doit rien demander d'autre que le texte : le
      // sélecteur est là si on le veut, il n'oblige à rien si on l'ignore.
      await pumpScreen(tester);

      await typeCard(tester, 'Le vertige');
      await typeCard(tester, 'Un huissier');

      final cards = await container
          .read(deckRepositoryProvider)
          .cardsOfDeck(deckId);
      expect(cards, hasLength(2));
      expect(cards.map((c) => c.difficulty), everyElement(Difficulty.medium));
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

    testWidgets('le niveau se règle aussi en touchant la carte', (
      tester,
    ) async {
      // Le formulaire pose le niveau à la saisie ; rouvrir la carte reste le
      // moyen de le corriger après coup. Les deux chemins existent, et les
      // libellés étant les mêmes, le tap est porté sur celui de la boîte de
      // dialogue — sinon il atteindrait le sélecteur du formulaire.
      await pumpScreen(tester);
      await typeCard(tester, 'Le vertige');

      await tester.tap(find.text('Le vertige'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.difficultyHard),
        ),
      );
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      final cards = await container
          .read(deckRepositoryProvider)
          .cardsOfDeck(deckId);
      expect(cards.single.difficulty, Difficulty.hard);
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text(l10n.difficultyHard),
        ),
        findsOneWidget,
        reason: 'la ligne de la carte annonce son nouveau niveau',
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
