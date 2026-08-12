import 'dart:async';

import 'package:cekoi/services/ads/ad_sdk.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une passerelle pilotée par le test.
///
/// Le `Completer` est ce qui rend l'ordre observable : tant qu'il n'est pas
/// complété, l'utilisateur n'a pas répondu au formulaire. C'est exactement la
/// fenêtre pendant laquelle le SDK n'a pas le droit de démarrer.
class _StubGateway implements ConsentGateway {
  _StubGateway({this.onChange = ConsentState.none});

  final Completer<ConsentState> answer = Completer<ConsentState>();
  final ConsentState onChange;
  int changeCalls = 0;

  @override
  Future<ConsentState> gather() => answer.future;

  @override
  Future<ConsentState> changeChoice() async {
    changeCalls++;
    return onChange;
  }
}

void main() {
  late _StubGateway gateway;
  late int demarrages;
  late ProviderContainer container;

  ProviderContainer build({
    ConsentGateway? passerelle,
    Future<void> Function()? sdk,
  }) {
    final c = ProviderContainer(
      overrides: [
        consentGatewayProvider.overrideWithValue(passerelle ?? gateway),
        adSdkStartProvider.overrideWithValue(
          sdk ?? () async => demarrages++,
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    gateway = _StubGateway();
    demarrages = 0;
  });

  test(
    "le SDK ne démarre pas tant que le consentement n'a pas répondu",
    () async {
      container = build();
      // Déclenche la construction du provider sans attendre sa réponse.
      unawaited(container.read(adConsentProvider.future));
      await Future<void>.delayed(Duration.zero);

      expect(
        demarrages,
        0,
        reason:
            "MONETISATION.md : le SDK ne s'initialise qu'après une réponse au "
            'formulaire. Un démarrage ici est une requête publicitaire avant '
            'consentement.',
      );

      gateway.answer.complete(
        const ConsentState(canRequestAds: true, canChangeChoice: true),
      );
      await container.read(adConsentProvider.future);

      expect(demarrages, 1);
    },
  );

  test('un refus laisse le SDK éteint', () async {
    container = build();
    gateway.answer.complete(const ConsentState(canChangeChoice: true));

    final state = await container.read(adConsentProvider.future);

    expect(demarrages, 0);
    expect(state.canRequestAds, isFalse);
    expect(
      state.canChangeChoice,
      isTrue,
      reason: 'Refuser ne doit pas retirer la possibilité de revenir dessus',
    );
  });

  test("un CMP en panne éteint la pub, pas l'application", () async {
    container = build();
    gateway.answer.completeError(StateError('CMP injoignable'));

    final state = await container.read(adConsentProvider.future);

    expect(state, ConsentState.none);
    expect(demarrages, 0);
  });

  test(
    'un SDK qui refuse de démarrer ne fait pas disparaître le choix',
    () async {
      container = build(
        sdk: () async => throw StateError('pas de Play Services'),
      );
      gateway.answer.complete(
        const ConsentState(canRequestAds: true, canChangeChoice: true),
      );

      final state = await container.read(adConsentProvider.future);

      expect(
        state.canRequestAds,
        isFalse,
        reason: 'Sans SDK démarré, aucune pub ne peut être demandée',
      );
      expect(
        state.canChangeChoice,
        isTrue,
        reason:
            "L'entrée des réglages est une obligation légale : elle ne dépend "
            "pas du succès d'une initialisation technique",
      );
    },
  );

  test('le choix reste modifiable après coup', () async {
    gateway = _StubGateway(
      onChange: const ConsentState(canRequestAds: true, canChangeChoice: true),
    );
    container = build();
    gateway.answer.complete(const ConsentState(canChangeChoice: true));
    await container.read(adConsentProvider.future);

    await container.read(adConsentProvider.notifier).changeChoice();

    expect(gateway.changeCalls, 1);
    expect(
      container.read(adConsentProvider).requireValue.canRequestAds,
      isTrue,
    );
    expect(
      demarrages,
      1,
      reason: 'Un consentement donné après coup démarre le SDK à ce moment-là',
    );
  });

  test('un build sans publicité ne demande rien', () async {
    container = build(passerelle: const NoConsentGateway());

    final state = await container.read(adConsentProvider.future);

    expect(state, ConsentState.none);
    expect(demarrages, 0);
  });

  test("le démarrage factice ne fait rien et n'échoue pas", () async {
    await expectLater(startNoAdSdk(), completes);
  });
}
