import 'package:cekoi/app/game_persistence.dart';
import 'package:cekoi/data/db/tables/entitlements.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/rules/ownership.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/rewarded_unlock.dart';
import 'package:cekoi/services/purchases/purchase_service.dart';
import 'package:cekoi/services/purchases/purchases.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ownership.g.dart';

/// Ce que le joueur possède.
///
/// Une lecture, invalidée après chaque acquisition, et **non** un flux Drift.
/// Ce n'est pas un choix de style : `StreamQueryStore.markAsClosed` programme
/// un `Timer` de durée nulle à l'annulation d'un stream, et sous le temps
/// simulé d'un test widget ce timer reste pendant quand l'arbre est détruit.
/// Un `watch()` vivant aussi longtemps qu'un écran fait donc échouer tout
/// fichier de test qui monte cet écran — on l'a payé une fois.
///
/// La réactivité n'y perd rien : les seuls écrivains sont juste en dessous, et
/// ils invalident. Elle y gagne même en lisibilité — la mise à jour suit
/// l'acquisition, au lieu d'arriver par un canal invisible.
///
/// La composition vit dans `app/` : la possession croise la base, le magasin
/// et l'horloge, qui ne se connaissent pas entre eux.
@Riverpod(keepAlive: true)
Future<Ownership> ownership(Ref ref) =>
    ref.watch(entitlementRepositoryProvider).read();

/// La possession telle qu'elle est connue à cet instant.
///
/// Le flux met un tour de boucle à répondre au premier lancement. Rien ne
/// justifie d'attendre : ne rien posséder est le bon défaut, et c'est le seul
/// qui ne donne jamais accès à ce qui n'a pas été payé.
@Riverpod(keepAlive: true)
Ownership currentOwnership(Ref ref) =>
    ref.watch(ownershipProvider).value ?? Ownership.none;

/// Écoute le magasin en permanence, et enregistre ce qu'il accorde.
///
/// Sans cet abonnement, tout ce que le magasin signale hors d'un achat en
/// cours est perdu : un paiement différé qui se conclut dix minutes plus tard,
/// un achat finalisé pendant que l'application était fermée. Sur iOS, c'est
/// aussi lui qui fait de l'application un observateur de la file de
/// transactions — sans quoi elle rejoue les transactions non finalisées à
/// chaque lancement, indéfiniment.
///
/// Il est lu par la racine de l'application, comme la sauvegarde de partie :
/// il n'expose rien, il doit seulement exister.
@Riverpod(keepAlive: true)
void storeListener(Ref ref) {
  final abonnement = ref.watch(purchaseServiceProvider).acquisitions.listen((
    productId,
  ) async {
    if (productId != fullVersionProductId) return;

    await ref
        .read(entitlementRepositoryProvider)
        .grantFullVersion(ref.read(nowProvider)());
    ref.invalidate(ownershipProvider);
  });

  ref.onDispose(abonnement.cancel);
}

/// Relit la possession, et attend qu'elle soit à jour.
///
/// Attendre, et pas seulement invalider : l'appelant rend la main à un écran
/// qui va afficher le résultat, et le laisser lire l'ancienne valeur ferait
/// clignoter un cadenas qu'on vient d'ouvrir.
Future<void> _reread(Ref ref) async {
  ref.invalidate(ownershipProvider);
  await ref.read(ownershipProvider.future);
}

/// L'achat de la version complète, et sa restauration.
@Riverpod(keepAlive: true)
class FullVersion extends _$FullVersion {
  @override
  Future<void> build() async {}

  /// Ouvre la feuille de paiement.
  Future<PurchaseOutcome> buy() =>
      _run((service) => service.buy(fullVersionProductId));

  /// Redemande au magasin ce que le joueur possède.
  ///
  /// Obligatoire côté Apple, et pas seulement pour la forme : réinstaller
  /// l'application vide la base locale, et c'est le seul chemin qui rende son
  /// achat au joueur. On ne le fait pas automatiquement au démarrage — sur
  /// iOS, restaurer peut demander une authentification, et l'imposer à
  /// l'ouverture d'un jeu de société serait absurde.
  Future<PurchaseOutcome> restore() =>
      _run((service) => service.restore(fullVersionProductId));

  Future<PurchaseOutcome> _run(
    Future<PurchaseOutcome> Function(PurchaseService) action,
  ) async {
    state = const AsyncValue<void>.loading();

    try {
      final outcome = await action(ref.read(purchaseServiceProvider));

      if (outcome == PurchaseOutcome.owned) {
        await ref
            .read(entitlementRepositoryProvider)
            .grantFullVersion(ref.read(nowProvider)());
        await _reread(ref);
      }

      return outcome;
    } on Object {
      // L'écriture aussi est dans la garde, et pas seulement l'appel au
      // magasin : un paiement encaissé dont l'enregistrement échoue laissait
      // l'écran sur son indicateur d'attente pour toujours, sans message et
      // sans même le bouton de restauration pour s'en sortir.
      return PurchaseOutcome.failed;
    } finally {
      // Dans tous les cas. C'est ce `finally` qui manquait.
      state = const AsyncValue<void>.data(null);
    }
  }
}

/// Le déblocage d'une catégorie contre une vidéo récompensée.
@Riverpod(keepAlive: true)
class DeckUnlock extends _$DeckUnlock {
  @override
  Future<void> build() async {}

  /// Rend `true` si la catégorie est désormais ouverte.
  Future<bool> unlock(String deckId) async {
    state = const AsyncValue<void>.loading();

    final unlocker = RewardedUnlock(
      // Inutile de proposer une vidéo à qui possède déjà tout : la version
      // complète éteint aussi ce point d'entrée.
      canRequestAds:
          (ref.read(adConsentProvider).value?.canRequestAds ?? false) &&
          ref.read(currentOwnershipProvider).showsAds,
      show: ref.read(showRewardedProvider),
      grant: (id) => ref
          .read(entitlementRepositoryProvider)
          .grantDeck(id, ref.read(nowProvider)()),
    );

    final ouverte = await unlocker.unlock(deckId);
    if (ouverte) await _reread(ref);

    state = const AsyncValue<void>.data(null);
    return ouverte;
  }
}
