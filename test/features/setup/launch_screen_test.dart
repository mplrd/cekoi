import 'dart:async';

import 'package:cekoi/app/launch_ad.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/features/setup/presentation/launch_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ad_frequency.dart';
import 'package:cekoi/services/ads/interstitial_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Un historique qui ne retient rien.
class _EmptyLog implements AdImpressionLog {
  const _EmptyLog();

  @override
  Future<List<DateTime>> since(DateTime since) async => const [];

  @override
  Future<void> record(
    DateTime shownAt, {
    required DateTime expiredBefore,
  }) async {}
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  /// Monte l'écran avec une pub qui n'arrive jamais : c'est pendant ce
  /// chargement que l'écran est visible, donc le seul moment où il y a quelque
  /// chose à regarder.
  Future<void> pumpLoading(
    WidgetTester tester, {
    Size taille = const Size(360, 640),
    double echelleTexte = 1,
  }) async {
    tester.view.physicalSize = taille;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    tester.platformDispatcher.textScaleFactorTestValue = echelleTexte;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          interstitialGateProvider.overrideWithValue(
            InterstitialGate(
              canRequestAds: true,
              show: ({required loadTimeout}) => Completer<bool>().future,
              log: const _EmptyLog(),
              now: () => DateTime.utc(2026, 8, 12, 20),
              policy: const AdFrequencyPolicy(),
            ),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: AppRoutes.launch,
            routes: [
              GoRoute(
                path: AppRoutes.launch,
                builder: (_, _) => const LaunchScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('la consigne et la manche 1 sont lisibles', (tester) async {
    await pumpLoading(tester);

    expect(find.text(l10n.launchSettleIn), findsOneWidget);
    expect(find.text(l10n.roundNameFree), findsOneWidget);
    expect(find.text(l10n.roundRuleFree), findsOneWidget);
  });

  testWidgets('rien ne déborde sur un petit écran au texte agrandi', (
    tester,
  ) async {
    // 360 × 640 à 1,3 est le pire cas de référence du projet. La colonne
    // centrée y débordait de 223 px, et c'est la carte de la manche 1 — celle
    // que la table vient lire — qui se faisait couper.
    await pumpLoading(tester, echelleTexte: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.roundRuleFree), findsOneWidget);
  });

  testWidgets('même à 2,0, le contenu reste atteignable en défilant', (
    tester,
  ) async {
    await pumpLoading(tester, echelleTexte: 2);

    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
