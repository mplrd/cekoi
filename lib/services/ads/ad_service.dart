import 'dart:async';
import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Les identifiants de blocs publicitaires.
///
/// Jamais en dur dans le code livré : la valeur réelle arrive par
/// `--dart-define`, et le défaut est l'identifiant de test **public** de
/// Google. Ce défaut n'est pas une négligence, c'est une protection — cliquer
/// sur ses propres vraies pubs en développement fait fermer un compte AdMob
/// pour trafic invalide, sans recours.
abstract final class AdUnitIds {
  static const String _override = String.fromEnvironment(
    'CEKOI_AD_INTERSTITIAL',
  );

  static const String _testAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testIos = 'ca-app-pub-3940256099942544/4411468910';

  /// L'interstitiel de lancement de partie.
  static String get interstitial {
    if (_override.isNotEmpty) return _override;
    return Platform.isIOS ? _testIos : _testAndroid;
  }
}

/// Charge et présente l'interstitiel de lancement (`MONETISATION.md`).
///
/// Rend `true` **seulement** si le joueur a réellement vu la pub : c'est ce
/// qui décide de consommer ou non le quota. Ne relance jamais.
///
/// `loadTimeout` borne le chargement, pas l'affichage : une fois la pub à
/// l'écran, on attend que le joueur la ferme, aussi longtemps qu'il veut.
///
/// Une fonction et non une interface à une méthode, comme `AdSdkStart` : le
/// seul emplacement autorisé est l'écran de lancement de partie. Pas de
/// bannière, pas d'interstitiel entre les manches ou les tours, aucune pub
/// pendant qu'un chrono tourne — n'exposer qu'un geste est la façon la moins
/// coûteuse de faire tenir ces interdictions.
typedef ShowInterstitial =
    Future<bool> Function({required Duration loadTimeout});

/// L'interstitiel de Google.
Future<bool> showGoogleInterstitial({required Duration loadTimeout}) async {
  final ad = await _load(loadTimeout);
  if (ad == null) return false;

  final closed = Completer<bool>();

  ad.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (ad) {
      unawaited(ad.dispose());
      if (!closed.isCompleted) closed.complete(true);
    },
    onAdFailedToShowFullScreenContent: (ad, error) {
      unawaited(ad.dispose());
      if (!closed.isCompleted) closed.complete(false);
    },
  );

  try {
    await ad.show();
  } on Object {
    unawaited(ad.dispose());
    return false;
  }

  return closed.future;
}

/// Le build sans publicité : rien à montrer.
Future<bool> showNoInterstitial({required Duration loadTimeout}) async => false;

/// Attend [pending] au plus [timeout], et **jette ce qui arrive en retard**.
///
/// `Future.timeout` ne fait que la première moitié : il rend la main, mais
/// laisse le futur d'origine vivre sa vie. Sans le drapeau ci-dessous, une pub
/// arrivée après le délai reste référencée par le SDK sans jamais être
/// détruite — une fuite d'objet plein écran par lancement, qui s'accumule sur
/// toute la durée de vie du processus. `isCompleted` ne peut pas jouer ce
/// rôle : le `Completer` source n'est jamais complété par le délai.
///
/// Générique et sans mention du SDK, donc vérifiable sans appareil : c'est la
/// seule logique de tout ce fichier.
Future<T?> awaitOrDiscard<T extends Object>(
  Future<T?> pending, {
  required Duration timeout,
  required void Function(T) discard,
}) {
  var expired = false;

  unawaited(
    pending
        .then((value) {
          if (expired && value != null) discard(value);
        })
        .catchError((_) {}),
  );

  return pending.timeout(
    timeout,
    onTimeout: () {
      expired = true;
      return null;
    },
  );
}

/// Charge une pub, ou rend `null` au bout de [timeout].
///
/// Une pub qui arrive après le délai est détruite : la partie a déjà démarré,
/// et la garder en réserve la ferait tomber au lancement suivant sans repasser
/// par le plafond de fréquence.
Future<InterstitialAd?> _load(Duration timeout) {
  final loaded = Completer<InterstitialAd?>();

  void fail() {
    if (!loaded.isCompleted) loaded.complete(null);
  }

  unawaited(
    InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
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

  return awaitOrDiscard(
    loaded.future,
    timeout: timeout,
    discard: (ad) => unawaited(ad.dispose()),
  );
}
