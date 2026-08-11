import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/features/play/presentation/play_controller.dart';
import 'package:cekoi/features/play/presentation/widgets/action_zone.dart';
import 'package:cekoi/features/play/presentation/widgets/round_labels.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// L'écran d'annonce d'un tour : quelle équipe, sous quelle contrainte.
///
/// `SPEC.md` en fait un écran à part entière et non une transition animée :
/// il existe pour que le téléphone ait le temps de changer de mains avant que
/// le chrono parte.
///
/// Le narrateur n'y est pas nommé : l'équipe le désigne elle-même (R3.1). La
/// règle de la manche, elle, y est rappelée en toutes lettres (R2.3) — c'est
/// le seul moment de la partie où tout le monde écoute.
class TurnIntroView extends ConsumerWidget {
  const TurnIntroView({required this.game, super.key});

  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final countdown = ref.watch(playControllerProvider);
    // Le fond est celui du thème, comme partout : l'encre est celle du jeu.
    const encre = AppColors.ink;
    final voile = AppColors.inkSoft;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.roundStep(game.roundIndex + 1, game.rounds.length),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: voile,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            game.round.label(l10n),
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              color: encre,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            game.round.rule(l10n),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: voile),
          ),
          const SizedBox(height: 40),
          Text(
            l10n.turnIntroTeam(game.activeTeam.name),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: encre,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.turnIntroPassPhone,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: voile),
          ),
          const SizedBox(height: 48),
          if (countdown == null)
            ActionZone(
              label: l10n.actionStartTurn,
              background: AppColors.deep,
              foreground: Colors.white,
              onPressed: ref.read(playControllerProvider.notifier).startTurn,
            )
          else
            Text(
              l10n.gameSecondsLeft(countdown),
              textAlign: TextAlign.center,
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: encre,
              ),
            ),
        ],
      ),
    );
  }
}
