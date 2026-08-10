import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// La carte affichée au narrateur.
///
/// Le texte occupe toute la largeur disponible et rétrécit s'il le faut : les
/// cartes vont d'un mot à une expression de huit, et une taille fixe rendrait
/// les longues illisibles à bout de bras.
class GameCardFace extends StatelessWidget {
  const GameCardFace({
    required this.card,
    required this.showTaboo,
    super.key,
  });

  final domain.Card card;

  /// Les mots interdits ne sont montrés qu'en manche 1 (R2, manche 1).
  ///
  /// En manche 2 le narrateur ne dit qu'un mot et en manche 3 il se tait :
  /// les afficher n'aurait aucun sens et encombrerait l'écran au moment où il
  /// doit se lire d'un coup d'œil.
  final bool showTaboo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final taboo = showTaboo ? card.taboo : const <String>[];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              card.text,
              textAlign: TextAlign.center,
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (taboo.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            l10n.gameTabooTitle,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              for (final mot in taboo)
                Text(
                  mot,
                  style: theme.textTheme.titleMedium?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
