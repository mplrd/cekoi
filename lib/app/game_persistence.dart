import 'dart:async';

import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/rules/resume.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'game_persistence.g.dart';

/// Écrit la partie en cours après chaque événement qui compte (R9.1).
///
/// « Après chaque événement » ne peut pas se prendre au pied de la lettre : le
/// chrono en produit dix par seconde, et écrire autant userait la mémoire du
/// téléphone pour une information que personne ne relira. Seuls les
/// changements qui ne portent pas **que** sur le temps écoulé sont sauvés.
///
/// Rien n'est perdu pour autant : passer en arrière-plan met le tour en pause
/// (R3.7), et cette pause est justement un changement qui déclenche l'écriture
/// — avec le temps écoulé exact. Une partie tuée par le système reprend donc
/// au temps qu'elle avait au moment où l'écran s'est éteint.
@Riverpod(keepAlive: true)
class GamePersistence extends _$GamePersistence {
  @override
  void build() {
    ref.listen(currentGameProvider, (previous, next) {
      unawaited(_persist(previous, next));
    });
  }

  Future<void> _persist(GameState? previous, GameState? next) async {
    final repository = ref.read(gameRepositoryProvider);

    // Plus de partie, ou partie terminée : il n'y a plus rien à reprendre, et
    // proposer un podium à la réouverture n'aurait aucun sens.
    if (next == null || next.phase == GamePhase.finished) {
      await repository.clear();
      return;
    }

    if (previous != null && _differsOnlyByElapsed(previous, next)) return;

    await repository.save(next, savedAt: ref.read(nowProvider)());
  }

  /// Vrai quand deux états ne diffèrent que par le temps consommé du tour.
  bool _differsOnlyByElapsed(GameState previous, GameState next) {
    final avant = previous.turn;
    final apres = next.turn;
    if (avant == null || apres == null) return false;

    return previous.copyWith(turn: avant.copyWith(elapsed: Duration.zero)) ==
        next.copyWith(turn: apres.copyWith(elapsed: Duration.zero));
  }
}

/// L'horloge murale de l'application.
///
/// Distincte de la source monotone du chrono : R9.2 compare des dates réelles
/// à 24 heures d'écart, ce qu'une durée depuis le lancement ne sait pas faire.
/// Isolée derrière un provider pour qu'un test puisse dater une sauvegarde de
/// la veille sans attendre.
typedef Now = DateTime Function();

@Riverpod(keepAlive: true)
Now now(Ref ref) => DateTime.now;

/// La partie proposée à la reprise au démarrage, ou `null`.
///
/// Applique la fenêtre de R9.2 et **efface** ce qui l'a dépassée : une partie
/// d'il y a trois jours ne doit pas rester en base à attendre indéfiniment.
@riverpod
Future<GameState?> resumableGame(Ref ref) async {
  final repository = ref.watch(gameRepositoryProvider);
  // Lu avant l'attente : ce provider s'auto-dispose, et `ref` n'est plus
  // utilisable après un `await` si plus personne ne l'écoute. Prendre
  // l'instant maintenant fixe aussi la référence de la comparaison, plutôt
  // que de la faire dépendre de la durée d'une lecture en base.
  final now = ref.read(nowProvider)();

  final saved = await repository.load();
  if (saved == null) return null;

  if (!isResumable(savedAt: saved.savedAt, now: now)) {
    await repository.clear();
    return null;
  }

  return saved.game;
}
