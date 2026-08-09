import 'dart:convert';

import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/repositories/deck_repository.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fabrique un JSON de deck minimal, pour ne pas remonter tout le format à la
/// main dans chaque test.
String deckJson({
  String id = 'animaux',
  int contentVersion = 1,
  List<String> cards = const ['Éléphant', 'Girafe'],
}) {
  return jsonEncode({
    'id': id,
    'name': 'Animaux',
    'audience': 'family',
    'minAge': 6,
    'contentVersion': contentVersion,
    'cards': [
      for (final text in cards) {'text': text, 'difficulty': 1},
    ],
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  DeckSeeder seederFor(Map<String, String> assets) => DeckSeeder(
    database: db,
    loadAsset: (key) async => assets[key]!,
    listAssets: () async => assets.keys.toList(),
  );

  test('insère un deck absent avec toutes ses cartes', () async {
    final report = await seederFor({
      'assets/decks/animaux.json': deckJson(),
    }).run();

    expect(report.inserted, 1);
    expect(report.cardsWritten, 2);

    final decks = await DeckRepository(db).byMode(Audience.family);
    expect(decks.single.id, 'animaux');
    expect(await DeckRepository(db).cardsOfDeck('animaux'), hasLength(2));
  });

  test('ignore un deck dont la version en base est déjà à jour', () async {
    final assets = {'assets/decks/animaux.json': deckJson()};
    await seederFor(assets).run();

    final report = await seederFor(assets).run();

    expect(report.skipped, 1);
    expect(report.inserted, 0);
    expect(report.updated, 0);
  });

  test('met à jour sur contentVersion supérieure', () async {
    await seederFor({'assets/decks/animaux.json': deckJson()}).run();

    final report = await seederFor({
      'assets/decks/animaux.json': deckJson(
        contentVersion: 2,
        cards: ['Éléphant', 'Girafe', 'Pingouin'],
      ),
    }).run();

    expect(report.updated, 1);
    expect(await DeckRepository(db).cardsOfDeck('animaux'), hasLength(3));
  });

  test('supprime les cartes officielles disparues du JSON', () async {
    await seederFor({'assets/decks/animaux.json': deckJson()}).run();

    final report = await seederFor({
      'assets/decks/animaux.json': deckJson(
        contentVersion: 2,
        cards: ['Éléphant'],
      ),
    }).run();

    expect(report.cardsRemoved, 1);
    expect(await DeckRepository(db).cardsOfDeck('animaux'), hasLength(1));
  });

  test('ne touche jamais aux cartes custom du joueur', () async {
    await seederFor({'assets/decks/animaux.json': deckJson()}).run();

    // Une carte que le joueur a ajoutée dans une catégorie officielle.
    await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            id: 'animaux:mon-chat',
            deckId: 'animaux',
            cardText: 'Mon chat',
            audience: Audience.family,
            difficulty: 1,
            origin: DeckOrigin.custom,
          ),
        );

    // Un re-seed qui vide presque tout le deck officiel.
    await seederFor({
      'assets/decks/animaux.json': deckJson(
        contentVersion: 2,
        cards: ['Éléphant'],
      ),
    }).run();

    final remaining = await DeckRepository(db).cardsOfDeck('animaux');
    expect(
      remaining.map((c) => c.id),
      contains('animaux:mon-chat'),
      reason: 'Le contenu du joueur ne doit jamais être perdu par un re-seed',
    );
  });

  test('les identifiants de carte sont stables entre deux versions', () async {
    await seederFor({'assets/decks/animaux.json': deckJson()}).run();
    final before = (await DeckRepository(
      db,
    ).cardsOfDeck('animaux')).map((c) => c.id).toSet();

    await seederFor({
      'assets/decks/animaux.json': deckJson(contentVersion: 2),
    }).run();
    final after = (await DeckRepository(
      db,
    ).cardsOfDeck('animaux')).map((c) => c.id).toSet();

    expect(after, before);
  });
}
