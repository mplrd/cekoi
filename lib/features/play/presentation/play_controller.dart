import 'dart:async';

import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/domain/engine/game_engine.dart';
import 'package:cekoi/domain/engine/game_event.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/engine/turn_clock.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'play_controller.g.dart';

/// Durée du compte à rebours qui précède un départ ou une reprise (R3.2, R3.7).
const int countdownSeconds = 3;

/// Pilote un tour : le chrono, le cycle de vie et le compte à rebours.
///
/// Ne contient **aucune règle de jeu** — il traduit des gestes et du temps en
/// [GameEvent] et confie le reste au réducteur. Tout ce qu'il décide de son
/// propre chef relève de l'appareil : quand lire l'horloge, quand faire
/// tourner un `Timer`, ce que signifie « l'application passe en arrière-plan ».
///
/// Son état est le compte à rebours en cours, en secondes, ou `null` quand il
/// n'y en a pas. La partie elle-même vit dans [CurrentGame] : deux détenteurs
/// d'un même état finiraient par diverger, et c'est celui d'`app/` qui sert de
/// point de rendez-vous entre la configuration et le jeu.
@Riverpod(keepAlive: true)
class PlayController extends _$PlayController {
  /// Assez fin pour un anneau de progression fluide, assez large pour ne pas
  /// réduire le réducteur en machine à gaz : dix états par seconde.
  static const Duration _tickPeriod = Duration(milliseconds: 100);

  Timer? _ticker;
  Timer? _countdown;
  TurnClock _clock = const TurnClock();

  /// Vrai quand la pause vient de l'arrière-plan et non du bouton (R3.8).
  ///
  /// Revenir au premier plan ne doit relancer que ce que l'arrière-plan a
  /// interrompu : une pause demandée à la main reste en place tant que le
  /// joueur ne la lève pas lui-même.
  bool _pausedByLifecycle = false;

  @override
  int? build() {
    final bridge = _LifecycleBridge(
      onBackground: _pauseForBackground,
      onForeground: _resumeFromBackground,
    );
    WidgetsBinding.instance.addObserver(bridge);

    ref.onDispose(() {
      _ticker?.cancel();
      _countdown?.cancel();
      WidgetsBinding.instance.removeObserver(bridge);
    });

    return null;
  }

  bool get isCountingDown => state != null;

  /// Vrai quand le `Timer` du chrono tourne réellement.
  ///
  /// Exposé pour les tests, et il le faut : le réducteur ignorant tout
  /// [GameEvent.ticked] hors d'un tour en cours, un chrono laissé vivant
  /// derrière une pause ou une manche terminée n'a **aucun effet observable
  /// sur l'état**. Il ne fait que réveiller l'application dix fois par seconde
  /// pendant que le téléphone est dans une poche. Sans cet accès, la garde qui
  /// l'arrête ne serait vérifiable par rien.
  @visibleForTesting
  bool get isTicking => _ticker != null;

  /// Lance le compte à rebours de 3 secondes de l'écran d'annonce (R3.2).
  void startTurn() {
    if (_game?.phase != GamePhase.turnIntro) return;
    _startCountdown(_beginTurn);
  }

  /// Met en pause à la demande du joueur (R3.8).
  void pause() => _pause(byLifecycle: false);

  /// Lève une pause demandée à la main, après le même compte à rebours qu'une
  /// reprise d'arrière-plan (R3.8).
  void requestResume() {
    final game = _game;
    if (game == null || !game.isPaused) return;
    _startCountdown(_resume);
  }

  /// Trouvé et Passer partent sans condition : c'est le réducteur qui juge.
  ///
  /// Un tap arrivé pendant un compte à rebours est déjà refusé par lui — la
  /// phase est `turnIntro` au départ, et le tour est en pause à la reprise. Un
  /// garde `isCountingDown` ici serait du code mort : la mutation qui le
  /// supprime ne fait tomber aucun test, et l'état rendu étant égal au
  /// précédent, il ne provoque même pas de reconstruction.
  void found() => _dispatch(const GameEvent.cardFound());

  void passed() => _dispatch(const GameEvent.cardPassed());

  void correctResult(String cardId, TurnOutcome outcome) =>
      _dispatch(GameEvent.resultCorrected(cardId: cardId, outcome: outcome));

  void confirmTurn() => _dispatch(const GameEvent.turnConfirmed());

  void startNextRound() => _dispatch(const GameEvent.nextRoundStarted());

  void tieBreakWon(String teamId) =>
      _dispatch(GameEvent.tieBreakWon(teamId: teamId));

  void restartTieBreak() => _dispatch(const GameEvent.tieBreakRestarted());

  GameState? get _game => ref.read(currentGameProvider);

  Duration get _now => ref.read(monotonicClockProvider)();

  void _dispatch(GameEvent event) {
    final game = _game;
    if (game == null) return;

    ref.read(currentGameProvider.notifier).game = reduce(game, event);
    _syncTicker();
  }

  void _beginTurn() {
    _clock = const TurnClock().startedAt(_now);
    _pausedByLifecycle = false;
    _dispatch(const GameEvent.turnStarted());
  }

  void _pauseForBackground() => _pause(byLifecycle: true);

  void _pause({required bool byLifecycle}) {
    // Un compte à rebours interrompu par l'arrière-plan repart de trois : le
    // reprendre à un ne laisserait pas le temps de rendre le téléphone.
    _cancelCountdown();

    final game = _game;
    if (game == null || game.phase != GamePhase.playing || game.isPaused) {
      return;
    }

    _clock = _clock.pausedAt(_now);
    _pausedByLifecycle = byLifecycle;
    _dispatch(const GameEvent.paused());
  }

  void _resumeFromBackground() {
    if (!_pausedByLifecycle) return;
    _startCountdown(_resume);
  }

  void _resume() {
    _clock = _clock.resumedAt(_now);
    _pausedByLifecycle = false;
    _dispatch(const GameEvent.resumed());
  }

  void _startCountdown(void Function() onDone) {
    _cancelCountdown();
    state = countdownSeconds;

    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = (state ?? 1) - 1;
      if (left > 0) {
        state = left;
        return;
      }
      _cancelCountdown();
      onDone();
    });
  }

  void _cancelCountdown() {
    _countdown?.cancel();
    _countdown = null;
    state = null;
  }

  /// Fait tourner le chrono si et seulement si la partie l'attend.
  ///
  /// Dérivé de l'état plutôt que piloté à la main depuis chaque action : c'est
  /// la seule façon de ne pas laisser un `Timer` vivant derrière une manche
  /// terminée par la dernière carte trouvée (R4.1), qui interrompt le tour
  /// sans que personne n'ait appuyé sur pause.
  void _syncTicker() {
    final game = _game;
    final shouldRun =
        game != null && game.phase == GamePhase.playing && !game.isPaused;

    if (!shouldRun) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }

    _ticker ??= Timer.periodic(_tickPeriod, (_) => _tick());
  }

  void _tick() => _dispatch(GameEvent.ticked(_clock.elapsedAt(_now)));
}

/// Traduit le cycle de vie de l'application en pause et en reprise (R3.7).
///
/// `inactive` compte comme un arrière-plan : sur iOS il couvre le centre de
/// contrôle et la bannière d'appel entrant. Se tromper dans ce sens coûte un
/// compte à rebours de trois secondes ; se tromper dans l'autre laisse une
/// équipe jouer pendant que l'écran est masqué.
class _LifecycleBridge extends WidgetsBindingObserver {
  _LifecycleBridge({required this.onBackground, required this.onForeground});

  final VoidCallback onBackground;
  final VoidCallback onForeground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        onBackground();
    }
  }
}
