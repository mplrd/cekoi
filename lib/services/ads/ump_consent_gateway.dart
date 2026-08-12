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

/// Le consentement par le CMP Google UMP, inclus dans `google_mobile_ads`.
///
/// Aucune de ces étapes ne relance d'exception : une pub est un agrément,
/// jamais une condition pour jouer. Un CMP en panne doit éteindre la
/// publicité, pas l'application. C'est `canRequestAds()` qui fait foi en fin
/// de parcours, et lui seul — un formulaire qui échoue à s'afficher n'annule
/// pas un consentement déjà donné lors d'un lancement précédent.
class UmpConsentGateway implements ConsentGateway {
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

    return done.future;
  }

  /// Présente le formulaire au premier lancement, en zone réglementée.
  ///
  /// L'UMP rappelle l'écouteur immédiatement quand aucun formulaire n'est
  /// requis : ce n'est pas une attente pour les utilisateurs hors zone.
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
      final info = ConsentInformation.instance;
      final status = await info.getPrivacyOptionsRequirementStatus();

      return ConsentState(
        canRequestAds: await info.canRequestAds(),
        canChangeChoice: status == PrivacyOptionsRequirementStatus.required,
      );
    } on Object {
      return ConsentState.none;
    }
  }

  /// Complète [done] une seule fois.
  ///
  /// Rien ne garantit qu'un SDK natif n'appelle pas deux fois son écouteur, et
  /// un `Completer` complété deux fois lance une `StateError` qui remonterait
  /// dans une zone d'erreur non gérée, loin d'ici.
  void _finish(Completer<void> done) {
    if (!done.isCompleted) done.complete();
  }
}
