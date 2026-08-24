import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/preferences.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/features/play/presentation/game_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/feedback/feedback.dart';
import 'package:cekoi/services/feedback/game_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/geometrie.dart';
import '../../support/providers.dart';
import 'play_controller_test.dart' show FakeClock;

/// Le récapitulatif de tour doit rester corrigeable (R3.6).
///
/// Sa structure est celle qui a déjà lâché ailleurs : un en-tête fixe, une
/// liste au milieu dans un `Expanded`, et l'action épinglée en bas. L'en-tête
/// porte quatre textes dont deux titres, et le bloc « carte au buzzer » vient
/// parfois s'ajouter — tout cela grandit avec le réglage système, tandis que
/// l'`Expanded` absorbe jusqu'à tomber à zéro. Au-delà, c'est le bouton de
/// validation qui passe sous le bord.
///
/// Ce que ça coûte en vrai : R3.6 existe parce qu'on valide une carte pour une
/// autre dans le feu de l'action, et que sans correction le score est faux
/// jusqu'au podium. Un bouton hors d'atteinte, c'est un tour qu'on ne peut
/// plus clore.
void main() {
  late AppLocalizations l10n;
  late FakeClock clock;
  late ProviderContainer container;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await exigerLesVraiesPolices();
  });

  /// Un récapitulatif au pire de ce que la règle permet : le tour est tombé au
  /// chrono, donc une carte était encore à l'écran et son bloc s'ajoute.
  GameState recapitulatif({int tranchees = 6}) {
    const duree = Duration(seconds: 30);
    final base = testGame(cardCount: 24, roundIndex: 1, turnDuration: duree);
    final cartes = [for (final carte in base.deck) carte.id];

    return base.copyWith(
      phase: GamePhase.turnSummary,
      // Le paquet reprend après les cartes tranchées : sa tête est donc celle
      // qui était à l'écran quand le chrono est tombé, et c'est elle que
      // `cardAtBuzzer` rend.
      pile: cartes.sublist(tranchees),
      turn: PlayedTurn(
        round: base.rounds[1],
        teamId: base.teams.first.id,
        elapsed: duree,
        results: [
          for (var i = 0; i < tranchees; i++)
            CardResult(
              cardId: cartes[i],
              outcome: i.isEven ? TurnOutcome.found : TurnOutcome.passed,
            ),
        ],
      ),
    );
  }

  Future<void> pumpRecapitulatif(
    WidgetTester tester, {
    required GameState game,
    required Size taille,
    double echelleTexte = 1,
  }) async {
    clock = FakeClock();
    poserEcran(tester, taille: taille, echelleTexte: echelleTexte);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monotonicClockProvider.overrideWithValue(clock.read),
          screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
          gameFeedbackProvider.overrideWithValue(const SilentGameFeedback()),
          currentPreferencesProvider.overrideWithValue(fakePreferences()),
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
    await tester.pumpAndSettle();
  }

  for (final (libelle, taille, echelle, tranchees) in [
    ('un écran courant', const Size(360, 800), 1.0, 6),
    ('un petit écran', const Size(360, 640), 1.0, 6),
    // Le seuil estimé de la dette.
    ('un texte agrandi', const Size(360, 800), 2.0, 6),
    ('un petit écran au texte agrandi', const Size(360, 640), 2.0, 3),
    // Le pire cas : petit écran, texte au maximum courant du système.
    ('le pire cas', const Size(360, 640), 2.5, 8),
  ]) {
    testWidgets('la correction reste atteignable sur $libelle', (tester) async {
      final game = recapitulatif(tranchees: tranchees);

      // Garde-fou : sans la carte au buzzer, le pire cas n'est pas atteint et
      // le test passerait sur une mise en page plus courte que la vraie.
      expect(
        game.cardAtBuzzer,
        isNotNull,
        reason: 'la fixture doit inclure le bloc « carte au buzzer »',
      );

      await pumpRecapitulatif(
        tester,
        game: game,
        taille: taille,
        echelleTexte: echelle,
      );

      expect(tester.takeException(), isNull);
      await resteAtteignable(tester, find.text(l10n.actionConfirmTurn));
      aucunTexteRogne(tester);
    });
  }
}
