import 'dart:async';

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

/// Un dépôt dont la lecture ne répond que sur ordre.
///
/// C'est la seule façon de reproduire la vraie fenêtre : la base s'ouvre
/// paresseusement, donc la première lecture paie l'ouverture du fichier, la
/// migration et la file d'attente derrière le seeding. Pendant ce temps
/// l'écran des réglages est affichable, et ses interrupteurs sont actifs.
class _SlowPreferences implements PreferencesRepository {
  _SlowPreferences(this.enBase);

  final AppPreferences enBase;
  final Completer<AppPreferences> _lecture = Completer<AppPreferences>();
  AppPreferences? ecrit;

  void repond() => _lecture.complete(enBase);

  @override
  Future<AppPreferences> read() => _lecture.future;

  @override
  Future<void> write(AppPreferences preferences) async => ecrit = preferences;
}

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

  testWidgets('ce qu on coupe, on peut le rallumer', (tester) async {
    // Le deuxième geste de tout utilisateur, et il n'était couvert par rien :
    // tous les tests coupaient. Un `onChanged` qui ignorerait son argument, ou
    // un `setSound(enabled: false)` écrit en dur, passait inaperçu.
    await PreferencesRepository(
      db,
    ).write(const AppPreferences(soundEnabled: false));
    await pumpSettings(tester);

    await tester.tap(switchOf(l10n.settingsSound));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(switchOf(l10n.settingsSound)).value,
      isTrue,
    );
    expect((await PreferencesRepository(db).read()).soundEnabled, isTrue);
  });

  testWidgets('la vibration se rallume aussi', (tester) async {
    await PreferencesRepository(
      db,
    ).write(const AppPreferences(hapticsEnabled: false));
    await pumpSettings(tester);

    await tester.tap(switchOf(l10n.settingsHaptics));
    await tester.pumpAndSettle();

    expect((await PreferencesRepository(db).read()).hapticsEnabled, isTrue);
  });

  testWidgets('couper l un ne rallume pas l autre', (tester) async {
    // Le cas de la lecture encore en vol : les interrupteurs affichent les
    // valeurs par défaut, tout activé, et composer sur ce défaut ferait
    // ressusciter un son coupé la veille.
    await PreferencesRepository(
      db,
    ).write(const AppPreferences(soundEnabled: false));
    await pumpSettings(tester);

    await tester.tap(switchOf(l10n.settingsHaptics));
    await tester.pumpAndSettle();

    final relus = await PreferencesRepository(db).read();
    expect(relus.hapticsEnabled, isFalse);
    expect(
      relus.soundEnabled,
      isFalse,
      reason: 'toucher un réglage ne doit jamais en réécrire un autre',
    );
  });

  testWidgets('une lecture encore en vol n écrase pas ce qui est en base', (
    tester,
  ) async {
    // Le joueur avait coupé le son hier. Il ouvre les réglages pendant que la
    // base s'ouvre : les deux interrupteurs s'affichent actifs, valeurs par
    // défaut. Il coupe la vibration. Son son doit rester coupé.
    final lent = _SlowPreferences(const AppPreferences(soundEnabled: false));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          consentGatewayProvider.overrideWithValue(fakeConsentGateway()),
          adSdkStartProvider.overrideWithValue(() async {}),
          purchaseServiceProvider.overrideWithValue(fakePurchaseService()),
          preferencesRepositoryProvider.overrideWithValue(lent),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppSettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(switchOf(l10n.settingsHaptics));
    await tester.pump();

    lent.repond();
    await tester.pumpAndSettle();

    expect(lent.ecrit?.hapticsEnabled, isFalse);
    expect(
      lent.ecrit?.soundEnabled,
      isFalse,
      reason:
          'composer sur les valeurs par défaut ferait ressusciter un son '
          'coupé la veille, sans que personne comprenne pourquoi',
    );
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
