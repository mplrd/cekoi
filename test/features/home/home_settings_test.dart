import 'package:cekoi/app/router.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une passerelle muette : cet écran ne parle pas de consentement, il ne fait
/// que mener aux réglages.
class _SilentGateway implements ConsentGateway {
  const _SilentGateway();

  @override
  Future<ConsentState> gather() async => ConsentState.none;

  @override
  Future<ConsentState> changeChoice() async => ConsentState.none;
}

void main() {
  late AppLocalizations l10n;
  late AppDatabase db;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  testWidgets("l'accueil ouvre les réglages de l'application", (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deckSeedingProvider.overrideWith((ref) async => const SeedReport()),
        consentGatewayProvider.overrideWithValue(const _SilentGateway()),
        adSdkStartProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: createAppRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // L'entrée est restée morte tout le temps que l'écran n'existait pas : ce
    // test est ce qui empêche d'y revenir.
    await tester.tap(find.text(l10n.homeSettings));
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsPrivacy), findsOneWidget);
  });
}
