import 'package:cekoi/app/router.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/data/repositories/entitlement_repository.dart';
import 'package:cekoi/features/settings/presentation/app_settings_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/purchases/purchase_service.dart';
import 'package:cekoi/services/purchases/purchases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/providers.dart';

/// Un magasin piloté par le test.
class _StubStore implements PurchaseService {
  _StubStore(this.outcome);

  final PurchaseOutcome outcome;
  int achats = 0;
  int restaurations = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => const [];

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    achats++;
    return outcome;
  }

  @override
  Future<PurchaseOutcome> restore(String productId) async {
    restaurations++;
    return outcome;
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

  Future<_StubStore> pumpSettings(
    WidgetTester tester, {
    PurchaseOutcome outcome = PurchaseOutcome.owned,
  }) async {
    final store = _StubStore(outcome);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          consentGatewayProvider.overrideWithValue(fakeConsentGateway()),
          adSdkStartProvider.overrideWithValue(() async {}),
          purchaseServiceProvider.overrideWithValue(store),
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
    return store;
  }

  testWidgets('l offre est là tant que l achat n est pas fait', (tester) async {
    await pumpSettings(tester);

    expect(find.text(l10n.settingsFullVersionPitch), findsOneWidget);
    expect(find.text(l10n.settingsFullVersionOwned), findsNothing);
  });

  testWidgets('aucun prix n est affiché par l application', (tester) async {
    // Le prix vient du magasin, qui connaît la devise et la taxe du joueur.
    // Un « 3,99 € » écrit ici serait faux hors zone euro.
    await pumpSettings(tester);

    expect(find.textContaining('€'), findsNothing);
    expect(find.textContaining('3,99'), findsNothing);
  });

  testWidgets('acheter ouvre le magasin et éteint l offre', (tester) async {
    final store = await pumpSettings(tester);

    await tester.tap(find.text(l10n.settingsFullVersionPitch));
    await tester.pumpAndSettle();

    expect(store.achats, 1);
    expect(find.text(l10n.settingsFullVersionOwned), findsOneWidget);
    expect(
      find.text(l10n.settingsFullVersionPitch),
      findsNothing,
      reason: 'proposer encore l achat à qui vient de payer serait une faute',
    );
  });

  testWidgets('un magasin qui refuse le dit, et ne débite rien', (
    tester,
  ) async {
    await pumpSettings(tester, outcome: PurchaseOutcome.failed);

    await tester.tap(find.text(l10n.settingsFullVersionPitch));
    await tester.pumpAndSettle();

    expect(find.text(l10n.purchaseFailed), findsOneWidget);
    expect(find.text(l10n.settingsFullVersionPitch), findsOneWidget);
  });

  testWidgets('une annulation ne dit rien du tout', (tester) async {
    // Le joueur vient de fermer la feuille de paiement : il le sait. Lui
    // afficher un message serait le sermonner.
    await pumpSettings(tester, outcome: PurchaseOutcome.cancelled);

    await tester.tap(find.text(l10n.settingsFullVersionPitch));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('la restauration est toujours joignable', (tester) async {
    // Exigence Apple : elle ne doit pas être conditionnelle, ni cachée.
    final store = await pumpSettings(tester);

    expect(find.text(l10n.settingsRestore), findsOneWidget);

    await tester.tap(find.text(l10n.settingsRestore));
    await tester.pumpAndSettle();

    expect(store.restaurations, 1);
    expect(find.text(l10n.settingsFullVersionOwned), findsWidgets);
  });

  testWidgets('une restauration sans achat le dit clairement', (tester) async {
    await pumpSettings(tester, outcome: PurchaseOutcome.cancelled);

    await tester.tap(find.text(l10n.settingsRestore));
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsRestoreNothing), findsOneWidget);
  });

  testWidgets('un achat déjà en base s affiche sans passer par le magasin', (
    tester,
  ) async {
    await EntitlementRepository(db).grantFullVersion(DateTime.utc(2026, 8, 13));

    final store = await pumpSettings(tester);

    expect(find.text(l10n.settingsFullVersionOwned), findsOneWidget);
    expect(
      store.achats,
      0,
      reason:
          'le jeu se joue hors ligne : une soirée sans réseau ne doit pas '
          'faire disparaître une catégorie payée',
    );
  });
}
