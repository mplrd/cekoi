/// Où en est la partie, du point de vue de l'interface.
///
/// Une seule phase est active à la fois, et c'est elle qui décide des
/// événements que le réducteur accepte : une correction reçue en plein tour ou
/// un « trouvé » reçu sur l'écran de scores sont sans effet.
enum GamePhase {
  /// Écran d'annonce du tour : équipe active et narrateur désigné. Le compte à
  /// rebours de 3 secondes de R3.2 se joue ici, le chrono n'a pas démarré.
  turnIntro,

  /// Le chrono tourne, le narrateur fait deviner.
  playing,

  /// Récapitulatif de fin de tour, corrigeable ligne par ligne (R3.6).
  turnSummary,

  /// Scores intermédiaires entre deux manches (R4.4).
  roundSummary,

  /// Manche de départage entre les équipes à égalité en tête (R5.3).
  tieBreak,

  /// Podium.
  finished,
}
