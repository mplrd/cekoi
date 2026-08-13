import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// L'issue d'une tentative d'achat ou de restauration.
enum PurchaseOutcome {
  /// Le joueur possède le produit — qu'il vienne de l'acheter ou qu'on l'ait
  /// retrouvé.
  owned,

  /// Le joueur a fermé la feuille de paiement. Ce n'est pas une erreur.
  cancelled,

  /// Le magasin a répondu, et ne connaît aucun achat pour ce compte.
  ///
  /// Distinct de [failed] : là, tout a fonctionné, il n'y a simplement rien à
  /// restaurer. Les confondre afficherait « le magasin n'a pas répondu » à
  /// quelqu'un dont le magasin a très bien répondu.
  nothing,

  /// Le magasin a refusé, ou n'a pas répondu.
  failed,
}

/// L'accès au magasin (`MONETISATION.md`).
///
/// Derrière une interface pour la même raison que la publicité : aucune
/// feature n'importe `in_app_purchase`, et un test n'a pas de magasin.
abstract interface class PurchaseService {
  /// Les produits acquis, signalés par le magasin.
  ///
  /// Ce flux est la **seule** autorité sur ce que le joueur possède, et le
  /// seul endroit où une transaction est finalisée. Il doit être écouté en
  /// permanence, pas seulement pendant un achat : un paiement différé — accord
  /// parental, validation bancaire — se conclut plusieurs minutes plus tard,
  /// parfois après un redémarrage. Sur iOS, s'y abonner est aussi ce qui fait
  /// de l'application un observateur de la file de transactions, ce qu'Apple
  /// demande d'établir au lancement.
  Stream<String> get acquisitions;

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
    this.settleDelay = const Duration(seconds: 3),
  }) : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;

  /// Garde-fou d'un achat sans réponse.
  ///
  /// Large, parce que le joueur est en train de saisir un moyen de paiement —
  /// ce n'est pas une latence réseau qu'on borne, c'est un abandon silencieux
  /// qui laisserait l'écran bloqué pour toujours.
  final Duration timeout;

  /// Ce qu'on accorde à une restauration pour dire qu'elle a trouvé.
  ///
  /// Court, et c'est le cœur du problème : **les deux plateformes n'émettent
  /// rien quand il n'y a rien à restaurer.** Android pousse une liste vide,
  /// iOS ne pousse rien du tout. Attendre [timeout] afficherait « le magasin
  /// n'a pas répondu » au bout de cinq minutes de blocage, à quelqu'un dont le
  /// magasin a répondu tout de suite.
  final Duration settleDelay;

  @override
  Stream<String> get acquisitions =>
      _store.purchaseStream.asyncExpand(_finalise);

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    final response = await _store.queryProductDetails({productId});
    final detail = response.productDetails.firstOrNull;
    if (detail == null) return PurchaseOutcome.failed;

    final guetteur = _Watcher(_store.purchaseStream, productId);
    try {
      final ouvert = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: detail),
      );
      if (!ouvert) return PurchaseOutcome.failed;

      return await guetteur.outcome(timeout, silence: PurchaseOutcome.failed);
    } on Object {
      return PurchaseOutcome.failed;
    } finally {
      // Toujours, y compris quand la feuille ne s'est pas ouverte : sans ça
      // l'abonnement survivrait jusqu'au bout du délai de cinq minutes.
      await guetteur.close();
    }
  }

  @override
  Future<PurchaseOutcome> restore(String productId) async {
    final guetteur = _Watcher(_store.purchaseStream, productId);
    try {
      await _store.restorePurchases();
      return await guetteur.outcome(
        settleDelay,
        silence: PurchaseOutcome.nothing,
      );
    } on Object {
      return PurchaseOutcome.failed;
    } finally {
      await guetteur.close();
    }
  }

  /// Finalise ce qui doit l'être, et rend les produits acquis.
  ///
  /// `completePurchase` n'est pas une politesse : un achat non finalisé est
  /// remboursé automatiquement au bout de trois jours sur Android, et rejoué à
  /// chaque lancement sur iOS. Un échec est ignoré — il veut dire que la
  /// transaction était déjà close, ce qui est le résultat recherché.
  ///
  /// Rien n'est finalisé tant que le statut est `pending` : sur Android,
  /// `pendingCompletePurchase` est vrai dès qu'un achat n'est pas acquitté,
  /// paiement différé compris, et Play refuse qu'on acquitte celui-là.
  Stream<String> _finalise(List<PurchaseDetails> achats) async* {
    for (final achat in achats) {
      if (achat.status == PurchaseStatus.pending) continue;

      if (achat.pendingCompletePurchase) {
        try {
          await _store.completePurchase(achat);
        } on Object {
          // Déjà finalisée.
        }
      }

      if (achat.status == PurchaseStatus.purchased ||
          achat.status == PurchaseStatus.restored) {
        yield achat.productID;
      }
    }
  }
}

/// Observe le flux du magasin le temps d'une opération, sans rien finaliser.
///
/// La finalisation appartient à [PurchaseService.acquisitions], et à lui seul :
/// deux endroits qui finalisent, ce sont deux `finishTransaction` sur la même
/// transaction, et iOS lève sur le second.
class _Watcher {
  _Watcher(Stream<List<PurchaseDetails>> flux, this._productId) {
    _subscription = flux.listen(
      _onPurchases,
      onError: (_) => _close(PurchaseOutcome.failed),
    );
  }

  final String _productId;
  final Completer<PurchaseOutcome> _issue = Completer<PurchaseOutcome>();
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  /// L'issue, ou [silence] si le magasin n'a rien dit avant [limit].
  Future<PurchaseOutcome> outcome(
    Duration limit, {
    required PurchaseOutcome silence,
  }) => _issue.future.timeout(limit, onTimeout: () => silence);

  Future<void> close() => _subscription.cancel();

  void _onPurchases(List<PurchaseDetails> achats) {
    for (final achat in achats) {
      if (achat.productID != _productId) continue;

      switch (achat.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _close(PurchaseOutcome.owned);
        case PurchaseStatus.canceled:
          _close(PurchaseOutcome.cancelled);
        case PurchaseStatus.error:
          _close(PurchaseOutcome.failed);
        case PurchaseStatus.pending:
          // Paiement différé. On ne conclut pas : le flux repassera, et
          // l'abonnement permanent le rattrapera même si l'écran est parti.
          break;
      }
    }
  }

  void _close(PurchaseOutcome outcome) {
    if (!_issue.isCompleted) _issue.complete(outcome);
  }
}

/// Le magasin des builds sans achat : il ne vend rien.
class NoPurchaseService implements PurchaseService {
  const NoPurchaseService();

  @override
  Stream<String> get acquisitions => const Stream<String>.empty();

  @override
  Future<PurchaseOutcome> buy(String productId) async => PurchaseOutcome.failed;

  @override
  Future<PurchaseOutcome> restore(String productId) async =>
      PurchaseOutcome.nothing;
}
