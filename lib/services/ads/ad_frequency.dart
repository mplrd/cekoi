/// Le plafond de fréquence de l'interstitiel (`MONETISATION.md`).
///
/// Du Dart pur, sans SDK ni base : c'est la seule partie de l'interstitiel qui
/// *décide* quelque chose, et l'isoler la rend vérifiable en millisecondes,
/// horloge comprise. Le reste n'est que du chargement et de l'affichage.
///
/// Le jeu se joue autour d'une table : une pub de trop ne gêne pas un
/// utilisateur, elle en gêne six. Ce plafond est donc une règle de produit,
/// pas un réglage d'optimisation de revenu — d'où les valeurs par défaut, qui
/// ne se surchargent qu'en test.
class AdFrequencyPolicy {
  const AdFrequencyPolicy({
    this.maxPerWindow = 3,
    this.window = const Duration(hours: 1),
    this.minimumGap = const Duration(minutes: 5),
  });

  /// Nombre maximum d'interstitiels sur [window].
  final int maxPerWindow;

  /// La fenêtre est **glissante** : elle ne se remet pas à zéro à heure ronde,
  /// sinon trois pubs à 10 h 55 en autoriseraient trois autres à 11 h 05.
  final Duration window;

  /// Écart minimum entre deux interstitiels.
  final Duration minimumGap;

  /// Vrai si un interstitiel peut être présenté à [now].
  ///
  /// [recent] est l'historique des impressions ; ni son ordre ni son fuseau
  /// n'importent, et il peut contenir plus que la fenêtre.
  bool allows({required Iterable<DateTime> recent, required DateTime now}) {
    final debut = expiredBefore(now);
    var dansLaFenetre = 0;

    for (final impression in recent) {
      final quand = impression.toUtc();
      final ecart = now.toUtc().difference(quand);

      // Un écart négatif est une impression datée du futur : le joueur a
      // reculé l'horloge de son téléphone. Elle est plus proche que n'importe
      // quel délai, donc elle bloque — reculer l'heure ne doit pas ouvrir un
      // passe-droit.
      if (ecart < minimumGap) return false;

      if (quand.isAfter(debut)) dansLaFenetre++;
    }

    return dansLaFenetre < maxPerWindow;
  }

  /// L'instant avant lequel une impression ne compte plus.
  ///
  /// Sert aussi à purger : la base n'a aucune raison de garder une ligne par
  /// pub depuis l'installation pour répondre à une question qui ne regarde que
  /// la dernière heure.
  DateTime expiredBefore(DateTime now) => now.subtract(window);
}
