import 'package:cekoi/app/app.dart';
import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parcours de configuration de bout en bout, sur une base en mémoire.
///
/// C'est le livrable du lot : cinq étapes, et un paquet réellement tiré au
/// bout. Le reste des écrans est couvert par les tests du domaine — on ne
/// teste pas ici la mise en page, mais le chemin critique.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  /// Installe une catégorie et ses cartes, réparties sur les difficultés.
  Future<void> installDeck(
    String id, {
    int easy = 10,
    int medium = 10,
    int hard = 10,
    Audience audience = Audience.family,
    MinAge minAge = MinAge.six,
  }) async {
    await db
        .into(db.decks)
        .insert(
          DecksCompanion.insert(
            id: id,
            name: id,
            audience: audience,
            minAge: minAge.years,
            origin: DeckOrigin.official,
          ),
        );

    var index = 0;
    for (final entry in {
      Difficulty.easy: easy,
      Difficulty.medium: medium,
      Difficulty.hard: hard,
    }.entries) {
      for (var i = 0; i < entry.value; i++, index++) {
        await db
            .into(db.cards)
            .insert(
              CardsCompanion.insert(
                id: '$id:$index',
                deckId: id,
                cardText: '$id carte $index',
                audience: audience,
                difficulty: entry.key.value,
                origin: DeckOrigin.official,
              ),
            );
      }
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    // Écran volontairement très haut : une `ListView` ne construit pas ses
    // enfants hors champ, et un test qui commence par faire défiler teste
    // surtout sa propre mécanique de défilement.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          // Le seeding lit `rootBundle`, absent d'un test widget : la base est
          // déjà remplie à la main ci-dessus.
          deckSeedingProvider.overrideWith((ref) async => const SeedReport()),
          seedSourceProvider.overrideWithValue(() => 42),
        ],
        child: CekoiApp(router: createAppRouter()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// La partie réellement ouverte, lue à la source.
  ///
  /// La taille du paquet ne s'affiche plus nulle part depuis que l'écran
  /// d'attente a cédé la place au vrai écran de jeu, qui ouvre sur l'annonce
  /// du tour. Elle reste la vérification qui compte ici — le parcours doit
  /// aboutir à un paquet tiré, pas seulement à un écran.
  GameState launchedGame(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(CekoiApp)),
  ).read(currentGameProvider)!;

  Future<void> tapText(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> addPlayer(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('les cinq étapes mènent à un paquet tiré', (tester) async {
    await installDeck('animaux');
    await installDeck('metiers', minAge: MinAge.ten);
    await pumpApp(tester);

    // 1 — le mode
    await tapText(tester, l10n.homePlay);
    expect(find.text(l10n.setupModeTitle), findsOneWidget);
    await tapText(tester, l10n.modeFamily);

    // 2 — les catégories, par un profil : un tap suffit à être prêt (R7.5)
    expect(find.text(l10n.setupDecksTitle), findsOneWidget);
    await tapText(tester, l10n.profileMix);
    await tapText(tester, l10n.actionContinue);

    // 3 — les réglages, traversés sans y toucher
    expect(find.text(l10n.setupSettingsTitle), findsOneWidget);
    await tapText(tester, l10n.actionContinue);

    // 4 — les joueurs et les équipes
    expect(find.text(l10n.setupTeamsTitle), findsOneWidget);
    for (final name in ['Léa', 'Tom', 'Ana', 'Hugo']) {
      await addPlayer(tester, name);
    }
    expect(find.text(l10n.playerCount(4)), findsOneWidget);

    await tapText(tester, l10n.actionProposeTeams);
    expect(find.text(l10n.teamDefaultName(1)), findsOneWidget);
    expect(find.text(l10n.teamDefaultName(2)), findsOneWidget);
    await tapText(tester, l10n.actionContinue);

    // 5 — le récapitulatif
    expect(find.text(l10n.setupSummaryTitle), findsOneWidget);
    expect(find.text(l10n.summaryMode), findsOneWidget);
    await tapText(tester, l10n.actionStartGame);

    // Le paquet est tiré : 5 × 4 joueurs arrondi au multiple de 4 (R6.1).
    expect(launchedGame(tester).deck, hasLength(20));

    // Et la partie s'ouvre sur l'annonce du premier tour, pas sur une carte :
    // le téléphone doit avoir le temps de changer de mains.
    expect(
      find.text(l10n.turnIntroTeam(l10n.teamDefaultName(1))),
      findsOneWidget,
    );
    expect(find.text(l10n.roundNameFree), findsOneWidget);
  });

  testWidgets(
    'un profil sans assez de cartes est visible mais inactif (R7.8)',
    (tester) async {
      // Une seule catégorie 6 ans, et cinq cartes faciles : « Les minis » ne
      // réunit pas les 12 cartes de R6.2, « Mix familial » si.
      await installDeck('animaux', easy: 5, medium: 20, hard: 20);
      await pumpApp(tester);

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);

      expect(find.text(l10n.profileMinis), findsOneWidget);
      expect(find.text(l10n.profileUnavailableNotEnough), findsOneWidget);

      // Le tap ne fait rien : la sélection reste vide, donc pas de suite.
      await tapText(tester, l10n.profileMinis);
      expect(find.text(l10n.setupDecksTitle), findsOneWidget);
      expect(find.text(l10n.setupSelectionSummary(0)), findsOneWidget);
    },
  );

  testWidgets('sous 12 cartes, on ne peut pas continuer (R6.2)', (
    tester,
  ) async {
    await installDeck('maigre', easy: 3, medium: 3, hard: 3);
    await pumpApp(tester);

    await tapText(tester, l10n.homePlay);
    await tapText(tester, l10n.modeFamily);
    await tapText(tester, l10n.setupCustomize);
    await tapText(tester, 'maigre');

    expect(find.text(l10n.setupSelectionSummary(9)), findsOneWidget);
    expect(
      find.text(l10n.setupNotEnoughCards(12)),
      findsOneWidget,
      reason: 'Le joueur doit savoir pourquoi le bouton ne répond pas',
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.actionContinue),
    );
    expect(button.onPressed, isNull);
  });

  /// Traverse les étapes 1 à 4 jusqu'au récapitulatif, avec [deck] coché à la
  /// main et quatre joueurs — soit 20 cartes demandées (R6.1).
  Future<void> goToSummary(WidgetTester tester, String deck) async {
    await tapText(tester, l10n.homePlay);
    await tapText(tester, l10n.modeFamily);
    await tapText(tester, l10n.setupCustomize);
    await tapText(tester, deck);
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionContinue);

    for (final name in ['Léa', 'Tom', 'Ana', 'Hugo']) {
      await addPlayer(tester, name);
    }
    await tapText(tester, l10n.actionProposeTeams);
    await tapText(tester, l10n.actionContinue);
    expect(find.text(l10n.setupSummaryTitle), findsOneWidget);
  }

  group('R6.2 — un vivier trop petit est annoncé avant de démarrer', () {
    testWidgets('le récapitulatif dit avec combien de cartes on jouera', (
      tester,
    ) async {
      // 16 cartes pour 20 demandées : au-dessus du plancher de 12, donc la
      // partie se lance — mais pas avec ce qui était demandé, et R6.2 exige
      // que ce soit dit et non découvert en jouant.
      await installDeck('animaux', easy: 6, medium: 6, hard: 4);
      await pumpApp(tester);
      await goToSummary(tester, 'animaux');

      expect(find.text(l10n.launchTruncated(16)), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, l10n.actionStartGame),
      );
      expect(
        button.onPressed,
        isNotNull,
        reason: 'On joue avec ce qui existe, on ne bloque pas',
      );

      await tapText(tester, l10n.actionStartGame);
      expect(launchedGame(tester).deck, hasLength(16));
    });

    testWidgets("rien n'est annoncé quand le vivier suffit", (tester) async {
      // Cas de contrôle : sans lui, un avertissement affiché en permanence
      // passerait le test précédent.
      await installDeck('animaux');
      await pumpApp(tester);
      await goToSummary(tester, 'animaux');

      expect(find.textContaining(l10n.launchTruncated(30)), findsNothing);
      expect(find.text(l10n.launchTruncated(20)), findsNothing);
      await tapText(tester, l10n.actionStartGame);
      expect(launchedGame(tester).deck, hasLength(20));
    });
  });

  testWidgets("le mode adultes demande une confirmation d'âge (R7.3)", (
    tester,
  ) async {
    await installDeck('apero', audience: Audience.adult);
    await pumpApp(tester);

    await tapText(tester, l10n.homePlay);
    await tapText(tester, l10n.modeAdult);

    expect(find.text(l10n.adultConfirmTitle), findsOneWidget);

    // Refuser laisse sur l'écran du mode, sans rien avoir choisi.
    await tapText(tester, l10n.actionCancel);
    expect(find.text(l10n.setupModeTitle), findsOneWidget);

    await tapText(tester, l10n.modeAdult);
    await tapText(tester, l10n.adultConfirmAccept);
    expect(find.text(l10n.setupDecksTitle), findsOneWidget);
  });
}
