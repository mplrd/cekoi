import 'dart:async';

import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/preferences.dart';
import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/rules/round.dart';
import 'package:cekoi/features/play/presentation/play_controller.dart';
import 'package:cekoi/features/play/presentation/widgets/action_zone.dart';
import 'package:cekoi/features/play/presentation/widgets/game_card_face.dart';
import 'package:cekoi/features/play/presentation/widgets/round_labels.dart';
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
    // Lu dans le `build` et non dans l'écouteur : la lecture en base est
    // asynchrone, et un provider instancié au moment du premier bip répondrait
    // par ses valeurs par défaut — le son coupé sonnerait une fois quand même.
    //
    // Deux réglages distincts et non un seul : couper le son sans perdre la
    // vibration est justement ce qu'on veut au restaurant, et l'inverse aussi
    // — la vibration seule agace celui qui tient le téléphone.
    final reglages = ref.watch(currentPreferencesProvider);

    ref.listen(
      currentGameProvider.select(
        (g) => (g?.remaining ?? Duration.zero).inSeconds,
      ),
      (avant, apres) {
        if (avant == apres || apres <= 0) return;
        if (apres >= TurnTimerRing.urgentBelow.inSeconds) return;

        if (reglages.hapticsEnabled) {
          unawaited(HapticFeedback.lightImpact());
        }
        if (reglages.soundEnabled) {
          unawaited(SystemSound.play(SystemSoundType.click));
        }
      },
    );

    // `SPEC.md` veut deux zones d'action occupant la moitié basse, et non deux
    // boutons : on tape sans regarder, téléphone tenu à bout de bras au milieu
    // d'une table qui crie.
    //
    // En manche 1 il n'en reste qu'une (R3.9), et lui laisser la moitié de
    // l'écran la rendait démesurée — retour d'usage. Elle descend à un tiers :
    // assez pour rester une zone qu'on tape sans viser, et la carte récupère
    // la place, ce qui est tout bénéfice puisque c'est elle qu'on lit.
    final actionsAreSplit = game.round.allowsPass;

    return Column(
      children: [
        _Header(game: game),
        Expanded(
          flex: actionsAreSplit ? 1 : 2,
          child: switch ((countdown, game.isPaused)) {
            // L'encre est celle du jeu, plus celle d'une couleur de manche :
            // le fond est le pastel du thème. Ces deux vues portaient encore
            // `onRound`, qui rend du blanc en manches 2 et 3 — soit 1,5:1 sur
            // ce fond. L'écran de pause et le compte à rebours de reprise
            // étaient donc invisibles deux manches sur trois.
            (final int seconds, _) => _Countdown(
              seconds: seconds,
              color: AppColors.ink,
            ),
            (_, true) => const _PausePanel(encre: AppColors.ink),
            _ => _CardZone(game: game),
          },
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              // La pastille de manche : le seul endroit où la couleur de la
              // manche est nommée *et* montrée. C'est ce qu'on cherche quand
              // on prend le téléphone au milieu d'une partie.
              _RoundPill(round: game.round),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.gameTeamScore(
                    game.activeTeam.name,
                    game.scoreOf(game.activeTeam.id),
                  ),
                  overflow: TextOverflow.ellipsis,
                  // Le nom de l'équipe prenait sa couleur d'équipe, illisible
                  // sur fond coloré : il reste en encre, la pastille de manche
                  // porte la couleur.
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: game.isPaused
                    ? ref.read(playControllerProvider.notifier).requestResume
                    : ref.read(playControllerProvider.notifier).pause,
                icon: Icon(game.isPaused ? Icons.play_arrow : Icons.pause),
                color: AppColors.ink,
                tooltip: game.isPaused ? l10n.actionResume : l10n.actionPause,
              ),
            ],
          ),
          TurnTimerRing(
            remaining: remaining,
            total: game.config.turnDuration,
            accent: AppColors.round(game.round),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.gameRemainingCards(game.pile.length),
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Le numéro de la manche, dans sa couleur.
///
/// Court exprès — « M2 » et non « Manche 2 » : la place de l'en-tête sert
/// d'abord au nom de l'équipe, et la couleur porte déjà l'essentiel. Le libellé
/// complet reste accessible aux lecteurs d'écran.
class _RoundPill extends StatelessWidget {
  const _RoundPill({required this.round});

  final Round round;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: round.label(l10n),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.round(round),
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
        child: Text(
          l10n.scoreRoundShort(round.number),
          // 19 px en gras, et non l'échelle du libellé : sur le rouge du mime,
          // le blanc plafonne à 4:1, sous le seuil du texte courant. À cette
          // taille et cette graisse, c'est du grand texte au sens WCAG, dont
          // le seuil est 3:1. Deux caractères — la place ne manque pas.
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 19,
            color: AppColors.onRound(round),
            fontWeight: FontWeight.w800,
          ),
        ),
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

    return _SwipeZone(
      // Le glissement décidait sur la seule vélocité, et le moindre signe
      // suffisait : un mouvement lent ne faisait rien du tout — le narrateur
      // croyait son geste ignoré — pendant qu'une dérive vive vers la gauche
      // passait la carte, qui ressortait plus tard. Deux plaintes distinctes
      // en partie, une seule cause.
      //
      // La distance parcourue décide désormais, la vélocité ne fait
      // qu'ouvrir un raccourci pour les gestes francs. En dessous des deux
      // seuils, le geste n'est pas une intention : on ne fait rien.
      onFound: controller.found,
      onPassed: game.canPass ? controller.passed : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: GameCardFace(card: card),
      ),
    );
  }
}

/// Le glissement horizontal qui double les deux zones d'action.
///
/// Décide sur la **distance**, pas sur la vélocité seule : un glissement lent
/// mais franc est une intention aussi claire qu'un geste vif, et l'ancienne
/// version ne faisait rien du tout dans ce cas. La vélocité reste un raccourci
/// pour les gestes rapides et courts, qui n'atteignent pas la distance.
///
/// En dessous des deux seuils, aucune action : mieux vaut un geste sans effet
/// qu'une carte passée par erreur, qui ressortira plus tard sans que personne
/// comprenne pourquoi.
class _SwipeZone extends StatefulWidget {
  const _SwipeZone({
    required this.onFound,
    required this.onPassed,
    required this.child,
  });

  final VoidCallback onFound;

  /// `null` en manche 1 : *Passer* n'y existe pas (R3.9).
  final VoidCallback? onPassed;

  final Widget child;

  @override
  State<_SwipeZone> createState() => _SwipeZoneState();
}

class _SwipeZoneState extends State<_SwipeZone> {
  /// Un quart de la largeur de l'écran, plafonné : au-delà, le geste
  /// deviendrait pénible à faire d'une main sur un grand téléphone.
  static const double _distanceMax = 90;

  /// Un geste vif et court compte aussi — c'est ainsi qu'on balaie quand on
  /// enchaîne les cartes.
  static const double _vitesseFranche = 600;

  double _parcouru = 0;

  void _decider(double vitesse, double largeur) {
    final seuil = (largeur / 4).clamp(40.0, _distanceMax);
    final franc = _parcouru.abs() >= seuil || vitesse.abs() >= _vitesseFranche;
    if (!franc) return;

    if (_parcouru > 0 || vitesse > 0) {
      widget.onFound();
    } else {
      widget.onPassed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final largeur = MediaQuery.sizeOf(context).width;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _parcouru = 0,
      onHorizontalDragUpdate: (d) => _parcouru += d.delta.dx,
      onHorizontalDragEnd: (d) => _decider(d.primaryVelocity ?? 0, largeur),
      child: widget.child,
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.seconds, required this.color});

  final int seconds;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Text(
        AppLocalizations.of(context).gameSecondsLeft(seconds),
        style: theme.textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

/// R3.8 : la pause masque la carte immédiatement.
class _PausePanel extends StatelessWidget {
  const _PausePanel({required this.encre});

  final Color encre;

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
            Icon(Icons.pause_circle_outline, size: 72, color: encre),
            const SizedBox(height: 16),
            Text(
              l10n.gamePausedTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: encre,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.gamePausedBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: encre.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les zones d'action, bas de l'écran : Passer à gauche, Trouvé à droite.
///
/// En manche 1, *Passer* n'existe pas (R3.9) : la zone est **retirée**, pas
/// grisée, et *Trouvé* prend toute la largeur. Un bouton mort pendant une
/// manche entière se lit comme une panne, et l'écran de jeu est celui où on ne
/// doit jamais se demander si l'application a compris.
///
/// Seule reste alors une zone pleine largeur, dont `PlayingView` réduit la
/// hauteur : à deux, elles se partagent la moitié basse ; seule, elle en garde
/// un tiers.
class _Actions extends ConsumerWidget {
  const _Actions({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(playControllerProvider.notifier);
    final offersPass = game.round.allowsPass;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Le rappel ne vaut que pour le verrou de la dernière carte (R3.4) :
          // en manche 1, il n'y a pas de bouton à expliquer.
          if (offersPass && !game.canPass && game.pile.length == 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.gamePassLocked,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.inkSoft,
                ),
              ),
            ),
          Expanded(
            child: Row(
              // Sans `stretch`, les boutons gardent leur hauteur intrinsèque
              // et flottent au milieu de la zone : on retomberait sur deux
              // boutons ordinaires au lieu des deux zones voulues.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (offersPass) ...[
                  Expanded(
                    child: ActionZone(
                      label: l10n.actionPass,
                      // Pleine elle aussi — blanche cernée de corail : elle
                      // vaut la moitié du jeu en manches 2 et 3, et le contour
                      // vide qu'elle a porté la faisait passer pour
                      // indisponible.
                      secondaire: true,
                      onPressed: game.canPass ? controller.passed : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ActionZone(
                    label: l10n.actionFound,
                    background: AppColors.deep,
                    foreground: Colors.white,
                    onPressed: game.canAct ? controller.found : null,
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
