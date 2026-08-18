import 'dart:async';

import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/preferences.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/data/repositories/preferences_repository.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/features/play/presentation/game_screen.dart';
import 'package:cekoi/features/play/presentation/widgets/action_zone.dart';
import 'package:cekoi/features/play/presentation/widgets/game_card_face.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/feedback/feedback.dart';
import 'package:flutter/material.dart';
// `JSONMethodCodec` et `MethodCall`, pour simuler le retour système.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fixtures.dart';
import '../../support/providers.dart';
import 'play_controller_test.dart' show FakeClock;

/// Une partie dont la carte du dessus porte un texte reconnaissable.
///
/// La manche passe par la fixture et non par un `copyWith` : `roundIndex` et
/// `turn.round` doivent rester d'accord, sinon `canPass` répond sur une manche
/// et l'affichage sur une autre.
GameState _withNamedCard({int roundIndex = 1}) {
  final autres = testCards(5);
  final carte = domain.Card(
    id: 'deck:tarte',
    deckId: 'deck',
    text: 'Tarte aux pommes',
    audience: autres.first.audience,
    difficulty: Difficulty.medium,
    origin: autres.first.origin,
  );

  return testGame(cardCount: 6, roundIndex: roundIndex).copyWith(
    deck: [carte, ...autres],
    pile: [carte.id, for (final c in autres) c.id],
  );
}

void main() {
  late AppLocalizations l10n;
  late FakeClock clock;
  late ProviderContainer container;

  /// Ce que l'écran a demandé au son et à la vibration.
  ///
  /// Ni l'un ni l'autre n'a d'effet observable dans l'arbre de widgets : sans
  /// ce témoin, les supprimer ne ferait rougir aucun test.
  late RecordingFeedback feedback;
  late GoRouter routeur;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  setUp(() {
    feedback = RecordingFeedback();
  });

  /// Monte l'écran de jeu sur une partie donnée.
  ///
  /// [surUnePile] empile la partie au-dessus de l'accueil, comme l'étape des
  /// équipes le fait en vrai : sans route en dessous, un retour n'a rien à
  /// dépiler et le comportement testé n'existe pas.
  Future<void> pumpScreen(
    WidgetTester tester, {
    GameState? game,
    bool surUnePile = false,

    /// La géométrie de l'appareil. Par défaut un écran très haut, pour que la
    /// mise en page ne soit jamais ce qui fait échouer un test de contenu.
    Size? taille,

    /// L'agrandissement du texte par le système. Rien ne le borne dans
    /// l'application : le réglage s'applique en entier.
    double echelleTexte = 1,

    /// Réglages de l'appareil. `null` laisse les valeurs par défaut, tout
    /// activé — l'état de quelqu'un qui n'a jamais rien touché.
    AppPreferences? reglages,
  }) async {
    clock = FakeClock();
    tester.view.physicalSize = taille ?? const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = echelleTexte;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monotonicClockProvider.overrideWithValue(clock.read),
          screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
          currentPreferencesProvider.overrideWithValue(
            reglages ?? AppPreferences.defaults,
          ),
          gameFeedbackProvider.overrideWithValue(feedback),
        ],
        // Routeur minimal plutôt qu'un simple `home` : quitter la partie
        // ramène à l'accueil, et sans routeur dans le contexte l'écran lève
        // au lieu de naviguer.
        child: MaterialApp.router(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: routeur = GoRouter(
            initialLocation: surUnePile ? AppRoutes.home : AppRoutes.game,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const Scaffold(body: Text('accueil')),
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

    if (surUnePile) {
      unawaited(routeur.push(AppRoutes.game));
      await tester.pumpAndSettle();
    }

    container = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    container.read(currentGameProvider.notifier).game = game ?? testGame();
    await tester.pump();
  }

  GameState partie() => container.read(currentGameProvider)!;

  /// Traverse l'annonce du tour et son compte à rebours.
  Future<void> startTurn(WidgetTester tester) async {
    await tester.tap(find.text(l10n.actionStartTurn));
    await tester.pump();
    await clock.advance(tester, const Duration(seconds: 3));
  }

  /// Déclenche un retour système, comme le bouton ou le geste d'Android.
  Future<void> simulateSystemBack() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          const MethodCall('popRoute'),
        ),
        (_) {},
      );

  /// Termine proprement : sans ça, le `Timer` du chrono survit au test.
  Future<void> stopGame(WidgetTester tester) async {
    container.read(currentGameProvider.notifier).game = null;
    await tester.pump();
  }

  group("l'annonce du tour", () {
    testWidgets("nomme l'équipe et rappelle la contrainte", (tester) async {
      // R3.1 : aucun narrateur n'est désigné, l'équipe s'en charge.
      await pumpScreen(tester);

      expect(find.text(l10n.turnIntroTeam('team-1')), findsOneWidget);
      expect(find.text(l10n.turnIntroPassPhone), findsOneWidget);
      expect(find.text(l10n.roundNameOneWord), findsOneWidget);
      expect(find.text(l10n.roundRuleOneWord), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('le compte à rebours remplace le bouton', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text(l10n.actionStartTurn));
      await tester.pump();

      expect(find.text(l10n.actionStartTurn), findsNothing);
      expect(find.text(l10n.gameSecondsLeft(3)), findsOneWidget);

      await clock.advance(tester, const Duration(seconds: 1));
      expect(find.text(l10n.gameSecondsLeft(2)), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('aucune carte ne se voit avant le départ', (tester) async {
      // Le narrateur suivant a le téléphone en main pendant l'annonce : voir
      // la carte à ce moment ruinerait le tour.
      final game = testGame();
      await pumpScreen(tester, game: game);

      expect(find.text(game.deck.first.text), findsNothing);
      await stopGame(tester);
    });

    for (final (libelle, taille, echelle) in const [
      // La géométrie Android la plus répandue, à l'échelle par défaut.
      ('un ecran courant', Size(360, 800), 1.0),
      // Le même écran avec le texte agrandi par le système.
      ('un texte agrandi', Size(360, 800), 1.3),
      // Une hauteur utile courte.
      ('un petit ecran', Size(360, 640), 1.0),
      // Le cumul des deux, soit le pire cas réellement atteignable.
      ('un petit ecran au texte agrandi', Size(360, 640), 1.3),
    ]) {
      testWidgets("l'annonce tient sur $libelle", (tester) async {
        // `SPEC.md` : un écran doit tenir, ou défiler. Celui-ci ne faisait ni
        // l'un ni l'autre — il débordait de 132 px sur un 360 × 640, et de
        // 454 px avec le texte agrandi, emportant « C'est parti » sous le bord.
        // C'est l'écran vu à chaque tour.
        //
        // Trouvé en tapant sur « Lancer la partie » depuis un test de
        // géométrie de la configuration : rien ici ne le couvrait.
        await pumpScreen(tester, taille: taille, echelleTexte: echelle);

        // Un débordement de `RenderFlex` remonte comme exception de test.
        expect(tester.takeException(), isNull);

        // Et le bouton reste entièrement à l'écran : c'est ce que « tenir »
        // veut dire ici. Le défilement n'aide que si l'on peut l'atteindre,
        // donc on le fait défiler d'abord, comme le joueur le ferait.
        final bouton = find.widgetWithText(ActionZone, l10n.actionStartTurn);
        await tester.ensureVisible(bouton);
        await tester.pumpAndSettle();

        final rect = tester.getRect(bouton);
        expect(rect.top, greaterThanOrEqualTo(0.0));
        expect(
          rect.bottom,
          lessThanOrEqualTo(taille.height),
          reason: "« C'est parti » sort de l'écran",
        );

        // Et il lance vraiment le tour : un bouton visible mais inerte ne
        // vaudrait pas mieux.
        await tester.tap(bouton);
        await tester.pump();
        expect(find.text(l10n.gameSecondsLeft(3)), findsOneWidget);

        await stopGame(tester);
      });
    }

    testWidgets("quand il y a de la place, l'annonce reste centrée", (
      tester,
    ) async {
      // Le témoin du `minHeight` : sans lui l'écran cesse de déborder — un
      // défilement ne déborde jamais — mais l'annonce se colle en haut, et
      // les quatre tests de géométrie restent verts. C'est le seul qui rougit
      // si on retire la contrainte.
      //
      // Sur l'écran haut par défaut, et non sur un 360 × 800 où l'espace libre
      // se compte en dizaines de pixels : la marge de détection y serait du
      // même ordre que la tolérance, et une règle de manche rallongée d'une
      // ligne suffirait à faire rougir le test pour une autre raison.
      await pumpScreen(tester);

      // Tout est dérivé de la géométrie rendue : la zone défilante, ses
      // marges, et les deux extrémités du bloc de texte.
      final zone = tester.getRect(find.byType(SingleChildScrollView));
      final entete = tester.getRect(find.text(l10n.roundStep(2, 3)));
      final pied = tester.getRect(find.text(l10n.turnIntroPassPhone));

      // Les marges sont lues sur le widget, pas recopiées : les réécrire ici
      // ferait rougir « l'annonce n'est pas centrée » à la première retouche
      // du `padding`, alors que la mise en page serait restée centrée.
      final marges = tester
          .widget<Padding>(
            find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Padding),
                )
                .first,
          )
          .padding
          .resolve(TextDirection.ltr);

      final airAuDessus = entete.top - (zone.top + marges.top);
      final airEnDessous = (zone.bottom - marges.bottom) - pied.bottom;

      expect(
        airAuDessus,
        greaterThan(50),
        reason: "l'annonce est collée en haut au lieu d'occuper la zone",
      );
      expect(
        airAuDessus,
        closeTo(airEnDessous, 4),
        reason: "l'annonce n'est pas centrée dans la zone qui lui reste",
      );

      await stopGame(tester);
    });
  });

  group("l'écran de jeu", () {
    testWidgets('affiche la carte, le chrono et les deux actions', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startTurn(tester);

      expect(find.text(partie().currentCard!.text), findsOneWidget);
      expect(find.text(l10n.actionFound), findsOneWidget);
      expect(find.text(l10n.actionPass), findsOneWidget);
      expect(find.text(l10n.gameSecondsLeft(60)), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('Trouvé marque un point et passe à la carte suivante', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startTurn(tester);
      final premiere = partie().currentCard!.text;

      await tester.tap(find.text(l10n.actionFound));
      await tester.pump();

      expect(find.text(premiere), findsNothing);
      expect(partie().turn!.score, 1);
      await stopGame(tester);
    });

    testWidgets('un glissement vers la droite vaut Trouvé', (tester) async {
      // `SPEC.md` : le glissement double les boutons pour ceux qui prennent le
      // coup de main.
      await pumpScreen(tester);
      await startTurn(tester);
      final premiere = partie().currentCard!.text;

      await tester.fling(find.text(premiere), const Offset(300, 0), 1000);
      await tester.pump();

      expect(partie().turn!.score, 1);
      await stopGame(tester);
    });

    testWidgets('un glissement vers la gauche vaut Passer', (tester) async {
      await pumpScreen(tester);
      await startTurn(tester);
      final premiere = partie().currentCard!.text;

      await tester.fling(find.text(premiere), const Offset(-300, 0), 1000);
      await tester.pump();

      expect(partie().turn!.score, 0);
      expect(partie().pile.last, partie().deck.first.id);
      await stopGame(tester);
    });

    testWidgets('R3.4 — Passer est grisé sur la dernière carte', (
      tester,
    ) async {
      await pumpScreen(tester, game: testGame(cardCount: 2));
      await startTurn(tester);

      var passer = tester.widget<ActionZone>(
        find.widgetWithText(ActionZone, l10n.actionPass),
      );
      expect(passer.onPressed, isNotNull, reason: 'deux cartes au paquet');

      await tester.tap(find.text(l10n.actionFound));
      await tester.pump();

      passer = tester.widget<ActionZone>(
        find.widgetWithText(ActionZone, l10n.actionPass),
      );
      expect(passer.onPressed, isNull);
      expect(find.text(l10n.gamePassLocked), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('la carte ne montre que son texte', (tester) async {
      // L'écran de jeu ne porte rien d'autre que la carte, quelle que soit la
      // manche : le narrateur doit le lire d'un coup d'œil, à bout de bras.
      await pumpScreen(tester, game: _withNamedCard());
      await startTurn(tester);

      expect(find.text('Tarte aux pommes'), findsOneWidget);
      expect(find.byType(GameCardFace), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GameCardFace),
          matching: find.byType(Text),
        ),
        findsOneWidget,
        reason: 'Un seul texte sur la carte, et c’est le sien',
      );
      await stopGame(tester);
    });

    testWidgets('en manche 3, la carte est la même', (tester) async {
      await pumpScreen(tester, game: _withNamedCard(roundIndex: 2));
      await startTurn(tester);

      expect(find.text('Tarte aux pommes'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GameCardFace),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      await stopGame(tester);
    });
  });

  group('on tape sans regarder, et le doigt bouge', () {
    testWidgets('un tap dont le doigt roule de 40 px vaut un tap', (
      tester,
    ) async {
      // Retour de partie : « des taps sur Trouvé qui passent pas ». Un
      // `TapGestureRecognizer` ordinaire rejette le tap dès 18 px de dérive ;
      // à bout de bras, debout, sans regarder l'écran, le pouce roule bien
      // plus que ça. L'action était perdue en silence, au pire moment — chrono
      // qui tourne, table qui crie.
      await pumpScreen(tester, game: testGame(cardCount: 12));
      await startTurn(tester);
      final avant = partie().pile.length;

      final geste = await tester.startGesture(
        tester.getCenter(find.widgetWithText(ActionZone, l10n.actionFound)),
      );
      await geste.moveBy(const Offset(40, 12));
      await geste.up();
      await tester.pump();

      expect(
        partie().pile.length,
        avant - 1,
        reason: 'le doigt a roulé, mais le narrateur a bien tapé Trouvé',
      );
      await stopGame(tester);
    });

    testWidgets('un glissement lent mais franc passe la carte', (tester) async {
      // L'ancienne version décidait sur la seule vélocité : un glissement lent
      // ne faisait rien du tout, et le geste semblait ignoré.
      await pumpScreen(tester, game: testGame(cardCount: 12));
      await startTurn(tester);
      final avant = [...partie().pile];

      final geste = await tester.startGesture(
        tester.getCenter(find.byType(GameCardFace)),
      );
      for (var i = 0; i < 10; i++) {
        await geste.moveBy(
          const Offset(-30, 0),
          timeStamp: Duration(milliseconds: 40 * (i + 1)),
        );
      }
      await geste.up();
      await tester.pump();

      expect(
        partie().turn!.results.single.outcome,
        TurnOutcome.passed,
        reason: 'lent ou vif, un geste franc reste un geste',
      );
      expect(partie().pile.last, avant.first);
      await stopGame(tester);
    });

    testWidgets('une derive de quelques pixels ne decide de rien', (
      tester,
    ) async {
      // Le pire des deux mondes serait qu'une hésitation passe la carte : elle
      // ressortirait plus tard sans que personne comprenne pourquoi.
      await pumpScreen(tester, game: testGame(cardCount: 12));
      await startTurn(tester);
      final avant = [...partie().pile];

      final geste = await tester.startGesture(
        tester.getCenter(find.byType(GameCardFace)),
      );
      await geste.moveBy(const Offset(-18, 0));
      await geste.up();
      await tester.pump();

      expect(partie().pile, avant);
      expect(partie().turn!.results, isEmpty);
      await stopGame(tester);
    });
  });

  group("R3.9 — en manche 1, l'action Passer n'est pas à l'écran", () {
    testWidgets('la zone Passer est absente, pas grisée', (tester) async {
      // Un bouton mort pendant toute une manche se lit comme une panne.
      await pumpScreen(tester, game: testGame(roundIndex: 0));
      await startTurn(tester);

      expect(find.text(l10n.actionPass), findsNothing);
      expect(find.text(l10n.actionFound), findsOneWidget);
      expect(
        find.text(l10n.gamePassLocked),
        findsNothing,
        reason: "Rien à expliquer : il n'y a pas de bouton",
      );
      await stopGame(tester);
    });

    testWidgets('seule, la zone Trouvé est plus basse qu à deux', (
      tester,
    ) async {
      // Retour d'usage : seule au bas de l'écran, la zone gardait la moitié de
      // la hauteur et paraissait démesurée. Elle descend à un tiers — mais
      // reste une zone qu'on tape sans viser, pas un bouton ordinaire.
      Future<double> hauteurDeTrouve(int roundIndex) async {
        await pumpScreen(tester, game: testGame(roundIndex: roundIndex));
        await startTurn(tester);
        final hauteur = tester
            .getSize(find.widgetWithText(ActionZone, l10n.actionFound))
            .height;
        await stopGame(tester);
        return hauteur;
      }

      final seule = await hauteurDeTrouve(0);
      final partagee = await hauteurDeTrouve(1);

      expect(
        seule,
        lessThan(partagee),
        reason: 'la zone seule ne garde pas la moitié basse',
      );
      // Une proportion, et non un nombre de pixels : la vue de test fait 2000
      // de haut, si bien qu'un seuil absolu de 120 resterait vert même en
      // réduisant la zone à 6 % de l'écran — il ne garderait rien.
      expect(
        seule,
        greaterThan(partagee * 0.5),
        reason: 'elle doit rester une cible qu on tape sans regarder',
      );
    });

    testWidgets('elle revient en manche 2', (tester) async {
      // Cas de contrôle : sans lui, retirer *toujours* la zone passerait.
      await pumpScreen(tester, game: testGame(roundIndex: 1));
      await startTurn(tester);

      expect(find.text(l10n.actionPass), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('le glissement vers la gauche ne passe pas non plus', (
      tester,
    ) async {
      // Le geste double les deux zones. Ce qui rend la manche 1 étanche est le
      // réducteur, pas la garde d'écran : retirer `game.canPass` de
      // `_CardZone` ne fait rougir aucun test, parce que l'événement part et
      // se fait refuser sans rien changer. La garde évite l'envoi inutile ; la
      // règle, elle, tient plus bas.
      await pumpScreen(tester, game: testGame(roundIndex: 0));
      await startTurn(tester);
      final avant = partie();

      await tester.fling(
        find.byType(GameCardFace),
        const Offset(-300, 0),
        1000,
      );
      await tester.pump();

      expect(partie().pile, avant.pile);
      expect(partie().turn!.results, isEmpty);
      await stopGame(tester);
    });

    testWidgets('le même glissement passe bien la carte en manche 2', (
      tester,
    ) async {
      // Cas de contrôle du test précédent : sans lui, un geste mort dans
      // toutes les manches le laisserait vert.
      await pumpScreen(tester, game: testGame(roundIndex: 1));
      await startTurn(tester);
      final avant = partie();

      await tester.fling(
        find.byType(GameCardFace),
        const Offset(-300, 0),
        1000,
      );
      await tester.pump();

      expect(partie().pile, isNot(avant.pile));
      expect(
        partie().turn!.results.single.outcome,
        TurnOutcome.passed,
        reason: 'le glissement gauche passe la carte',
      );
      await stopGame(tester);
    });
  });

  group('les dix dernières secondes se sentent sans regarder', () {
    testWidgets('chaque seconde de la fin sonne et vibre', (tester) async {
      // Le narrateur a les yeux sur la carte : c'est par l'oreille et la main
      // qu'il doit sentir la fin arriver.
      await pumpScreen(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 12)),
      );
      await startTurn(tester);

      await clock.advance(tester, const Duration(seconds: 2));
      feedback.calls.clear();
      expect(partie().remaining, const Duration(seconds: 10));

      await clock.advance(tester, const Duration(seconds: 3));

      expect(
        feedback.compte('son:tick'),
        3,
        reason: 'Une fois par seconde, pas une fois par tic',
      );
      expect(feedback.compte('vibration:tick'), 3);
      await stopGame(tester);
    });

    testWidgets('son coupé, la vibration reste', (tester) async {
      // Le réglage ne vaut que s'il coupe vraiment quelque chose : sans cette
      // vérification, les deux interrupteurs seraient décoratifs.
      await pumpScreen(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 12)),
        reglages: const AppPreferences(soundEnabled: false),
      );
      await startTurn(tester);

      await clock.advance(tester, const Duration(seconds: 2));
      feedback.calls.clear();
      await clock.advance(tester, const Duration(seconds: 3));

      expect(feedback.compte('son:tick'), 0);
      expect(
        feedback.compte('vibration:tick'),
        3,
        reason: 'les deux réglages sont indépendants',
      );
      await stopGame(tester);
    });

    testWidgets('vibration coupée, le son reste', (tester) async {
      await pumpScreen(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 12)),
        reglages: const AppPreferences(hapticsEnabled: false),
      );
      await startTurn(tester);

      await clock.advance(tester, const Duration(seconds: 2));
      feedback.calls.clear();
      await clock.advance(tester, const Duration(seconds: 3));

      expect(feedback.compte('son:tick'), 3);
      expect(feedback.compte('vibration:tick'), 0);
      await stopGame(tester);
    });

    testWidgets('les deux coupés, le tour se joue en silence', (tester) async {
      await pumpScreen(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 12)),
        reglages: const AppPreferences(
          soundEnabled: false,
          hapticsEnabled: false,
        ),
      );
      await startTurn(tester);

      await clock.advance(tester, const Duration(seconds: 2));
      feedback.calls.clear();
      await clock.advance(tester, const Duration(seconds: 3));

      expect(feedback.calls, isEmpty);
      await stopGame(tester);
    });

    testWidgets('au-dessus du seuil, rien ne se déclenche', (tester) async {
      await pumpScreen(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 60)),
      );
      await startTurn(tester);
      feedback.calls.clear();

      await clock.advance(tester, const Duration(seconds: 5));

      expect(
        feedback.calls,
        isEmpty,
        reason: 'Sonner pendant tout le tour rendrait le signal inutile',
      );
      await stopGame(tester);
    });
  });

  group('R3.6, R3.6 bis — la fin du tour se signale, et se raconte', () {
    /// Le fond de la zone nommée. C'est lui qui bat (R3.6 bis).
    Color? fondDe(WidgetTester tester, String label) {
      final boite = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.widgetWithText(ActionZone, label),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return (boite.decoration as BoxDecoration).color;
    }

    /// Joue jusqu'au buzzer, sans jamais trancher de carte.
    Future<void> jusquAuBuzzer(WidgetTester tester) async {
      await pumpScreen(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 12)),
      );
      await startTurn(tester);
      feedback.calls.clear();
      await clock.advance(tester, const Duration(seconds: 12));
    }

    testWidgets('le buzzer est franc, et distinct du tic du décompte', (
      tester,
    ) async {
      // Le tic s'arrêtait à une seconde : rien ne marquait le zéro. Le
      // narrateur, téléphone à bout de bras, découvrait la fin du tour parce
      // que l'écran avait changé.
      await jusquAuBuzzer(tester);

      expect(partie().phase, GamePhase.turnSummary);
      expect(feedback.calls, contains('son:buzzer'));
      expect(feedback.calls, contains('vibration:buzzer'));
      expect(
        feedback.compte('son:tick'),
        9,
        reason:
            'le tic va de 9 à 1 : le zéro appartient au buzzer, seul, '
            'sinon les deux sons se superposent et se brouillent',
      );
    });

    testWidgets('un paquet vidé ne buzze pas : ce n est pas une interruption', (
      tester,
    ) async {
      await pumpScreen(tester, game: testGame(cardCount: 2));
      await startTurn(tester);
      feedback.calls.clear();

      await tester.tap(find.text(l10n.actionFound));
      await tester.pump();
      await tester.tap(find.text(l10n.actionFound));
      await tester.pump();

      expect(partie().phase, GamePhase.turnSummary);
      expect(partie().pile, isEmpty);
      expect(
        feedback.calls,
        isNot(contains('son:buzzer')),
        reason: 'la dernière carte trouvée est une manche gagnée (R4.1)',
      );
    });

    testWidgets('son coupé, le buzzer vibre quand même', (tester) async {
      await pumpScreen(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 12)),
        reglages: const AppPreferences(soundEnabled: false),
      );
      await startTurn(tester);
      feedback.calls.clear();
      await clock.advance(tester, const Duration(seconds: 12));

      expect(feedback.calls, isNot(contains('son:buzzer')));
      expect(feedback.calls, contains('vibration:buzzer'));
    });

    testWidgets('la carte du buzzer est nommée au récapitulatif', (
      tester,
    ) async {
      // Son silence faisait croire à un bug : elle disparaissait sans un mot
      // et ressortait deux tours plus tard.
      await jusquAuBuzzer(tester);

      final auBuzzer = partie().cardAtBuzzer;
      expect(auBuzzer, isNotNull);
      expect(find.text(l10n.turnSummaryAtBuzzer), findsOneWidget);
      expect(find.text(auBuzzer!.text), findsOneWidget);
      expect(find.text(l10n.turnSummaryAtBuzzerHint), findsOneWidget);
    });

    testWidgets('rien à annoncer quand le paquet s est vidé', (tester) async {
      await pumpScreen(tester, game: testGame(cardCount: 2));
      await startTurn(tester);
      await tester.tap(find.text(l10n.actionFound));
      await tester.pump();
      await tester.tap(find.text(l10n.actionFound));
      await tester.pump();

      expect(find.text(l10n.turnSummaryAtBuzzer), findsNothing);
    });

    testWidgets(
      'les zones d action battent dans les trois dernieres secondes',
      (
        tester,
      ) async {
        // C'est la surface que le narrateur a sous les yeux — pas l'anneau du
        // chrono, qu'il ne regarde pas.
        await pumpScreen(
          tester,
          game: testGame(turnDuration: const Duration(seconds: 12)),
        );
        await startTurn(tester);

        ActionZone zone() =>
            tester.widget<ActionZone>(find.byType(ActionZone).first);

        await clock.advance(tester, const Duration(seconds: 8));
        expect(zone().urgent, isFalse, reason: 'il reste 4 secondes');

        await clock.advance(tester, const Duration(seconds: 1));
        expect(zone().urgent, isTrue, reason: 'il reste 3 secondes');
      },
    );

    testWidgets('la zone bat vraiment, et seulement sur la fin', (
      tester,
    ) async {
      // Le test precedent ne verifie que la circulation du booleen : retirer
      // le battement ou le `repeat` le laissait vert. C'est pourtant la moitie
      // visible de R3.6 bis.
      await pumpScreen(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 12)),
      );
      await startTurn(tester);

      await clock.advance(tester, const Duration(seconds: 8));
      final repos = fondDe(tester, l10n.actionFound);
      expect(repos, AppColors.deep, reason: '4 s : la zone est au repos');

      await tester.pump(const Duration(milliseconds: 250));
      expect(
        fondDe(tester, l10n.actionFound),
        repos,
        reason: 'au repos, la couleur ne bouge pas d une image a l autre',
      );

      // Sous trois secondes. Le battement part de sa valeur basse, qui est la
      // couleur de repos : c'est un quart de seconde plus tard qu'il se voit.
      await clock.advance(tester, const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      final haut = fondDe(tester, l10n.actionFound);
      expect(haut, isNot(repos), reason: '3 s : la zone s est eclaircie');

      await tester.pump(const Duration(milliseconds: 250));
      expect(
        fondDe(tester, l10n.actionFound),
        isNot(haut),
        reason: 'une couleur fixe ne se remarque pas : elle doit battre',
      );
      await stopGame(tester);
    });

    testWidgets('une zone desactivee par R3.4 ne bat pas', (tester) async {
      // Derniere carte du paquet en manche 2 : *Passer* est verrouille. Le
      // faire clignoter en rouge vif serait demander de taper la zone morte au
      // moment ou le narrateur ne regarde plus rien d'autre.
      await pumpScreen(
        tester,
        game: testGame(
          cardCount: 12,
          turnDuration: const Duration(seconds: 12),
        ),
      );
      await startTurn(tester);
      for (var i = 0; i < 11; i++) {
        await tester.tap(find.text(l10n.actionFound));
        await tester.pump();
      }
      await clock.advance(tester, const Duration(seconds: 9));

      expect(partie().pile, hasLength(1));
      expect(partie().canPass, isFalse, reason: 'R3.4');

      final passeAvant = fondDe(tester, l10n.actionPass);
      final trouveAvant = fondDe(tester, l10n.actionFound);
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        fondDe(tester, l10n.actionPass),
        passeAvant,
        reason: 'la zone verrouillee par R3.4 appelle un tap qu elle refuse',
      );
      expect(
        fondDe(tester, l10n.actionFound),
        isNot(trouveAvant),
        reason: 'temoin : dans le meme intervalle, la zone active a bouge',
      );
      await stopGame(tester);
    });

    testWidgets('vibration coupee, le buzzer sonne quand meme', (tester) async {
      await pumpScreen(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 12)),
        reglages: const AppPreferences(hapticsEnabled: false),
      );
      await startTurn(tester);
      feedback.calls.clear();
      await clock.advance(tester, const Duration(seconds: 12));

      expect(feedback.calls, contains('son:buzzer'));
      expect(feedback.calls, isNot(contains('vibration:buzzer')));
    });

    testWidgets('R9.1 — une partie reprise en recapitulatif ne buzze pas', (
      tester,
    ) async {
      // Le tour s'est termine hier. Buzzer a l'ouverture de l'application
      // annoncerait une fin qui n'a pas lieu maintenant.
      final finiAuChrono = testGame(turnDuration: const Duration(seconds: 12));
      await pumpScreen(
        tester,
        game: finiAuChrono.copyWith(
          phase: GamePhase.turnSummary,
          turn: finiAuChrono.turn!.copyWith(
            elapsed: const Duration(seconds: 12),
          ),
        ),
      );

      expect(partie().turnEndedOnTime, isTrue);
      expect(find.text(l10n.turnSummaryAtBuzzer), findsOneWidget);
      expect(
        feedback.calls,
        isNot(contains('son:buzzer')),
        reason: 'la partie est adoptee, elle n a pas bascule sous nos yeux',
      );
    });
  });

  group('quitter une partie demande confirmation', () {
    testWidgets('le retour système ne quitte pas tout seul', (tester) async {
      // `SPEC.md` : aucun geste irréversible sans confirmation. Perdre le tour
      // d'une équipe en est un, et le retour système est vite déclenché.
      await pumpScreen(tester);
      await startTurn(tester);

      await simulateSystemBack();
      await tester.pumpAndSettle();

      expect(find.text(l10n.quitGameTitle), findsOneWidget);
      expect(
        container.read(currentGameProvider),
        isNotNull,
        reason: 'La partie est toujours là tant que rien n’est confirmé',
      );

      await tester.tap(find.text(l10n.actionKeepPlaying));
      await tester.pumpAndSettle();
      expect(find.text(l10n.quitGameTitle), findsNothing);
      await stopGame(tester);
    });

    testWidgets('confirmer abandonne la partie', (tester) async {
      await pumpScreen(tester);
      await startTurn(tester);

      await simulateSystemBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionQuitGame));
      await tester.pumpAndSettle();

      expect(container.read(currentGameProvider), isNull);
    });

    testWidgets(
      'avant « C est parti » de la manche 1, le retour ne demande rien',
      (tester) async {
        // Retour de terrain : on descend dans la configuration pour changer
        // une catégorie ou une équipe, et l'application demandait « voulez-vous
        // abandonner ? » pour une partie que personne n'avait commencée. Il n'y
        // a qu'un paquet tiré, qu'un nouveau tirage remplacera.
        await pumpScreen(
          tester,
          game: testGame(roundIndex: 0).copyWith(phase: GamePhase.turnIntro),
          surUnePile: true,
        );

        await simulateSystemBack();
        await tester.pumpAndSettle();

        expect(find.text(l10n.quitGameTitle), findsNothing);
        expect(
          container.read(currentGameProvider),
          isNull,
          reason: 'le paquet tiré est jeté, pas proposé en reprise (R9.1)',
        );
      },
    );

    testWidgets('une fois le tour lancé, le retour redemande', (tester) async {
      // La contrepartie : dès que le premier tour commence, il y a de nouveau
      // quelque chose à perdre.
      await pumpScreen(
        tester,
        game: testGame(roundIndex: 0).copyWith(phase: GamePhase.turnIntro),
      );
      await startTurn(tester);

      await simulateSystemBack();
      await tester.pumpAndSettle();

      expect(find.text(l10n.quitGameTitle), findsOneWidget);
      await tester.tap(find.text(l10n.actionKeepPlaying));
      await tester.pumpAndSettle();
      await stopGame(tester);
    });

    testWidgets('une partie terminée se quitte sans rien demander', (
      tester,
    ) async {
      // Il n'y a plus rien à perdre : demander confirmation serait une friction
      // gratuite au moment où tout le monde repose le téléphone.
      await pumpScreen(
        tester,
        game: testGame().copyWith(phase: GamePhase.finished),
      );

      await simulateSystemBack();
      await tester.pumpAndSettle();

      expect(find.text(l10n.quitGameTitle), findsNothing);
      await stopGame(tester);
    });
  });

  group('R3.8 — la pause masque la carte', () {
    testWidgets('la carte disparaît et le panneau de pause la remplace', (
      tester,
    ) async {
      await pumpScreen(tester);
      await startTurn(tester);
      final carte = partie().currentCard!.text;
      expect(find.text(carte), findsOneWidget);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      expect(
        find.text(carte),
        findsNothing,
        reason: 'Une carte visible en pause se mémorise gratuitement',
      );
      expect(find.text(l10n.gamePausedTitle), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('les deux actions sont hors service en pause', (tester) async {
      await pumpScreen(tester);
      await startTurn(tester);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      final trouve = tester.widget<ActionZone>(
        find.widgetWithText(ActionZone, l10n.actionFound),
      );
      final passer = tester.widget<ActionZone>(
        find.widgetWithText(ActionZone, l10n.actionPass),
      );

      expect(trouve.onPressed, isNull);
      expect(passer.onPressed, isNull);
      await stopGame(tester);
    });

    testWidgets('la reprise repasse par le compte à rebours', (tester) async {
      await pumpScreen(tester);
      await startTurn(tester);
      final carte = partie().currentCard!.text;

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      expect(find.text(l10n.gameSecondsLeft(3)), findsOneWidget);
      expect(find.text(carte), findsNothing);

      await clock.advance(tester, const Duration(seconds: 3));
      expect(find.text(carte), findsOneWidget);
      await stopGame(tester);
    });
  });
}
