import 'package:cekoi/app/router.dart';
import 'package:cekoi/domain/engine/team_builder.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/widgets/choice_tile.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_scaffold.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Étape 4 — combien d'équipes, et comment elles s'appellent (R8.3).
///
/// L'écran tient en deux gestes parce que c'est le moment où tout le monde
/// attend autour de la table. L'application ne connaît pas les joueurs (R8.2) :
/// qui joue avec qui se règle de vive voix, plus vite que par un écran.
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
      step: 4,
      title: l10n.setupTeamsTitle,
      footer: FilledButton(
        onPressed: () => context.push(AppRoutes.setupSummary),
        child: Text(l10n.actionContinue),
      ),
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

class _TeamCountSelector extends StatelessWidget {
  const _TeamCountSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  /// R8.1 ne pose pas de limite haute, seulement une exigence d'ergonomie :
  /// au-delà de six équipes on passe par la saisie, pas par une rangée de
  /// pastilles qui déborde.
  static const int _presetTop = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final top = value > _presetTop ? value : _presetTop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.teamCountLabel,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var count = minimumTeamCount; count <= top; count++)
              ChoiceTile(
                label: '$count',
                selected: value == count,
                onTap: () => onChanged(count),
              ),
            ChoiceTile(
              label: l10n.teamCountMore,
              icon: Icons.add,
              selected: false,
              // Une équipe de plus que celles qu'on joue, pas une de plus que
              // la rangée : à deux équipes, « Plus » en donne trois.
              onTap: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}
