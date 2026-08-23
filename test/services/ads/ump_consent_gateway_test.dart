import 'package:cekoi/services/ads/ad_sdk.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:cekoi/services/ads/ump_consent_gateway.dart';
import 'package:flutter/services.dart';
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

  bool ads;
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

/// Le canal natif de l'UMP.
///
/// `ConsentForm` n'expose que des méthodes statiques, sans instance
/// injectable : contrairement à `ConsentInformation`, on ne peut pas le
/// remplacer. Passer par le canal est le seul moyen de piloter un formulaire
/// depuis un test — et c'est pour ça que ce chemin n'était couvert par rien.
/// Le codec est celui par défaut, là où le plugin emploie
/// `StandardMethodCodec(UserMessagingCodec())` : `UserMessagingCodec`
/// n'est pas exporté par le barrel du paquet, et aller le chercher dans
/// `src/` déclencherait `implementation_imports`. Sans conséquence tant que
/// les appels portent des arguments nuls et que le faux renvoie `null`, ce
/// que les deux codecs encodent à l'identique. La limite à connaître : ce
/// faux ne peut pas **renvoyer** un `FormError`, et doit modéliser l'échec
/// en lançant une `PlatformException` — ce que fait aussi le natif.
const _umpChannel = MethodChannel('plugins.flutter.io/google_mobile_ads/ump');

/// Cette méthode-là n'aboutit **qu'à la fermeture du formulaire**, pas à son
/// affichage : côté natif, le résultat est renvoyé quand le joueur a répondu.
const _afficheLeFormulaire =
    'UserMessagingPlatform#loadAndShowConsentFormIfRequired';

/// Idem pour le formulaire rouvert depuis les réglages.
const _rouvreLeFormulaire = 'UserMessagingPlatform#showPrivacyOptionsForm';

void main() {
  late ConsentInformation original;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    original = ConsentInformation.instance;
  });

  tearDown(() {
    ConsentInformation.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_umpChannel, null);
  });

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

    test(
      'la réponse du joueur est prise en compte, même lue lentement',
      () async {
        // Le vrai parcours : le formulaire s'affiche, le joueur **lit** — c'est
        // un mur de texte réglementaire —, puis accepte. Tant qu'il n'a pas
        // répondu, l'UMP dit non ; il ne dit oui qu'au moment du rejet du
        // formulaire.
        final ump = _StubConsentInformation(
          privacyOptions: PrivacyOptionsRequirementStatus.required,
        );
        ConsentInformation.instance = ump;

        const lecture = Duration(milliseconds: 200);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_umpChannel, (call) async {
              if (call.method == _afficheLeFormulaire) {
                await Future<void>.delayed(lecture);
                ump.ads = true; // le joueur vient d'accepter
              }
              return null;
            });

        final state = await UmpConsentGateway(
          deadline: const Duration(milliseconds: 50),
        ).gather();

        expect(
          state.canRequestAds,
          isTrue,
          reason:
              'Le joueur a accepté : son choix ne peut pas être perdu parce '
              "qu'il a mis plus de temps à lire que le délai de garde.",
        );
      },
    );

    test('un UMP qui explose éteint la pub, sans relancer', () async {
      ConsentInformation.instance = _ExplodingConsentInformation();

      final state = await UmpConsentGateway(
        deadline: const Duration(milliseconds: 50),
      ).gather();

      expect(state, ConsentState.none);
    });

    // Les deux tests qui suivent épinglent ce qui porte le correctif. Le délai
    // de garde retiré, la seule chose qui empêche `gather()` de rester
    // suspendu à vie est le `.onError` branché sur les méthodes de formulaire.
    // Le retirer ne fait pas rougir les autres tests : il les **fige** jusqu'au
    // délai du lanceur, ce qui est un bien plus mauvais mode d'échec qu'une
    // assertion. D'où le `.timeout` explicite, et un `deadline` volontairement
    // trop grand pour pouvoir sauver le test s'il servait encore de filet.
    test(
      "un formulaire qui échoue termine l'attente, sans délai de garde",
      () async {
        ConsentInformation.instance = _StubConsentInformation();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_umpChannel, (call) async {
              throw PlatformException(
                code: '3',
                message: 'formulaire indisponible',
              );
            });

        final state = await UmpConsentGateway(
          deadline: const Duration(seconds: 30),
        ).gather().timeout(const Duration(seconds: 2));

        expect(state.canRequestAds, isFalse);
      },
    );

    test("un canal absent termine l'attente, sans délai de garde", () async {
      // Aucun faux enregistré : `invokeMethod` lève une
      // `MissingPluginException`, que le plugin n'attrape pas — elle ressort
      // par le `Future`, donc par `onError`.
      ConsentInformation.instance = _StubConsentInformation();

      final state = await UmpConsentGateway(
        deadline: const Duration(seconds: 30),
      ).gather().timeout(const Duration(seconds: 2));

      expect(state.canRequestAds, isFalse);
    });
  });

  group('changeChoice()', () {
    test('un retrait de consentement lu lentement est bien retenu', () async {
      // Le sens qui compte le plus : le joueur avait accepté, il revient dans
      // les réglages et refuse. Perdre cette réponse-là laisserait le SDK
      // servir des publicités à quelqu'un qui vient de les refuser.
      final ump = _StubConsentInformation(
        ads: true,
        privacyOptions: PrivacyOptionsRequirementStatus.required,
      );
      ConsentInformation.instance = ump;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_umpChannel, (call) async {
            if (call.method == _rouvreLeFormulaire) {
              await Future<void>.delayed(const Duration(milliseconds: 200));
              ump.ads = false; // le joueur vient de retirer son consentement
            }
            return null;
          });

      final state = await UmpConsentGateway(
        deadline: const Duration(milliseconds: 50),
      ).changeChoice();

      expect(
        state.canRequestAds,
        isFalse,
        reason:
            'Le joueur a retiré son consentement : le lire lentement ne '
            'peut pas laisser la publicité allumée.',
      );
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
