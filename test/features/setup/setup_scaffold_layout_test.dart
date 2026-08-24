import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/features/setup/presentation/setup_steps.dart';
import 'package:cekoi/features/setup/presentation/widgets/setup_scaffold.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/geometrie.dart';

/// L'ossature des quatre étapes de configuration doit garder son pied
/// atteignable.
///
/// `SetupScaffold` porte les cinq écrans du parcours, et tous lui passent une
/// `ListView` — c'est donc lui, et lui seul, qui décide de ce qui cède quand
/// la place manque. Sa structure est celle du récapitulatif de tour : en-tête
/// fixe, `Expanded` au milieu, action épinglée en bas. Le `Expanded` absorbe
/// jusqu'à zéro, puis c'est la somme des parties fixes qui déborde, et le
/// bouton d'avancement passe sous le bord.
///
/// Le tester ici plutôt que sur les cinq écrans : c'est l'ossature qui est en
/// cause, les écrans n'y changent rien, et cinq harnais à base de données pour
/// mesurer une hauteur seraient cinq occasions de diverger.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await exigerLesVraiesPolices();
  });

  Future<void> pumpEtape(
    WidgetTester tester, {
    required Size taille,
    double echelleTexte = 1,
    int entrees = 8,
  }) async {
    poserEcran(tester, taille: taille, echelleTexte: echelleTexte);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l = AppLocalizations.of(context);
              return SetupScaffold(
                // L'étape des réglages : son titre est le plus long des cinq.
                step: SetupStep.settings,
                title: l.setupSettingsTitle,
                footer: FilledButton(
                  onPressed: () {},
                  child: Text(l.actionContinue),
                ),
                child: ListView(
                  children: [
                    for (var i = 0; i < entrees; i++)
                      ListTile(title: Text('Réglage $i')),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (libelle, taille, echelle) in [
    ('un écran courant', const Size(360, 800), 1.0),
    ('un petit écran', const Size(360, 640), 1.0),
    // Le seuil estimé de la dette.
    ('un texte agrandi', const Size(360, 800), 2.5),
    ('un petit écran au texte agrandi', const Size(360, 640), 2.5),
    // Le pire cas : petit écran, texte au maximum courant du système.
    ('le pire cas', const Size(360, 640), 3.0),
  ]) {
    testWidgets("le pied de l'étape reste atteignable sur $libelle", (
      tester,
    ) async {
      await pumpEtape(tester, taille: taille, echelleTexte: echelle);

      expect(tester.takeException(), isNull);
      await resteAtteignable(tester, find.text(l10n.actionContinue));
      aucunTexteRogne(tester);
    });
  }

  testWidgets("le rang et le total restent affichés quoi qu'il arrive", (
    tester,
  ) async {
    await pumpEtape(tester, taille: const Size(360, 640), echelleTexte: 3);

    // Le libellé déclare `ellipsis` : il a le droit de céder. Les points, eux,
    // sont ce qui dit combien d'étapes restent, et ils ne cèdent pas.
    final parcours = setupStepsFor(Audience.family);
    expect(parcours, contains(SetupStep.settings));
    expect(
      find.text(l10n.setupStep(parcours.indexOf(SetupStep.settings) + 1, 4)),
      findsOneWidget,
    );
  });
}
