/// Au-delà de ce délai, une partie abandonnée n'est plus proposée (R9.2).
///
/// Vingt-quatre heures couvre le cas réel : on joue le samedi soir, on rouvre
/// le dimanche matin. Plus court perdrait la reprise la plus probable ; plus
/// long ferait resurgir une partie que personne ne se rappelle avoir commencée.
const Duration resumeWindow = Duration(hours: 24);

/// Vrai si une partie sauvegardée à [savedAt] mérite encore d'être proposée
/// (R9.2).
///
/// L'instant courant entre en paramètre : le domaine ne lit pas l'horloge, ce
/// qui rend la bascule des 24 heures testable sans attendre.
///
/// Une sauvegarde datée du futur reste reprenable. Changement d'heure, fuseau,
/// horloge réglée à la main : refuser une partie pour cette raison serait
/// incompréhensible pour le joueur, qui vient de la quitter.
bool isResumable({required DateTime savedAt, required DateTime now}) =>
    now.difference(savedAt) <= resumeWindow;
