import 'package:cekoi/app/router.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/features/settings/presentation/app_settings_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Une passerelle qui rend l'état demandé et compte les réouvertures.
class _StubGateway implements ConsentGateway {
  _StubGateway(this.state);

  final ConsentState state;
  int changeCalls = 0;

  @override
  Future<ConsentState> gather() async => state;

  @override
  Future<ConsentState> changeChoice() async {
    changeCalls++;
    return state;
  }
}

void main() {
  late AppLocalizations l10n;
  late AppDatabase db;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<_StubGateway> pumpSettings(
    WidgetTester tester,
    ConsentState consent,
  ) async {
    final gateway = _StubGateway(consent);
    final container = ProviderContainer(
      overrides: [
        // L'écran lit désormais la possession, donc la base : sans base en
        // mémoire, il ouvre celle de l'appareil et le test se bloque sur un
        // canal de plateforme absent.
        appDatabaseProvider.overrideWithValue(db),
        consentGatewayProvider.overrideWithValue(gateway),
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
    return gateway;
  }

  testWidgets("l'entrée de consentement est là quand un formulaire existe", (
    tester,
  ) async {
    await pumpSettings(
      tester,
      const ConsentState(canRequestAds: true, canChangeChoice: true),
    );

    expect(find.text(l10n.settingsAdConsent), findsOneWidget);
    expect(find.text(l10n.settingsAdConsentNone), findsNothing);
  });

  testWidgets('le tap rouvre le formulaire', (tester) async {
    final gateway = await pumpSettings(
      tester,
      const ConsentState(canRequestAds: true, canChangeChoice: true),
    );

    await tester.tap(find.text(l10n.settingsAdConsent));
    await tester.pumpAndSettle();

    expect(gateway.changeCalls, 1);
  });

  testWidgets("hors zone réglementée, l'écran le dit au lieu de rester vide", (
    tester,
  ) async {
    await pumpSettings(tester, const ConsentState(canRequestAds: true));

    expect(find.text(l10n.settingsAdConsent), findsNothing);
    expect(find.text(l10n.settingsAdConsentNone), findsOneWidget);
  });

  testWidgets('la section confidentialité est toujours présente', (
    tester,
  ) async {
    await pumpSettings(tester, ConsentState.none);

    expect(find.text(l10n.settingsPrivacy), findsOneWidget);
  });
}
