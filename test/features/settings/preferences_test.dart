import 'package:cekoi/app/router.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/data/repositories/preferences_repository.dart';
import 'package:cekoi/features/settings/presentation/app_settings_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/purchases/purchases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/providers.dart';

void main() {
  late AppLocalizations l10n;
  late AppDatabase db;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          consentGatewayProvider.overrideWithValue(fakeConsentGateway()),
          adSdkStartProvider.overrideWithValue(() async {}),
          purchaseServiceProvider.overrideWithValue(fakePurchaseService()),
        ],
        child: MaterialApp.router(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: AppRoutes.settings,
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (_, _) => const AppSettingsScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder switchOf(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(SwitchListTile),
  );

  testWidgets('les deux réglages arrivent actifs', (tester) async {
    await pumpSettings(tester);

    expect(
      tester.widget<SwitchListTile>(switchOf(l10n.settingsSound)).value,
      isTrue,
    );
    expect(
      tester.widget<SwitchListTile>(switchOf(l10n.settingsHaptics)).value,
      isTrue,
    );
  });

  testWidgets('couper le son ne coupe pas la vibration', (tester) async {
    await pumpSettings(tester);

    await tester.tap(switchOf(l10n.settingsSound));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(switchOf(l10n.settingsSound)).value,
      isFalse,
    );
    expect(
      tester.widget<SwitchListTile>(switchOf(l10n.settingsHaptics)).value,
      isTrue,
      reason: 'au restaurant, on veut la vibration sans le son',
    );
  });

  testWidgets('le réglage est écrit en base, pas seulement à l écran', (
    tester,
  ) async {
    // Sinon il reviendrait au lancement suivant, sans que personne comprenne
    // pourquoi.
    await pumpSettings(tester);

    await tester.tap(switchOf(l10n.settingsHaptics));
    await tester.pumpAndSettle();

    expect((await PreferencesRepository(db).read()).hapticsEnabled, isFalse);
  });

  testWidgets('un réglage déjà en base est celui qui s affiche', (
    tester,
  ) async {
    await PreferencesRepository(
      db,
    ).write(const AppPreferences(soundEnabled: false));

    await pumpSettings(tester);

    expect(
      tester.widget<SwitchListTile>(switchOf(l10n.settingsSound)).value,
      isFalse,
    );
  });
}
