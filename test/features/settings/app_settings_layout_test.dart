import 'package:cekoi/app/build_info.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/features/settings/presentation/app_settings_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/geometrie.dart';

/// L'étiquette d'identité ne doit pas se faire rogner.
///
/// `docs/REPRISE.md` annonce « Écrans à risque de débordement : 0, testés
/// jusqu'à ×3,1 ». Cette section ajoute à un écran la chaîne la plus dense de
/// l'application — quarante caractères de version, d'empreinte et de date —
/// et l'affirmation ne vaut plus rien tant qu'on ne l'a pas revérifiée avec
/// l'outil qui existe pour ça.
///
/// Le cas mesuré est le pire : un commit d'arbre sale, qui porte quatre
/// caractères de plus que l'empreinte nue.
class _StubGateway implements ConsentGateway {
  const _StubGateway();

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
    await exigerLesVraiesPolices();
  });

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  /// Le pire des cas : arbre sale, donc empreinte allongée.
  const pire = BuildInfo(
    version: '1.0.0',
    numero: '212',
    commit: 'dc4ecad-sale',
    date: '2026-08-25',
  );

  Future<void> pumpReglages(
    WidgetTester tester, {
    required Size taille,
    double echelleTexte = 1,
  }) async {
    poserEcran(tester, taille: taille, echelleTexte: echelleTexte);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          consentGatewayProvider.overrideWithValue(const _StubGateway()),
          adSdkStartProvider.overrideWithValue(() async {}),
          buildInfoProvider.overrideWithValue(pire),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (libelle, taille, echelle) in [
    ('un écran courant', const Size(360, 800), 1.0),
    ('un petit écran', const Size(360, 640), 1.0),
    ('un texte agrandi', const Size(360, 800), 2.0),
    // Le maximum du réglage système d'Android.
    ("un petit écran au maximum d'Android", const Size(360, 640), 2.0),
    // iOS pousse plus loin : AX5 vaut ×3,1.
    ('un iPhone SE en AX5', const Size(375, 667), 3.1),
    ('un écran de 320 à ×3', const Size(320, 568), 3.0),
  ]) {
    testWidgets("l'identité du build tient sur $libelle", (tester) async {
      await pumpReglages(tester, taille: taille, echelleTexte: echelle);

      final etiquette = find.text(
        l10n.settingsBuildStamp('1.0.0', '212', 'dc4ecad-sale', '2026-08-25'),
      );
      // La section est la dernière de la liste : hors de la fenêtre, elle
      // n'est pas construite du tout, et rien ne serait mesuré.
      await tester.scrollUntilVisible(
        etiquette,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      aucunTexteRogne(tester);
      await resteAtteignable(tester, etiquette);
    });
  }

  testWidgets('les titres de section tiennent aussi', (tester) async {
    // « Confidentialité » est un mot de quinze lettres, et il était rogné
    // avant même que cette section existe. Le cas ci-dessus le couvre par
    // accident — il balaie ce qui est monté après le défilement, et rien
    // n'assure que ce titre en fasse encore partie le jour où la liste
    // changera.
    await pumpReglages(tester, taille: const Size(320, 568), echelleTexte: 3);

    final titre = find.text(l10n.settingsPrivacy);
    await tester.scrollUntilVisible(
      titre,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(titre, findsOneWidget);
    aucunTexteRogne(tester);
  });
}
