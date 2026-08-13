import 'dart:async';

import 'package:cekoi/app/ownership.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/tables/entitlements.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/data/repositories/entitlement_repository.dart';
import 'package:cekoi/services/purchases/purchase_service.dart';
import 'package:cekoi/services/purchases/purchases.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un magasin qui signale des acquisitions quand le test le décide.
class _FakeStore implements PurchaseService {
  // Broadcast, comme le vrai `purchaseStream` : ce qui est émis sans
  // auditeur est perdu, au lieu d être mis en attente d un abonné qui ne
  // viendra jamais.
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  void acquiert(String productId) => _controller.add(productId);

  Future<void> dispose() => _controller.close();

  @override
  Stream<String> get acquisitions => _controller.stream;

  @override
  Future<PurchaseOutcome> buy(String productId) async => PurchaseOutcome.failed;

  @override
  Future<PurchaseOutcome> restore(String productId) async =>
      PurchaseOutcome.nothing;
}

/// L'abonnement permanent au magasin.
///
/// Sans lui, tout ce que le magasin signale hors d'un achat en cours est
/// perdu : un paiement différé qui se conclut dix minutes plus tard, un achat
/// finalisé pendant que l'application était fermée. Sur iOS, c'est aussi lui
/// qui fait de l'application un observateur de la file de transactions.
void main() {
  late AppDatabase db;
  late _FakeStore magasin;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.memory();
    magasin = _FakeStore();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        purchaseServiceProvider.overrideWithValue(magasin),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await magasin.dispose();
    await db.close();
  });

  test('un achat signalé hors écran est enregistré', () async {
    container.read(storeListenerProvider);

    magasin.acquiert(fullVersionProductId);
    await pumpEventQueue();

    expect((await EntitlementRepository(db).read()).hasFullVersion, isTrue);
  });

  test('la possession relue reflète le nouvel achat', () async {
    container
      ..read(storeListenerProvider)
      ..read(ownershipProvider);
    await container.read(ownershipProvider.future);

    magasin.acquiert(fullVersionProductId);
    await pumpEventQueue();

    expect(
      (await container.read(ownershipProvider.future)).hasFullVersion,
      isTrue,
      reason: "l'écran doit suivre sans qu'on le recharge",
    );
  });

  test('un produit inconnu n accorde rien', () async {
    container.read(storeListenerProvider);

    magasin.acquiert('un_autre_produit');
    await pumpEventQueue();

    expect((await EntitlementRepository(db).read()).hasFullVersion, isFalse);
  });

  test("sans l'abonnement, l'achat serait perdu", () async {
    // Le témoin : c'est bien l'abonnement qui fait le travail, et non un
    // effet de bord du conteneur.
    magasin.acquiert(fullVersionProductId);
    await pumpEventQueue();

    expect((await EntitlementRepository(db).read()).hasFullVersion, isFalse);
  });
}
