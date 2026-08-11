import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/features/play/presentation/widgets/playing_view.dart';
import 'package:cekoi/features/play/presentation/widgets/podium_view.dart';
import 'package:cekoi/features/play/presentation/widgets/round_summary_view.dart';
import 'package:cekoi/features/play/presentation/widgets/tie_break_view.dart';
import 'package:cekoi/features/play/presentation/widgets/turn_intro_view.dart';
import 'package:cekoi/features/play/presentation/widgets/turn_summary_view.dart';
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

    return PopScope(
      // Une partie terminée se quitte librement : il n'y a plus rien à perdre.
      canPop: game.phase == GamePhase.finished,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !context.mounted) return;
        if (await _confirmQuit(context) && context.mounted) {
          ref.read(currentGameProvider.notifier).game = null;
          context.go(AppRoutes.home);
        }
      },
      // La partie se joue en couleur, et la couleur dit la manche : le corail
      // de la bulle en description libre, le teal des étincelles au mot
      // unique, le rouge de l'explosion au mime. C'est l'information qu'on
      // perd le plus vite en jouant, et elle se lit ici sans un mot.
      //
      // Les écrans de bilan sortent de ce code : une manche vient de finir, la
      // couleur suivante n'a pas encore de sens. Ils prennent le corail de la
      // marque, comme l'accueil.
      child: Scaffold(
        backgroundColor: switch (game.phase) {
          GamePhase.turnIntro ||
          GamePhase.playing ||
          GamePhase.turnSummary => AppColors.round(game.round),
          _ => AppColors.seed,
        },
        body: SafeArea(
          child: switch (game.phase) {
            GamePhase.turnIntro => TurnIntroView(game: game),
            GamePhase.playing => PlayingView(game: game),
            GamePhase.turnSummary => TurnSummaryView(game: game),
            GamePhase.roundSummary => RoundSummaryView(game: game),
            GamePhase.tieBreak => TieBreakView(game: game),
            GamePhase.finished => PodiumView(game: game),
          },
        ),
      ),
    );
  }

  /// Demande confirmation avant d'abandonner (`SPEC.md` : aucun geste
  /// irréversible sans confirmation).
  ///
  /// Un retour système en plein tour est vite arrivé, et perdre le tour d'une
  /// équipe en fait partie. La confirmation rappelle au passage que la partie
  /// peut être reprise depuis l'accueil (R9.1) plutôt qu'abandonnée.
  Future<bool> _confirmQuit(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    final quitte = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.quitGameTitle),
        content: Text(l10n.quitGameBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionKeepPlaying),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionQuitGame),
          ),
        ],
      ),
    );

    return quitte ?? false;
  }
}
