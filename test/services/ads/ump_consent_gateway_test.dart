import 'package:cekoi/services/ads/ad_sdk.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:cekoi/services/ads/ump_consent_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Une UMP pilotée par le test.
///
/// `ConsentInformation.instance` est un statique **assignable** : c'est ce qui
/// rend la passerelle vérifiable sans appareil, alors qu'elle parle à un SDK
/// natif de bout en bout.
class _StubConsentInformation implements ConsentInformation {
  _StubConsentInformation({
    this.ads = false,
    this.privacyOptions = PrivacyOptionsRequirementStatus.notRequired,
    this.muet = false,
  });

  final bool ads;
  final PrivacyOptionsRequirementStatus privacyOptions;

  /// Reproduit le vrai défaut du plugin : `requestConsentInfoUpdate` est un
  /// `void async` qui n'attrape que `PlatformException`, donc une
  /// `MissingPluginException` s'échappe **sans appeler aucun des deux
  /// écouteurs**. La passerelle n'apprend jamais que c'est fini.
  final bool muet;

  int updates = 0;

  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    void Function() successListener,
    void Function(FormError) failureListener,
  ) {
    updates++;
    if (muet) return;
    successListener();
  }

  @override
  Future<bool> canRequestAds() async => ads;

  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async => privacyOptions;

  @override
  Future<ConsentStatus> getConsentStatus() async => ConsentStatus.obtained;

  @override
  Future<bool> isConsentFormAvailable() async => false;

  @override
  Future<void> reset() async {}
}

void main() {
  late ConsentInformation original;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    original = ConsentInformation.instance;
  });

  tearDown(() => ConsentInformation.instance = original);

  group('traduction de l’état UMP', () {
    test('un formulaire requis rend le choix modifiable', () {
      final state = consentStateFrom(
        canRequestAds: true,
        privacyOptions: PrivacyOptionsRequirementStatus.required,
      );

      expect(state.canChangeChoice, isTrue);
      expect(state.canRequestAds, isTrue);
    });

    test('hors zone réglementée, aucun choix à proposer', () {
      for (final statut in [
        PrivacyOptionsRequirementStatus.notRequired,
        PrivacyOptionsRequirementStatus.unknown,
      ]) {
        expect(
          consentStateFrom(
            canRequestAds: true,
            privacyOptions: statut,
          ).canChangeChoice,
          isFalse,
          reason: 'Statut $statut',
        );
      }
    });
  });

  group('gather()', () {
    test("interroge l'UMP et rend son verdict", () async {
      final ump = _StubConsentInformation(
        ads: true,
        privacyOptions: PrivacyOptionsRequirementStatus.required,
      );
      ConsentInformation.instance = ump;

      final state = await UmpConsentGateway().gather();

      expect(ump.updates, 1);
      expect(state.canRequestAds, isTrue);
      expect(state.canChangeChoice, isTrue);
    });

    test('un UMP qui ne rappelle jamais son écouteur ne fige pas la '
        'passerelle', () async {
      ConsentInformation.instance = _StubConsentInformation(muet: true);

      // Le délai de garde est ce qui empêche l'écran de réglages de rester sur
      // son indicateur de chargement à vie, et donc l'entrée légalement
      // obligatoire de devenir injoignable.
      final state = await UmpConsentGateway(
        deadline: const Duration(milliseconds: 50),
      ).gather();

      expect(state, ConsentState.none);
    });

    test('un UMP qui explose éteint la pub, sans relancer', () async {
      ConsentInformation.instance = _ExplodingConsentInformation();

      final state = await UmpConsentGateway(
        deadline: const Duration(milliseconds: 50),
      ).gather();

      expect(state, ConsentState.none);
    });
  });

  group('ciblage des requêtes', () {
    test('la note de contenu est plafonnée à PG', () {
      // MONETISATION.md : une pub pour un jeu d'argent au milieu d'une partie
      // en famille est un désinstallement.
      expect(
        adRequestConfiguration().maxAdContentRating,
        MaxAdContentRating.pg,
      );
    });

    test("l'audience n'est ni enfant ni adolescent", () {
      // Déclarer autre chose ferait basculer l'app sous la politique Families
      // et COPPA, avec un inventaire publicitaire nettement plus pauvre.
      expect(
        adRequestConfiguration().ageRestrictedTreatment,
        AgeRestrictedTreatment.unspecified,
      );
    });
  });
}

/// Une UMP qui lance au lieu de répondre.
class _ExplodingConsentInformation implements ConsentInformation {
  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    void Function() successListener,
    void Function(FormError) failureListener,
  ) => throw StateError('canal absent');

  @override
  Future<bool> canRequestAds() async => throw StateError('canal absent');

  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async =>
      throw StateError('canal absent');

  @override
  Future<ConsentStatus> getConsentStatus() async =>
      throw StateError('canal absent');

  @override
  Future<bool> isConsentFormAvailable() async => throw StateError('canal');

  @override
  Future<void> reset() async {}
}
