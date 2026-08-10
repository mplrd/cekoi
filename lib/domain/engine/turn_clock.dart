/// Le temps de jeu consommé par un tour, pauses exclues (R3.7, R3.8).
///
/// C'est le pont entre l'horloge de l'appareil et `GameEvent.ticked` : le
/// réducteur reçoit un temps écoulé déjà nettoyé de ses pauses, et n'a donc
/// jamais à savoir que l'application est passée en arrière-plan.
///
/// Pur et immuable comme le reste du domaine. Le temps entre par les
/// paramètres, jamais par `DateTime.now()`, ce qui rend le cas limite 8 — mise
/// en arrière-plan à 1 s de la fin — testable sans attendre une seconde.
///
/// Les lectures attendues viennent d'une **source monotone** (un `Stopwatch`),
/// pas de l'horloge système : changer l'heure de son téléphone pendant un tour
/// ne doit pas faire bondir le temps restant. Leur origine n'a aucune
/// importance, seuls les écarts comptent.
class TurnClock {
  const TurnClock({this.consumed = Duration.zero, this.runningSince});

  /// Temps de jeu déjà accumulé lors des périodes précédentes.
  final Duration consumed;

  /// Lecture de la source au dernier départ. `null` quand le tour est à
  /// l'arrêt — pas encore commencé, ou en pause.
  final Duration? runningSince;

  bool get isRunning => runningSince != null;

  /// Le temps de jeu à la lecture [now].
  ///
  /// À l'arrêt, il ne dépend plus de [now] : c'est toute la définition d'une
  /// pause.
  Duration elapsedAt(Duration now) {
    final since = runningSince;
    if (since == null) return consumed;

    final running = now - since;
    // Une source qui recule ne doit pas rajeunir le tour : le narrateur
    // récupérerait du temps de jeu.
    return running.isNegative ? consumed : consumed + running;
  }

  /// Démarre le tour à la première carte (R3.2).
  TurnClock startedAt(Duration now) => TurnClock(runningSince: now);

  /// Gèle le tour, que la pause vienne du bouton ou de l'arrière-plan (R3.8).
  ///
  /// Deux `paused` de suite sont sans conséquence sans avoir à s'en prémunir :
  /// à l'arrêt, [elapsedAt] rend déjà [consumed], donc la seconde pause fige
  /// la même valeur. Un garde `if (!isRunning)` serait ici du code mort — la
  /// mutation qui le supprime ne fait tomber aucun test, et pour cause.
  TurnClock pausedAt(Duration now) => TurnClock(consumed: elapsedAt(now));

  /// Reprend après le compte à rebours de 3 secondes.
  ///
  /// Sans effet si le tour tourne déjà : le cycle de vie peut livrer deux
  /// `resumed` d'affilée, et le second effacerait le temps déjà joué.
  TurnClock resumedAt(Duration now) =>
      isRunning ? this : TurnClock(consumed: consumed, runningSince: now);
}
