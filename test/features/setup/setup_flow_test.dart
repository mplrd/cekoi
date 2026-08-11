import 'package:cekoi/app/app.dart';
import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/providers.dart';

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
          screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
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

    // 4 — les équipes : deux par défaut, sans rien taper (R8.3)
    expect(find.text(l10n.setupTeamsTitle), findsOneWidget);
    expect(find.text(l10n.teamDefaultName(1)), findsOneWidget);
    expect(find.text(l10n.teamDefaultName(2)), findsOneWidget);
    await tapText(tester, l10n.actionContinue);

    // 5 — le récapitulatif
    expect(find.text(l10n.setupSummaryTitle), findsOneWidget);
    expect(find.text(l10n.summaryMode), findsOneWidget);
    await tapText(tester, l10n.actionStartGame);

    // Le paquet est tiré : 12 × 2 équipes (R6.1).
    expect(launchedGame(tester).deck, hasLength(24));

    // Et la partie s'ouvre sur l'annonce du premier tour, pas sur une carte :
    // le téléphone doit avoir le temps de changer de mains.
    expect(
      find.text(l10n.turnIntroTeam(l10n.teamDefaultName(1))),
      findsOneWidget,
    );
    expect(find.text(l10n.roundNameFree), findsOneWidget);
  });

  testWidgets('R8.3 — les équipes se nomment, ou pas', (tester) async {
    // Vivier large : trois équipes demandent 36 cartes, et un paquet tronqué
    // ferait passer l'assertion de R6.1 pour une histoire de pénurie.
    await installDeck('animaux', easy: 15, medium: 15, hard: 15);
    await pumpApp(tester);

    await tapText(tester, l10n.homePlay);
    await tapText(tester, l10n.modeFamily);
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionContinue);

    // Trois équipes, dont une seule nommée : R8.4 garde la saisie, R8.3
    // comble le reste.
    await tapText(tester, '3');
    await tester.enterText(find.byType(TextField).at(1), 'Les Zèbres');
    await tester.pumpAndSettle();
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionStartGame);

    expect(
      launchedGame(tester).teams.map((t) => t.name),
      [l10n.teamDefaultName(1), 'Les Zèbres', l10n.teamDefaultName(3)],
    );
    expect(
      launchedGame(tester).deck,
      hasLength(36),
      reason: 'Trois équipes, donc 12 × 3 cartes (R6.1)',
    );
  });

  testWidgets('R8.1 — « Plus » ajoute une équipe, pas cinq', (tester) async {
    // La rangée de pastilles s'arrête à six. Le bouton doit compter depuis les
    // équipes qu'on joue et non depuis le bout de la rangée, sinon deux
    // équipes en deviennent sept d'un tap — et le paquet auto passe à 80.
    await installDeck('animaux', easy: 15, medium: 15, hard: 15);
    await pumpApp(tester);

    await tapText(tester, l10n.homePlay);
    await tapText(tester, l10n.modeFamily);
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionContinue);

    expect(find.byType(TextField), findsNWidgets(2));

    await tapText(tester, l10n.teamCountMore);

    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('R8.4 — un nom coupé ne revient pas si on remonte', (
    tester,
  ) async {
    // Cas limite 14. L'écran garde un champ par équipe : si ces champs
    // survivent à la baisse du nombre d'équipes, il affiche un nom que le
    // domaine a jeté, et la partie part sous un autre — visible dès le
    // premier tour.
    await installDeck('animaux', easy: 15, medium: 15, hard: 15);
    await pumpApp(tester);

    await tapText(tester, l10n.homePlay);
    await tapText(tester, l10n.modeFamily);
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionContinue);

    await tapText(tester, '3');
    await tester.enterText(find.byType(TextField).at(0), 'Les Verts');
    await tester.enterText(find.byType(TextField).at(2), 'Les Bleus');
    await tester.pumpAndSettle();

    await tapText(tester, '2');
    await tapText(tester, '3');

    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).controller?.text,
      isEmpty,
      reason: "le champ montre ce que la partie emportera, pas ce qu'on a tapé",
    );

    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionStartGame);

    // « Les Verts » n'a jamais été coupé, lui : R8.4 garde les noms des
    // équipes qui restent, et c'est ce qui distingue la correction d'un simple
    // effacement de tous les champs.
    expect(
      launchedGame(tester).teams.map((t) => t.name),
      ['Les Verts', l10n.teamDefaultName(2), l10n.teamDefaultName(3)],
    );
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

      // Le tap ne fait rien : on reste sur l'étape, et la sélection n'a pas
      // bougé. Elle n'est plus vide au départ depuis R7.9 — on arrive avec
      // toutes les catégories cochées — donc c'est son immobilité qui prouve
      // que le profil indisponible a bien été ignoré.
      await tapText(tester, l10n.profileMinis);
      expect(find.text(l10n.setupDecksTitle), findsOneWidget);
      expect(find.text(l10n.setupSelectionSummary(45)), findsOneWidget);
    },
  );

  group('R7.9 — on arrive avec tout coché', () {
    testWidgets('le mode Sans filtres est jouable sans rien toucher', (
      tester,
    ) async {
      // Le cas qui a fait remonter la règle : ce mode n'a aucun profil, donc
      // l'étape s'ouvrait sur une sélection vide et il fallait cocher les
      // catégories une par une avant de pouvoir continuer.
      //
      // Depuis R7.10 elle est carrément sautée — mais la sélection doit être
      // faite quand même, sinon on arriverait aux réglages avec un paquet vide
      // et un bouton de lancement grisé sans explication.
      await installDeck('animaux', easy: 10, medium: 10, hard: 10);
      await installDeck(
        'sans-filtres',
        audience: Audience.adult,
        minAge: MinAge.eighteen,
        easy: 5,
        medium: 5,
        hard: 5,
      );
      await pumpApp(tester);

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeAdult);
      await tapText(tester, l10n.adultConfirmAccept);

      // R7.10 : on atterrit directement sur les réglages, l'étape des
      // catégories n'étant pas sur le chemin.
      expect(find.text(l10n.setupSettingsTitle), findsOneWidget);

      // R7.1 : ce mode tire aussi dans le tout public, donc les deux
      // catégories sont retenues, et les 45 cartes avec.
      final setup = ProviderScope.containerOf(
        tester.element(find.byType(CekoiApp)),
      ).read(setupControllerProvider);
      expect(setup.deckIds, containsAll(['animaux', 'sans-filtres']));

      // Et le parcours annonce quatre étapes, pas cinq.
      expect(find.text(l10n.setupStep(2, 4)), findsOneWidget);
    });

    testWidgets('une categorie decochee ne revient pas seule', (tester) async {
      // La présélection n'a lieu qu'à la première arrivée : décocher est une
      // décision, et la voir annulée au retour serait pire que le problème
      // qu'on corrige (R7.6).
      await installDeck('animaux', easy: 10, medium: 10, hard: 10);
      await installDeck('metiers', easy: 10, medium: 10, hard: 10);
      await pumpApp(tester);

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);
      expect(find.text(l10n.setupSelectionSummary(60)), findsOneWidget);

      await tapText(tester, l10n.setupCustomize);
      await tapText(tester, 'metiers');
      expect(find.text(l10n.setupSelectionSummary(30)), findsOneWidget);

      // Aller-retour sur l'étape suivante, par le retour système — c'est le
      // geste réel, et l'écran de configuration n'a pas de flèche.
      await tapText(tester, l10n.actionContinue);
      expect(find.text(l10n.setupSettingsTitle), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(l10n.setupDecksTitle), findsOneWidget);

      expect(
        find.text(l10n.setupSelectionSummary(30)),
        findsOneWidget,
        reason: 'la catégorie décochée doit le rester',
      );
    });
  });

  testWidgets('sous 12 cartes, on ne peut pas continuer (R6.2)', (
    tester,
  ) async {
    await installDeck('maigre', easy: 3, medium: 3, hard: 3);
    await pumpApp(tester);

    await tapText(tester, l10n.homePlay);
    await tapText(tester, l10n.modeFamily);

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
  /// main et deux équipes — soit 24 cartes demandées (R6.1).
  Future<void> goToSummary(WidgetTester tester, String deck) async {
    await tapText(tester, l10n.homePlay);
    await tapText(tester, l10n.modeFamily);
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionContinue);
    expect(find.text(l10n.setupSummaryTitle), findsOneWidget);
  }

  group('R6.2 — un vivier trop petit est annoncé avant de démarrer', () {
    testWidgets('le récapitulatif dit avec combien de cartes on jouera', (
      tester,
    ) async {
      // 16 cartes pour 24 demandées : au-dessus du plancher de 12, donc la
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
      expect(find.text(l10n.launchTruncated(24)), findsNothing);
      await tapText(tester, l10n.actionStartGame);
      expect(launchedGame(tester).deck, hasLength(24));
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
    // R7.10 : accepter mène aux réglages, l'étape des catégories étant sautée
    // dans ce mode.
    expect(find.text(l10n.setupSettingsTitle), findsOneWidget);
  });
}
