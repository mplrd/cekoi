import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/game_persistence.dart';
import 'package:cekoi/app/preferences.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/rules/resume.dart';
import 'package:cekoi/features/play/presentation/game_screen.dart';
import 'package:cekoi/features/play/presentation/play_controller.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/providers.dart';
import 'play_controller_test.dart' show FakeClock;

void main() {
  late AppLocalizations l10n;
  late AppDatabase db;
  late FakeClock clock;
  late ProviderContainer container;
  late DateTime wallClock;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  setUp(() {
    db = AppDatabase.memory();
    wallClock = DateTime.utc(2026, 8, 10, 20);
  });
  tearDown(() => db.close());

  /// Compte les montages, et sert de clé au `ProviderScope`.
  ///
  /// Sans clé distincte, remonter un `ProviderScope` de même type ne recrée
  /// rien : `Widget.canUpdate` est vrai, l'élément est seulement mis à jour,
  /// le `ProviderContainer` survit — et avec lui le `PlayController`, qui est
  /// `keepAlive` et garde son chrono déjà chargé. Un démarrage à froid, c'est
  /// justement ce contrôleur qui n'existe plus ; un test qui croit le simuler
  /// sans le vérifier ne teste que la mémoire du précédent.
  Future<PlayController> pumpGame(
    WidgetTester tester, {
    GameState? game,
  }) async {
    clock = FakeClock();
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Conteneur créé à la main plutôt que par `ProviderScope` : c'est la seule
    // façon d'en obtenir un **neuf** à chaque montage. Remonter un
    // `ProviderScope` de même type ne recrée rien — `Widget.canUpdate` est
    // vrai, le conteneur survit, et avec lui le `PlayController`, qui est
    // `keepAlive` et garde son chrono déjà chargé. Un démarrage à froid, c'est
    // justement ce contrôleur qui n'existe plus ; un test qui croit le simuler
    // sans le vérifier ne teste que la mémoire du précédent.
    container = ProviderContainer(
      overrides: [
        monotonicClockProvider.overrideWithValue(clock.read),
        appDatabaseProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(() => wallClock),
        screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
        currentPreferencesProvider.overrideWithValue(fakePreferences()),
      ],
    );
    addTearDown(container.dispose);

    // La sauvegarde automatique est branchée par `CekoiApp` en vrai ; ici
    // l'écran est monté seul, on l'active à la main.
    container
      ..read(gamePersistenceProvider)
      ..read(currentGameProvider.notifier).game = game ?? testGame();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GameScreen(),
        ),
      ),
    );

    return container.read(playControllerProvider.notifier);
  }

  Future<void> stopGame(WidgetTester tester) async {
    container.read(currentGameProvider.notifier).game = null;
    await tester.pump();
  }

  Future<int> writes() async => (await db.select(db.savedGames).get()).length;

  GameState partie() => container.read(currentGameProvider)!;

  Future<GameState?> saved() async =>
      (await container.read(gameRepositoryProvider).load())?.game;

  group('R9.1 — la partie est sauvegardée au fil du jeu', () {
    testWidgets('ouvrir une partie la sauvegarde aussitôt', (tester) async {
      await pumpGame(tester);
      await tester.pump();

      expect(await saved(), isNotNull);
      await stopGame(tester);
    });

    testWidgets('chaque carte tranchée est sauvegardée', (tester) async {
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      controller.found();
      await tester.pump();
      await tester.pump();

      expect((await saved())!.turn!.score, 1);
      await stopGame(tester);
    });

    testWidgets('le chrono seul n’écrit pas en base', (tester) async {
      // Dix événements par seconde : écrire à chaque tic userait la mémoire du
      // téléphone pour une information que personne ne relira.
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      await tester.pump();
      final apresDepart = (await saved())!.turn!.elapsed;

      await clock.advance(tester, const Duration(seconds: 20));
      await tester.pump();

      expect(
        (await saved())!.turn!.elapsed,
        apresDepart,
        reason: 'Vingt secondes de chrono, aucune écriture',
      );
      await stopGame(tester);
    });

    testWidgets('la mise en arrière-plan sauvegarde le temps exact', (
      tester,
    ) async {
      // C'est ce qui rattrape la règle précédente : le tour se met en pause
      // (R3.7), et cette pause est un vrai changement, donc une écriture avec
      // le temps consommé réel.
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      await clock.advance(tester, const Duration(seconds: 20));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();

      final reprise = (await saved())!;
      expect(reprise.turn!.elapsed, const Duration(seconds: 20));
      expect(reprise.isPaused, isTrue);
      await stopGame(tester);
    });

    testWidgets('la fin de manche est sauvegardée, tour compris', (
      tester,
    ) async {
      // Entre deux manches, `turn` vaut `null` : la comparaison qui écarte les
      // simples tics doit traiter ce cas, sinon on quitte sur l'écran de
      // scores, on rouvre, et on retombe sur le récapitulatif de tour à
      // revalider.
      final controller = await pumpGame(
        tester,
        game: testGame(cardCount: 2, turnDuration: const Duration(seconds: 30)),
      );

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      controller
        ..found()
        ..found();
      await tester.pump();
      controller.confirmTurn();
      await tester.pump();
      await tester.pump();

      expect(partie().phase, GamePhase.roundSummary);
      expect(partie().turn, isNull);
      expect((await saved())?.phase, GamePhase.roundSummary);
      await stopGame(tester);
    });

    testWidgets('une partie terminée n’est plus proposée', (tester) async {
      // Rouvrir l'application sur un podium n'aurait aucun sens.
      await pumpGame(tester);
      await tester.pump();
      expect(await writes(), 1);

      container.read(currentGameProvider.notifier).game = testGame().copyWith(
        phase: GamePhase.finished,
      );
      await tester.pump();
      await tester.pump();

      expect(await writes(), 0);
      await stopGame(tester);
    });
  });

  group('R9.2 — la reprise expire au bout de 24 h', () {
    testWidgets('une partie de la veille est proposée', (tester) async {
      await pumpGame(tester);
      await tester.pump();

      wallClock = wallClock.add(const Duration(hours: 12));
      container.invalidate(resumableGameProvider);

      expect(await container.read(resumableGameProvider.future), isNotNull);
      await stopGame(tester);
    });

    testWidgets('au-delà, elle est oubliée et la ligne est effacée', (
      tester,
    ) async {
      // Sans l'effacement, une partie de la semaine dernière resterait en base
      // à attendre indéfiniment.
      await pumpGame(tester);
      await tester.pump();
      expect(await writes(), 1);

      wallClock = wallClock.add(resumeWindow + const Duration(minutes: 1));
      container.invalidate(resumableGameProvider);

      expect(await container.read(resumableGameProvider.future), isNull);
      expect(await writes(), 0);
      await stopGame(tester);
    });
  });

  group('reprendre depuis la sauvegarde', () {
    testWidgets('la partie repart exactement où elle en était', (tester) async {
      final controller = await pumpGame(tester);

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      controller.found();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();

      final avant = container.read(currentGameProvider)!;
      final reprise = (await saved())!;

      expect(reprise, avant);
      expect(reprise.currentCardId, avant.currentCardId);
      expect(reprise.turn!.results, avant.turn!.results);
      await stopGame(tester);
    });

    testWidgets("l'écran reprend sur la phase sauvegardée", (tester) async {
      // Une partie tuée en plein tour rouvre en pause, carte masquée : le
      // téléphone a changé de mains entre-temps.
      final controller = await pumpGame(tester);
      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();

      final sauvegardee = (await saved())!;
      expect(sauvegardee.phase, GamePhase.playing);
      expect(sauvegardee.isPaused, isTrue);

      final repris = await pumpGame(tester, game: sauvegardee);
      expect(identical(repris, controller), isFalse, reason: _froid);

      expect(find.text(l10n.gamePausedTitle), findsOneWidget);
      expect(
        find.text(sauvegardee.currentCard!.text),
        findsNothing,
        reason: 'La carte reste masquée tant que le jeu est en pause',
      );
      await stopGame(tester);
    });

    testWidgets('le tour reprend avec le temps qu’il lui restait', (
      tester,
    ) async {
      // Le chrono du contrôleur est un champ d'instance, pas une lecture de
      // l'état : après un démarrage à froid il repart de zéro, et le tour
      // s'étire du temps déjà consommé. Vingt secondes offertes à l'équipe
      // active, ce qui fausse la partie sans que rien ne paraisse anormal.
      final controller = await pumpGame(
        tester,
        game: testGame(turnDuration: const Duration(seconds: 60)),
      );

      controller.startTurn();
      await clock.advance(tester, const Duration(seconds: 3));
      await clock.advance(tester, const Duration(seconds: 20));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();
      final sauvegardee = (await saved())!;
      expect(sauvegardee.remaining, const Duration(seconds: 40));

      final repris = await pumpGame(tester, game: sauvegardee);
      expect(identical(repris, controller), isFalse, reason: _froid);

      repris.requestResume();
      await clock.advance(tester, const Duration(seconds: 3));
      expect(partie().remaining, const Duration(seconds: 40));

      await clock.advance(tester, const Duration(seconds: 10));
      expect(
        partie().remaining,
        const Duration(seconds: 30),
        reason: 'Le tour continue de se consumer, il ne recommence pas',
      );
      await stopGame(tester);
    });
  });
}

const String _froid =
    'Sans contrôleur neuf, le test ne prouve rien : le chrono du précédent '
    'survivrait et masquerait le défaut';
