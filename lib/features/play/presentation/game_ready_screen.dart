import 'package:cekoi/app/router.dart';
import 'package:cekoi/features/play/presentation/current_game.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Ce que la configuration produit : une partie prête, paquet tiré.
///
/// L'écran de jeu proprement dit appartient au lot suivant. Celui-ci existe
/// pour que le parcours aboutisse à quelque chose de vérifiable à la main
/// plutôt qu'à un bouton sans effet.
class GameReadyScreen extends ConsumerWidget {
  const GameReadyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final game = ref.watch(currentGameProvider);

    if (game == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go(AppRoutes.home),
            child: Text(l10n.actionBackHome),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gameReadyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              l10n.gameReadyDeck(game.deck.length),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.gameReadyPending, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            for (final team in game.teams)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(team.name),
                subtitle: Text(
                  [
                    for (final id in team.playerIds)
                      game.players.firstWhere((p) => p.id == id).name,
                  ].join(', '),
                ),
              ),
            const Divider(height: 32),
            for (final card in game.deck)
              Text('· ${card.text}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                ref.read(currentGameProvider.notifier).game = null;
                context.go(AppRoutes.home);
              },
              child: Text(l10n.actionBackHome),
            ),
          ],
        ),
      ),
    );
  }
}
