import 'package:cekoi/app/build_info.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/features/settings/presentation/app_settings_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un téléphone doit pouvoir dire ce qu'il exécute.
///
/// Le 24 août, la question « quelle version as-tu ? » n'avait aucune réponse :
/// `versionName` vaut `1.0.0` sur tous les builds depuis le premier, et la
/// seule façon d'établir ce qu'un appareil portait était de le brancher pour
/// comparer une empreinte SHA-256. Praticable pour une personne, intenable
/// pour douze testeurs.
///
/// Ce que ces tests tiennent, et qui n'est pas évident : l'écran doit se taire
/// plutôt que mentir. Un binaire construit hors du chemin de livraison n'a
/// aucune identité, et afficher la version de `pubspec.yaml` dans ce cas
/// désignerait n'importe lequel des builds de la semaine.
class _StubGateway implements ConsentGateway {
  const _StubGateway();

  @override
  Future<ConsentState> gather() async => ConsentState.none;

  @override
  Future<ConsentState> changeChoice() async => ConsentState.none;
}

/// L'identité vide, écrite en toutes lettres.
///
/// Et non `BuildInfo.ceBinaire`, que l'analyseur propose à sa place parce que
/// les deux valent aujourd'hui la même chose : ce que ces tests posent, c'est
/// un binaire **sans identité**, pas celui qui exécute le test. Les deux ne se
/// confondent que tant que `flutter test` ne reçoit pas les options de
/// livraison, et le jour où ce ne serait plus vrai, les écrire pareil ferait
/// passer ces cas pour la mauvaise raison.
// ignore: use_named_constants
const _inconnu = BuildInfo(version: '', numero: '', commit: '', date: '');

void main() {
  late AppLocalizations l10n;
  late AppDatabase db;
  late List<String> copies;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  setUp(() {
    db = AppDatabase.memory();
    copies = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (appel) async {
          if (appel.method == 'Clipboard.setData') {
            copies.add(
              (appel.arguments as Map<Object?, Object?>)['text']! as String,
            );
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    return db.close();
  });

  Future<void> pumpSettings(WidgetTester tester, BuildInfo info) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          consentGatewayProvider.overrideWithValue(const _StubGateway()),
          adSdkStartProvider.overrideWithValue(() async {}),
          buildInfoProvider.overrideWithValue(info),
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

  /// Amène la ligne d'identité sous les yeux avant de l'interroger.
  ///
  /// Elle est la dernière d'une liste défilante, donc hors de l'écran de test
  /// et **pas construite du tout** : une `ListView` ne monte que ce qui entre
  /// dans sa fenêtre plus sa marge. `find.text` n'y voit rien, et
  /// `ensureVisible` pas davantage — il lui faut déjà un widget.
  Future<void> amener(WidgetTester tester, Finder cible) async {
    await tester.scrollUntilVisible(
      cible,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  const identifie = BuildInfo(
    version: '1.0.0',
    numero: '128',
    commit: '050e30a',
    date: '2026-08-24',
  );

  testWidgets('un build livré porte son commit, son numéro et sa date', (
    tester,
  ) async {
    await pumpSettings(tester, identifie);

    final etiquette = find.text(
      l10n.settingsBuildStamp('1.0.0', '128', '050e30a', '2026-08-24'),
    );
    await amener(tester, etiquette);
    expect(etiquette, findsOneWidget);

    // Les quatre valeurs séparément : une étiquette qui perdrait l'empreinte
    // resterait une phrase plausible, et c'est elle qui identifie le binaire.
    final texte = tester.widget<Text>(etiquette).data!;
    for (final valeur in ['1.0.0', '128', '050e30a', '2026-08-24']) {
      expect(texte, contains(valeur), reason: '« $valeur » manque');
    }
  });

  testWidgets("un build hors chemin de livraison dit qu'il ne se connaît pas", (
    tester,
  ) async {
    await pumpSettings(tester, _inconnu);

    await amener(tester, find.text(l10n.settingsBuildUnidentified));
    expect(find.text(l10n.settingsBuildUnidentified), findsOneWidget);
    // Surtout pas de version affichée : « 1.0.0 » tout seul désignerait
    // n'importe lequel des builds depuis le premier.
    expect(find.textContaining('1.0.0'), findsNothing);
  });

  testWidgets("l'étiquette se copie d'un appui", (tester) async {
    await pumpSettings(tester, identifie);

    final attendue = l10n.settingsBuildStamp(
      '1.0.0',
      '128',
      '050e30a',
      '2026-08-24',
    );
    await amener(tester, find.text(attendue));
    await tester.tap(find.text(attendue));
    await tester.pumpAndSettle();

    expect(copies, [attendue]);
    expect(find.text(l10n.settingsBuildCopied), findsOneWidget);
  });

  testWidgets("ce que l'appui déclenche est annoncé aux lecteurs d'écran", (
    tester,
  ) async {
    // L'affordance visible a été retirée au profit d'une icône. Sans
    // onTapHint, un lecteur d'écran annonce une ligne cliquable sans dire ce
    // que l'appui fait — et l'icône ne lui parle pas.
    await pumpSettings(tester, identifie);

    final etiquette = find.text(
      l10n.settingsBuildStamp('1.0.0', '128', '050e30a', '2026-08-24'),
    );
    await amener(tester, etiquette);

    expect(
      tester.getSemantics(etiquette),
      matchesSemantics(
        label: l10n.settingsBuildStamp('1.0.0', '128', '050e30a', '2026-08-24'),
        onTapHint: l10n.settingsBuildHint,
        hasTapAction: true,
        hasFocusAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        isButton: true,
        hasSelectedState: true,
      ),
    );
  });

  testWidgets("rien à copier quand il n'y a rien à dire", (tester) async {
    await pumpSettings(tester, _inconnu);

    await amener(tester, find.text(l10n.settingsBuildUnidentified));
    await tester.tap(find.text(l10n.settingsBuildUnidentified));
    await tester.pumpAndSettle();

    expect(copies, isEmpty);
    expect(find.text(l10n.settingsBuildCopied), findsNothing);
  });

  group('ce que le binaire sait de lui-même', () {
    test('un commit vide vaut « non identifié »', () {
      expect(_inconnu.identifie, isFalse);
      expect(identifie.identifie, isTrue);
    });

    test('un test tourne forcément sur un binaire non identifié', () {
      // Ce n'est pas une évidence à laisser implicite : c'est la raison d'être
      // de `buildInfoProvider`. Le jour où `flutter test` recevrait les
      // `--dart-define` de livraison, les cas ci-dessus cesseraient d'être
      // exercés pour ce qu'ils croient exercer.
      expect(BuildInfo.ceBinaire.identifie, isFalse);
    });
  });
}
