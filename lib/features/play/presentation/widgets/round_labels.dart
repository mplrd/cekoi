import 'package:cekoi/domain/rules/round.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';

/// Les libellés des manches, côté présentation.
///
/// [Round] est du domaine et ne connaît que son numéro : les noms et les
/// contraintes affichés viennent de l'ARB, et la table de correspondance vit
/// ici plutôt que recopiée dans chaque écran qui en a besoin.
extension RoundLabels on Round {
  String label(AppLocalizations l10n) => switch (this) {
    Round.freeDescription => l10n.roundNameFree,
    Round.oneWord => l10n.roundNameOneWord,
    Round.mime => l10n.roundNameMime,
  };

  /// La contrainte, telle qu'on la rappelle au narrateur avant son tour.
  String rule(AppLocalizations l10n) => switch (this) {
    Round.freeDescription => l10n.roundRuleFree,
    Round.oneWord => l10n.roundRuleOneWord,
    Round.mime => l10n.roundRuleMime,
  };
}
