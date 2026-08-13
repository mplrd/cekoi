import 'package:cekoi/app/game_persistence.dart';
import 'package:cekoi/app/ownership.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/data/repositories/ad_impression_repository.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/interstitial_gate.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'launch_ad.g.dart';

/// Le portillon de l'interstitiel, assemblé.
///
/// La composition se fait dans `app/` et non dans `services/` : le portillon a
/// besoin de la base et de l'horloge, qui vivent en dessous et à côté de lui.
/// Le câbler chez lui inverserait le sens des dépendances — même raison qui
/// fait vivre `gamePersistenceProvider` ici.
@Riverpod(keepAlive: true)
InterstitialGate interstitialGate(Ref ref) => InterstitialGate(
  // Deux conditions, et il faut les deux. Le consentement peut ne pas avoir
  // répondu — le CMP travaille pendant que le joueur configure — et pas de
  // réponse veut dire pas de pub : on ne retient pas un lancement de partie
  // pour attendre un formulaire. Et posséder la version complète éteint
  // l'interstitiel : c'est la moitié de ce qu'on vend.
  canRequestAds:
      (ref.watch(adConsentProvider).value?.canRequestAds ?? false) &&
      ref.watch(currentOwnershipProvider).showsAds,
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
