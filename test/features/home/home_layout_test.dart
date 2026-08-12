import 'package:cekoi/app/app.dart';
import 'package:cekoi/app/game_persistence.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/providers.dart';

/// L'accueil doit tenir sur les écrans qui existent.
///
/// Il n'avait aucun test de mise en page, et il débordait de 268 px en
/// paysage — d'où le verrou du portrait. Mais le portrait ne garantit pas une
/// hauteur : un 360 × 640 existe, et l'agrandissement du texte système
/// s'applique en entier, rien ne bornant `textScaler` dans l'application.
///
/// C'est le pire cas de l'application : un logo, un titre, et jusqu'à quatre
/// entrées de 64 px quand une partie est reprenable.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    required Size taille,
    double echelleTexte = 1,
    GameState? reprise,
  }) async {
    tester.view.physicalSize = taille;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    tester.platformDispatcher.textScaleFactorTestValue = echelleTexte;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // L'accueil ne touche pas la base une fois ces deux-là fournis :
          // c'est la mise en page qu'on teste, pas le chargement.
          deckSeedingProvider.overrideWith((ref) async => const SeedReport()),
          resumableGameProvider.overrideWith((ref) async => reprise),
          screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
          consentGatewayProvider.overrideWithValue(fakeConsentGateway()),
        ],
        child: CekoiApp(router: createAppRouter()),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (libelle, taille, echelle, avecReprise) in [
    ('un ecran courant', const Size(360, 800), 1.0, false),
    // Le cas qui serre : quatre entrées au lieu de trois.
    ('une partie reprenable', const Size(360, 800), 1.0, true),
    ('un petit ecran', const Size(360, 640), 1.0, true),
    // Rien ne borne `textScaler` : le réglage système s'applique en entier.
    ('un texte agrandi', const Size(360, 800), 1.3, true),
    // Le pire cas atteignable : petit écran, texte agrandi, quatre entrées.
    ('un petit ecran au texte agrandi', const Size(360, 640), 1.3, true),
  ]) {
    testWidgets("l'accueil tient sur $libelle", (tester) async {
      await pumpHome(
        tester,
        taille: taille,
        echelleTexte: echelle,
        reprise: avecReprise ? testGame(cardCount: 12) : null,
      );

      // Un débordement de `RenderFlex` remonte comme exception de test.
      expect(tester.takeException(), isNull);

      // Et les entrées restent atteignables : « tenir » veut dire qu'on peut
      // encore taper dessus, pas seulement qu'aucun bandeau raye l'écran.
      for (final entree in [
        l10n.homePlay,
        l10n.homeMyDecks,
        l10n.homeSettings,
        if (avecReprise) l10n.homeResumeGame,
      ]) {
        final cible = find.text(entree);
        expect(cible, findsOneWidget, reason: '« $entree » a disparu');
        await tester.ensureVisible(cible);
      }
    });
  }
}
