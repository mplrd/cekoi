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
/// **Chaque étape est bornée dans le temps.** Ce n'est pas de la prudence
/// décorative : `UserMessagingChannel.requestConsentInfoUpdate` est un `void
/// async` qui n'attrape que `PlatformException`, si bien qu'une
/// `MissingPluginException` s'échappe sans appeler ni l'écouteur de succès ni
/// celui d'échec. Sans délai de garde, la réponse ne vient jamais, et ce n'est
/// pas la partie qui en souffre — personne ne l'attend — mais l'écran de
/// réglages, qui resterait sur son indicateur de chargement à vie. L'entrée
/// légalement obligatoire deviendrait définitivement injoignable.
class UmpConsentGateway implements ConsentGateway {
  UmpConsentGateway({this.deadline = const Duration(seconds: 10)});

  /// Au-delà, on considère que le CMP ne répondra pas.
  ///
  /// Large exprès : c'est un garde-fou contre une absence de réponse, pas une
  /// limite de patience. Un formulaire ouvert attend le joueur aussi longtemps
  /// qu'il le faut — l'attente commence à l'appel, pas à l'affichage, mais dix
  /// secondes couvrent le chargement sans jamais couper une lecture.
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
  Future<void> _showFormIfRequired() {
    final done = Completer<void>();
    unawaited(
      ConsentForm.loadAndShowConsentFormIfRequired(
        (_) => _finish(done),
      ).onError((_, _) => _finish(done)),
    );
    return _bounded(done);
  }

  /// Rouvre le formulaire depuis les réglages, et attend la réponse.
  Future<void> _showPrivacyOptions() {
    final done = Completer<void>();
    unawaited(
      ConsentForm.showPrivacyOptionsForm(
        (_) => _finish(done),
      ).onError((_, _) => _finish(done)),
    );
    return _bounded(done);
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
