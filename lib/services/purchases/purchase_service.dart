import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// Ce qu'un magasin dit d'un produit en vente.
///
/// Le **prix vient du magasin**, jamais du code : c'est lui qui connaît la
/// devise du joueur, la TVA locale et le palier appliqué dans son pays.
/// Écrire « 3,99 € » en dur afficherait un prix faux partout ailleurs qu'en
/// zone euro, et un prix mensonger là où la taxe diffère.
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.price,
  });

  final String id;
  final String title;

  /// Déjà formaté par le magasin, devise comprise.
  final String price;
}

/// L'issue d'une tentative d'achat ou de restauration.
enum PurchaseOutcome {
  /// Le joueur possède le produit — qu'il vienne de l'acheter ou qu'on l'ait
  /// retrouvé.
  owned,

  /// Le joueur a fermé la feuille de paiement. Ce n'est pas une erreur.
  cancelled,

  /// Le magasin a refusé, ou n'a pas répondu.
  failed,
}

/// L'accès au magasin (`MONETISATION.md`).
///
/// Derrière une interface pour la même raison que la publicité : aucune
/// feature n'importe `in_app_purchase`, et un test n'a pas de magasin. Ici
/// c'est encore plus net qu'ailleurs — le passage en caisse ne peut pas être
/// simulé, même sur un appareil, tant que le SKU n'existe pas dans les deux
/// consoles.
abstract interface class PurchaseService {
  /// Vrai si le magasin est joignable sur cet appareil.
  Future<bool> isAvailable();

  /// Le catalogue, tel que le magasin le décrit.
  Future<List<StoreProduct>> products(Set<String> ids);

  /// Ouvre la feuille de paiement pour [productId], et attend l'issue.
  Future<PurchaseOutcome> buy(String productId);

  /// Redemande au magasin ce que le joueur possède déjà.
  ///
  /// **Obligatoire côté Apple** pour un produit non consommable : un joueur
  /// qui change de téléphone ou réinstalle doit retrouver son achat sans
  /// repayer, et l'absence de ce chemin est un motif de rejet.
  Future<PurchaseOutcome> restore(String productId);
}

/// Le magasin réel, par `in_app_purchase`.
class StorePurchaseService implements PurchaseService {
  StorePurchaseService({
    InAppPurchase? store,
    this.timeout = const Duration(minutes: 5),
  }) : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;

  /// Garde-fou : sans réponse du magasin au bout de ce délai, on rend la main.
  ///
  /// Large, parce que le joueur est en train de saisir un moyen de paiement —
  /// ce n'est pas une latence réseau qu'on borne, c'est un abandon silencieux
  /// qui laisserait l'écran bloqué pour toujours.
  final Duration timeout;

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async {
    final response = await _store.queryProductDetails(ids);

    return [
      for (final detail in response.productDetails)
        StoreProduct(
          id: detail.id,
          title: detail.title,
          price: detail.price,
        ),
    ];
  }

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    final response = await _store.queryProductDetails({productId});
    final detail = response.productDetails.firstOrNull;
    if (detail == null) return PurchaseOutcome.failed;

    final issue = _await(productId);

    // `buyNonConsumable` : le produit est acquis à vie et ne se reconsomme
    // pas. Un consommable serait racheté à chaque fois.
    final ouvert = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: detail),
    );
    if (!ouvert) return PurchaseOutcome.failed;

    return issue;
  }

  @override
  Future<PurchaseOutcome> restore(String productId) async {
    final issue = _await(productId);
    await _store.restorePurchases();
    return issue;
  }

  /// Écoute le flux du magasin jusqu'à l'issue concernant [productId].
  ///
  /// Le flux est la seule source d'issue : `buyNonConsumable` ne rend que le
  /// fait que la feuille de paiement s'est ouverte, pas ce que le joueur en a
  /// fait.
  Future<PurchaseOutcome> _await(String productId) {
    final issue = Completer<PurchaseOutcome>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;

    void close(PurchaseOutcome outcome) {
      if (issue.isCompleted) return;
      issue.complete(outcome);
      unawaited(subscription.cancel());
    }

    subscription = _store.purchaseStream.listen(
      (achats) async {
        for (final achat in achats) {
          if (achat.productID != productId) continue;

          // `completePurchase` est obligatoire : un achat non finalisé est
          // remboursé automatiquement au bout de trois jours sur Android, et
          // rejoué à chaque lancement sur iOS.
          if (achat.pendingCompletePurchase) {
            await _store.completePurchase(achat);
          }

          switch (achat.status) {
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              close(PurchaseOutcome.owned);
            case PurchaseStatus.canceled:
              close(PurchaseOutcome.cancelled);
            case PurchaseStatus.error:
              close(PurchaseOutcome.failed);
            case PurchaseStatus.pending:
              // Paiement différé — carte cadeau à valider, accord parental.
              // On ne conclut pas : le flux repassera.
              break;
          }
        }
      },
      onError: (_) => close(PurchaseOutcome.failed),
    );

    return issue.future.timeout(
      timeout,
      onTimeout: () {
        close(PurchaseOutcome.failed);
        return PurchaseOutcome.failed;
      },
    );
  }
}

/// Le magasin des builds sans achat : il ne vend rien.
class NoPurchaseService implements PurchaseService {
  const NoPurchaseService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => const [];

  @override
  Future<PurchaseOutcome> buy(String productId) async => PurchaseOutcome.failed;

  @override
  Future<PurchaseOutcome> restore(String productId) async =>
      PurchaseOutcome.failed;
}
