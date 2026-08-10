import 'dart:async';

import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/features/play/presentation/play_controller.dart';
import 'package:cekoi/features/play/presentation/widgets/game_card_face.dart';
import 'package:cekoi/features/play/presentation/widgets/turn_timer_ring.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// L'écran de jeu : chrono, carte, deux actions. Rien d'autre.
///
/// Il se reconstruit dix fois par seconde à cause du chrono, d'où les `select`
/// : seul l'anneau doit suivre ce rythme, la carte et les boutons ne changent
/// qu'aux actions du narrateur.
class PlayingView extends ConsumerWidget {
  const PlayingView({required this.game, super.key});

  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdown = ref.watch(playControllerProvider);

    // Son discret et retour haptique sur chaque seconde de la fin (`SPEC.md`).
    // Le narrateur regarde la carte, pas le chrono : il doit sentir la fin
    // arriver sans lever les yeux.
    //
    // Le son est celui du système plutôt qu'un fichier : il suit le volume et
    // le mode silencieux de l'appareil, ce qu'un asset joué à plein régime au
    // milieu d'un repas ne ferait pas. Un son dessiné pourra le remplacer.
    ref.listen(
      currentGameProvider.select(
        (g) => (g?.remaining ?? Duration.zero).inSeconds,
      ),
      (avant, apres) {
        if (avant == apres || apres <= 0) return;
        if (apres < TurnTimerRing.urgentBelow.inSeconds) {
          unawaited(HapticFeedback.lightImpact());
          unawaited(SystemSound.play(SystemSoundType.click));
        }
      },
    );

    return Column(
      children: [
        _Header(game: game),
        Expanded(
          child: switch ((countdown, game.isPaused)) {
            (final int seconds, _) => _Countdown(seconds: seconds),
            (_, true) => const _PausePanel(),
            _ => _CardZone(game: game),
          },
        ),
        // `SPEC.md` veut deux zones d'action occupant la moitié basse, et non
        // deux boutons : on tape sans regarder, téléphone tenu à bout de bras
        // au milieu d'une table qui crie.
        Expanded(child: _Actions(game: game)),
      ],
    );
  }
}

/// Équipe active, score et pause, discrets — `SPEC.md` veut l'écran nu.
class _Header extends ConsumerWidget {
  const _Header({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final remaining = ref.watch(
      currentGameProvider.select((g) => g?.remaining ?? Duration.zero),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.gameTeamScore(
                    game.activeTeam.name,
                    game.scoreOf(game.activeTeam.id),
                  ),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.team(game.activeTeam.colorId),
                  ),
                ),
              ),
              IconButton(
                onPressed: game.isPaused
                    ? ref.read(playControllerProvider.notifier).requestResume
                    : ref.read(playControllerProvider.notifier).pause,
                icon: Icon(game.isPaused ? Icons.play_arrow : Icons.pause),
                tooltip: game.isPaused ? l10n.actionResume : l10n.actionPause,
              ),
            ],
          ),
          TurnTimerRing(
            remaining: remaining,
            total: game.config.turnDuration,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.gameRemainingCards(game.pile.length),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// La carte, et le glissement horizontal qui double les deux boutons.
class _CardZone extends ConsumerWidget {
  const _CardZone({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = game.currentCard;
    if (card == null) return const SizedBox.shrink();

    final controller = ref.read(playControllerProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final vitesse = details.primaryVelocity ?? 0;
        if (vitesse > 0) {
          controller.found();
        } else if (vitesse < 0 && game.canPass) {
          controller.passed();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: GameCardFace(card: card),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Text(
        AppLocalizations.of(context).gameSecondsLeft(seconds),
        style: theme.textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// R3.8 : la pause masque la carte immédiatement.
class _PausePanel extends StatelessWidget {
  const _PausePanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pause_circle_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.gamePausedTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              l10n.gamePausedBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les deux zones d'action, moitié basse : Passer à gauche, Trouvé à droite.
class _Actions extends ConsumerWidget {
  const _Actions({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(playControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!game.canPass && game.pile.length == 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.gamePassLocked,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          Expanded(
            child: Row(
              // Sans `stretch`, les boutons gardent leur hauteur intrinsèque
              // et flottent au milieu de la zone : on retomberait sur deux
              // boutons ordinaires au lieu des deux zones voulues.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: game.canPass ? controller.passed : null,
                    child: Text(l10n.actionPass),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.found,
                    ),
                    onPressed: game.canAct ? controller.found : null,
                    child: Text(l10n.actionFound),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
