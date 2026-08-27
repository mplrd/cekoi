import 'package:cekoi/app/widgets/texte_qui_tient.dart';
import 'package:flutter/material.dart';

/// Une bifurcation de la configuration : une icône, un titre, une phrase.
///
/// Partagée par le choix du mode (étape 1) et celui du vivier (étape 2 du mode
/// Sans filtre) parce que c'est la même nature de décision — on tape, on
/// choisit, on avance. Deux copies auraient fini par diverger, et l'écart se
/// serait vu : ces deux écrans s'enchaînent.
class SetupChoiceCard extends StatelessWidget {
  const SetupChoiceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Le titre partage la ligne avec une icône de 48 px : ce
                    // qui lui reste rétrécit quand le texte grossit, alors que
                    // l'icône, elle, ne bouge pas. Mesuré, « En famille »
                    // réclamait 230,4 px dans 196 à ×3,1 — et « famille » seul
                    // n'a pas de point de coupure.
                    TexteQuiTient(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
