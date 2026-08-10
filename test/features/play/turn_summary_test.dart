import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/features/play/presentation/game_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/providers.dart';
import 'play_controller_test.dart' show FakeClock;

void main() {
  late AppLocalizations l10n;
  late FakeClock clock;
  late ProviderContainer container;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required GameState game,
  }) async {
    clock = FakeClock();
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monotonicClockProvider.overrideWithValue(clock.read),
          screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
        ],
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
    container.read(currentGameProvider.notifier).game = game;
    await tester.pump();
  }

  GameState partie() => container.read(currentGameProvider)!;

  Future<void> stopGame(WidgetTester tester) async {
    container.read(currentGameProvider.notifier).game = null;
    await tester.pump();
  }

  /// Joue un tour entier au chrono et arrive au récapitulatif avec des lignes
  /// des deux sortes.
  ///
  /// Les passes viennent **avant** les trouvées : R3.4 grise *Passer* dès
  /// qu'il ne reste qu'une carte, donc passer en fin de tour ne ferait rien du
  /// tout — et le test passerait sur une fixture qui ne teste rien.
  Future<void> playTurn(
    WidgetTester tester, {
    int found = 2,
    int passed = 1,
    int cardCount = 6,
  }) async {
    await pumpScreen(
      tester,
      game: testGame(
        cardCount: cardCount,
        turnDuration: const Duration(seconds: 30),
      ),
    );

    await tester.tap(find.text(l10n.actionStartTurn));
    await clock.advance(tester, const Duration(seconds: 3));

    for (var i = 0; i < passed; i++) {
      await tester.tap(find.text(l10n.actionPass));
      await tester.pump();
    }
    for (var i = 0; i < found; i++) {
      await tester.tap(find.text(l10n.actionFound));
      await tester.pump();
    }

    expect(
      partie().turn!.results,
      hasLength(found + passed),
      reason: 'Un tap sans effet rendrait toute la suite décorative',
    );

    await clock.advance(tester, const Duration(seconds: 30));
    expect(partie().phase, GamePhase.turnSummary);
  }

  group('R3.6 — le récapitulatif liste les cartes vues', () {
    testWidgets('chaque carte tranchée a sa ligne, avec son résultat', (
      tester,
    ) async {
      await playTurn(tester);

      expect(find.text(l10n.turnSummaryTitle), findsOneWidget);
      expect(find.text(l10n.outcomeFound), findsNWidgets(2));
      expect(find.text(l10n.outcomePassed), findsOneWidget);
      expect(find.text(l10n.turnSummaryScore(2)), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('une carte jamais retournée n’y figure pas', (tester) async {
      // Le récapitulatif ne corrige que ce qui a été vu : proposer les autres
      // reviendrait à donner des points sur des cartes jamais montrées.
      await playTurn(tester, found: 1, passed: 0, cardCount: 6);

      expect(find.byType(ListTile), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('un tour sans aucune carte tranchée le dit', (tester) async {
      await playTurn(tester, found: 0, passed: 0);

      expect(find.text(l10n.turnSummaryEmpty), findsOneWidget);
      expect(find.text(l10n.turnSummaryScore(0)), findsOneWidget);
      await stopGame(tester);
    });
  });

  group('R3.6 — corriger recalcule le score et le paquet', () {
    testWidgets('basculer une trouvée en passée retire le point', (
      tester,
    ) async {
      await playTurn(tester);
      final avant = partie().pile.length;

      await tester.tap(find.text(l10n.outcomeFound).first);
      await tester.pump();

      expect(find.text(l10n.turnSummaryScore(1)), findsOneWidget);
      expect(
        partie().pile.length,
        avant + 1,
        reason: 'La carte revient au paquet de la manche',
      );
      await stopGame(tester);
    });

    testWidgets('basculer une passée en trouvée ajoute le point', (
      tester,
    ) async {
      await playTurn(tester);
      final avant = partie().pile.length;

      await tester.tap(find.text(l10n.outcomePassed));
      await tester.pump();

      expect(find.text(l10n.turnSummaryScore(3)), findsOneWidget);
      expect(partie().pile.length, avant - 1);
      await stopGame(tester);
    });

    testWidgets('le score du tour suit en direct, sans validation', (
      tester,
    ) async {
      await playTurn(tester);

      await tester.tap(find.text(l10n.outcomeFound).first);
      await tester.pump();
      expect(find.text(l10n.turnSummaryScore(1)), findsOneWidget);

      await tester.tap(find.text(l10n.outcomeFound).first);
      await tester.pump();
      expect(
        find.text(l10n.turnSummaryScore(0)),
        findsOneWidget,
        reason: 'Deux corrections successives se lisent immédiatement',
      );
      await stopGame(tester);
    });
  });

  group('valider passe la main', () {
    testWidgets("le tour suivant s'ouvre sur l'équipe suivante (R4.3)", (
      tester,
    ) async {
      await playTurn(tester);
      expect(partie().activeTeam.id, 'team-1');

      await tester.tap(find.text(l10n.actionConfirmTurn));
      await tester.pump();

      expect(partie().phase, GamePhase.turnIntro);
      expect(partie().activeTeam.id, 'team-2');
      expect(find.text(l10n.turnIntroTeam('team-2')), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('le score validé est acquis', (tester) async {
      await playTurn(tester);

      await tester.tap(find.text(l10n.actionConfirmTurn));
      await tester.pump();

      expect(partie().scoreOf('team-1'), 2);
      await stopGame(tester);
    });

    testWidgets('cas limite 3 — corriger peut finir la manche', (tester) async {
      // Six cartes, cinq trouvées, une passée : le paquet ne contient plus que
      // la passée. La corriger en « trouvée » le vide, et valider doit donc
      // terminer la manche au lieu d'ouvrir un tour sur un paquet vide.
      await playTurn(tester, found: 5, passed: 1);
      expect(partie().pile, hasLength(1));

      await tester.tap(find.text(l10n.outcomePassed));
      await tester.pump();
      expect(partie().pile, isEmpty);

      await tester.tap(find.text(l10n.actionConfirmTurn));
      await tester.pump();

      expect(partie().phase, GamePhase.roundSummary);
      await stopGame(tester);
    });

    testWidgets(
      'cas limite 4 — annuler la dernière trouvée relance la manche',
      (
        tester,
      ) async {
        // Les six cartes trouvées : la manche est finie. Annuler la dernière
        // remet une carte en jeu, et la manche doit reprendre.
        await playTurn(tester, found: 6, passed: 0);
        expect(partie().pile, isEmpty);

        await tester.tap(find.text(l10n.outcomeFound).first);
        await tester.pump();
        expect(partie().pile, hasLength(1));

        await tester.tap(find.text(l10n.actionConfirmTurn));
        await tester.pump();

        expect(
          partie().phase,
          GamePhase.turnIntro,
          reason: 'La manche reprend avec la carte remise en jeu',
        );
        await stopGame(tester);
      },
    );
  });
}
