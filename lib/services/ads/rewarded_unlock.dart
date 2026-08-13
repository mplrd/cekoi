/// Débloque une catégorie contre une vidéo récompensée (`MONETISATION.md`).
///
/// Pas de plafond de fréquence ici, contrairement à l'interstitiel, et ce
/// n'est pas un oubli : c'est le joueur qui déclenche cette vidéo, en échange
/// de quelque chose qu'il veut. L'espacer serait lui refuser ce qu'il demande.
///
/// Le déblocage est **définitif**. Une récompense qui expire est perçue comme
/// une arnaque et détruit la confiance sur ce type d'application — c'est écrit
/// dans `MONETISATION.md` et c'est tenu ici : on écrit en base, on ne compte
/// pas une durée.
class RewardedUnlock {
  const RewardedUnlock({
    required this.canRequestAds,
    required this.show,
    required this.grant,
    this.loadTimeout = const Duration(seconds: 10),
  });

  /// Le consentement est donné, le SDK a démarré, et le joueur n'a pas déjà
  /// la version complète — auquel cas il n'y aurait rien à débloquer.
  final bool canRequestAds;

  final Future<bool> Function({required Duration loadTimeout}) show;

  /// Écrit le déblocage. Appelé **seulement** si la récompense est acquise.
  final Future<void> Function(String deckId) grant;

  /// Plus large que les trois secondes de l'interstitiel : le joueur vient de
  /// demander cette vidéo et regarde un indicateur d'attente. Là où une pub
  /// non sollicitée ne doit jamais faire patienter, celle-ci a le droit.
  final Duration loadTimeout;

  /// Rend `true` si la catégorie est désormais débloquée.
  Future<bool> unlock(String deckId) async {
    if (!canRequestAds) return false;

    final bool gagnee;
    try {
      gagnee = await show(loadTimeout: loadTimeout);
    } on Object {
      return false;
    }

    // Fermer la vidéo avant la fin ne débloque rien — et ne coûte rien : le
    // joueur peut retenter tout de suite.
    if (!gagnee) return false;

    try {
      await grant(deckId);
    } on Object {
      // La vidéo a été regardée et l'écriture a échoué. Rendre `false` ferait
      // croire à un échec alors que la récompense est due ; rendre `true`
      // afficherait un déblocage que la base ne confirme pas. On dit non,
      // parce que c'est ce que l'écran relira au prochain rendu — mieux vaut
      // une récompense à retenter qu'un déblocage fantôme.
      return false;
    }

    return true;
  }
}
