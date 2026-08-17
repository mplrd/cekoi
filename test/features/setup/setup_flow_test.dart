import 'dart:async';

import 'package:cekoi/app/app.dart';
import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/preferences.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/data/repositories/entitlement_repository.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/features/setup/presentation/deck_catalog.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ad_service.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:cekoi/services/feedback/feedback.dart';
import 'package:cekoi/services/feedback/game_feedback.dart';
import 'package:cekoi/services/purchases/purchases.dart';
import 'package:drift/drift.dart' show Value;
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
    bool premium = false,
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
            isPremium: Value(premium),
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

  /// [taille] permet de repasser à une géométrie réelle quand c'est le
  /// **tenue à l'écran** qu'on teste et non l'enchaînement : la vue par
  /// défaut est trop haute pour qu'un débordement puisse s'y produire.
  Future<void> pumpApp(
    WidgetTester tester, {
    Size? taille,
    double echelleTexte = 1,

    /// Remplace le catalogue du mode adultes, pour tester ce que fait l'écran
    /// du vivier tant qu'il n'a pas répondu.
    Future<DeckCatalog>? catalogueAdulte,

    /// Remplace la passerelle de consentement, pour vérifier ce que devient
    /// le parcours quand le CMP ne répond pas.
    ConsentGateway? passerelle,

    /// Remplace l interstitiel. Par defaut aucune pub : c est l etat d un
    /// build sans publicite, et celui de la quasi-totalite des parcours.
    ShowInterstitial? interstitiel,
  }) async {
    // Écran volontairement très haut : une `ListView` ne construit pas ses
    // enfants hors champ, et un test qui commence par faire défiler teste
    // surtout sa propre mécanique de défilement.
    tester.view.physicalSize = taille ?? const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    tester.platformDispatcher.textScaleFactorTestValue = echelleTexte;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          // Le seeding lit `rootBundle`, absent d'un test widget : la base est
          // déjà remplie à la main ci-dessus.
          deckSeedingProvider.overrideWith((ref) async => const SeedReport()),
          seedSourceProvider.overrideWithValue(() => 42),
          screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
          gameFeedbackProvider.overrideWithValue(const SilentGameFeedback()),
          currentPreferencesProvider.overrideWithValue(fakePreferences()),
          consentGatewayProvider.overrideWithValue(
            passerelle ?? fakeConsentGateway(),
          ),
          adSdkStartProvider.overrideWithValue(() async {}),
          purchaseServiceProvider.overrideWithValue(fakePurchaseService()),
          showInterstitialProvider.overrideWithValue(
            interstitiel ?? showNoInterstitial,
          ),
          if (catalogueAdulte != null)
            deckCatalogProvider(
              Audience.adult,
            ).overrideWith((ref) => catalogueAdulte),
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

  /// Amène le compteur d'équipes à [cible], dans un sens ou dans l'autre.
  ///
  /// Le nombre se règle au compteur depuis les retours d'août 2026 : il n'y a
  /// plus de pastille par valeur sur laquelle taper directement.
  Future<void> setTeamCount(WidgetTester tester, int cible) async {
    var garde = 0;
    while (find.text('$cible').evaluate().isEmpty) {
      final actuel = int.parse(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .whereType<String>()
            .firstWhere((d) => int.tryParse(d) != null),
      );
      await tester.tap(
        find.bySemanticsLabel(
          cible > actuel ? l10n.teamCountMore : l10n.teamCountFewer,
        ),
      );
      await tester.pumpAndSettle();
      if (++garde > 20) fail('le compteur n atteint pas $cible');
    }
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

    // Le paquet est tiré, au volume par défaut de R6.1.
    expect(launchedGame(tester).deck, hasLength(GameConfig.defaultCardCount));

    // Et la partie s'ouvre sur l'annonce du premier tour, pas sur une carte :
    // le téléphone doit avoir le temps de changer de mains.
    expect(
      find.text(l10n.turnIntroTeam(l10n.teamDefaultName(1))),
      findsOneWidget,
    );
    expect(find.text(l10n.roundNameFree), findsOneWidget);
  });

  testWidgets('une catégorie premium n entre pas dans la présélection (R7.9)', (
    tester,
  ) async {
    // Le cadenas de l'écran de sélection est écrit depuis R7.1, mais la
    // présélection de R7.9 prenait le catalogue entier : la case arrivait
    // cochée ET grisée, et les cartes verrouillées entraient dans le paquet
    // sans que personne puisse les retirer.
    await installDeck('animaux', easy: 15, medium: 15, hard: 15);
    await installDeck('disney', easy: 15, medium: 15, hard: 15, premium: true);
    await pumpApp(tester);

    await tapText(tester, l10n.homePlay);
    await tapText(tester, l10n.modeFamily);

    final selection = ProviderScope.containerOf(
      tester.element(find.byType(CekoiApp)),
    ).read(setupControllerProvider).deckIds;

    expect(
      selection,
      isNot(contains('disney')),
      reason: 'une catégorie non débloquée ne peut pas être cochée d office',
    );
    expect(selection, contains('animaux'));

    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionStartGame);

    expect(
      launchedGame(tester).deck.every((c) => !c.id.startsWith('disney')),
      isTrue,
      reason: 'aucune carte premium ne doit atterrir dans le paquet tiré',
    );
  });

  testWidgets('le parcours aboutit même si le CMP ne répond jamais', (
    tester,
  ) async {
    // La garantie centrale de MONETISATION.md : aucune fonctionnalité de jeu
    // ne dépend du succès d un appel publicitaire. Elle était tenue par
    // accident — rien n attendait la réponse — et par aucune intention.
    await installDeck('animaux', easy: 15, medium: 15, hard: 15);
    await pumpApp(tester, passerelle: const _MuteGateway());

    await tapText(tester, l10n.homePlay);
    await tapText(tester, l10n.modeFamily);
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionStartGame);

    expect(launchedGame(tester).deck, hasLength(GameConfig.defaultCardCount));
  });

  group('l interstitiel ne peut pas retenir une partie', () {
    testWidgets('sans pub, le lancement traverse et la partie demarre', (
      tester,
    ) async {
      await installDeck('animaux', easy: 15, medium: 15, hard: 15);
      await pumpApp(tester);

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionStartGame);

      expect(launchedGame(tester).deck, hasLength(GameConfig.defaultCardCount));
      expect(
        find.text(l10n.turnIntroTeam(l10n.teamDefaultName(1))),
        findsOneWidget,
        reason: 'l ecran de lancement doit passer la main a la partie',
      );
    });

    testWidgets('pendant le chargement, le bouton tourne et rien ne bouge', (
      tester,
    ) async {
      // La pub n'a plus d'ecran a elle : elle recouvre le recapitulatif, qui
      // reste donc a l'ecran le temps du chargement. Sans etat d'attente, le
      // bouton paraitrait inerte et on le taperait deux fois.
      await installDeck('animaux', easy: 15, medium: 15, hard: 15);
      await pumpApp(
        tester,
        passerelle: fakeConsentGateway(_accorde),
        interstitiel: _SlowInterstitial().call,
      );

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tester.tap(find.text(l10n.actionStartGame));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.setupSummaryTitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
        reason: 'un second tap relancerait un tirage et une seconde pub',
      );
      expect(
        find.text(l10n.turnIntroTeam(l10n.teamDefaultName(1))),
        findsNothing,
        reason: 'la partie ne s ouvre qu au retour de la pub',
      );
    });

    testWidgets('le retour est ferme pendant le chargement de la pub', (
      tester,
    ) async {
      // Sans cela, un retour pendant les trois secondes ramene a l'etape
      // precedente et la pub s affiche par-dessus un ecran de configuration :
      // MONETISATION.md l interdit nommement, et le quota serait consomme
      // pour une pub que personne n a demandee.
      await installDeck('animaux', easy: 15, medium: 15, hard: 15);
      await pumpApp(
        tester,
        passerelle: fakeConsentGateway(_accorde),
        interstitiel: _SlowInterstitial().call,
      );

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tester.tap(find.text(l10n.actionStartGame));
      await tester.pump();
      await tester.pump();

      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      // `pump` et non `pumpAndSettle` : l'indicateur du bouton tourne tant que
      // la pub charge, et rien ne se stabiliserait jamais.
      await tester.pump();
      await tester.pump();

      expect(
        find.text(l10n.setupSummaryTitle),
        findsOneWidget,
        reason: 'on ne quitte pas le recapitulatif tant que la pub charge',
      );
    });

    testWidgets('une pub qui explose laisse la partie demarrer', (
      tester,
    ) async {
      await installDeck('animaux', easy: 15, medium: 15, hard: 15);
      await pumpApp(
        tester,
        interstitiel: ({required loadTimeout}) async =>
            throw StateError('SDK absent'),
      );

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionStartGame);

      expect(launchedGame(tester).deck, hasLength(GameConfig.defaultCardCount));
    });

    testWidgets('le retour depuis la partie ramene au recapitulatif', (
      tester,
    ) async {
      // Tant que le premier tour n a pas commence, le retour reste libre. Il
      // n y a plus d ecran intercale a retraverser — et donc plus de pub
      // relancee au passage.
      await installDeck('animaux', easy: 15, medium: 15, hard: 15);
      await pumpApp(tester);

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionStartGame);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(find.text(l10n.setupSummaryTitle), findsOneWidget);
      expect(
        find.text(l10n.turnIntroTeam(l10n.teamDefaultName(1))),
        findsNothing,
      );
    });
  });

  group('la version complete eteint la publicite', () {
    testWidgets('un achat en base supprime l interstitiel de lancement', (
      tester,
    ) async {
      // MONETISATION.md : posseder la version complete doit masquer TOUS les
      // points d entree publicitaires. C est la moitie de ce qu on vend, et
      // c est la seule qui se verifie sans magasin.
      await installDeck('animaux', easy: 15, medium: 15, hard: 15);
      await EntitlementRepository(db).grantFullVersion(DateTime.utc(2026, 8));

      var interstitiels = 0;
      await pumpApp(
        tester,
        passerelle: fakeConsentGateway(_accorde),
        interstitiel: ({required loadTimeout}) async {
          interstitiels++;
          return true;
        },
      );

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionStartGame);

      expect(interstitiels, 0);
      expect(launchedGame(tester).deck, hasLength(GameConfig.defaultCardCount));
    });

    testWidgets('sans achat, la pub est bien demandee', (tester) async {
      // Le temoin du test precedent : sans lui, une erreur de cablage rendrait
      // le compteur nul pour de mauvaises raisons.
      await installDeck('animaux', easy: 15, medium: 15, hard: 15);

      var interstitiels = 0;
      await pumpApp(
        tester,
        passerelle: fakeConsentGateway(_accorde),
        interstitiel: ({required loadTimeout}) async {
          interstitiels++;
          return true;
        },
      );

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionStartGame);

      expect(interstitiels, 1);
    });
  });

  group('une categorie premium se debloque', () {
    testWidgets('elle porte un bouton plutot qu un cadenas muet', (
      tester,
    ) async {
      await installDeck('animaux', easy: 15, medium: 15, hard: 15);
      await installDeck('disney', premium: true);
      await pumpApp(tester);

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);
      await tapText(tester, l10n.setupCustomize);

      expect(find.text(l10n.deckUnlockAction), findsOneWidget);
    });

    testWidgets('la version complete la rend selectionnable, sans bouton', (
      tester,
    ) async {
      await installDeck('animaux', easy: 15, medium: 15, hard: 15);
      await installDeck('disney', premium: true);
      await EntitlementRepository(db).grantFullVersion(DateTime.utc(2026, 8));
      await pumpApp(tester);

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);
      await tapText(tester, l10n.setupCustomize);

      expect(
        find.text(l10n.deckUnlockAction),
        findsNothing,
        reason:
            'proposer de debloquer a qui a paye est le defaut que '
            'MONETISATION.md nomme explicitement',
      );

      final selection = ProviderScope.containerOf(
        tester.element(find.byType(CekoiApp)),
      ).read(setupControllerProvider).deckIds;

      expect(
        selection,
        contains('disney'),
        reason: 'debloquee, elle rentre dans la preselection de R7.9',
      );
    });

    testWidgets('une recompense en base l ouvre, sans rien acheter', (
      tester,
    ) async {
      await installDeck('animaux', easy: 15, medium: 15, hard: 15);
      await installDeck('disney', premium: true);
      await EntitlementRepository(
        db,
      ).grantDeck('disney', DateTime.utc(2026, 8));
      await pumpApp(tester);

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);
      await tapText(tester, l10n.setupCustomize);

      expect(find.text(l10n.deckUnlockAction), findsNothing);
    });
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
    await setTeamCount(tester, 3);
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
      hasLength(GameConfig.defaultCardCount),
      reason: 'le paquet ne suit plus le nombre d équipes (R6.1)',
    );
  });

  testWidgets('R8.1 — le compteur monte d une équipe, et redescend', (
    tester,
  ) async {
    // R8.1 ne pose aucune limite haute, et R8.3 en pose une basse à deux. Le
    // compteur doit donc monter sans butée et s'arrêter en bas — un « moins »
    // qui passe à une équipe donnerait une partie sans adversaire.
    await installDeck('animaux', easy: 15, medium: 15, hard: 15);
    await pumpApp(tester);

    await tapText(tester, l10n.homePlay);
    await tapText(tester, l10n.modeFamily);
    await tapText(tester, l10n.actionContinue);
    await tapText(tester, l10n.actionContinue);

    expect(find.byType(TextField), findsNWidgets(2));

    await tester.tap(find.bySemanticsLabel(l10n.teamCountMore));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));

    await tester.tap(find.bySemanticsLabel(l10n.teamCountFewer));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));

    // En butée basse, le bouton est désactivé : un tap de plus ne fait rien.
    await tester.tap(find.bySemanticsLabel(l10n.teamCountFewer));
    await tester.pumpAndSettle();
    expect(
      find.byType(TextField),
      findsNWidgets(2),
      reason: 'deux équipes est le minimum d une partie (R8.3)',
    );
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

    await setTeamCount(tester, 3);
    await tester.enterText(find.byType(TextField).at(0), 'Les Verts');
    await tester.enterText(find.byType(TextField).at(2), 'Les Bleus');
    await tester.pumpAndSettle();

    await setTeamCount(tester, 2);
    await setTeamCount(tester, 3);

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
    testWidgets('le mode Sans filtre est jouable sans rien toucher', (
      tester,
    ) async {
      // Le cas qui a fait remonter la règle : ce mode n'a aucun profil, donc
      // l'étape s'ouvrait sur une sélection vide et il fallait cocher les
      // catégories une par une avant de pouvoir continuer.
      //
      // Depuis R7.10 l'étape 2 de ce mode est le choix du vivier — mais la
      // sélection des catégories doit être faite quand même, sinon on
      // arriverait aux réglages avec un paquet vide et un bouton de lancement
      // grisé sans explication. C'est l'écran du vivier qui la porte.
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

      // R7.10 : l'étape 2 de ce mode est le choix du vivier, au même rang que
      // les catégories en Famille — cinq étapes des deux côtés.
      expect(find.text(l10n.setupPoolTitle), findsOneWidget);
      expect(find.text(l10n.setupStep(2, 5)), findsOneWidget);

      await tapText(tester, l10n.adultPoolAll);
      expect(find.text(l10n.setupSettingsTitle), findsOneWidget);

      // R7.1 : ce mode tire aussi dans le tout public, donc les deux
      // catégories sont retenues, et les 45 cartes avec.
      final setup = ProviderScope.containerOf(
        tester.element(find.byType(CekoiApp)),
      ).read(setupControllerProvider);
      expect(setup.deckIds, containsAll(['animaux', 'sans-filtres']));
      // Tout le paquet, donc le vivier n'est pas réduit : sans cette
      // assertion, un choix qui répondrait toujours « rien d'autre » passerait.
      expect(setup.adultOnly, isFalse);
    });

    testWidgets('R7.10 — le retour depuis les réglages ramène au vivier', (
      tester,
    ) async {
      // L'étape 2 est une étape comme une autre : on doit pouvoir y revenir
      // pour changer d'avis, exactement comme sur les catégories en Famille.
      await installDeck('animaux');
      await installDeck('sans-filtres', audience: Audience.adult);
      await pumpApp(tester);

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeAdult);
      await tapText(tester, l10n.adultConfirmAccept);
      await tapText(tester, l10n.adultPoolAll);
      expect(find.text(l10n.setupSettingsTitle), findsOneWidget);

      // `pageBack` cherche une infobulle « Back » : l'application est en
      // français, son bouton dit « Retour ».
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.setupPoolTitle), findsOneWidget);
      expect(find.text(l10n.setupStep(2, 5)), findsOneWidget);

      // Et revenir n'a pas défait la présélection de R7.9.
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(CekoiApp)),
        ).read(setupControllerProvider).deckIds,
        containsAll(['animaux', 'sans-filtres']),
      );
    });

    testWidgets(
      "R7.10 — le vivier est une étape, pas une variante de l'écran des modes",
      (tester) async {
        // Deux défauts corrigés l'un après l'autre, que ce test verrouille
        // ensemble : « rien d'autre » avait d'abord été posé en troisième
        // tuile de mode, puis dans une boîte de dialogue accrochée à la
        // confirmation d'âge. C'est une décision de contenu — elle a son écran
        // d'étape, comme les catégories en Famille.
        await installDeck('animaux');
        await installDeck('sans-filtres', audience: Audience.adult);
        await pumpApp(tester);

        await tapText(tester, l10n.homePlay);

        // L'écran des modes n'a que deux directions, et ne dit rien du vivier.
        expect(find.text(l10n.modeFamily), findsOneWidget);
        expect(find.text(l10n.modeAdult), findsOneWidget);
        expect(find.text(l10n.adultPoolAll), findsNothing);
        expect(find.text(l10n.adultPoolOnly), findsNothing);

        await tapText(tester, l10n.modeAdult);

        // R7.3 : la confirmation d'âge ne fait que ça — elle ne porte aucun
        // choix de contenu.
        expect(find.text(l10n.adultConfirmTitle), findsOneWidget);
        expect(find.text(l10n.adultPoolOnly), findsNothing);

        await tapText(tester, l10n.adultConfirmAccept);

        // Et le choix arrive après, sur son propre écran d'étape.
        expect(find.text(l10n.setupPoolTitle), findsOneWidget);
        expect(find.text(l10n.adultPoolAll), findsOneWidget);
        expect(find.text(l10n.adultPoolOnly), findsOneWidget);
      },
    );

    testWidgets(
      "R7.9 — l'étape du vivier attend le catalogue avant de laisser choisir",
      (tester) async {
        // Les deux cartes ne dépendent pas du catalogue, mais la présélection
        // si : avancer avant qu'il ait répondu partirait avec un paquet vide
        // et un bouton de lancement grisé sans explication. Sans ce test, le
        // garde était une promesse de commentaire — remplacer l'attente par la
        // liste nue laissait toute la suite verte.
        await installDeck('animaux');
        await installDeck('sans-filtres', audience: Audience.adult);

        // Un catalogue qui ne répond jamais : l'écran doit rester à sa place.
        await pumpApp(
          tester,
          catalogueAdulte: Completer<DeckCatalog>().future,
        );

        await tapText(tester, l10n.homePlay);
        await tapText(tester, l10n.modeAdult);

        // Pas de `pumpAndSettle` à partir d'ici : l'indicateur de chargement
        // tourne sans fin, et attendre la stabilité ne rendrait jamais la main.
        await tester.tap(find.text(l10n.adultConfirmAccept));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(l10n.setupPoolTitle), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(l10n.adultPoolAll), findsNothing);
        expect(find.text(l10n.adultPoolOnly), findsNothing);
      },
    );

    for (final (libelle, taille, echelle) in const [
      // La géométrie Android la plus répandue, à l'échelle par défaut. La
      // version en boîte de dialogue y débordait de 28 px, et c'est la seconde
      // option qui passait sous le bord — la moitié de la décision, devenue
      // intapable. L'écran d'étape défile, mais ça se vérifie.
      ('un ecran courant', Size(360, 800), 1.0),
      // Le même écran avec le texte agrandi par le système. Rien ne borne
      // `textScaler` dans l'application, donc le réglage s'applique en entier.
      ('un texte agrandi', Size(360, 800), 1.3),
      // Un petit écran, autre hauteur utile courte.
      ('un petit ecran', Size(360, 640), 1.0),
      // Pas de cas paysage : l'application est verrouillée en portrait. C'est
      // l'accueil, qui y débordait de 268 px, qui a motivé le verrou.
    ]) {
      testWidgets("R7.10 — l'étape du vivier tient sur $libelle", (
        tester,
      ) async {
        await installDeck('animaux');
        await installDeck('sans-filtres', audience: Audience.adult);
        await pumpApp(tester, taille: taille, echelleTexte: echelle);

        await tapText(tester, l10n.homePlay);
        await tapText(tester, l10n.modeAdult);
        await tapText(tester, l10n.adultConfirmAccept);

        // Un débordement de `RenderFlex` remonte comme exception de test.
        expect(tester.takeException(), isNull);

        // Et la seconde option reste atteignable, quitte à faire défiler :
        // c'est ce que « tenir » veut dire ici.
        final option = find.text(l10n.adultPoolOnly);
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        await tester.tap(option);
        await tester.pumpAndSettle();

        expect(
          ProviderScope.containerOf(
            tester.element(find.byType(CekoiApp)),
          ).read(setupControllerProvider).adultOnly,
          isTrue,
        );
      });
    }

    testWidgets('R7.1 — « rien d autre » retire les cartes tout public', (
      tester,
    ) async {
      // La variante ne change pas de mode : même confirmation d'âge (R7.3),
      // même parcours (R7.10). Seul le vivier maigrit.
      await installDeck('animaux', easy: 10, medium: 10, hard: 10);
      await installDeck(
        'apero',
        audience: Audience.adult,
        minAge: MinAge.eighteen,
        easy: 10,
        medium: 10,
        hard: 10,
      );
      await pumpApp(tester);

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeAdult);
      await tapText(tester, l10n.adultConfirmAccept);
      await tapText(tester, l10n.adultPoolOnly);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CekoiApp)),
      );
      expect(container.read(setupControllerProvider).adultOnly, isTrue);

      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionContinue);
      await tapText(tester, l10n.actionStartGame);

      final tirees = launchedGame(tester).deck;
      expect(tirees, isNotEmpty);
      expect(
        tirees.map((c) => c.audience).toSet(),
        {Audience.adult},
        reason: 'aucune carte tout public dans le paquet',
      );
    });

    testWidgets('le mode Famille garde ses cinq étapes', (tester) async {
      // Rien d'autre ne fixe la longueur du parcours familial : raccourcir
      // `setupStepsFor` laisserait toute la suite verte.
      await installDeck('animaux');
      await pumpApp(tester);

      await tapText(tester, l10n.homePlay);
      await tapText(tester, l10n.modeFamily);

      expect(find.text(l10n.setupDecksTitle), findsOneWidget);
      expect(find.text(l10n.setupStep(2, 5)), findsOneWidget);
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
      await tapText(tester, l10n.actionStartGame);
      expect(
        launchedGame(tester).deck,
        hasLength(GameConfig.defaultCardCount),
      );
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
    // Et sans rien avoir écrit non plus : « sans rien avoir choisi » se
    // vérifie dans l'état, pas seulement à l'écran.
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(CekoiApp)),
      ).read(setupControllerProvider).adultOnly,
      isFalse,
    );

    await tapText(tester, l10n.modeAdult);
    await tapText(tester, l10n.adultConfirmAccept);
    // R7.10 : accepter mène à l'étape 2 de ce mode, le choix du vivier.
    expect(find.text(l10n.setupPoolTitle), findsOneWidget);
  });
}

/// Une passerelle qui ne répond jamais.
///
/// Ni réponse ni erreur : le cas réel d une `MissingPluginException` qui
/// s échappe du plugin sans appeler aucun écouteur.
class _MuteGateway implements ConsentGateway {
  const _MuteGateway();

  @override
  Future<ConsentState> gather() => Completer<ConsentState>().future;

  @override
  Future<ConsentState> changeChoice() => Completer<ConsentState>().future;
}

/// Un consentement accorde, pour les tests qui veulent atteindre la pub.
///
/// Sans lui le portillon s arrete sur « pas de reponse, pas de pub » et rend
/// la main tout de suite : l ecran de lancement est remplace avant d avoir ete
/// vu, et un test qui regarde deux frames trop tot passe pour de mauvaises
/// raisons.
const _accorde = ConsentState(canRequestAds: true, canChangeChoice: true);

/// Un interstitiel qui met du temps a repondre.
///
/// Sert a observer l ecran de lancement pendant que la pub charge : sans lui,
/// l ecran est traverse en une frame et rien n est visible.
class _SlowInterstitial {
  Future<bool> call({required Duration loadTimeout}) =>
      Completer<bool>().future;
}
