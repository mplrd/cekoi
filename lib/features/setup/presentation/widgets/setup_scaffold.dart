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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.setupStep(step, stepCount),
          style: theme.textTheme.labelLarge,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: step / stepCount),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(child: child),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}
