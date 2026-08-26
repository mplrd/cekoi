import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/features/play/presentation/widgets/texte_de_carte.dart';
import 'package:flutter/material.dart';

/// La carte affichée au narrateur, et rien d'autre.
///
/// Une vraie carte blanche posée sur la couleur de la manche — c'est
/// exactement l'image du logo, et c'est aussi ce que le jeu imite : on tient
/// un paquet de cartes. Le fond neutre d'avant faisait de l'écran une page de
/// texte.
///
/// Le texte occupe toute la largeur disponible, replie aux espaces, et ne
/// rétrécit que si le repli ne suffit pas : les cartes vont d'un mot à une
/// phrase de dix, depuis que les catégories de situations sont arrivées, et
/// une taille fixe rendrait les longues illisibles à bout de bras.
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Center(
          child: TexteDeCarte(
            card.text,
            // Volontairement plus gros que l'échelle du thème : le texte est
            // seul sur la carte et se lit à un mètre. Les mots courts gardent
            // cette taille — sans quoi « Chat » flotterait, minuscule, au
            // milieu d'un rectangle blanc — et les phrases replient avant de
            // céder un seul point.
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 60,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
