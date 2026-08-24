import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/features/setup/presentation/setup_steps.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_scaffold.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/geometrie.dart';

/// L'ossature des étapes de configuration doit garder son pied atteignable.
///
/// `SetupScaffold` porte les cinq écrans du parcours et tous lui passent une
/// `ListView` : c'est lui, et lui seul, qui décide de ce qui cède quand la
/// place manque. Sa structure est celle du récapitulatif de tour — en-tête,
/// liste, action épinglée — et elle avait la même faiblesse : le `Expanded` du
/// milieu absorbe jusqu'à zéro, puis c'est la somme des parties fixes qui
/// déborde.
///
/// **Le pied n'est pas le même d'un écran à l'autre**, et c'est ce que la
/// première version de ce fichier a manqué : elle mesurait un `FilledButton`
/// nu, sans le thème de l'application, alors que l'étape des équipes pose une
/// colonne pouvant porter deux avis au-dessus du bouton — et que c'est elle
/// qui lance la partie. On teste donc le **contrat** de l'ossature, « l'action
/// reste atteignable quelle que soit la hauteur du pied », plutôt qu'un pied
/// particulier qui finirait par dériver du vrai.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await exigerLesVraiesPolices();
  });

  /// Un pied de [avis] lignes au-dessus du bouton, comme en pose
  /// `launch_button.dart` : deux au pire, en `bodySmall`.
  Widget pied(BuildContext context, int avis) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < avis; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l.launchAdNotice,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        FilledButton(onPressed: () {}, child: Text(l.actionStartGame)),
      ],
    );
  }

  Future<void> pumpEtape(
    WidgetTester tester, {
    required Size taille,
    required SetupStep etape,
    required String titre,
    double echelleTexte = 1,
    int avis = 2,
    int entrees = 8,
  }) async {
    poserEcran(tester, taille: taille, echelleTexte: echelleTexte);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Le thème donne aux boutons 64 px de haut minimum et un libellé de
          // 20 points : sans lui, le pied mesuré fait la moitié du vrai.
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => SetupScaffold(
              step: etape,
              title: titre,
              footer: pied(context, avis),
              child: ListView(
                children: [
                  for (var i = 0; i < entrees; i++)
                    ListTile(title: Text('Réglage $i')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Les cinq titres réels. Celui des équipes est le plus large — 174,9 px de
  /// mot insécable à ×1, contre 147,5 pour celui des réglages — et c'est lui
  /// qui porte le lancement de la partie.
  List<(SetupStep, String)> titres() => [
    (SetupStep.mode, l10n.setupModeTitle),
    (SetupStep.pool, l10n.setupPoolTitle),
    (SetupStep.decks, l10n.setupDecksTitle),
    (SetupStep.settings, l10n.setupSettingsTitle),
    (SetupStep.teams, l10n.setupTeamsTitle),
  ];

  for (final (libelle, taille, echelle) in [
    ('un écran courant', const Size(360, 800), 1.0),
    ('un petit écran', const Size(360, 640), 1.0),
    ('un texte agrandi', const Size(360, 800), 2.0),
    // Le maximum du réglage système d'Android.
    ("un petit écran au maximum d'Android", const Size(360, 640), 2.0),
    // iOS va plus loin : AX4 vaut ×2,35 et AX5 ×3,1.
    ('un iPhone SE en AX4', const Size(375, 667), 2.35),
    ('un iPhone SE en AX5', const Size(375, 667), 3.1),
    // Un 320 de large, et la taille d'affichage poussée au maximum.
    ('un écran de 320 à ×3', const Size(320, 568), 3.0),
  ]) {
    testWidgets('les cinq étapes tiennent sur $libelle', (tester) async {
      for (final (etape, titre) in titres()) {
        await pumpEtape(
          tester,
          taille: taille,
          etape: etape,
          titre: titre,
          echelleTexte: echelle,
        );

        expect(tester.takeException(), isNull, reason: 'étape « $titre »');
        await resteAtteignable(tester, find.text(l10n.actionStartGame));
        aucunTexteRogne(tester);
      }
    });
  }

  testWidgets("le pied peut grandir sans emporter l'action", (tester) async {
    // Le contrat pris au mot : trois avis, soit un de plus que ce que
    // `launch_button.dart` sait poser aujourd'hui.
    for (var avis = 0; avis <= 3; avis++) {
      await pumpEtape(
        tester,
        taille: const Size(360, 640),
        etape: SetupStep.teams,
        titre: l10n.setupTeamsTitle,
        echelleTexte: 3,
        avis: avis,
      );

      expect(tester.takeException(), isNull, reason: '$avis avis');
      await resteAtteignable(tester, find.text(l10n.actionStartGame));
    }
  });

  testWidgets('le compte des étapes ne cède pas', (tester) async {
    await pumpEtape(
      tester,
      taille: const Size(360, 640),
      etape: SetupStep.settings,
      titre: l10n.setupSettingsTitle,
      echelleTexte: 3,
    );

    // Le libellé déclare `ellipsis` : il a le droit de céder. Ce qui ne cède
    // pas, c'est le rang et le total.
    final parcours = setupStepsFor(Audience.family);
    expect(parcours, contains(SetupStep.settings));
    expect(
      find.text(
        l10n.setupStep(
          parcours.indexOf(SetupStep.settings) + 1,
          parcours.length,
        ),
      ),
      findsOneWidget,
    );
  });
}
