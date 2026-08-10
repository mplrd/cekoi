import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/features/play/presentation/game_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import 'play_controller_test.dart' show FakeClock;

/// Une partie dont la carte du dessus porte des mots interdits.
GameState _withTaboo({int roundIndex = 0}) {
  final autres = testCards(5);
  final carte = domain.Card(
    id: 'deck:tarte',
    deckId: 'deck',
    text: 'Tarte aux pommes',
    audience: autres.first.audience,
    difficulty: Difficulty.medium,
    origin: autres.first.origin,
    taboo: const ['pomme', 'dessert'],
  );

  return testGame(cardCount: 6).copyWith(
    roundIndex: roundIndex,
    deck: [carte, ...autres],
    pile: [carte.id, for (final c in autres) c.id],
  );
}

void main() {
  late AppLocalizations l10n;
  late FakeClock clock;
  late ProviderContainer container;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  /// Monte l'écran de jeu sur une partie donnée.
  Future<void> pumpScreen(WidgetTester tester, {GameState? game}) async {
    clock = FakeClock();
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [monotonicClockProvider.overrideWithValue(clock.read)],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GameScreen(),
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

  /// Termine proprement : sans ça, le `Timer` du chrono survit au test.
  Future<void> stopGame(WidgetTester tester) async {
    container.read(currentGameProvider.notifier).game = null;
    await tester.pump();
  }

  group("l'annonce du tour", () {
    testWidgets("nomme l'équipe, le narrateur et la contrainte", (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text(l10n.turnIntroTeam('team-1')), findsOneWidget);
      expect(find.text(l10n.turnIntroNarrator('team-1-1')), findsOneWidget);
      expect(find.text(l10n.roundNameFree), findsOneWidget);
      expect(find.text(l10n.roundRuleFree), findsOneWidget);
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

    testWidgets('les mots tabous sortent en manche 1', (tester) async {
      await pumpScreen(tester, game: _withTaboo());
      await startTurn(tester);

      expect(find.text('pomme'), findsOneWidget);
      expect(find.text('dessert'), findsOneWidget);
      expect(find.text(l10n.gameTabooTitle), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('ils disparaissent dès la manche 2', (tester) async {
      // L'autre moitié de la règle, sans laquelle afficher les tabous
      // partout passerait le test précédent. En manche 2 le narrateur ne dit
      // qu'un mot et en manche 3 il se tait : la liste n'a plus de sens et
      // encombre un écran qui doit se lire d'un coup d'œil.
      await pumpScreen(tester, game: _withTaboo(roundIndex: 1));
      await startTurn(tester);

      expect(find.text(l10n.roundNameOneWord), findsNothing);
      expect(find.text('Tarte aux pommes'), findsOneWidget);
      expect(find.text('pomme'), findsNothing);
      expect(find.text(l10n.gameTabooTitle), findsNothing);
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
