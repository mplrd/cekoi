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

    // Un seul fond, du haut de l'écran au bas : celui du thème.
    //
    // La version précédente posait un bandeau corail sur un fond presque
    // blanc. Deux surfaces, deux couleurs, une bordure arrondie qui laissait
    // des encoches dans les coins hauts — l'écran avait l'air coupé en deux.
    // Ici l'en-tête n'est plus une surface, juste le haut de la page.
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
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
                            color: AppColors.inkSoft,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Spacer(),
                      // Cinq points valent mieux qu'une barre : on compte les
                      // étapes restantes d'un coup d'œil, ce qu'un pourcentage
                      // ne dit pas. L'étape courante est un trait plein dans
                      // le teal des actions, les franchies des points d'encre.
                      for (var i = 1; i <= stepCount; i++)
                        Container(
                          width: i == step ? 22 : 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 5),
                          decoration: BoxDecoration(
                            color: switch (i) {
                              _ when i == step => AppColors.deep,
                              _ when i < step => AppColors.ink,
                              _ => AppColors.ink.withValues(alpha: 0.22),
                            },
                            borderRadius: const BorderRadius.all(
                              Radius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      title,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
