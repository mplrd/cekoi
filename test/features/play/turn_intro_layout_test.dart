import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/features/play/presentation/widgets/turn_intro_view.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/geometrie.dart';
import '../../support/partie.dart';

/// L'annonce de tour, l'écran vu le plus souvent de toute la partie.
///
/// Un tour par équipe et par manche : à quatre équipes, c'est douze fois. Il
/// existe pour que le téléphone change de mains, donc il est lu par quelqu'un
/// qui ne regardait pas — et c'est le seul moment où la contrainte de la manche
/// est rappelée en toutes lettres (R2.3).
///
/// Il était pourtant exercé au seul ×1,3, et par des tests qui ne rougissent
/// que sur une exception de `RenderFlex` ou un widget introuvable. Un texte
/// plus large que sa boîte n'est ni l'un ni l'autre : il est **rogné**, en
/// silence, et seulement chez qui a agrandi le texte dans les réglages du
/// système.
void main() {
  late AppLocalizations l10n;
  late ProviderContainer container;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await exigerLesVraiesPolices();
  });

  /// Une partie arrêtée sur l'annonce du tour de [equipe], dans [manche].
  GameState annonce({int manche = 0, String equipe = 'Équipe 1'}) {
    final game = testGame(cardCount: 12, roundIndex: manche);
    final equipes = [
      game.teams.first.copyWith(name: equipe),
      ...game.teams.skip(1),
    ];
    return game.copyWith(teams: equipes);
  }

  Future<void> poser(
    WidgetTester tester,
    GameState game, {
    Size taille = const Size(360, 800),
    double echelleTexte = 1,
  }) async {
    container = await monterLaPartie(
      tester,
      game,
      taille: taille,
      echelleTexte: echelleTexte,
    );
    expect(find.byType(TurnIntroView), findsOneWidget);
  }

  Future<void> ranger(WidgetTester tester) => rangerLaPartie(tester, container);

  /// Les trois manches, aux deux géométries visées, aux échelles qui comptent.
  ///
  /// ×2 est le maximum d'Android ; ×3,1 est AX5 sur iOS, qui n'a jamais tourné
  /// ailleurs qu'en compilation. Le nom de manche est un mot — « Description »
  /// — et un mot n'a pas de point de coupure : c'est le candidat évident, et le
  /// reste de l'écran se replie.
  for (final (manche, libelleManche) in const [
    (0, 'description libre'),
    (1, 'un seul mot'),
    (2, 'mime'),
  ]) {
    for (final (taille, echelle) in const [
      (Size(360, 800), 2.0),
      (Size(360, 640), 2.0),
      (Size(360, 640), 3.1),
    ]) {
      final ecran = '${taille.width.toInt()}×${taille.height.toInt()}';
      testWidgets('$libelleManche tient sur $ecran à ×$echelle', (
        tester,
      ) async {
        await poser(
          tester,
          annonce(manche: manche),
          taille: taille,
          echelleTexte: echelle,
        );

        // Un débordement de `RenderFlex` remonte comme exception de test.
        expect(tester.takeException(), isNull);

        // Le bouton est collé en bas et hors du défilement : s'il sort, rien
        // ne permet de le ramener et le tour ne peut plus commencer.
        await resteAtteignable(tester, find.text(l10n.actionStartTurn));

        // Et ce qu'aucune exception ne signale.
        aucunTexteRogne(tester);
        await ranger(tester);
      });
    }
  }

  testWidgets('le nom de manche et l équipe restent centrés', (tester) async {
    // Même piège que sur le départage : `TexteQuiTient` n'aligne rien par
    // défaut, et ces deux textes vivent sous un `CrossAxisAlignment.stretch`.
    // Sans `textAlign`, ils passaient à gauche à taille de texte normale —
    // pour tout le monde, donc, et sans que rien ne le signale.
    await poser(tester, annonce(), taille: const Size(360, 640));

    resteCentre(tester, find.text(l10n.roundNameFree));
    resteCentre(tester, find.text(l10n.turnIntroTeam('Équipe 1')));
    await ranger(tester);
  });

  testWidgets('un nom d équipe long ne se fait pas rogner', (tester) async {
    // Le nom est saisi par le joueur, et rien ne le borne. Celui-ci tient en
    // un mot de seize lettres : le repli ne peut rien pour lui.
    await poser(
      tester,
      annonce(equipe: 'Anticonstitution'),
      taille: const Size(360, 640),
      echelleTexte: 2,
    );

    expect(tester.takeException(), isNull);
    await resteAtteignable(tester, find.text(l10n.actionStartTurn));
    aucunTexteRogne(tester);
    await ranger(tester);
  });
}
