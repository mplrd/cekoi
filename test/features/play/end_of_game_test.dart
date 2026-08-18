import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/preferences.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/features/play/presentation/game_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:cekoi/services/feedback/feedback.dart';
import 'package:cekoi/services/feedback/game_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/providers.dart';
import 'play_controller_test.dart' show FakeClock;

/// Un tour archivé où [found] cartes ont été trouvées.
PlayedTurn _turn({
  required GameState game,
  required String teamId,
  required int roundIndex,
  required int found,
  int offset = 0,
}) => PlayedTurn(
  round: game.rounds[roundIndex],
  teamId: teamId,
  results: [
    for (final card in game.deck.skip(offset).take(found))
      CardResult(cardId: card.id, outcome: TurnOutcome.found),
  ],
);

void main() {
  /// Compte les interstitiels demandés pendant un test.
  var interstitiels = 0;
  setUp(() => interstitiels = 0);
  late AppLocalizations l10n;
  late ProviderContainer container;
  late AppDatabase db;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  /// Remplit le vivier du mode Famille, dans la catégorie que les parties de
  /// test utilisent.
  Future<void> installPool(int count) async {
    await db
        .into(db.decks)
        .insert(
          DecksCompanion.insert(
            id: 'deck',
            name: 'deck',
            audience: Audience.family,
            minAge: MinAge.six.years,
            origin: DeckOrigin.official,
          ),
        );

    for (var i = 0; i < count; i++) {
      await db
          .into(db.cards)
          .insert(
            CardsCompanion.insert(
              id: 'deck:neuve-$i',
              deckId: 'deck',
              cardText: 'neuve $i',
              audience: Audience.family,
              difficulty: Difficulty.values[i % 3].value,
              origin: DeckOrigin.official,
            ),
          );
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    GameState game, {

    /// La géométrie de l'appareil. Par défaut un écran très haut, pour que la
    /// mise en page ne soit jamais ce qui fait échouer un test de contenu.
    Size? taille,

    /// L'agrandissement du texte par le système. Rien ne le borne dans
    /// l'application : le réglage s'applique en entier.
    double echelleTexte = 1,
  }) async {
    tester.view.physicalSize = taille ?? const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = echelleTexte;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monotonicClockProvider.overrideWithValue(FakeClock().read),
          appDatabaseProvider.overrideWithValue(db),
          seedSourceProvider.overrideWithValue(() => 7),
          screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
          gameFeedbackProvider.overrideWithValue(const SilentGameFeedback()),
          currentPreferencesProvider.overrideWithValue(fakePreferences()),
          // Consentement accordé, exprès : sans lui le portillon s'arrête
          // avant la pub, et le test ne prouverait plus rien — il resterait
          // vert même si rejouer déclenchait un interstitiel.
          consentGatewayProvider.overrideWithValue(
            fakeConsentGateway(
              const ConsentState(canRequestAds: true, canChangeChoice: true),
            ),
          ),
          adSdkStartProvider.overrideWithValue(() async {}),
          showInterstitialProvider.overrideWithValue(({
            required loadTimeout,
          }) async {
            interstitiels++;
            return true;
          }),
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

  group('R4.4 — les scores entre deux manches', () {
    /// Manche 1 terminée : 3 points pour team-1, 1 pour team-2.
    GameState afterFirstRound() {
      final game = testGame(cardCount: 8, roundIndex: 0);
      return game.copyWith(
        phase: GamePhase.roundSummary,
        pile: const [],
        turn: null,
        history: [
          _turn(game: game, teamId: 'team-1', roundIndex: 0, found: 3),
          _turn(
            game: game,
            teamId: 'team-2',
            roundIndex: 0,
            found: 1,
            offset: 3,
          ),
        ],
      );
    }

    testWidgets('le détail par manche et le cumul sont affichés', (
      tester,
    ) async {
      await pumpScreen(tester, afterFirstRound());

      expect(find.text(l10n.roundSummaryTitle(1)), findsOneWidget);
      expect(find.text(l10n.scoreTotal), findsOneWidget);
      expect(find.text(l10n.scoreRoundShort(1)), findsOneWidget);
      expect(find.text('3'), findsNWidgets(2), reason: 'manche 1 et cumul');
      await stopGame(tester);
    });

    testWidgets('seules les manches jouées ont une colonne', (tester) async {
      // Afficher les manches à venir à zéro laisserait croire qu'elles ont
      // été jouées sans marquer un point.
      await pumpScreen(tester, afterFirstRound());

      expect(find.text(l10n.scoreRoundShort(2)), findsNothing);
      expect(find.text(l10n.scoreRoundShort(3)), findsNothing);
      await stopGame(tester);
    });

    testWidgets('la contrainte de la manche à venir est rappelée', (
      tester,
    ) async {
      // C'est le moment où tout le monde réalise que les cartes décrites
      // librement vont devoir se mimer.
      await pumpScreen(tester, afterFirstRound());

      expect(find.text(l10n.roundSummaryNext(l10n.roundNameOneWord)), findsOne);
      expect(find.text(l10n.roundRuleOneWord), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('la manche suivante rebat les cartes (R4.2)', (tester) async {
      await pumpScreen(tester, afterFirstRound());

      await tester.tap(find.text(l10n.actionNextRound));
      await tester.pump();

      expect(partie().phase, GamePhase.turnIntro);
      expect(partie().roundIndex, 1);
      expect(
        partie().pile,
        hasLength(8),
        reason: 'Toutes les cartes reviennent en jeu',
      );
      await stopGame(tester);
    });
  });

  group('R5.3 — le départage', () {
    /// Trois équipes à égalité parfaite : cas limite 7.
    GameState threeWayTie() {
      final game = testGame(cardCount: 9, teamCount: 3);
      return game.copyWith(
        phase: GamePhase.tieBreak,
        roundIndex: game.rounds.length - 1,
        pile: const [],
        turn: null,
        tieBreakTeamIds: const ['team-1', 'team-2', 'team-3'],
        tieBreakReserve: testCards(4, prefix: 'reserve'),
        history: [
          for (var i = 0; i < 3; i++)
            _turn(
              game: game,
              teamId: 'team-${i + 1}',
              roundIndex: 0,
              found: 1,
              offset: i,
            ),
        ],
      );
    }

    testWidgets('chaque équipe à égalité a son bouton, et elles seules', (
      tester,
    ) async {
      final game = threeWayTie().copyWith(
        tieBreakTeamIds: const ['team-1', 'team-3'],
      );
      await pumpScreen(tester, game);

      expect(find.text(l10n.tieBreakWinner('team-1')), findsOneWidget);
      expect(find.text(l10n.tieBreakWinner('team-3')), findsOneWidget);
      expect(
        find.text(l10n.tieBreakWinner('team-2')),
        findsNothing,
        reason: 'Une équipe hors du départage ne peut pas le gagner',
      );
      await stopGame(tester);
    });

    testWidgets('la carte vient de la réserve, jamais du paquet joué', (
      tester,
    ) async {
      // À ce stade les cartes du paquet ont été vues trois fois : elles ne
      // départageraient plus rien.
      final game = threeWayTie();
      await pumpScreen(tester, game);

      expect(find.text(game.tieBreakReserve.first.text), findsOneWidget);
      for (final card in game.deck) {
        expect(find.text(card.text), findsNothing);
      }
      await stopGame(tester);
    });

    testWidgets('cas limite 7 — un départage à trois désigne un vainqueur', (
      tester,
    ) async {
      await pumpScreen(tester, threeWayTie());

      await tester.tap(find.text(l10n.tieBreakWinner('team-2')));
      await tester.pump();

      expect(partie().phase, GamePhase.finished);
      expect(partie().winnerIds, ['team-2']);
      expect(find.text(l10n.podiumWinner('team-2')), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('personne n’a trouvé : une autre carte, sans vainqueur', (
      tester,
    ) async {
      final game = threeWayTie();
      await pumpScreen(tester, game);
      final premiere = game.tieBreakCard!.text;

      await tester.tap(find.text(l10n.actionTieBreakRestart));
      await tester.pump();

      expect(partie().phase, GamePhase.tieBreak);
      expect(find.text(premiere), findsNothing);
      expect(find.text(partie().tieBreakCard!.text), findsOneWidget);
      await stopGame(tester);
    });

    /// Dix équipes à égalité — le plafond que R8.1 promet utilisable.
    ///
    /// Cas extrême mais atteignable : une partie où personne n'a rien trouvé
    /// met toutes les équipes à zéro, donc toutes à égalité.
    GameState tenWayTie() {
      final game = testGame(cardCount: 12, teamCount: 10);
      return game.copyWith(
        phase: GamePhase.tieBreak,
        roundIndex: game.rounds.length - 1,
        pile: const [],
        turn: null,
        tieBreakTeamIds: [for (var i = 1; i <= 10; i++) 'team-$i'],
        tieBreakReserve: testCards(4, prefix: 'reserve'),
      );
    }

    for (final (libelle, taille, echelle) in const [
      ('un ecran courant', Size(360, 800), 1.0),
      // La combinaison la plus probable sur le terrain : un telephone
      // ordinaire chez quelqu un qui a grossi la police du systeme.
      ('un ecran courant au texte agrandi', Size(360, 800), 1.3),
      ('un petit ecran', Size(360, 640), 1.0),
      ('un petit ecran au texte agrandi', Size(360, 640), 1.3),
    ]) {
      testWidgets('R8.1 — dix equipes a egalite tiennent sur $libelle', (
        tester,
      ) async {
        // R8.1 promet l'interface utilisable jusqu'a dix equipes. Ici, un
        // bouton de vainqueur sous le bord n'est pas un defaut cosmetique :
        // R5.3 ne peut plus etre tranchee, donc la partie ne peut plus se
        // terminer. Il n'y a aucune autre sortie que ces boutons.
        final game = tenWayTie();
        await pumpScreen(tester, game, taille: taille, echelleTexte: echelle);

        // Un debordement de `RenderFlex` remonte comme exception de test.
        expect(tester.takeException(), isNull);

        // Chaque equipe reste designable, quitte a faire defiler.
        for (final id in game.tieBreakTeamIds) {
          final bouton = find.widgetWithText(
            FilledButton,
            l10n.tieBreakWinner(id),
          );
          // `ensureVisible` n'est pas l'assertion, et ne protege de rien :
          // sans `Scrollable` ancetre il ne leve pas, il ne fait rien. Ce qui
          // attrape un retour a la colonne non defilante, c'est l'exception
          // de `RenderFlex` ci-dessus et la mesure ci-dessous — une colonne
          // qui deborde positionne quand meme ses enfants au-dela du bord, et
          // `getRect` lit la transformee, pas le rognage.
          //
          // `pump` et non `pumpAndSettle` : l'ecran de jeu anime en
          // permanence, rien ne s'y stabilise jamais. C'est la convention de
          // tous les tests de `play/`.
          await tester.ensureVisible(bouton);
          await tester.pump();

          final rect = tester.getRect(bouton);
          expect(rect.top, greaterThanOrEqualTo(0.0));
          expect(
            rect.bottom,
            lessThanOrEqualTo(taille.height),
            reason: 'le bouton de $id sort de l ecran',
          );
        }

        // Et la partie se termine reellement : un bouton visible mais inerte
        // ne vaudrait pas mieux qu'un bouton sous le bord.
        await tester.tap(
          find.widgetWithText(FilledButton, l10n.tieBreakWinner('team-10')),
        );
        await tester.pump();

        expect(partie().phase, GamePhase.finished);
        expect(partie().winnerIds, ['team-10']);
        await stopGame(tester);
      });
    }

    testWidgets('a trois equipes, le depart reste centre', (tester) async {
      // Le temoin du `minHeight` : sans lui l'ecran cesse de deborder — un
      // defilement ne deborde jamais — mais tout se colle en haut, et les
      // trois tests de geometrie restent verts. C'est le seul qui rougit si
      // on retire la contrainte.
      await pumpScreen(tester, threeWayTie());

      final zone = tester.getRect(find.byType(SingleChildScrollView));
      final titre = tester.getRect(find.text(l10n.tieBreakTitle));
      final pied = tester.getRect(
        find.widgetWithText(OutlinedButton, l10n.actionTieBreakRestart),
      );

      // Les marges sont lues sur le widget, pas recopiees : les reecrire ici
      // ferait rougir « le departage n'est pas centre » a la premiere retouche
      // du `padding`, alors que la mise en page serait restee parfaitement
      // centree.
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

      final airAuDessus = titre.top - (zone.top + marges.top);
      final airEnDessous = (zone.bottom - marges.bottom) - pied.bottom;

      expect(
        airAuDessus,
        greaterThan(50),
        reason: 'le departage est colle en haut au lieu d occuper l ecran',
      );
      expect(
        airAuDessus,
        closeTo(airEnDessous, 4),
        reason: "le departage n'est pas centre",
      );

      await stopGame(tester);
    });
  });

  group('le podium', () {
    GameState finishedGame({int cardCount = 16}) {
      final game = testGame(cardCount: cardCount);
      return game.copyWith(
        phase: GamePhase.finished,
        roundIndex: game.rounds.length - 1,
        pile: const [],
        turn: null,
        history: [
          _turn(game: game, teamId: 'team-1', roundIndex: 0, found: 5),
          _turn(
            game: game,
            teamId: 'team-2',
            roundIndex: 0,
            found: 2,
            offset: 5,
          ),
        ],
      );
    }

    testWidgets('le vainqueur est nommé, avec le détail des scores', (
      tester,
    ) async {
      await pumpScreen(tester, finishedGame());

      expect(find.text(l10n.podiumWinner('team-1')), findsOneWidget);
      expect(
        find.text(l10n.podiumWinner('team-2')),
        findsNothing,
        reason: "L'équipe battue n'est pas annoncée gagnante",
      );
      expect(find.text(l10n.scoreTotal), findsOneWidget);
      await stopGame(tester);
    });

    testWidgets('rejouer ne redéclenche pas de pub', (tester) async {
      // MONETISATION.md le dit explicitement, et la structure le garantit :
      // rejouer ne repasse pas par l'écran de lancement, seul emplacement
      // interstitiel autorisé. Une pub ici tomberait alors que le groupe est
      // déjà installé et vient d'en voir une il y a quarante minutes.
      await installPool(24);
      await pumpScreen(tester, finishedGame());

      // Le consentement doit avoir répondu avant de rejouer. Sinon le
      // portillon s'arrête sur « pas de réponse, pas de pub » et le test
      // resterait vert même si rejouer déclenchait un interstitiel — il
      // prouverait que le CMP n'a pas fini, pas que la règle est tenue.
      await container.read(adConsentProvider.future);

      await tester.tap(find.text(l10n.actionReplaySameSettings));
      await tester.pumpAndSettle();

      expect(interstitiels, 0);
      await stopGame(tester);
    });

    testWidgets('rejouer retire un paquet et repart de la manche 1', (
      tester,
    ) async {
      await installPool(24);
      final previous = finishedGame();
      await pumpScreen(tester, previous);

      await tester.tap(find.text(l10n.actionReplaySameSettings));
      await tester.pumpAndSettle();

      expect(partie().phase, GamePhase.turnIntro);
      expect(partie().roundIndex, 0);
      expect(partie().history, isEmpty);
      expect(partie().scoreOf('team-1'), 0);
      expect(
        partie().deck.map((c) => c.id),
        isNot(previous.deck.map((c) => c.id)),
        reason: 'Rejouer le même paquet viderait le jeu de son ressort',
      );
      expect(partie().config, previous.config);
      await stopGame(tester);
    });

    testWidgets('un vivier devenu trop maigre le dit', (tester) async {
      // Une catégorie custom supprimée entre deux parties, et le bouton ne
      // peut plus rien faire : il doit expliquer, pas rester muet.
      await installPool(5);
      await pumpScreen(tester, finishedGame());

      await tester.tap(find.text(l10n.actionReplaySameSettings));
      await tester.pumpAndSettle();

      expect(find.text(l10n.replayImpossible), findsOneWidget);
      expect(
        partie().phase,
        GamePhase.finished,
        reason: 'La partie précédente reste affichée',
      );
      await stopGame(tester);
    });
  });
}
