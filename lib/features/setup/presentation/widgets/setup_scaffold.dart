import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Ossature commune aux cinq étapes de la configuration.
///
/// La barre de progression et le retour sont ici plutôt que recopiés dans
/// chaque écran : `SPEC.md` demande de pouvoir revenir à chaque niveau, et
/// cinq implémentations finiraient par diverger.
class SetupScaffold extends StatelessWidget {
  const SetupScaffold({
    required this.step,
    required this.title,
    required this.child,
    this.footer,
    super.key,
  });

  /// Nombre d'étapes du parcours, de `SPEC.md`.
  static const int stepCount = 5;

  /// Étape courante, de 1 à [stepCount].
  final int step;
  final String title;
  final Widget child;

  /// Zone d'action collée en bas, hors de la zone défilante : le bouton
  /// d'avancement doit rester sous le pouce quelle que soit la longueur.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Un bandeau coloré en tête, le contenu sur fond clair en dessous.
    //
    // La configuration se lit et se coche : lui donner le fond plein des
    // écrans de jeu rendrait des listes de vingt catégories fatigantes. Le
    // bandeau suffit à dire qu'on est dans le même jeu, et il porte ce qui
    // compte à ce moment-là — où on en est du parcours.
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.seed,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const BackButton(color: AppColors.ink),
                        // Le libellé cède avant les points : sur une petite
                        // largeur, savoir combien d'étapes restent vaut mieux
                        // que de les compter en toutes lettres.
                        Flexible(
                          child: Text(
                            l10n.setupStep(step, stepCount),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.ink.withValues(alpha: 0.8),
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Spacer(),
                        // Cinq points valent mieux qu'une barre : on compte
                        // les étapes restantes d'un coup d'œil, ce qu'un
                        // pourcentage ne dit pas.
                        for (var i = 1; i <= stepCount; i++)
                          Container(
                            width: i == step ? 20 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: AppColors.ink.withValues(
                                alpha: i <= step ? 1 : 0.3,
                              ),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(top: false, bottom: false, child: child),
          ),
          if (footer != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: footer,
              ),
            ),
        ],
      ),
    );
  }
}
