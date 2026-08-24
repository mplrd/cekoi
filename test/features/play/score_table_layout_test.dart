import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/rules/round.dart';
import 'package:cekoi/features/play/presentation/widgets/score_table.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/geometrie.dart';

/// Le tableau des scores se dégrade **en silence**.
///
/// C'est le pire des trois écrans de la dette de géométrie, et la raison est
/// dans sa structure : ses colonnes sont des `FlexColumnWidth`, donc le
/// tableau tient toujours dans sa largeur, quoi qu'il arrive. Rien ne déborde,
/// aucune exception ne remonte, la CI reste verte. Ce qui cède, c'est le
/// **contenu** des colonnes : un nombre à deux chiffres n'a pas de point de
/// coupure, il ne se replie pas, il se fait rogner.
///
/// Le cas réel tient en trois faits qui se cumulent : R8.1 promet dix équipes,
/// la manche 3 ajoute une quatrième colonne de chiffres, et l'agrandissement
/// du texte du système s'applique en entier.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await exigerLesVraiesPolices();
  });

  /// Une partie dont les trois manches sont jouées et les scores à deux
  /// chiffres — c'est le seuil où la colonne cède.
  GameState partieAvancee({int teamCount = 2}) {
    final base = testGame(cardCount: 60, teamCount: teamCount, roundIndex: 2);
    final cartes = [for (final carte in base.deck) carte.id];
    var suivante = 0;

    return base.copyWith(
      history: [
        for (final round in Round.sequence)
          for (final team in base.teams)
            PlayedTurn(
              round: round,
              teamId: team.id,
              results: [
                for (var n = 0; n < 12; n++)
                  CardResult(
                    cardId: cartes[suivante++ % cartes.length],
                    outcome: TurnOutcome.found,
                  ),
              ],
            ),
      ],
    );
  }

  Future<void> pumpTable(
    WidgetTester tester, {
    required GameState game,
    required Size taille,
    double echelleTexte = 1,
  }) async {
    poserEcran(tester, taille: taille, echelleTexte: echelleTexte);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            // 24 px de chaque côté, comme `round_summary_view` et
            // `podium_view`, les deux seuls écrans qui posent ce tableau. Un
            // harnais plus large qu'eux mentirait dans le sens rassurant.
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ScoreTable(game: game),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (libelle, taille, echelle, equipes) in [
    ('un écran courant', const Size(360, 800), 1.0, 2),
    ('dix équipes', const Size(360, 800), 1.0, 10),
    // Le seuil estimé de la dette.
    ('un texte agrandi', const Size(360, 800), 1.8, 2),
    ('un petit écran au texte agrandi', const Size(360, 640), 1.8, 4),
    // Le pire cas atteignable : dix équipes, petit écran, texte doublé.
    ('le pire cas', const Size(360, 640), 2.0, 10),
  ]) {
    testWidgets('les scores restent entiers sur $libelle', (tester) async {
      final game = partieAvancee(teamCount: equipes);

      // Garde-fou sur la fixture : sans deux chiffres, ce test ne prouve rien.
      expect(
        game.scoreOf(game.teams.first.id),
        greaterThanOrEqualTo(10),
        reason: 'la fixture doit produire des scores à deux chiffres',
      );

      await pumpTable(
        tester,
        game: game,
        taille: taille,
        echelleTexte: echelle,
      );

      expect(tester.takeException(), isNull);

      // Le contrôle qui compte : aucun chiffre rogné. Le nom d'équipe, lui,
      // déclare `ellipsis` — il a le droit de céder, et ça se voit.
      aucunTexteRogne(tester);

      // Et chaque total est bien à l'écran, pas seulement dans l'arbre.
      for (final team in game.teams) {
        expect(
          find.text('${game.scoreOf(team.id)}'),
          findsWidgets,
          reason: 'le total de ${team.name} a disparu',
        );
      }
      expect(find.text(l10n.scoreTotal), findsOneWidget);
    });
  }
}
