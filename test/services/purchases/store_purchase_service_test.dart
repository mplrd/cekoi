import 'dart:async';

import 'package:cekoi/services/purchases/purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Un magasin piloté par le test.
///
/// `StorePurchaseService` accepte l'injection d'un `InAppPurchase` : c'est ce
/// qui rend testable la partie la plus délicate du lot, celle qu'aucun
/// appareil ne permet d'éprouver tant que le SKU n'existe pas dans les
/// consoles.
class _FakeStore implements InAppPurchase {
  _FakeStore({this.opens = true, this.throwsOnBuy = false});

  final bool opens;
  final bool throwsOnBuy;

  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  final List<String> completed = [];
  int restoreCalls = 0;
  bool completeThrows = false;

  void emit(List<PurchaseDetails> achats) => _controller.add(achats);

  /// Ce qui rend la fuite d'abonnement observable : un `listen` abandonné
  /// laisse ce drapeau vrai bien après la fin de l'opération.
  bool get hasListener => _controller.hasListener;

  Future<void> dispose() => _controller.close();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [
          for (final id in ids)
            ProductDetails(
              id: id,
              title: 'Version complète',
              description: '',
              price: '3,99 €',
              rawPrice: 3.99,
              currencyCode: 'EUR',
            ),
        ],
        notFoundIDs: const [],
      );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    if (throwsOnBuy) throw StateError('facturation indisponible');
    return opens;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async => false;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (completeThrows) throw StateError('transaction déjà close');
    completed.add(purchase.productID);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
  }

  @override
  Future<String> countryCode() async => 'FR';

  /// `getPlatformAddition` porte une borne de type qui vit dans le paquet
  /// d'interface, pas dans `in_app_purchase` : l'implémenter obligerait à
  /// déclarer une dépendance de plus pour une méthode que le service n'appelle
  /// jamais.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

PurchaseDetails _achat(
  String id, {
  PurchaseStatus status = PurchaseStatus.purchased,
  bool pendingComplete = true,
}) => PurchaseDetails(
  productID: id,
  purchaseID: 'p-$id',
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: '',
    source: 'test',
  ),
  transactionDate: null,
  status: status,
)..pendingCompletePurchase = pendingComplete;

void main() {
  late _FakeStore magasin;

  const sku = 'cekoi_version_complete';
  const court = Duration(milliseconds: 60);

  setUp(() => magasin = _FakeStore());
  tearDown(() => magasin.dispose());

  StorePurchaseService service() => StorePurchaseService(
    store: magasin,
    timeout: court,
    settleDelay: court,
  );

  group('restaurer', () {
    test('sans rien à restaurer, le dit — et ne fait pas attendre', () async {
      // Le défaut que ce fichier existe pour attraper. Les deux plateformes
      // n'émettent rien quand il n'y a rien : Android pousse une liste vide,
      // iOS ne pousse rien. Sans borne courte, on attendait cinq minutes pour
      // afficher « le magasin n'a pas répondu ».
      final debut = DateTime.now();
      final outcome = await service().restore(sku);

      expect(outcome, PurchaseOutcome.nothing);
      expect(magasin.restoreCalls, 1);
      expect(
        DateTime.now().difference(debut),
        lessThan(const Duration(seconds: 2)),
      );
    });

    test('une liste vide ne se prend pas pour un achat', () async {
      final futur = service().restore(sku);
      magasin.emit(const []);

      expect(await futur, PurchaseOutcome.nothing);
    });

    test('une restauration relâche son abonnement', () async {
      await service().restore(sku);

      expect(magasin.hasListener, isFalse);
    });

    test('un achat retrouvé rend owned', () async {
      final futur = service().restore(sku);
      magasin.emit([_achat(sku, status: PurchaseStatus.restored)]);

      expect(await futur, PurchaseOutcome.owned);
    });
  });

  group('acheter', () {
    test('un achat conclu rend owned', () async {
      final futur = service().buy(sku);
      await pumpEventQueue();
      magasin.emit([_achat(sku)]);

      expect(await futur, PurchaseOutcome.owned);
    });

    test('une feuille fermée rend cancelled, pas une erreur', () async {
      final futur = service().buy(sku);
      await pumpEventQueue();
      magasin.emit([_achat(sku, status: PurchaseStatus.canceled)]);

      expect(await futur, PurchaseOutcome.cancelled);
    });

    test('un paiement différé ne conclut pas tout de suite', () async {
      final futur = service().buy(sku);
      await pumpEventQueue();
      magasin.emit([_achat(sku, status: PurchaseStatus.pending)]);

      // Le statut d'attente ne dit rien : c'est l'abonnement permanent qui
      // rattrapera l'issue, même si l'écran est parti entre-temps.
      expect(await futur, PurchaseOutcome.failed);
    });

    test('une feuille qui ne s ouvre pas échoue sans attendre', () async {
      final lent = StorePurchaseService(
        store: _FakeStore(opens: false),
        timeout: const Duration(minutes: 5),
      );

      final debut = DateTime.now();
      expect(await lent.buy(sku), PurchaseOutcome.failed);
      expect(
        DateTime.now().difference(debut),
        lessThan(const Duration(seconds: 2)),
        reason: "l'abonnement doit être annulé, pas laissé courir",
      );
    });

    test('une feuille qui ne s ouvre pas relâche son abonnement', () async {
      // Sans annulation, l'abonnement vivait jusqu'au bout du délai de cinq
      // minutes — invisible au chronomètre, bien réel en mémoire.
      final ferme = _FakeStore(opens: false);

      await StorePurchaseService(
        store: ferme,
        timeout: const Duration(minutes: 5),
      ).buy(sku);

      expect(ferme.hasListener, isFalse);
    });

    test('un magasin qui lève relâche aussi son abonnement', () async {
      final casse = _FakeStore(throwsOnBuy: true);

      await StorePurchaseService(
        store: casse,
        timeout: const Duration(minutes: 5),
      ).buy(sku);

      expect(casse.hasListener, isFalse);
    });

    test('un magasin qui lève échoue proprement', () async {
      final casse = StorePurchaseService(
        store: _FakeStore(throwsOnBuy: true),
        timeout: court,
      );

      expect(await casse.buy(sku), PurchaseOutcome.failed);
    });

    test('un achat pour un autre produit ne conclut rien', () async {
      final futur = service().buy(sku);
      await pumpEventQueue();
      magasin.emit([_achat('autre_produit')]);

      expect(await futur, PurchaseOutcome.failed);
    });
  });

  group('les acquisitions finalisent, et elles seules', () {
    test('un achat conclu est finalisé et signalé', () async {
      final vus = <String>[];
      final abonnement = service().acquisitions.listen(vus.add);
      addTearDown(abonnement.cancel);

      magasin.emit([_achat(sku)]);
      await pumpEventQueue();

      expect(vus, [sku]);
      expect(
        magasin.completed,
        [sku],
        reason:
            'un achat non finalisé est remboursé sous trois jours sur Android '
            'et rejoué à chaque lancement sur iOS',
      );
    });

    test('un paiement en attente n est pas finalisé', () async {
      // Sur Android, `pendingCompletePurchase` est vrai dès qu un achat n est
      // pas acquitté, paiement différé compris — et Play refuse qu on
      // acquitte celui-là.
      final vus = <String>[];
      final abonnement = service().acquisitions.listen(vus.add);
      addTearDown(abonnement.cancel);

      magasin.emit([_achat(sku, status: PurchaseStatus.pending)]);
      await pumpEventQueue();

      expect(vus, isEmpty);
      expect(magasin.completed, isEmpty);
    });

    test('une finalisation qui échoue n empêche pas de signaler', () async {
      // Elle échoue parce que la transaction était déjà close : c'est le
      // résultat recherché, pas une panne.
      magasin.completeThrows = true;

      final vus = <String>[];
      final abonnement = service().acquisitions.listen(vus.add);
      addTearDown(abonnement.cancel);

      magasin.emit([_achat(sku)]);
      await pumpEventQueue();

      expect(vus, [sku]);
    });

    test('un achat en erreur est finalisé, mais rien n est accordé', () async {
      final vus = <String>[];
      final abonnement = service().acquisitions.listen(vus.add);
      addTearDown(abonnement.cancel);

      magasin.emit([_achat(sku, status: PurchaseStatus.error)]);
      await pumpEventQueue();

      expect(vus, isEmpty);
      expect(
        magasin.completed,
        [sku],
        reason: 'une transaction en erreur doit quand même être close',
      );
    });

    test('un achat pendant une opération n est finalisé qu une fois', () async {
      // Deux endroits qui finalisent, ce sont deux `finishTransaction` sur la
      // même transaction, et iOS lève sur le second.
      final vus = <String>[];
      final abonnement = service().acquisitions.listen(vus.add);
      addTearDown(abonnement.cancel);

      final futur = service().buy(sku);
      await pumpEventQueue();
      magasin.emit([_achat(sku)]);

      expect(await futur, PurchaseOutcome.owned);
      await pumpEventQueue();

      expect(magasin.completed, [sku]);
    });
  });
}
