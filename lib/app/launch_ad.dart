import 'package:cekoi/app/game_persistence.dart';
import 'package:cekoi/app/ownership.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/data/repositories/ad_impression_repository.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/interstitial_gate.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'launch_ad.g.dart';

/// Une publicité de lancement est-elle possible sur cet appareil ?
///
/// Deux conditions, et il faut les deux. Le consentement peut ne pas avoir
/// répondu — le CMP travaille pendant que le joueur configure — et pas de
/// réponse veut dire pas de pub : on ne retient pas un lancement de partie
/// pour attendre un formulaire. Et posséder la version complète éteint
/// l'interstitiel : c'est la moitié de ce qu'on vend.
///
/// La possession doit avoir **répondu** : `Ownership.none` par défaut est le
/// bon choix pour « qu'est-ce qui est jouable » — ne rien donner — et le
/// mauvais pour « peut-on montrer une pub », puisqu'il en montrerait une à
/// qui a payé. Le parcours actuel garantit qu'elle est lue avant d'arriver
/// ici ; ce n'est pas une raison pour que le code en dépende.
///
/// C'est aussi ce que lit le bouton de lancement pour annoncer la publicité, et
/// c'est ce qui fixe la frontière : le plafond de fréquence n'est pas ici, et
/// ce n'est pas un oubli. Il vaut pour la partie qui commence, pas pour
/// l'appareil, et l'y mettre ferait clignoter la mention d'une partie à
/// l'autre.
///
/// La frontière est celle du **rattrapage**, pas celle de la durée : ce qui est
/// ici ne se répare que par un achat ou une réouverture du formulaire. Deux des
/// états rendus faux sont pourtant passagers — le CMP n'a pas encore répondu,
/// ou le SDK n'a pas démarré (`ads.dart`) — et se corrigeront d'eux-mêmes au
/// prochain lancement. Ils vont du bon côté : ils taisent la mention le temps
/// qu'ils durent, et on ne promet jamais une pub avant de savoir.
@Riverpod(keepAlive: true)
bool launchAdPossible(Ref ref) =>
    (ref.watch(adConsentProvider).value?.canRequestAds ?? false) &&
    (ref.watch(ownershipProvider).value?.showsAds ?? false);

/// Le portillon de l'interstitiel, assemblé.
///
/// La composition se fait dans `app/` et non dans `services/` : le portillon a
/// besoin de la base et de l'horloge, qui vivent en dessous et à côté de lui.
/// Le câbler chez lui inverserait le sens des dépendances — même raison qui
/// fait vivre `gamePersistenceProvider` ici.
@Riverpod(keepAlive: true)
InterstitialGate interstitialGate(Ref ref) => InterstitialGate(
  // La même valeur que la mention affichée au-dessus du bouton, et non une
  // expression recopiée : une ligne qui annonce une pub que le portillon
  // refuse est un mensonge, et deux copies finissent par diverger.
  canRequestAds: ref.watch(launchAdPossibleProvider),
  show: ref.watch(showInterstitialProvider),
  log: _RepositoryLog(ref.watch(adImpressionRepositoryProvider)),
  now: ref.watch(nowProvider),
);

/// Branche le dépôt Drift sur l'interface du portillon.
///
/// Un adaptateur plutôt qu'un `implements` sur le dépôt lui-même : `data/` ne
/// doit pas connaître `services/`.
class _RepositoryLog implements AdImpressionLog {
  const _RepositoryLog(this._repository);

  final AdImpressionRepository _repository;

  @override
  Future<List<DateTime>> since(DateTime since) => _repository.since(since);

  @override
  Future<void> record(DateTime shownAt, {required DateTime expiredBefore}) =>
      _repository.record(shownAt, expiredBefore: expiredBefore);
}
