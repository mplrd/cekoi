import 'package:cekoi/app/app.dart';
import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/preferences.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/feedback/feedback.dart';
import 'package:cekoi/services/feedback/game_feedback.dart';
import 'package:cekoi/services/purchases/purchases.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'geometrie.dart';
import 'providers.dart';

/// Monte l'application **comme elle démarre**, sur son accueil.
///
/// Le pendant de `partie.dart` pour les écrans qui vivent avant la partie :
/// l'accueil, les quatre étapes de configuration, les catégories. Ils passent
/// tous par le routeur, et aucun ne se monte seul — la dernière étape porte le
/// bouton de lancement, qui lit le catalogue, qui lit la base.
///
/// Comme pour `monterLaPartie`, l'intérêt n'est pas d'économiser des lignes :
/// c'est qu'un fichier de mesure ne vaut que par ce qu'il monte, et qu'une
/// copie qui dérive paraît verte.
///
/// Ne charge pas les polices : c'est à l'appelant d'appeler
/// [exigerLesVraiesPolices] dans son `setUpAll`.
Future<void> monterLaConfiguration(
  WidgetTester tester,
  AppDatabase db, {
  required Size taille,
  double echelleTexte = 1,
}) async {
  poserEcran(tester, taille: taille, echelleTexte: echelleTexte);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        // Le seeding lit `rootBundle`, absent d'un test widget : la base est
        // remplie à la main par [installerCategorie].
        deckSeedingProvider.overrideWith((ref) async => const SeedReport()),
        seedSourceProvider.overrideWithValue(() => 42),
        screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
        gameFeedbackProvider.overrideWithValue(const SilentGameFeedback()),
        currentPreferencesProvider.overrideWithValue(fakePreferences()),
        consentGatewayProvider.overrideWithValue(fakeConsentGateway()),
        adSdkStartProvider.overrideWithValue(() async {}),
        purchaseServiceProvider.overrideWithValue(fakePurchaseService()),
      ],
      child: CekoiApp(router: createAppRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Installe une catégorie officielle et ses cartes.
///
/// Les trois difficultés sont remplies : un vivier déséquilibré ferait
/// apparaître l'avertissement de pénurie, qui change la hauteur du pied de
/// page et donc ce qu'on mesure.
Future<void> installerCategorie(
  AppDatabase db,
  String id, {
  String? nom,
  int facile = 10,
  int moyen = 10,
  int difficile = 10,
  Audience audience = Audience.family,
  MinAge ageMinimum = MinAge.six,
}) async {
  await db
      .into(db.decks)
      .insert(
        DecksCompanion.insert(
          id: id,
          name: nom ?? id,
          audience: audience,
          minAge: ageMinimum.years,
          origin: DeckOrigin.official,
          isPremium: const Value(false),
        ),
      );

  var index = 0;
  for (final entree in {
    Difficulty.easy: facile,
    Difficulty.medium: moyen,
    Difficulty.hard: difficile,
  }.entries) {
    for (var i = 0; i < entree.value; i++, index++) {
      await db
          .into(db.cards)
          .insert(
            CardsCompanion.insert(
              id: '$id:$index',
              deckId: id,
              cardText: '$id carte $index',
              audience: audience,
              difficulty: entree.key.value,
              origin: DeckOrigin.official,
            ),
          );
    }
  }
}
