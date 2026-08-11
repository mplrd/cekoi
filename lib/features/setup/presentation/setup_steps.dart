import 'package:cekoi/domain/entities/audience.dart';

/// Les étapes de la configuration.
///
/// L'énumération sert de position **logique** : le numéro affiché et le nombre
/// total se déduisent du mode, parce que le parcours n'a pas la même longueur
/// des deux côtés (R7.10). Chaque écran déclare qui il est, jamais son rang —
/// sinon retirer une étape obligerait à renuméroter les quatre suivantes.
enum SetupStep { mode, decks, settings, teams, summary }

/// Les étapes réellement traversées dans [mode].
///
/// Le mode Sans filtre saute le choix des catégories : il les prend toutes
/// (R7.1) et n'a aucun profil, l'écran n'y proposait donc rien à décider
/// (R7.10).
List<SetupStep> setupStepsFor(Audience mode) => switch (mode) {
  Audience.adult => const [
    SetupStep.mode,
    SetupStep.settings,
    SetupStep.teams,
    SetupStep.summary,
  ],
  Audience.family => SetupStep.values,
};
