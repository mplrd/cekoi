import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/setup_steps.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ossature commune aux étapes de la configuration.
///
/// La barre de progression et le retour sont ici plutôt que recopiés dans
/// chaque écran : `SPEC.md` demande de pouvoir revenir à chaque niveau, et
/// cinq implémentations finiraient par diverger.
///
/// Le rang et le total se calculent depuis le mode en cours : cinq étapes des
/// deux côtés, mais pas les mêmes — la deuxième est les catégories en Famille,
/// l'étendue du vivier en Sans filtre (R7.10). Aucun écran ne connaît son
/// numéro : il déclare quelle étape il est.
class SetupScaffold extends ConsumerWidget {
  const SetupScaffold({
    required this.step,
    required this.title,
    required this.child,
    this.footer,
    super.key,
  });

  final SetupStep step;
  final String title;
  final Widget child;

  /// Zone d'action collée en bas, hors de la zone défilante : le bouton
  /// d'avancement doit rester sous le pouce quelle que soit la longueur.
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final parcours = setupStepsFor(ref.watch(setupControllerProvider).mode);
    // Garde-fou : un écran hors du parcours de son mode ne devrait pas exister
    // — chaque mode a ses cinq étapes et ne traverse que les siennes. Si ça
    // arrivait quand même, on cherche le parcours **qui contient cette étape**
    // plutôt qu'un repli arbitraire : chaque étape n'appartient qu'à un seul,
    // donc le rang affiché reste celui de l'écran. Un repli sur le parcours
    // familial aurait annoncé « Étape 1 sur 5 » sur l'écran du vivier — un
    // rang que rien ne justifie, et le point plein sur la mauvaise étape.
    final etapes = parcours.contains(step)
        ? parcours
        : Audience.values
              .map(setupStepsFor)
              .firstWhere((e) => e.contains(step), orElse: () => parcours);
    final index = etapes.indexOf(step);
    final rang = index + 1;
    final stepCount = etapes.length;

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
                          l10n.setupStep(rang, stepCount),
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
                          width: i == rang ? 22 : 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 5),
                          decoration: BoxDecoration(
                            color: switch (i) {
                              _ when i == rang => AppColors.deep,
                              _ when i < rang => AppColors.ink,
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
