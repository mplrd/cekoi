import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Une tuile de choix de la configuration — une durée, un nombre de cartes,
/// un nombre d'équipes.
///
/// Remplace les `ChoiceChip` de Material, qui donnaient des boutons écrasés sur
/// une ligne, cernés d'un filet qui disparaissait sur le fond pastel : on ne
/// voyait ni ce qui était retenu, ni où appuyer. Ici la tuile est pleine, haute
/// d'un doigt, et le choix retenu prend le vert du personnage du logo avec un
/// liseré du teal des actions.
///
/// Une seule implémentation pour les trois écrans : trois copies auraient fini
/// par diverger, et c'est exactement ce qui donne une application qui n'a pas
/// l'air d'en être une seule.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Icône optionnelle, à gauche du libellé.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const rayon = BorderRadius.all(Radius.circular(AppTheme.radius));

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.secondary : AppColors.groundSoft,
        borderRadius: rayon,
        child: InkWell(
          onTap: onTap,
          borderRadius: rayon,
          child: Container(
            height: AppTheme.minTile,
            constraints: const BoxConstraints(minWidth: AppTheme.minTile),
            padding: EdgeInsets.symmetric(horizontal: icon == null ? 14 : 18),
            decoration: BoxDecoration(
              borderRadius: rayon,
              border: selected
                  ? Border.all(color: AppColors.deep, width: 2.5)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: AppColors.deep),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
