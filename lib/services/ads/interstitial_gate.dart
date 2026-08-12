import 'package:cekoi/services/ads/ad_frequency.dart';
import 'package:cekoi/services/ads/ad_service.dart';

/// L'historique dont le portillon a besoin, réduit à deux gestes.
///
/// Une interface et non le dépôt Drift directement : le portillon est la seule
/// pièce qui *décide*, et il doit rester vérifiable sans base.
abstract interface class AdImpressionLog {
  /// Les impressions postérieures à [since].
  Future<List<DateTime>> since(DateTime since);

  /// Enregistre une pub vue, et purge ce qui est sorti de la fenêtre.
  Future<void> record(DateTime shownAt, {required DateTime expiredBefore});
}

/// Décide si l'interstitiel de lancement se présente, et le présente.
///
/// Trois conditions, dans cet ordre, et la première qui échoue arrête tout :
/// le consentement, le plafond de fréquence, puis le chargement de la pub.
///
/// **Rien ici ne peut empêcher une partie de démarrer.** Le seul retour est
/// « le joueur a-t-il vu une pub », qui ne sert qu'à consommer le quota ;
/// l'appelant lance la partie dans tous les cas, y compris si tout a échoué.
class InterstitialGate {
  const InterstitialGate({
    required this.canRequestAds,
    required this.show,
    required this.log,
    required this.now,
    this.policy = const AdFrequencyPolicy(),
    this.loadTimeout = const Duration(seconds: 3),
  });

  /// Le consentement a été donné et le SDK a démarré.
  final bool canRequestAds;

  final ShowInterstitial show;
  final AdImpressionLog log;

  /// L'horloge murale, injectée : le plafond se compte en minutes réelles, et
  /// un test n'a pas à en attendre cinq.
  final DateTime Function() now;

  final AdFrequencyPolicy policy;

  /// Au-delà, la partie démarre sans pub — jamais d'attente imposée.
  final Duration loadTimeout;

  /// Rend `true` si une pub a réellement été vue.
  Future<bool> present() async {
    if (!canRequestAds) return false;

    final instant = now();

    // Une lecture de l'historique qui échoue ne doit pas ouvrir les vannes :
    // sans historique lisible, on s'abstient plutôt que de risquer la pub de
    // trop.
    final List<DateTime> recent;
    try {
      recent = await log.since(policy.expiredBefore(instant));
    } on Object {
      return false;
    }

    if (!policy.allows(recent: recent, now: instant)) return false;

    final bool vue;
    try {
      vue = await show(loadTimeout: loadTimeout);
    } on Object {
      return false;
    }

    if (!vue) return false;

    try {
      // L'instant de l'affichage, et non celui de la fermeture : le joueur a
      // pu laisser la pub à l'écran, et c'est le déclenchement qu'on espace.
      await log.record(instant, expiredBefore: policy.expiredBefore(instant));
    } on Object {
      // La pub a été vue, l'écriture a échoué. Tant pis pour le quota — c'est
      // la seule branche où on préfère une pub de trop à une partie retenue.
    }

    return true;
  }
}
