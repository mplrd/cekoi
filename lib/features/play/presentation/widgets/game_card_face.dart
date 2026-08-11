import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:flutter/material.dart';

/// La carte affichée au narrateur, et rien d'autre.
///
/// Une vraie carte blanche posée sur la couleur de la manche — c'est
/// exactement l'image du logo, et c'est aussi ce que le jeu imite : on tient
/// un paquet de cartes. Le fond neutre d'avant faisait de l'écran une page de
/// texte.
///
/// Le texte occupe toute la largeur disponible et rétrécit s'il le faut : les
/// cartes vont d'un mot à une phrase de dix, depuis que les catégories de
/// situations sont arrivées, et une taille fixe rendrait les longues
/// illisibles à bout de bras.
class GameCardFace extends StatelessWidget {
  const GameCardFace({required this.card, super.key});

  final domain.Card card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          // L'ombre décolle la carte du fond coloré. Portée basse et diffuse :
          // la carte est posée sur la table, pas en lévitation.
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              card.text,
              textAlign: TextAlign.center,
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
