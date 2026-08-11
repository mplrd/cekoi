import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/features/play/presentation/play_controller.dart';
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
    // Le compte à rebours de « C'est parti » : tant qu'il tourne, le tour est
    // lancé même si la phase ne l'est pas encore.
    final countdown = ref.watch(playControllerProvider);

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

    // Le retour reste libre **jusqu'au clic sur « C'est parti »** de la manche
    // 1 : à ce stade il n'y a qu'un paquet tiré, qu'un nouveau tirage
    // remplacera. On revient donc à la configuration comme d'un écran
    // ordinaire, sans confirmation — demander « voulez-vous abandonner ? »
    // pour une partie que personne n'a commencée est une fausse alerte.
    //
    // Une partie terminée se quitte librement pour la raison inverse : il n'y
    // a plus rien à perdre.
    final librementQuittable =
        game.phase == GamePhase.finished ||
        (game.isUntouched && countdown == null);

    return PopScope(
      canPop: librementQuittable,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          // La partie tirée est jetée en repartant : la laisser en place la
          // ferait proposer en reprise depuis l'accueil (R9.1), alors qu'elle
          // n'a jamais commencé.
          if (game.isUntouched) {
            ref.read(currentGameProvider.notifier).game = null;
          }
          return;
        }
        if (!context.mounted) return;
        if (await _confirmQuit(context) && context.mounted) {
          ref.read(currentGameProvider.notifier).game = null;
          context.go(AppRoutes.home);
        }
      },
      // Le fond vient du thème, comme sur tous les autres écrans. La manche se
      // lit sur l'anneau du chrono et sur la pastille de l'en-tête : repeindre
      // l'écran entier à chaque manche donnait trois applications différentes,
      // et forçait chaque élément à recalculer son encre selon le fond.
      child: Scaffold(
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
