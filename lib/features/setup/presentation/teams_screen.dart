import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/app/widgets/texte_qui_tient.dart';
import 'package:cekoi/domain/engine/team_builder.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/setup_steps.dart';
import 'package:cekoi/features/setup/presentation/widgets/launch_button.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_scaffold.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dernière étape — combien d'équipes, comment elles s'appellent (R8.3), et
/// le lancement de la partie.
///
/// L'écran tient en deux gestes parce que c'est le moment où tout le monde
/// attend autour de la table. L'application ne connaît pas les joueurs (R8.2) :
/// qui joue avec qui se règle de vive voix, plus vite que par un écran.
///
/// C'est aussi d'ici que part la partie. Une sixième étape récapitulait la
/// configuration avant de lancer : elle n'apprenait rien à qui venait de tout
/// choisir, et son seul contenu propre était le bouton. Il a donc rejoint la
/// dernière étape réelle, avec la mention de la publicité qui peut suivre.
class TeamsScreen extends ConsumerStatefulWidget {
  const TeamsScreen({super.key});

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen> {
  /// Un contrôleur par équipe, créés à la demande.
  ///
  /// Le domaine fait foi sur les noms : redescendre le nombre d'équipes coupe
  /// celles du bas, et remonter ne les ressuscite pas (R8.4, cas limite 14).
  /// Les contrôleurs doivent donc disparaître avec elles — les garder ferait
  /// afficher un nom que la partie n'emporterait pas.
  final _controllers = <int, TextEditingController>{};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int index, String value) {
    final existing = _controllers[index];
    if (existing != null) return existing;
    return _controllers[index] = TextEditingController(text: value);
  }

  /// Change le nombre d'équipes en jetant les champs des équipes retirées.
  ///
  /// Le tri se fait ici et non pendant `build` : écrire dans un
  /// `TextEditingController` en cours de construction ferait reconstruire le
  /// champ qui l'écoute.
  void _setTeamCount(int count) {
    for (final index in _controllers.keys.toList()) {
      if (index >= count) _controllers.remove(index)!.dispose();
    }
    ref.read(setupControllerProvider.notifier).setTeamCount(count);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setup = ref.watch(setupControllerProvider);
    final controller = ref.read(setupControllerProvider.notifier);

    return SetupScaffold(
      step: SetupStep.teams,
      title: l10n.setupTeamsTitle,
      footer: const LaunchButton(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        children: [
          _TeamCountSelector(
            value: setup.teamCount,
            onChanged: _setTeamCount,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.teamNamesOptional,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < setup.teamCount; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              // **Pas de `maxLength`, et c'est un arbitrage rendu** (27 août
              // 2026) : le texte d'une carte est borné à 60 caractères et le
              // nom d'une catégorie à 30, mais un nom d'équipe est libre. Un
              // joueur qui en choisit un à rallonge le verra tout petit à
              // l'écran, et c'est son affaire.
              //
              // Ce que ça impose au reste : les quatre endroits qui affichent
              // ce nom — annonce de tour, bilan de tour, bouton du départage,
              // podium — le composent avec `TexteQuiTient`, sans quoi il est
              // rogné. Un nom en un seul mot n'a aucun point de coupure.
              child: TextField(
                controller: _controllerFor(index, setup.teamNames[index]),
                textInputAction: TextInputAction.next,
                onChanged: (name) => controller.renameTeam(index, name),
                decoration: InputDecoration(
                  // Le nom par défaut est un libellé de champ et non une
                  // valeur : il s'affiche dans le champ vide sans qu'il faille
                  // l'effacer avant de taper le sien (R8.3).
                  labelText: l10n.teamDefaultName(index + 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le nombre d'équipes : moins, le nombre, plus.
///
/// Une rangée de pastilles pour un entier, c'était offrir un choix là où il n'y
/// a qu'un compteur. Elle débordait sur deux lignes, s'arrêtait arbitrairement
/// à une valeur, et demandait un bouton *Plus* pour aller au-delà — trois
/// mécaniques pour un nombre qu'on monte et qu'on descend.
///
/// Le compteur n'a **pas de limite haute** : R8.1 n'en pose aucune, et une
/// dixième équipe coûte huit taps comme la troisième en coûte un.
/// La largeur de la case du nombre, entre les deux flèches.
///
/// Elle vaut `AppTheme.minTouchTarget` par coïncidence, et n'a rien à voir avec
/// une cible tactile : c'est la place qu'il faut pour que « 10 » ne pousse pas
/// les flèches. Les deux valeurs sont nommées pour qu'on ne les « harmonise »
/// pas un jour.
const double _largeurDuCompteur = 64;

class _TeamCountSelector extends StatelessWidget {
  const _TeamCountSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Row(
      children: [
        // La ligne se partage entre ce libellé et un compteur de largeur fixe :
        // ce qui reste au libellé rétrécit à mesure que le texte grossit.
        // Mesuré, « équipes » réclamait 137,2 px dans 128 à ×2.
        Expanded(
          child: TexteQuiTient(
            l10n.teamCountLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _Step(
          icon: Icons.remove,
          // R8.5 : deux équipes est le minimum d'une partie.
          onTap: value > minimumTeamCount ? () => onChanged(value - 1) : null,
          semantics: l10n.teamCountFewer,
        ),
        // La boîte reste à 64 px : les deux flèches ne doivent pas se
        // déplacer quand le nombre passe à deux chiffres. C'est donc le
        // nombre qui se ramène, et pas la boîte qui s'élargit.
        //
        // Un nombre n'a **aucun** point de coupure : il était écrêté, sans
        // exception ni trace. Mesuré, « 10 » réclamait 66,7 px dès ×1,6 —
        // un cran ordinaire du réglage Android, pas un cas extrême — 83,4 à
        // ×2 et 129,3 à ×3,1, où la moitié du zéro disparaissait. Or c'est
        // exactement à dix équipes, le maximum que R8.1 promet utilisable,
        // que le nombre passe à deux chiffres.
        SizedBox(
          width: _largeurDuCompteur,
          child: TexteQuiTient(
            '$value',
            alignment: Alignment.center,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
              // Le nombre ne doit pas se décaler en passant à deux chiffres.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _Step(
          icon: Icons.add,
          onTap: () => onChanged(value + 1),
          semantics: l10n.teamCountMore,
        ),
      ],
    );
  }
}

/// Un des deux boutons du compteur.
class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.onTap,
    required this.semantics,
  });

  final IconData icon;

  /// `null` en butée basse : grisé plutôt que retiré, sinon la rangée se
  /// décale d'un bouton entre deux et trois équipes.
  final VoidCallback? onTap;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final actif = onTap != null;

    return Semantics(
      button: true,
      enabled: actif,
      label: semantics,
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppTheme.radius),
          ),
          side: BorderSide(
            color: AppColors.main.withValues(alpha: actif ? 1 : 0.3),
            width: 3,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppTheme.radius),
          ),
          child: SizedBox(
            width: AppTheme.minTile,
            height: AppTheme.minTile,
            child: Icon(
              icon,
              size: 26,
              color: AppColors.ink.withValues(alpha: actif ? 1 : 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
