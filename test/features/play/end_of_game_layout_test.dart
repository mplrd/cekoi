import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/features/play/presentation/widgets/podium_view.dart';
import 'package:cekoi/features/play/presentation/widgets/round_summary_view.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/geometrie.dart';
import '../../support/partie.dart';

/// Les deux écrans de fin — bilan de manche, podium — mesurés.
///
/// `end_of_game_test.dart` les couvre déjà, mais en contenu : il vérifie les
/// scores, les égalités, le rejeu. Sa géométrie tourne en Ahem, sans le thème
/// de l'application, et ne dépasse pas ×1,3.
///
/// Or ces deux écrans affichent la seule chaîne de l'application que **rien**
/// ne borne : le nom d'équipe, saisi au clavier à l'étape des équipes, sans
/// `maxLength`. Un nom qui tient en un mot n'a aucun point de coupure — le
/// repli ne peut rien pour lui, et il se fait rogner en silence.
void main() {
  late AppLocalizations l10n;
  late ProviderContainer container;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await exigerLesVraiesPolices();
  });

  /// Un tour archivé où [found] cartes ont été trouvées.
  PlayedTurn tour({
    required GameState game,
    required String teamId,
    required int found,
    int offset = 0,
  }) => PlayedTurn(
    round: game.rounds[0],
    teamId: teamId,
    results: [
      for (final card in game.deck.skip(offset).take(found))
        CardResult(cardId: card.id, outcome: TurnOutcome.found),
    ],
  );

  /// Une partie terminée, dont l'équipe en tête porte [vainqueur].
  GameState podium({String vainqueur = 'Les Renards'}) {
    final base = testGame(cardCount: 16);
    final game = base.copyWith(
      teams: [
        base.teams.first.copyWith(name: vainqueur),
        ...base.teams.skip(1),
      ],
    );
    return game.copyWith(
      phase: GamePhase.finished,
      roundIndex: game.rounds.length - 1,
      pile: const [],
      turn: null,
      history: [
        tour(game: game, teamId: 'team-1', found: 5),
        tour(game: game, teamId: 'team-2', found: 2, offset: 5),
      ],
    );
  }

  /// La fin de la manche 1, avec ses scores intermédiaires (R4.4).
  GameState bilanDeManche({String equipe = 'Les Renards'}) {
    final base = testGame(cardCount: 8, roundIndex: 0);
    final game = base.copyWith(
      teams: [
        base.teams.first.copyWith(name: equipe),
        ...base.teams.skip(1),
      ],
    );
    return game.copyWith(
      phase: GamePhase.roundSummary,
      pile: const [],
      turn: null,
      history: [
        tour(game: game, teamId: 'team-1', found: 3),
        tour(game: game, teamId: 'team-2', found: 1, offset: 3),
      ],
    );
  }

  Future<void> poser(
    WidgetTester tester,
    GameState game, {
    required Size taille,
    double echelleTexte = 1,
  }) async {
    container = await monterLaPartie(
      tester,
      game,
      taille: taille,
      echelleTexte: echelleTexte,
    );

    // Dire quelle vue est montée, comme les deux autres fichiers de mesure :
    // sans ça, une fixture qui dérive ferait mesurer un autre écran.
    expect(
      switch (game.phase) {
        GamePhase.finished => find.byType(PodiumView),
        _ => find.byType(RoundSummaryView),
      },
      findsOneWidget,
    );
  }

  Future<void> ranger(WidgetTester tester) => rangerLaPartie(tester, container);

  /// Un nom d'équipe en un seul mot, tel qu'un joueur peut en taper un.
  ///
  /// Rien ne le borne : le champ de l'étape des équipes n'a pas de `maxLength`.
  /// Seize lettres suffisent à dépasser, et personne n'a jamais mesuré au-delà
  /// de « team-1 » — dont le trait d'union est justement un point de coupure.
  const longNom = 'Anticonstitution';

  for (final (taille, echelle) in const [
    (Size(360, 800), 2.0),
    (Size(360, 640), 2.0),
    (Size(360, 640), 3.1),
  ]) {
    final ecran = '${taille.width.toInt()}×${taille.height.toInt()}';

    testWidgets('le podium tient sur $ecran à ×$echelle', (tester) async {
      await poser(
        tester,
        podium(vainqueur: longNom),
        taille: taille,
        echelleTexte: echelle,
      );

      expect(tester.takeException(), isNull);

      // Les deux seules sorties de la partie.
      await resteAtteignable(tester, find.text(l10n.actionNewGame));
      await resteAtteignable(
        tester,
        find.text(l10n.actionReplaySameSettings),
      );
      aucunTexteRogne(tester);
      await ranger(tester);
    });

    testWidgets('le bilan de manche tient sur $ecran à ×$echelle', (
      tester,
    ) async {
      await poser(
        tester,
        bilanDeManche(equipe: longNom),
        taille: taille,
        echelleTexte: echelle,
      );

      expect(tester.takeException(), isNull);
      await resteAtteignable(tester, find.text(l10n.actionNextRound));
      aucunTexteRogne(tester);
      await ranger(tester);
    });
  }

  testWidgets('le libellé d une zone d action se déclare centré', (
    tester,
  ) async {
    // « Rejouer avec les mêmes réglages » replie à ×2 sur un 360.
    // `ActionZone` portait un `textAlign: TextAlign.center` qu'une PR de
    // rognage a retiré sans le vouloir, en le croyant remplacé par
    // `alignment` — qui place le bloc réduit, pas les lignes dans leur boîte.
    // Le libellé partait alors à gauche dans un bouton pleine largeur, sur les
    // zones qu'on tape sans regarder.
    await poser(
      tester,
      podium(),
      taille: const Size(360, 800),
      echelleTexte: 2,
    );

    final libelle = find.text(l10n.actionReplaySameSettings);
    final para = tester.renderObject<RenderParagraph>(libelle);

    // Garde-fou : hors repli, le libellé tient dans un `Center` qui ajuste sa
    // largeur au contenu, les deux marges valent zéro et le centrage devient
    // indécidable. C'est le repli qui rend la mesure possible.
    expect(
      para.getMaxIntrinsicWidth(double.infinity),
      greaterThan(para.size.width),
      reason: 'le libellé ne replie pas ici : le cas mesuré a changé',
    );

    resteCentre(tester, libelle);
    await ranger(tester);
  });

  testWidgets('le nom du vainqueur reste centré à taille normale', (
    tester,
  ) async {
    // `TexteQuiTient` n'aligne rien par défaut : le poser sur un titre centré
    // le décale pour tout le monde, c'est-à-dire dans le cas où il n'y avait
    // rien à corriger.
    // « Renards » et non « Les Renards » : mesuré, « Les Renards gagne »
    // réclame 309,6 px dans une liste de 312, soit 0,8 % de marge. Une mise à
    // jour de Roboto, un changement de graisse ou un mot de plus dans l'ARB le
    // ferait replier, et ce test rougirait sur « la dernière ligne occupe toute
    // la boîte » — rouge pour la mauvaise raison. Le nom ne porte aucun sens
    // ici, seul le centrage compte.
    await poser(
      tester,
      podium(vainqueur: 'Renards'),
      taille: const Size(360, 800),
    );

    resteCentre(tester, find.text(l10n.podiumWinner('Renards')));
    await ranger(tester);
  });
}
