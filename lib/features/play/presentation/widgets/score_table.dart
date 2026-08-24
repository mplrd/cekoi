import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/engine/game_state.dart';
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
          // 360 × 800, deux équipes, trois manches jouées, agrandissement du
          // texte à ×1,8 : 38,9 px par colonne pour 45,9 qu'exige « 36 » et
          // 46,1 qu'exige l'en-tête « Total ».
          //
          // Le nom d'équipe, lui, déclare déjà `ellipsis` : céder est son
          // rôle, et la pastille de couleur identifie la ligne quand il ne
          // reste plus rien du texte.
          columnWidths: {
            0: const FlexColumnWidth(),
            for (var colonne = 1; colonne <= played.length + 1; colonne++)
              colonne: const IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                const SizedBox.shrink(),
                for (final round in played)
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
                  for (final round in played)
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
