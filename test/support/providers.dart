import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:cekoi/services/purchases/purchase_service.dart';

/// Un maintien d'écran inoffensif, pour les tests widget.
///
/// L'implémentation réelle passe par un canal de plateforme, absent du binding
/// de test : sans cette substitution, tout écran qui monte `PlayController`
/// échoue sur une `MissingPluginException` sans rapport avec ce qu'il teste.
///
/// [onCall] permet d'observer les ordres reçus quand c'est le maintien
/// d'écran lui-même qu'on vérifie.
ScreenAwake fakeScreenAwake([void Function({required bool enable})? onCall]) =>
    ({required enable}) async => onCall?.call(enable: enable);

/// Une passerelle de consentement inoffensive, pour les tests widget.
///
/// Même raison que [fakeScreenAwake] : monter `CekoiApp` construit le
/// consentement, et la vraie passerelle tape sur un canal de plateforme absent
/// du binding de test. L'appel se perd aujourd'hui dans le vide, ce qui rend
/// l'oubli indolore — et c'est bien le problème : le jour où la passerelle
/// gagne un délai de garde ou une gestion d'erreur, l'oubli devient un test
/// lent ou instable, très loin de sa cause.
///
/// [state] est ce que la passerelle rend ; par défaut, aucun consentement et
/// aucun formulaire à proposer.
ConsentGateway fakeConsentGateway([ConsentState state = ConsentState.none]) =>
    _FakeConsentGateway(state);

class _FakeConsentGateway implements ConsentGateway {
  const _FakeConsentGateway(this.state);

  final ConsentState state;

  @override
  Future<ConsentState> gather() async => state;

  @override
  Future<ConsentState> changeChoice() async => state;
}

/// Un magasin inoffensif, pour les tests widget.
///
/// Même raison que [fakeConsentGateway] : la racine de l'application écoute le
/// magasin en permanence, et le vrai passe par un canal de plateforme absent
/// du binding de test.
PurchaseService fakePurchaseService() => const _FakeStore();

class _FakeStore implements PurchaseService {
  const _FakeStore();

  @override
  Stream<String> get acquisitions => const Stream<String>.empty();

  @override
  Future<PurchaseOutcome> buy(String productId) async => PurchaseOutcome.failed;

  @override
  Future<PurchaseOutcome> restore(String productId) async =>
      PurchaseOutcome.nothing;
}
