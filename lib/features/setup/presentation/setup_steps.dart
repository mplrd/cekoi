import 'package:cekoi/domain/entities/audience.dart';

/// Les étapes de la configuration.
///
/// L'énumération sert de position **logique** : le numéro affiché et le nombre
/// total se déduisent du mode, parce que les deux parcours ne passent pas par
/// les mêmes écrans. Chaque écran déclare qui il est, jamais son rang — sinon
/// retirer une étape obligerait à renuméroter les suivantes.
enum SetupStep { mode, decks, pool, settings, teams, summary }

/// Les étapes réellement traversées dans [mode].
///
/// Cinq de chaque côté, et c'est voulu : la deuxième étape est le choix de
/// contenu, quel que soit le mode. En Famille ce sont les catégories, en Sans
/// filtre c'est l'étendue du vivier (R7.10) — les catégories n'y proposeraient
/// rien à décider, ce mode les prend toutes (R7.1).
///
/// Aucun parcours ne contient les deux : [SetupStep.decks] et [SetupStep.pool]
/// occupent la même place, chacun dans son mode.
List<SetupStep> setupStepsFor(Audience mode) => switch (mode) {
  Audience.adult => const [
    SetupStep.mode,
    SetupStep.pool,
    SetupStep.settings,
    SetupStep.teams,
    SetupStep.summary,
  ],
  Audience.family => const [
    SetupStep.mode,
    SetupStep.decks,
    SetupStep.settings,
    SetupStep.teams,
    SetupStep.summary,
  ],
};
