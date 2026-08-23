import 'dart:async';

import 'package:cekoi/services/ads/consent.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// L'identifiant de l'appareil de test du CMP, en développement.
///
/// L'UMP ne présente son formulaire que dans les zones réglementées : depuis
/// une machine hors UE, on ne verrait jamais l'écran qu'on vient d'écrire.
/// Passer le hachage que le SDK écrit dans les logs au premier lancement
/// (`Use new ConsentDebugSettings.Builder().addTestDeviceHashedId(...)`) fait
/// croire à l'UMP que l'appareil est européen :
///
/// ```bash
/// flutter run --dart-define=CEKOI_CONSENT_DEBUG_DEVICE=<hachage>
/// ```
const String _debugDevice = String.fromEnvironment(
  'CEKOI_CONSENT_DEBUG_DEVICE',
);

/// Traduit l'état de l'UMP en ce que l'application en retient.
///
/// Fonction pure et à part, parce que c'est la seule décision de tout ce
/// fichier : le reste n'est que du branchement de callbacks natifs. Ici,
/// remplacer `required` par `notRequired` ferait disparaître à jamais une
/// entrée de réglages légalement obligatoire, sans rien casser d'autre — c'est
/// exactement le genre de faute qu'un test doit pouvoir attraper.
ConsentState consentStateFrom({
  required bool canRequestAds,
  required PrivacyOptionsRequirementStatus privacyOptions,
}) => ConsentState(
  canRequestAds: canRequestAds,
  canChangeChoice: privacyOptions == PrivacyOptionsRequirementStatus.required,
);

/// Le consentement par le CMP Google UMP, inclus dans `google_mobile_ads`.
///
/// Aucune de ces étapes ne relance d'exception : une pub est un agrément,
/// jamais une condition pour jouer. Un CMP en panne doit éteindre la
/// publicité, pas l'application. C'est `canRequestAds()` qui fait foi en fin
/// de parcours, et lui seul — un formulaire qui échoue à s'afficher n'annule
/// pas un consentement déjà donné lors d'un lancement précédent.
///
/// **Ce qui attend une machine est borné ; ce qui attend une personne ne
/// l'est pas.** L'interrogation de l'UMP et la lecture de l'état ont un délai
/// de garde, parce que `UserMessagingChannel.requestConsentInfoUpdate` est un
/// `void async` qui n'attrape que `PlatformException` : une
/// `MissingPluginException` s'y échappe sans appeler ni l'écouteur de succès
/// ni celui d'échec, et la réponse ne viendrait jamais. Les deux étapes qui
/// affichent un formulaire, elles, n'en ont pas — voir `_showFormIfRequired`.
///
/// Ce qu'un blocage coûterait, si le natif violait son contrat : rien à la
/// partie, que personne ne fait attendre, mais l'entrée de consentement des
/// réglages resterait sur son indicateur de chargement pour cette session.
/// Elle revient au lancement suivant, `gather()` étant rejoué. C'est le prix
/// assumé pour ne plus jamais inventer une réponse à la place du joueur.
class UmpConsentGateway implements ConsentGateway {
  UmpConsentGateway({this.deadline = const Duration(seconds: 10)});

  /// Au-delà, on considère que le CMP ne répondra pas.
  ///
  /// **Ne borne que ce qui n'attend pas le joueur** : l'interrogation de
  /// l'UMP et la lecture de l'état final. Les deux étapes qui affichent un
  /// formulaire n'en ont pas, et c'est délibéré — voir `_showFormIfRequired`.
  ///
  /// La version précédente bornait tout, et prétendait dans ce commentaire
  /// « couvrir le chargement sans jamais couper une lecture ». C'était faux :
  /// le compte à rebours partait à l'appel, formulaire affiché ou non. Passé
  /// dix secondes, la passerelle lisait l'état pendant que le formulaire était
  /// encore à l'écran, concluait au refus, et n'y revenait jamais. Le joueur
  /// acceptait ensuite dans le vide.
  final Duration deadline;

  @override
  Future<ConsentState> gather() async {
    await _requestUpdate();
    await _showFormIfRequired();
    return _read();
  }

  @override
  Future<ConsentState> changeChoice() async {
    await _showPrivacyOptions();
    return _read();
  }

  /// Interroge l'UMP sur la zone et l'état du consentement.
  Future<void> _requestUpdate() {
    final done = Completer<void>();

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(
          // L'audience déclarée est 13 ans et plus : les utilisateurs ne sont
          // pas sous l'âge du consentement.
          tagForUnderAgeOfConsent: false,
          consentDebugSettings: _debugDevice.isEmpty
              ? null
              : ConsentDebugSettings(
                  debugGeography: DebugGeography.debugGeographyEea,
                  testIdentifiers: [_debugDevice],
                ),
        ),
        () => _finish(done),
        (_) => _finish(done),
      );
    } on Object {
      _finish(done);
    }

    return _bounded(done);
  }

  /// Présente le formulaire au premier lancement, en zone réglementée.
  ///
  /// L'UMP rappelle l'écouteur immédiatement quand aucun formulaire n'est
  /// requis : ce n'est pas une attente pour les utilisateurs hors zone.
  ///
  /// **Sans délai de garde, contrairement au reste.** Ce que cette étape
  /// attend n'est pas un SDK, c'est une personne en train de lire un mur de
  /// texte réglementaire, et dix secondes n'y suffisent pas. Borner ici
  /// revenait à conclure au refus pendant que le formulaire était affiché,
  /// puis à ignorer la réponse.
  ///
  /// Le risque que le délai couvrait ailleurs ne se pose pas ici : la méthode
  /// du plugin rend un vrai `Future`, et `onError` est branché dessus. Un
  /// canal absent, une `PlatformException`, un formulaire qui refuse de
  /// s'afficher — tous terminent l'attente. Le seul cas restant est « le
  /// formulaire est à l'écran et personne n'a encore répondu », qui n'est pas
  /// une panne mais le fonctionnement normal.
  Future<void> _showFormIfRequired() {
    final done = Completer<void>();
    unawaited(
      ConsentForm.loadAndShowConsentFormIfRequired(
        (_) => _finish(done),
      ).onError((_, _) => _finish(done)),
    );
    return done.future;
  }

  /// Rouvre le formulaire depuis les réglages, et attend la réponse.
  ///
  /// Sans délai de garde, pour la même raison que `_showFormIfRequired` — et
  /// le sens de la panne y était pire. Un joueur qui **retire** son
  /// consentement lentement voyait la passerelle relire l'ancien état, le
  /// trouver favorable, et laisser le SDK servir des publicités jusqu'au
  /// prochain lancement, alors qu'il venait de les refuser.
  Future<void> _showPrivacyOptions() {
    final done = Completer<void>();
    unawaited(
      ConsentForm.showPrivacyOptionsForm(
        (_) => _finish(done),
      ).onError((_, _) => _finish(done)),
    );
    return done.future;
  }

  /// Lit l'état final auprès de l'UMP.
  Future<ConsentState> _read() async {
    try {
      return await _readFromUmp().timeout(
        deadline,
        onTimeout: () => ConsentState.none,
      );
    } on Object {
      return ConsentState.none;
    }
  }

  Future<ConsentState> _readFromUmp() async {
    final info = ConsentInformation.instance;

    return consentStateFrom(
      canRequestAds: await info.canRequestAds(),
      privacyOptions: await info.getPrivacyOptionsRequirementStatus(),
    );
  }

  /// Borne l'attente d'un écouteur natif.
  Future<void> _bounded(Completer<void> done) =>
      done.future.timeout(deadline, onTimeout: () {});

  /// Complète [done] une seule fois.
  ///
  /// Rien ne garantit qu'un SDK natif n'appelle pas deux fois son écouteur, et
  /// un `Completer` complété deux fois lance une `StateError` qui remonterait
  /// dans une zone d'erreur non gérée, loin d'ici.
  void _finish(Completer<void> done) {
    if (!done.isCompleted) done.complete();
  }
}
