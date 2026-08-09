import 'package:cekoi/domain/engine/turn.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_event.freezed.dart';

/// Tout ce qui peut arriver à une partie.
///
/// C'est la seule porte d'entrée du réducteur : le temps et les actions du
/// joueur entrent par ici, et une partie se rejoue à l'identique depuis sa
/// liste d'événements et sa graine.
///
/// Un événement reçu dans une phase qui ne l'attend pas est **sans effet** :
/// le réducteur rend l'état inchangé plutôt que de lever. Une interface qui
/// envoie un « trouvé » en retard pendant une transition d'écran ne doit pas
/// faire tomber la partie.
@freezed
sealed class GameEvent with _$GameEvent {
  /// Le compte à rebours de 3 secondes est écoulé : le chrono démarre en même
  /// temps que s'affiche la première carte (R3.2).
  const factory GameEvent.turnStarted() = TurnStarted;

  /// La carte courante est devinée : +1 point, elle quitte le paquet (R3.3).
  const factory GameEvent.cardFound() = CardFound;

  /// La carte courante est passée : elle retourne au fond du paquet, sans
  /// pénalité (R3.3). Indisponible s'il ne reste qu'une carte (R3.4).
  const factory GameEvent.cardPassed() = CardPassed;

  /// Temps écoulé depuis le début du tour, **pauses exclues**.
  ///
  /// Le temps restant est calculé à partir de cette valeur, jamais décrémenté :
  /// un compteur qu'on décrémente dérive, celui-ci ne peut pas.
  const factory GameEvent.ticked(Duration elapsed) = Ticked;

  /// L'application passe en arrière-plan (R3.7).
  const factory GameEvent.paused() = Paused;

  /// L'application revient au premier plan. Le compte à rebours de reprise de
  /// 3 secondes est affaire d'interface : pour le moteur, le chrono repart au
  /// temps restant.
  const factory GameEvent.resumed() = Resumed;

  /// Correction d'une ligne du récapitulatif de fin de tour (R3.6).
  const factory GameEvent.resultCorrected({
    required String cardId,
    required TurnOutcome outcome,
  }) = ResultCorrected;

  /// Le récapitulatif est validé : au tour suivant, ou à la fin de manche.
  const factory GameEvent.turnConfirmed() = TurnConfirmed;

  /// L'écran de scores intermédiaires est validé, la manche suivante s'ouvre.
  const factory GameEvent.nextRoundStarted() = NextRoundStarted;

  /// Une équipe remporte la carte de départage (R5.3).
  const factory GameEvent.tieBreakWon({required String teamId}) = TieBreakWon;

  /// Personne n'a trouvé la carte de départage : on recommence avec une autre
  /// carte, « répétée jusqu'à départage » (R5.3).
  const factory GameEvent.tieBreakRestarted() = TieBreakRestarted;
}
