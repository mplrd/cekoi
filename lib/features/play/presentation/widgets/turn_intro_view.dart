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

    // L'annonce défile, l'action reste collée en bas — la convention du
    // dépôt, écrite dans `SetupScaffold` et suivie par le podium, le bilan de
    // tour et le bilan de manche. Elle vaut doublement ici : c'est l'écran qui
    // existe pour que le téléphone change de mains, et celui qui le reçoit
    // n'était pas en train de regarder. Un bouton qu'il faut d'abord trouver
    // en faisant défiler n'est pas un bouton.
    //
    // L'écran ne faisait avant ni l'un ni l'autre de ce que `SPEC.md` accepte
    // — tenir, ou défiler : 132 px sous le bord sur un 360 × 640, 454 px avec
    // le texte agrandi par le système, et « C'est parti » avec eux.
    //
    // Le `minHeight` est ce qui préserve le centrage : sans lui le texte se
    // colle en haut dès qu'il y a de la place, et l'annonce n'occupe plus
    // l'écran. Il tient parce que la colonne n'a aucun enfant flexible et peut
    // donc se mesurer sous une hauteur infinie — y ajouter un `Expanded` ou un
    // `Spacer` ferait lever `RenderFlex` dès la première mise en page.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, contraintes) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: contraintes.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: voile,
                        ),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: voile,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Le compte à rebours prend exactement la place du bouton : ce qui
        // bouge à l'écran est ce qui a changé, et rien d'autre.
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
          child: countdown == null
              ? ActionZone(
                  label: l10n.actionStartTurn,
                  background: AppColors.deep,
                  foreground: Colors.white,
                  onPressed: ref
                      .read(playControllerProvider.notifier)
                      .startTurn,
                )
              : Text(
                  l10n.gameSecondsLeft(countdown),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: encre,
                  ),
                ),
        ),
      ],
    );
  }
}
