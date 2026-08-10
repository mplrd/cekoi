import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/features/play/presentation/game_screen.dart';
import 'package:cekoi/features/play/presentation/widgets/game_card_face.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
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

  /// Appels natifs déclenchés par l'écran, par nom de méthode.
  ///
  /// Le son et la vibration passent par le canal `flutter/platform`, sans
  /// effet observable dans l'arbre de widgets : sans les compter, leur
  /// suppression ne ferait rougir aucun test.
  late List<String> platformCalls;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  setUp(() {
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Monte l'écran de jeu sur une partie donnée.
  Future<void> pumpScreen(WidgetTester tester, {GameState? game}) async {
    clock = FakeClock();
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monotonicClockProvider.overrideWithValue(clock.read),
          screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
        ],
        // Routeur minimal plutôt qu'un simple `home` : quitter la partie
        // ramène à l'accueil, et sans routeur dans le contexte l'écran lève
        // au lieu de naviguer.
        child: MaterialApp.router(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: AppRoutes.game,
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

      var passer = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, l10n.actionPass),
      );
      expect(passer.onPressed, isNotNull, reason: 'deux cartes au paquet');

      await tester.tap(find.text(l10n.actionFound));
      await tester.pump();

      passer = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, l10n.actionPass),
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
            .getSize(find.widgetWithText(FilledButton, l10n.actionFound))
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
      platformCalls.clear();
      expect(partie().remaining, const Duration(seconds: 10));

      await clock.advance(tester, const Duration(seconds: 3));

      expect(
        platformCalls.where((m) => m == 'SystemSound.play'),
        hasLength(3),
        reason: 'Une fois par seconde, pas une fois par tic',
      );
      expect(
        platformCalls.where((m) => m == 'HapticFeedback.vibrate'),
        hasLength(3),
      );
      await stopGame(tester);
    });

    testWidgets('au-dessus du seuil, rien ne se déclenche', (tester) async {
      await pumpScreen(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 60)),
      );
      await startTurn(tester);
      platformCalls.clear();

      await clock.advance(tester, const Duration(seconds: 5));

      expect(
        platformCalls.where(
          (m) => m == 'SystemSound.play' || m == 'HapticFeedback.vibrate',
        ),
        isEmpty,
        reason: 'Sonner pendant tout le tour rendrait le signal inutile',
      );
      await stopGame(tester);
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

      final trouve = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, l10n.actionFound),
      );
      final passer = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, l10n.actionPass),
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
