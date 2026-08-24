/// Rend chaque écran dans un PNG, pour les regarder côte à côte.
///
/// Ce n'est pas une suite de non-régression : aucune assertion, rien à casser.
/// C'est un banc de rendu — le seul moyen de contrôler la cohérence visuelle
/// d'un écran à l'autre sans réinstaller l'application à chaque essai. Il a
/// trouvé, en une passe, un bouton blanc oublié, un bouton flottant cerné de
/// noir et un écran sans surface : aucun test fonctionnel ne voit ces
/// défauts-là.
///
/// ```bash
/// flutter test tool/apercus/apercu.dart --update-goldens
/// ```
///
/// Le chemin du **fichier** est nécessaire : `flutter test tool/apercus`, avec
/// le seul dossier, retombe silencieusement sur toute la suite de `test/`.
///
/// Il vit **hors de `test/`** exprès. `matchesGoldenFile` échoue quand l'image
/// de référence manque, et ces images ne sont pas versionnées — elles
/// dépendent du moteur de rendu de la machine. Dans `test/`, il aurait rendu
/// `flutter test` rouge sur tout clone neuf, avec un message qui ne dit pas
/// quoi faire. Ici, ni la commande du projet ni la CI ne le ramassent : on le
/// lance quand on veut regarder.
library;

import 'package:cekoi/app/app.dart';
import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/preferences.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:cekoi/features/play/presentation/game_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ad_service.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:cekoi/services/feedback/feedback.dart';
import 'package:cekoi/services/feedback/game_feedback.dart';
import 'package:cekoi/services/purchases/purchases.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test/support/fixtures.dart';
import '../../test/support/polices.dart';
import '../../test/support/providers.dart';

/// Le chargement des vraies polices vit dans `test/support/polices.dart`.
///
/// Il y a été déplacé le 24 août, quand les tests de géométrie en ont eu
/// besoin : sans les vraies polices, `flutter test` compose en Ahem et toute
/// mesure de largeur est fausse. Ce banc s'en passait déjà mal — il montre
/// des écrans —, mais deux copies de la même liste de fichiers auraient fini
/// par diverger.

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await chargerLesVraiesPolices();
  });

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
    // Le son et la vibration de l'écran de jeu passent par un canal absent du
    // binding de test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    return db.close();
  });

  /// Format d'un téléphone courant, en points logiques.
  ///
  /// C'est la contrainte qui compte : le rendu doit tenir sur 390 × 844, pas
  /// sur l'écran de 4000 pixels de haut que les tests fonctionnels s'offrent
  /// pour ne pas avoir à faire défiler.
  const taille = Size(390, 844);

  Future<void> shoot(WidgetTester tester, String nom) async {
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('img/$nom.png'),
    );
  }

  Future<void> installDeck(
    String id,
    String nom, {
    Audience audience = Audience.family,
    MinAge minAge = MinAge.six,
  }) async {
    await db
        .into(db.decks)
        .insert(
          DecksCompanion.insert(
            id: id,
            name: nom,
            audience: audience,
            minAge: minAge.years,
            origin: DeckOrigin.official,
          ),
        );

    var index = 0;
    for (final entry in {
      Difficulty.easy: 10,
      Difficulty.medium: 10,
      Difficulty.hard: 10,
    }.entries) {
      for (var i = 0; i < entry.value; i++, index++) {
        await db
            .into(db.cards)
            .insert(
              CardsCompanion.insert(
                id: '$id:$index',
                deckId: id,
                cardText: '$nom carte $index',
                audience: audience,
                difficulty: entry.key.value,
                origin: DeckOrigin.official,
              ),
            );
      }
    }
  }

  /// Les catégories réelles, pour que l'écran de choix ait sa vraie densité.
  Future<void> installCatalogue() async {
    const catalogue = {
      'animaux': 'Animaux',
      'metiers': 'Métiers',
      'musique': 'Musique',
      'sport': 'Sport',
      'histoire': 'Histoire',
      'quotidien': 'Quotidien',
      'gourmandises': 'Gourmandises',
      'monuments': 'Monuments',
    };
    for (final entry in catalogue.entries) {
      await installDeck(entry.key, entry.value);
    }
  }

  Future<void> pumpApp(
    WidgetTester tester, {

    /// Un interstitiel qui prend son temps, pour que l'écran de lancement
    /// reste visible assez longtemps pour être photographié.
    ShowInterstitial? interstitiel,
  }) async {
    tester.view.physicalSize = taille * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          deckSeedingProvider.overrideWith((ref) async => const SeedReport()),
          seedSourceProvider.overrideWithValue(() => 42),
          screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
          gameFeedbackProvider.overrideWithValue(const SilentGameFeedback()),
          consentGatewayProvider.overrideWithValue(
            fakeConsentGateway(
              const ConsentState(canRequestAds: true, canChangeChoice: true),
            ),
          ),
          // Sans cette doublure, accorder le consentement fait démarrer le
          // vrai SDK publicitaire, qui attend une réponse native qui ne vient
          // jamais : l'écran reste sur son indicateur et le banc expire.
          adSdkStartProvider.overrideWithValue(() async {}),
          currentPreferencesProvider.overrideWithValue(fakePreferences()),
          purchaseServiceProvider.overrideWithValue(fakePurchaseService()),
          if (interstitiel != null)
            showInterstitialProvider.overrideWithValue(interstitiel),
        ],
        child: CekoiApp(router: createAppRouter()),
      ),
    );
    await tester.pumpAndSettle();

    // Le décodage d'une image est asynchrone : sous le faux temps du test il
    // ne se termine jamais et le logo reste un trou. `runAsync` rend la main
    // au vrai ordonnanceur le temps de le charger.
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/branding/logo_mark.png'),
        tester.element(find.byType(MaterialApp).first),
      );
    });
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  testWidgets('le parcours de configuration', (tester) async {
    await installCatalogue();
    await pumpApp(tester);

    await shoot(tester, '01-accueil');

    await tapText(tester, l10n.homePlay);
    await shoot(tester, '02-mode');

    await tapText(tester, l10n.modeFamily);
    await shoot(tester, '03-categories');

    await tapText(tester, l10n.actionContinue);
    await shoot(tester, '04-reglages');

    await tapText(tester, l10n.actionContinue);
    // Dernière étape : c'est d'ici que part la partie, le bouton de lancement
    // est au pied de l'écran.
    await shoot(tester, '05-equipes');
  });

  testWidgets('les réglages de l application', (tester) async {
    // L'apparence de cet écran dépend de ce que le joueur possède : l'offre
    // d'achat s'efface une fois payée. Le banc n'accorde jamais la version
    // complète, donc l'offre est là — comme la mention de publicité de
    // `05-equipes`, qui suit la même possession. Consentement et formulaire
    // sont accordés, donc la carte de choix publicitaire est là aussi.
    await installCatalogue();
    await pumpApp(tester);

    await tapText(tester, l10n.homeSettings);
    await shoot(tester, '15-reglages');
  });

  // Il a existé ici deux aperçus, `06-recapitulatif` et `16-lancement` : le
  // récapitulatif de la configuration, et l'écran intercalé qui portait
  // l'interstitiel. Les deux écrans ont été retirés — le premier n'apprenait
  // rien à qui venait de tout choisir, le second redisait ce que l'annonce du
  // tour affiche juste après.

  testWidgets('mes catégories', (tester) async {
    await installCatalogue();
    await pumpApp(tester);

    await tapText(tester, l10n.homeMyDecks);
    await shoot(tester, '12-mes-categories');
  });

  testWidgets('le menu d une catégorie custom', (tester) async {
    // Les surfaces posées par-dessus la page — menu contextuel, dialogue —
    // n'apparaissaient sur aucune capture : elles prenaient le fond du thème
    // et se confondaient avec l'écran qu'elles recouvrent.
    await installCatalogue();
    await pumpApp(tester);

    await tapText(tester, l10n.homeMyDecks);
    await tapText(tester, l10n.actionCreateDeck);
    await tester.enterText(find.byType(TextField).first, 'Souvenirs de fac');
    await tapText(tester, l10n.actionSave);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await shoot(tester, '14-menu-categorie');
  });

  testWidgets('créer une carte custom', (tester) async {
    // L'écran que le niveau par carte a fait bouger : le sélecteur doit se
    // lire comme celui de la carte en cours de saisie, pas de la catégorie.
    await installCatalogue();
    await pumpApp(tester);

    await tapText(tester, l10n.homeMyDecks);
    await tapText(tester, l10n.actionCreateDeck);
    await tester.enterText(find.byType(TextField).first, 'Souvenirs de fac');
    await tapText(tester, l10n.actionSave);
    await tapText(tester, 'Souvenirs de fac');
    await tester.enterText(
      find.byType(TextField).first,
      'La soirée intégration',
    );
    await tapText(tester, l10n.actionAddCard);
    await tester.enterText(find.byType(TextField).first, 'Le partiel de 8h');
    await tapText(tester, l10n.actionAddCard);
    await shoot(tester, '13-carte-custom');
  });

  testWidgets('le mode sans filtre saute les catégories', (tester) async {
    await installCatalogue();
    await installDeck(
      'sexe-et-tabou',
      'Sexe et tabou',
      audience: Audience.adult,
    );
    await pumpApp(tester);

    await tapText(tester, l10n.homePlay);
    await tapText(tester, l10n.modeAdult);
    await tapText(tester, l10n.adultConfirmAccept);
    // R7.10 : l'étape 2 du mode Sans filtre, au même rang que les catégories
    // en Famille. C'est l'écran à comparer à l'œil avec `03-categories`.
    await shoot(tester, '03b-sans-filtre-choix-vivier');

    await tapText(tester, l10n.adultPoolAll);
    await shoot(tester, '04b-sans-filtre-va-aux-reglages');
  });

  /// Une partie posée directement dans la phase voulue : traverser tout le
  /// parcours pour atteindre le podium coûterait bien plus qu'il ne montre.
  group('les écrans de jeu', () {
    late FakeMonotonicClock clock;

    Future<void> pumpGame(WidgetTester tester, GameState game) async {
      clock = FakeMonotonicClock();
      tester.view.physicalSize = taille * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            monotonicClockProvider.overrideWithValue(clock.read),
            screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
            gameFeedbackProvider.overrideWithValue(const SilentGameFeedback()),
          ],
          child: MaterialApp.router(
            locale: const Locale('fr'),
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: GoRouter(
              initialLocation: AppRoutes.game,
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (_, _) => const Scaffold(),
                ),
                GoRoute(
                  path: AppRoutes.game,
                  builder: (_, _) => const GameScreen(),
                ),
              ],
            ),
          ),
        ),
      );

      ProviderScope.containerOf(
        tester.element(find.byType(GameScreen)),
      ).read(currentGameProvider.notifier).game = game;
      await tester.pumpAndSettle();
    }

    /// Une partie dont la carte du dessus porte un texte plausible.
    GameState partie({int roundIndex = 0}) {
      final autres = testCards(9);
      const carte = domain.Card(
        id: 'deck:tarte',
        deckId: 'deck',
        text: 'La tarte aux pommes',
        audience: Audience.family,
        difficulty: Difficulty.medium,
        origin: DeckOrigin.official,
      );

      return testGame(cardCount: 10, roundIndex: roundIndex).copyWith(
        teams: const [
          Team(id: 't1', name: 'Les Renards'),
          Team(id: 't2', name: 'Les Hiboux', colorId: 1),
        ],
        deck: [carte, ...autres],
        pile: [carte.id, for (final c in autres) c.id],
      );
    }

    testWidgets('annonce du tour', (tester) async {
      await pumpGame(tester, partie());
      await shoot(tester, '07-annonce-tour');
    });

    testWidgets('en jeu, manche 1', (tester) async {
      await pumpGame(tester, partie());
      await tapText(tester, l10n.actionStartTurn);
      await clock.advance(tester, const Duration(seconds: 4));
      await shoot(tester, '08-jeu-manche1');
    });

    testWidgets('en jeu, manche 3', (tester) async {
      await pumpGame(tester, partie(roundIndex: 2));
      await tapText(tester, l10n.actionStartTurn);
      await clock.advance(tester, const Duration(seconds: 4));
      await shoot(tester, '09-jeu-manche3');
    });

    testWidgets('en jeu, chrono urgent', (tester) async {
      await pumpGame(tester, partie());
      await tapText(tester, l10n.actionStartTurn);
      // Trois secondes de décompte, puis le tour : il reste 2,7 secondes.
      // Sous les trois dernières (R3.6 bis), les zones d'action battent — on
      // attrape donc le liseret en pleine pulsation, en plus du chrono rouge.
      await clock.advance(
        tester,
        const Duration(seconds: 60, milliseconds: 300),
      );
      await shoot(tester, '10-jeu-urgence');
    });

    testWidgets('bilan de tour', (tester) async {
      final jouee = partie();
      await pumpGame(
        tester,
        jouee.copyWith(
          phase: GamePhase.turnSummary,
          // Le paquet tel que le moteur l'aurait laissé : les deux trouvées
          // retirées, la passée renvoyée au fond. Le laisser intact mettrait
          // en tête une carte déjà tranchée — un état qu'aucune partie ne
          // produit, et qui masquait le bloc « À l'écran au buzzer ».
          pile: [...jouee.pile.skip(3), jouee.pile[2]],
          turn: PlayedTurn(
            teamId: 't1',
            round: jouee.round,
            results: [
              CardResult(cardId: jouee.pile[0], outcome: TurnOutcome.found),
              CardResult(cardId: jouee.pile[1], outcome: TurnOutcome.found),
              CardResult(cardId: jouee.pile[2], outcome: TurnOutcome.passed),
            ],
            elapsed: const Duration(seconds: 60),
          ),
        ),
      );
      await shoot(tester, '11-bilan-tour');
    });
  });
}

/// Une horloge monotone pilotée par le test.
class FakeMonotonicClock {
  Duration _now = Duration.zero;

  Duration read() => _now;

  Future<void> advance(WidgetTester tester, Duration by) async {
    const pas = Duration(milliseconds: 100);
    for (var passe = Duration.zero; passe < by; passe += pas) {
      _now += pas;
      await tester.pump(pas);
    }
  }
}
