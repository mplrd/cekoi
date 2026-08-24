import 'dart:math';

import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:cekoi/domain/rules/round.dart';
import 'package:cekoi/features/play/presentation/widgets/round_labels.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Les scores par équipe, détaillés par manche et cumulés (R4.4).
///
/// Le même tableau sert entre deux manches et au podium : c'est la même
/// information, et deux implémentations finiraient par ne plus additionner
/// pareil.
class ScoreTable extends StatelessWidget {
  const ScoreTable({required this.game, super.key});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final byRound = game.scoresByRound;

    // Seules les manches déjà jouées ont une colonne : afficher les suivantes
    // à zéro laisserait croire qu'elles ont été jouées sans marquer.
    final played = [
      for (final round in game.rounds)
        if (byRound.containsKey(round)) round,
    ];

    final classees = [...game.teams]
      ..sort((a, b) => game.scoreOf(b.id).compareTo(game.scoreOf(a.id)));

    return LayoutBuilder(
      builder: (context, contraintes) => _table(
        context,
        l10n,
        theme,
        byRound,
        classees,
        // Les colonnes de manche cèdent avant le nom d'équipe.
        //
        // Elles sont en `IntrinsicColumnWidth`, donc irréductibles : quand
        // leur somme dépasse la place, c'est la colonne du nom — la seule qui
        // soit flexible — qui tombe à zéro. `RenderFlex` ne peint alors plus
        // rien du tout, ni le nom ni la pastille de couleur, et `RenderTable`
        // écrête sa boîte en peignant ses cellules par-dessus, hors de la
        // carte blanche puis hors de l'écran. Sans exception, sans trace.
        //
        // Plutôt que de laisser cet enchaînement se produire, on retire le
        // détail par manche : il reste le nom, la pastille et le total, qui
        // est l'information dont R4.4 a besoin. Mesuré, un seul chiffre laisse
        // toujours de la place au nom, même à ×4 sur un écran de 300.
        detaille: _detailTient(
          context,
          l10n,
          theme,
          byRound,
          played,
          contraintes,
        ),
        played: played,
      ),
    );
  }

  /// La largeur qu'occuperaient les colonnes de chiffres, à l'unité près.
  bool _detailTient(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    Map<Round, Map<String, int>> byRound,
    List<Round> played,
    BoxConstraints contraintes,
  ) {
    final echelle = MediaQuery.textScalerOf(context);
    final chiffres = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final entetes = theme.textTheme.labelSmall;

    var besoin = _largeur(l10n.scoreTotal, entetes, echelle);
    for (final team in game.teams) {
      besoin = max(
        besoin,
        _largeur('${game.scoreOf(team.id)}', chiffres, echelle),
      );
    }

    var total = besoin;
    for (final round in played) {
      var colonne = _largeur(
        l10n.scoreRoundShort(round.number),
        entetes,
        echelle,
      );
      for (final team in game.teams) {
        final valeur = '${byRound[round]?[team.id] ?? 0}';
        colonne = max(colonne, _largeur(valeur, chiffres, echelle));
      }
      total += colonne;
    }

    // 20 px de marge horizontale de chaque côté, plus la place qu'il faut au
    // nom : la pastille, son écart, et de quoi lire trois ou quatre lettres.
    return total + _minimumDuNom <= contraintes.maxWidth - 40;
  }

  static const double _minimumDuNom = 84;

  double _largeur(String texte, TextStyle? style, TextScaler echelle) {
    final peintre = TextPainter(
      text: TextSpan(text: texte, style: style),
      textDirection: TextDirection.ltr,
      textScaler: echelle,
    )..layout();
    // 20 px : le `_Cell` pose 10 px de chaque côté.
    return peintre.width + 20;
  }

  Widget _table(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    Map<Round, Map<String, int>> byRound,
    List<Team> classees, {
    required bool detaille,
    required List<Round> played,
  }) {
    final colonnes = detaille ? played : const <Round>[];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Table(
          // Les chiffres prennent la place qu'il leur faut, le nom prend le
          // reste.
          //
          // Toutes les colonnes étaient en `FlexColumnWidth` : le tableau
          // tenait donc toujours dans sa largeur, et c'est le contenu qui
          // cédait. Un nombre n'a pas de point de coupure — il ne se replie
          // pas, il se fait rogner, sans exception ni trace. Mesuré sur un
          // 360 × 800, deux équipes, trois manches jouées : le seuil est
          // ×1,6, où 38,9 px de colonne ne suffisent plus aux 40,8 qu'exige
          // « 36 ». Sur un écran de 320, il tombe à ×1,3.
          //
          // Ces deux constantes sont volontairement `const` : `RenderTable`
          // compare `columnWidths` par identité et relance une mesure
          // d'intrinsèques — que Flutter documente comme coûteuse — dès que la
          // table change d'objet.
          columnWidths: const {0: FlexColumnWidth()},
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                const SizedBox.shrink(),
                for (final round in colonnes)
                  _Cell(
                    text: l10n.scoreRoundShort(round.number),
                    style: theme.textTheme.labelSmall,
                    tooltip: round.label(l10n),
                  ),
                _Cell(text: l10n.scoreTotal, style: theme.textTheme.labelSmall),
              ],
            ),
            for (final team in classees)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        // La couleur d'équipe tient dans une pastille : en
                        // texte, elle devait rester lisible sur tous les
                        // fonds, ce qu'aucune des huit ne garantit.
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: AppColors.team(team.colorId),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            team.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final round in colonnes)
                    _Cell(
                      text: '${byRound[round]?[team.id] ?? 0}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  _Cell(
                    text: '${game.scoreOf(team.id)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// L'encre des chiffres secondaires du tableau.
final Color _defaut = AppColors.ink.withValues(alpha: 0.6);

class _Cell extends StatelessWidget {
  const _Cell({required this.text, this.style, this.tooltip});

  final String text;
  final TextStyle? style;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cell = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: (style ?? const TextStyle()).copyWith(
          color: style?.color ?? _defaut,
        ),
      ),
    );

    final message = tooltip;
    return message == null ? cell : Tooltip(message: message, child: cell);
  }
}
