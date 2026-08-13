import 'dart:async';
import 'dart:io';

import 'package:cekoi/services/ads/ad_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Les identifiants de la vidéo récompensée.
abstract final class RewardedAdUnitIds {
  static const String _override = String.fromEnvironment('CEKOI_AD_REWARDED');

  static const String _testAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testIos = 'ca-app-pub-3940256099942544/1712485313';

  static String get rewarded {
    if (_override.isNotEmpty) return _override;
    return Platform.isIOS ? _testIos : _testAndroid;
  }
}

/// Présente une vidéo récompensée, et dit si la récompense est acquise.
///
/// Rend `true` **uniquement** si le SDK a signalé la récompense, c'est-à-dire
/// si le joueur a regardé assez longtemps. Fermer la vidéo en cours de route
/// ne débloque rien — et ne coûte rien non plus.
///
/// `loadTimeout` borne le chargement, pas le visionnage : c'est le joueur qui
/// a demandé cette vidéo, il n'y a aucune raison de la lui couper.
typedef ShowRewarded = Future<bool> Function({required Duration loadTimeout});

/// La vidéo récompensée de Google.
Future<bool> showGoogleRewarded({required Duration loadTimeout}) async {
  final ad = await _load(loadTimeout);
  if (ad == null) return false;

  // Deux signaux distincts, et il faut les deux : la récompense dit que le
  // visionnage compte, la fermeture dit qu'on peut reprendre la main. Rendre
  // la main sur la seule récompense laisserait l'écran de sélection réagir
  // pendant que la vidéo est encore à l'écran.
  var earned = false;
  final closed = Completer<bool>();

  void close() {
    if (!closed.isCompleted) closed.complete(earned);
  }

  ad.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (ad) {
      unawaited(ad.dispose());
      close();
    },
    onAdFailedToShowFullScreenContent: (ad, error) {
      unawaited(ad.dispose());
      close();
    },
  );

  try {
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
  } on Object {
    unawaited(ad.dispose());
    return false;
  }

  return closed.future;
}

/// Le build sans publicité : aucune vidéo, donc aucune récompense.
Future<bool> showNoRewarded({required Duration loadTimeout}) async => false;

Future<RewardedAd?> _load(Duration timeout) {
  final loaded = Completer<RewardedAd?>();

  void fail() {
    if (!loaded.isCompleted) loaded.complete(null);
  }

  unawaited(
    RewardedAd.load(
      adUnitId: RewardedAdUnitIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (loaded.isCompleted) {
            unawaited(ad.dispose());
            return;
          }
          loaded.complete(ad);
        },
        onAdFailedToLoad: (error) => fail(),
      ),
    ).onError((_, _) => fail()),
  );

  // Même garde que l'interstitiel : ce qui arrive en retard est détruit, sans
  // quoi une vidéo plein écran reste référencée par le SDK pour rien.
  return awaitOrDiscard(
    loaded.future,
    timeout: timeout,
    discard: (ad) => unawaited(ad.dispose()),
  );
}
