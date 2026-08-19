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
///
/// Elle peut répondre autrement une fois le formulaire rouvert : c'est le seul
/// moyen de vérifier que l'écran suit un changement d'avis au lieu d'afficher
/// la réponse lue au lancement.
class _StubGateway implements ConsentGateway {
  _StubGateway(this.state, {ConsentState? apresChangement})
    : apresChangement = apresChangement ?? state;

  final ConsentState state;
  final ConsentState apresChangement;
  int changeCalls = 0;

  @override
  Future<ConsentState> gather() async => state;

  @override
  Future<ConsentState> changeChoice() async {
    changeCalls++;
    return apresChangement;
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
    ConsentState consent, {
    ConsentState? apresChangement,
  }) async {
    final gateway = _StubGateway(consent, apresChangement: apresChangement);
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

  /// Amène l'entrée de consentement sous le doigt avant de la toucher.
  ///
  /// Elle est la dernière d'une liste défilante, et le plan de test fait
  /// 800 × 600 : elle tombe quelques pixels sous le bord. `tap` ne défile pas
  /// tout seul — il avertit et frappe dans le vide, ce qui donne un test qui
  /// passe ou non selon la hauteur du sous-titre.
  Future<void> tapConsent(WidgetTester tester) async {
    await tester.ensureVisible(find.text(l10n.settingsAdConsent));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsAdConsent));
    await tester.pumpAndSettle();
  }

  testWidgets('le tap rouvre le formulaire', (tester) async {
    final gateway = await pumpSettings(
      tester,
      const ConsentState(canRequestAds: true, canChangeChoice: true),
    );

    await tapConsent(tester);

    expect(gateway.changeCalls, 1);
  });

  testWidgets("l'entrée dit que les publicités sont autorisées", (
    tester,
  ) async {
    await pumpSettings(
      tester,
      const ConsentState(canRequestAds: true, canChangeChoice: true),
    );

    expect(find.text(l10n.settingsAdConsentAllowed), findsOneWidget);
    expect(find.text(l10n.settingsAdConsentRefused), findsNothing);
  });

  testWidgets("l'entrée dit que les publicités sont refusées", (tester) async {
    await pumpSettings(tester, const ConsentState(canChangeChoice: true));

    expect(find.text(l10n.settingsAdConsentRefused), findsOneWidget);
    expect(find.text(l10n.settingsAdConsentAllowed), findsNothing);
  });

  testWidgets('le statut suit le choix que le joueur vient de changer', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      const ConsentState(canRequestAds: true, canChangeChoice: true),
      apresChangement: const ConsentState(canChangeChoice: true),
    );

    await tapConsent(tester);

    expect(find.text(l10n.settingsAdConsentRefused), findsOneWidget);
    expect(find.text(l10n.settingsAdConsentAllowed), findsNothing);
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
