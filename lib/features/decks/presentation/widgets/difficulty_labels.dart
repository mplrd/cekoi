import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';

/// Les libellés de difficulté, côté présentation.
///
/// [Difficulty] est du domaine et ne connaît que sa valeur numérique : les
/// noms affichés viennent de l'ARB, et la table de correspondance vit ici
/// plutôt que recopiée dans chaque écran qui en a besoin.
extension DifficultyLabels on Difficulty {
  String label(AppLocalizations l10n) => switch (this) {
    Difficulty.easy => l10n.difficultyEasy,
    Difficulty.medium => l10n.difficultyMedium,
    Difficulty.hard => l10n.difficultyHard,
  };
}
