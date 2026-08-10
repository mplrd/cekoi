import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/features/play/presentation/widgets/playing_view.dart';
import 'package:cekoi/features/play/presentation/widgets/turn_intro_view.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// L'écran de partie. Une route, six phases.
///
/// La phase du moteur décide de ce qui s'affiche : l'interface ne tient pas sa
/// propre machine à états en parallèle, qui finirait par diverger de celle du
/// réducteur — sur un retour arrière ou une reprise de partie, typiquement.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
      body: SafeArea(
        child: switch (game.phase) {
          GamePhase.turnIntro => TurnIntroView(game: game),
          GamePhase.playing => PlayingView(game: game),
          // Les phases suivantes arrivent dans la tranche d'après ; l'écran
          // reste navigable en attendant plutôt que de rendre du vide.
          GamePhase.turnSummary ||
          GamePhase.roundSummary ||
          GamePhase.tieBreak ||
          GamePhase.finished => _Pending(l10n: l10n),
        },
      ),
    );
  }
}

class _Pending extends ConsumerWidget {
  const _Pending({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.gamePhasePending),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            ref.read(currentGameProvider.notifier).game = null;
            context.go(AppRoutes.home);
          },
          child: Text(l10n.actionBackHome),
        ),
      ],
    ),
  );
}
