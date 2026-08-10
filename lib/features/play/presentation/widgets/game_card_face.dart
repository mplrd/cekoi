import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:flutter/material.dart';

/// La carte affichée au narrateur, et rien d'autre.
///
/// Le texte occupe toute la largeur disponible et rétrécit s'il le faut : les
/// cartes vont d'un mot à une expression de huit, et une taille fixe rendrait
/// les longues illisibles à bout de bras.
class GameCardFace extends StatelessWidget {
  const GameCardFace({required this.card, super.key});

  final domain.Card card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
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
    );
  }
}
