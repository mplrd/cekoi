import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/preferences.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/domain/decks/card_length.dart';
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
  GameState recapitulatif({
    int tranchees = 6,
    String? premiereCarte,
    String? carteAuBuzzer,
  }) {
    const duree = Duration(seconds: 30);
    final tire = testGame(cardCount: 24, roundIndex: 1, turnDuration: duree);
    // La substitution se fait **avant** de relever les identifiants : celui
    // d'une carte se dérive de son texte, donc remplacer la carte après coup
    // laisserait le tour référencer une carte qui n'existe plus.
    final paquet = [...tire.deck];
    final terrain = paquet.first.deckId;
    if (premiereCarte != null) {
      paquet[0] = testCard(premiereCarte, deckId: terrain);
    }
    // La carte au buzzer est la tête de ce qui reste du paquet : les cartes
    // tranchées sont derrière elle.
    if (carteAuBuzzer != null) {
      paquet[tranchees] = testCard(carteAuBuzzer, deckId: terrain);
    }
    final base = tire.copyWith(deck: paquet);
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
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Sans le theme, on mesure la typographie Material par defaut et
          // non celle de l application.
          theme: AppTheme.light(),
          home: const GameScreen(),
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
    // iOS pousse plus loin qu'Android : AX4 vaut ×2,35 et AX5 ×3,1.
    ('un iPhone SE en AX4', const Size(375, 667), 2.35, 6),
    ('un iPhone SE en AX5', const Size(375, 667), 3.1, 6),
    ('un écran de 320 à ×3', const Size(320, 568), 3.0, 8),
    ('le pire cas', const Size(360, 640), 3.5, 8),
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

  testWidgets('une carte aussi longue que la borne tient, en un seul mot', (
    tester,
  ) async {
    // Le défaut trouvé par le contrôle de géométrie le jour où il est entré :
    // un mot unique de trente-trois caractères était rogné **à taille de
    // texte normale**. Borner la saisie à soixante n'y suffit pas — soixante
    // en un seul mot n'a toujours aucun point de coupure. C'est le pire des
    // textes que la saisie autorise désormais.
    final long = 'a' * maxCardTextLength;
    // Les deux endroits qui affichent un texte de carte : la ligne d'un
    // résultat, et le bloc « carte au buzzer ». Ne poser que la première
    // laissait le second sans rien qui puisse le faire rougir.
    final game = recapitulatif(
      tranchees: 4,
      premiereCarte: long,
      carteAuBuzzer: 'b' * maxCardTextLength,
    );

    // Garde-fou : la carte longue doit être une de celles que l'écran affiche,
    // sans quoi le test mesurerait un récapitulatif ordinaire.
    expect(
      game.turn!.results.map((r) => r.cardId),
      contains(game.deck.first.id),
    );

    await pumpRecapitulatif(tester, game: game, taille: const Size(360, 800));

    expect(tester.takeException(), isNull);
    expect(find.text(long), findsOneWidget);
    expect(find.text('b' * maxCardTextLength), findsOneWidget);
    aucunTexteRogne(tester);
  });

  testWidgets('un nom d équipe long ne se fait pas rogner', (tester) async {
    // Le texte de carte est borné à soixante caractères ; le **nom d équipe**
    // n est borné par rien — le champ de l étape des équipes n a pas de
    // `maxLength`. Ce fichier montait jusqu à ×3,5 sans jamais le voir, parce
    // que « team-1 » porte un trait d union, qui est un point de coupure.
    //
    // Mesuré au pire cas du fichier : « Anticonstitution · 2 » réclamait
    // 405,7 px dans 312. À ×2 il passe — ce n est donc pas une précaution,
    // c est un rognage, et il fallait aller jusqu au pire cas pour le voir.
    const nom = 'Anticonstitution';
    final base = recapitulatif(tranchees: 4);
    final game = base.copyWith(
      teams: [
        base.teams.first.copyWith(name: nom),
        ...base.teams.skip(1),
      ],
    );

    await pumpRecapitulatif(
      tester,
      game: game,
      taille: const Size(360, 640),
      echelleTexte: 3.5,
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining(nom), findsWidgets);
    aucunTexteRogne(tester);
  });
}
