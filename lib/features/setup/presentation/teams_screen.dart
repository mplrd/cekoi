import 'package:cekoi/app/router.dart';
import 'package:cekoi/domain/engine/team_builder.dart';
import 'package:cekoi/domain/entities/player.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:cekoi/domain/setup/game_setup.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_scaffold.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Étape 4 — joueurs et composition des équipes (R8).
///
/// L'étape la plus travaillée de la configuration : c'est le moment où tout
/// le monde attend autour de la table.
class TeamsScreen extends ConsumerStatefulWidget {
  const TeamsScreen({super.key});

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// Une validation par joueur, et le focus revient au champ : on saisit huit
  /// prénoms d'affilée sans lever les yeux.
  void _addPlayer() {
    if (ref
        .read(setupControllerProvider.notifier)
        .addPlayer(
          _nameController.text,
        )) {
      _nameController.clear();
    }
    _nameFocus.requestFocus();
  }

  /// Conserve les noms déjà donnés aux équipes quand on relance (R8.4).
  List<String> _teamNames(GameSetup setup, AppLocalizations l10n) => [
    for (var i = 0; i < setup.teamCount; i++)
      if (i < setup.teams.length)
        setup.teams[i].name
      else
        l10n.teamDefaultName(i + 1),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setup = ref.watch(setupControllerProvider);
    final controller = ref.read(setupControllerProvider.notifier);
    final teamsAreValid =
        setup.teams.isNotEmpty &&
        setup.teams.every((t) => t.playerIds.length >= minimumTeamSize);

    return SetupScaffold(
      step: 4,
      title: l10n.setupTeamsTitle,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (setup.teams.isNotEmpty && !teamsAreValid)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.teamNeedsTwoPlayers,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: teamsAreValid
                ? () => context.push(AppRoutes.setupSummary)
                : null,
            child: Text(l10n.actionContinue),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.playerNameHint,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addPlayer(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: _addPlayer,
                icon: const Icon(Icons.add),
                tooltip: l10n.actionAddPlayer,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.playerCount(setup.players.length)),
          for (final player in setup.players)
            _PlayerTile(
              player: player,
              onToggleChild: () => controller.toggleChild(player.id),
              onRemove: () => controller.removePlayer(player.id),
            ),
          const Divider(height: 32),
          _TeamCountSelector(
            value: setup.teamCount,
            maxCount: setup.players.length ~/ minimumTeamSize,
            onChanged: controller.setTeamCount,
          ),
          const SizedBox(height: 12),
          if (!setup.canProposeTeams)
            Text(
              l10n.teamsNeedMorePlayers(
                setup.teamCount * minimumTeamSize,
                setup.teamCount,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton.tonalIcon(
            onPressed: setup.canProposeTeams
                ? () => controller.proposeTeams(_teamNames(setup, l10n))
                : null,
            icon: const Icon(Icons.casino_outlined),
            label: Text(
              setup.teams.isEmpty
                  ? l10n.actionProposeTeams
                  : l10n.actionShuffleTeams,
            ),
          ),
          const SizedBox(height: 16),
          for (final team in setup.teams)
            _TeamCard(
              team: team,
              players: setup.players,
              otherTeams: [
                for (final other in setup.teams)
                  if (other.id != team.id) other,
              ],
              onRename: (name) => controller.renameTeam(team.id, name),
              onMove: (playerId, toTeamId) =>
                  controller.movePlayer(playerId, toTeamId: toTeamId),
            ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.onToggleChild,
    required this.onRemove,
  });

  final Player player;
  final VoidCallback onToggleChild;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(player.name),
      leading: IconButton(
        // Un tap marque « enfant » : la répartition les répartira au lieu de
        // les concentrer dans une équipe (R8.3).
        onPressed: onToggleChild,
        tooltip: l10n.playerChildBadge,
        isSelected: player.isChild,
        icon: const Icon(Icons.child_care_outlined),
        selectedIcon: const Icon(Icons.child_care),
      ),
      subtitle: player.isChild ? Text(l10n.playerChildBadge) : null,
      trailing: IconButton(
        onPressed: onRemove,
        icon: const Icon(Icons.close),
      ),
    );
  }
}

class _TeamCountSelector extends StatelessWidget {
  const _TeamCountSelector({
    required this.value,
    required this.maxCount,
    required this.onChanged,
  });

  final int value;

  /// Plafonné par l'effectif : proposer huit équipes à six joueurs n'a pas
  /// de sens, et R8.1 ne pose de limite haute que sur l'ergonomie.
  final int maxCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final top = maxCount < minimumTeamCount ? minimumTeamCount : maxCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.teamCountLabel,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            for (var count = minimumTeamCount; count <= top; count++)
              ChoiceChip(
                label: Text('$count'),
                selected: value == count,
                onSelected: (_) => onChanged(count),
              ),
          ],
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.players,
    required this.otherTeams,
    required this.onRename,
    required this.onMove,
  });

  final Team team;
  final List<Player> players;
  final List<Team> otherTeams;
  final ValueChanged<String> onRename;
  final void Function(String playerId, String toTeamId) onMove;

  String _nameOf(String playerId) =>
      players.firstWhere((p) => p.id == playerId).name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    team.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _rename(context),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.actionRenameTeam,
                ),
              ],
            ),
            for (final playerId in team.playerIds)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_nameOf(playerId)),
                trailing: otherTeams.isEmpty
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: l10n.actionMovePlayer,
                        icon: const Icon(Icons.swap_horiz),
                        onSelected: (toTeamId) => onMove(playerId, toTeamId),
                        itemBuilder: (context) => [
                          for (final other in otherTeams)
                            PopupMenuItem(
                              value: other.id,
                              child: Text(other.name),
                            ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: team.name);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.actionRenameTeam),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.actionContinue),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name != null) onRename(name);
  }
}
