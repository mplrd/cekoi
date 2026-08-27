import 'package:cekoi/app/app.dart';
import 'package:cekoi/app/game_persistence.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/feedback/feedback.dart';
import 'package:cekoi/services/feedback/game_feedback.dart';
import 'package:cekoi/services/purchases/purchases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/geometrie.dart';
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
    // Sans les vraies polices, toute mesure de largeur est fausse : Ahem rend
    // chaque glyphe comme un carré du corps. Ce fichier ne mesurait rien
    // jusqu'au 27 août.
    await exigerLesVraiesPolices();
  });

  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<void> pumpHome(
    WidgetTester tester, {
    required Size taille,
    double echelleTexte = 1,
    GameState? reprise,
  }) async {
    poserEcran(tester, taille: taille, echelleTexte: echelleTexte);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Une base en mémoire : le `runAsync` ci-dessous laisse tourner le
          // vrai asynchrone, et l'ouverture de la base réelle réclame alors
          // `path_provider`, absent d'un test widget.
          appDatabaseProvider.overrideWithValue(db),
          // L'accueil ne touche pas la base une fois ces deux-là fournis :
          // c'est la mise en page qu'on teste, pas le chargement.
          deckSeedingProvider.overrideWith((ref) async => const SeedReport()),
          resumableGameProvider.overrideWith((ref) async => reprise),
          screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
          gameFeedbackProvider.overrideWithValue(const SilentGameFeedback()),
          consentGatewayProvider.overrideWithValue(fakeConsentGateway()),
          purchaseServiceProvider.overrideWithValue(fakePurchaseService()),
        ],
        child: CekoiApp(router: createAppRouter()),
      ),
    );
    // Le décodage d'une image ne se termine jamais sous le temps simulé : sans
    // ce `runAsync`, le logo est un trou de 0 × 0 et le bloc d'identité ne
    // pèse que son titre. `tool/apercus/apercu.dart` le fait depuis toujours,
    // et pour la même raison.
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/branding/logo_mark.png'),
        tester.element(find.byType(MaterialApp).first),
      );
    });
    await tester.pumpAndSettle();
  }

  /// Le bloc d'identité se réduit, mais reste un logo — pas un point.
  ///
  /// Relevé, avec les quatre entrées : **1,00** à taille normale — le logo
  /// garde ses 280 px et personne ne perd rien —, 0,87 au maximum d'Android,
  /// 0,46 sur le même réglage et un petit écran. Au pire cas, AX5 sur un
  /// 360 × 640, il ne resterait que 17 px : le bloc s'efface plutôt que de
  /// tomber à 4 %.
  ///
  /// `aucunTexteRogne` ne peut pas voir ça : le `FittedBox` compose son enfant
  /// sans borne, donc le paragraphe a toujours la place qu'il demande et la
  /// mesure le trouve sain. Réduire est l'autre façon de perdre un texte, et
  /// c'est celle que la série du 26 au 27 août a installée partout en
  /// corrigeant les rognages. Elle a besoin de son propre plancher.
  for (final (libelle, taille, echelle, plancher) in [
    // Relevé : 1,00 — le bloc garde ses 280 px, personne ne perd rien.
    ('un ecran courant', const Size(360, 800), 1.0, 0.95),
    // Relevé : 0,87 puis 0,46. Le logo descend à 244 px, puis à 129.
    ('le maximum d Android', const Size(360, 800), 2.0, 0.8),
    ('un petit ecran au maximum d Android', const Size(360, 640), 2.0, 0.4),
    // Ici il ne reste que 17 px : le bloc s'efface au lieu de tomber à 4 %.
    ('AX5 sur iOS', const Size(360, 640), 3.1, null),
  ]) {
    testWidgets('le bloc d identite reste lisible, ou s efface, sur $libelle', (
      tester,
    ) async {
      await pumpHome(
        tester,
        taille: taille,
        echelleTexte: echelle,
        // Quatre entrées : c'est la reprise qui serre le bloc d'identité.
        reprise: testGame(cardCount: 12),
      );

      final logo = find.byType(Image);
      if (plancher == null) {
        expect(
          logo,
          findsNothing,
          reason: 'le bloc devrait avoir cede la place aux entrees',
        );
        return;
      }

      // `getRect` traverse la transformation du `FittedBox`, `getSize` non :
      // leur rapport **est** l'échelle de peinture.
      final reduction =
          tester.getRect(logo).height / tester.getSize(logo).height;

      expect(
        reduction,
        greaterThanOrEqualTo(plancher),
        reason:
            'le bloc d identite est reduit a '
            '${(reduction * 100).toStringAsFixed(0)} %',
      );
      expect(reduction, lessThanOrEqualTo(1.0));
    });
  }

  testWidgets('le logo pese vraiment ses 280 px', (tester) async {
    // Le temoin de tout ce fichier : si cette assertion tombe, le bloc
    // d'identite ne fait que la hauteur de son titre et rien de ce qui est
    // mesure au-dessous ne veut dire quoi que ce soit.
    await pumpHome(tester, taille: const Size(360, 800));
    expect(tester.getSize(find.byType(Image)).height, 280);
  });

  for (final (libelle, taille, echelle, avecReprise) in [
    ('un ecran courant', const Size(360, 800), 1.0, false),
    // Le cas qui serre : quatre entrées au lieu de trois.
    ('une partie reprenable', const Size(360, 800), 1.0, true),
    ('un petit ecran', const Size(360, 640), 1.0, true),
    // Rien ne borne `textScaler` : le réglage système s'applique en entier.
    ('un texte agrandi', const Size(360, 800), 1.3, true),
    // Le pire cas atteignable : petit écran, texte agrandi, quatre entrées.
    ('un petit ecran au texte agrandi', const Size(360, 640), 1.3, true),
    // Le maximum d'Android, puis AX5 sur iOS. Les deux étaient hors de portée
    // de ce fichier, et ils cachaient trois défauts : « Cékoi » réclamait
    // 355,5 px dans 312, « Mes catégories » 324,4 dans 312, et les entrées
    // rognaient leur libellé **par le bas** — 87 px de haut demandés dans une
    // boîte fixée à 64.
    ('le maximum d Android', const Size(360, 800), 2.0, true),
    ('un petit ecran au maximum d Android', const Size(360, 640), 2.0, true),
    ('AX5 sur iOS', const Size(360, 640), 3.1, true),
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
        // `ensureVisible` ne protégeait de rien : sans `Scrollable` ancêtre il
        // ne lève pas, il ne fait rien. C'est le défaut que `resteAtteignable`
        // corrige — elle cherche la cible dans le chemin du toucher.
        await resteAtteignable(tester, find.text(entree));
      }

      // Et ce qu'aucune exception ne signale : un texte plus large ou plus
      // haut que sa boîte est coupé, et l'écran reste vert.
      aucunTexteRogne(tester);
    });
  }
}
