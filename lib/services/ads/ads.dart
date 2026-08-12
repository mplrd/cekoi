import 'package:cekoi/services/ads/ad_sdk.dart';
import 'package:cekoi/services/ads/ad_service.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:cekoi/services/ads/ump_consent_gateway.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ads.g.dart';

/// Interrupteur de compilation de toute la publicité.
///
/// ```bash
/// flutter run --dart-define=CEKOI_ADS=false
/// ```
///
/// Vrai par défaut : c'est l'application livrée qui doit être juste sans
/// drapeau. L'éteindre sert au développement quotidien — répondre à un
/// formulaire de consentement à chaque `flutter run` n'apprend rien, et un
/// émulateur sans services Google ne sait pas le montrer.
const bool adsEnabled = bool.fromEnvironment('CEKOI_ADS', defaultValue: true);

@Riverpod(keepAlive: true)
ConsentGateway consentGateway(Ref ref) =>
    adsEnabled ? UmpConsentGateway() : const NoConsentGateway();

@Riverpod(keepAlive: true)
AdSdkStart adSdkStart(Ref ref) => adsEnabled ? startGoogleAdSdk : startNoAdSdk;

@Riverpod(keepAlive: true)
ShowInterstitial showInterstitial(Ref ref) =>
    adsEnabled ? showGoogleInterstitial : showNoInterstitial;

/// Le consentement de l'appareil, et le démarrage du SDK qui en dépend.
///
/// L'ordre est imposé par le RGPD et par `MONETISATION.md` : le formulaire
/// d'abord, le SDK ensuite, **aucune requête publicitaire entre les deux**.
/// Les deux étant tenues ici, il n'existe pas de chemin où une feature
/// démarrerait le SDK de son côté.
///
/// Ce provider est lu au démarrage sans être attendu : l'accueil s'affiche
/// pendant que le CMP travaille. Rien dans le jeu ne dépend de sa réponse.
@Riverpod(keepAlive: true)
class AdConsent extends _$AdConsent {
  @override
  Future<ConsentState> build() =>
      _resolve(ref.watch(consentGatewayProvider).gather());

  /// Rouvre le formulaire depuis les réglages.
  Future<void> changeChoice() async {
    final gateway = ref.read(consentGatewayProvider);
    state = const AsyncValue<ConsentState>.loading();
    state = await AsyncValue.guard(() => _resolve(gateway.changeChoice()));
  }

  /// Applique une réponse : elle décide du démarrage du SDK.
  Future<ConsentState> _resolve(Future<ConsentState> answer) async {
    ConsentState consent;
    try {
      consent = await answer;
    } on Object {
      return ConsentState.none;
    }

    if (!consent.canRequestAds) return consent;

    try {
      await ref.read(adSdkStartProvider)();
    } on Object {
      // Le SDK n'a pas démarré : plus de pub possible. Le choix, lui, reste
      // modifiable — l'entrée des réglages ne doit pas disparaître parce
      // qu'une initialisation a échoué.
      return consent.copyWith(canRequestAds: false);
    }

    return consent;
  }
}
