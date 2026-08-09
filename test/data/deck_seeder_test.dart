import 'dart:convert';

import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/repositories/deck_repository.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fabrique un JSON de deck, pour ne pas remonter tout le format à la main.
String deckJson({
  String id = 'animaux',
  String name = 'Animaux',
  String audience = 'family',
  int minAge = 6,
  int contentVersion = 1,
  List<Map<String, Object?>> cards = const [
    {'text': 'Éléphant', 'difficulty': 1},
    {'text': 'Girafe', 'difficulty': 1},
  ],
}) {
  return jsonEncode({
    'id': id,
    'name': name,
    'audience': audience,
    'minAge': minAge,
    'contentVersion': contentVersion,
    'cards': cards,
  });
}

void main() {
  late AppDatabase db;
  late DeckRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = DeckRepository(db);
  });
  tearDown(() => db.close());

  DeckSeeder seederFor(Map<String, String> assets) => DeckSeeder(
    database: db,
    loadAsset: (key) async => assets[key]!,
    listAssets: () async => assets.keys.toList(),
  );

  Future<SeedReport> seed(String json) =>
      seederFor({'assets/decks/animaux.json': json}).run();

  /// Relit une carte par son identifiant, pour asserter sur son contenu réel
  /// et pas seulement sur la présence de l'id.
  Future<CardRow?> cardById(String id) => (db.select(
    db.cards,
  )..where((c) => c.id.equals(id))).getSingleOrNull();

  group('cycle de vie du contenu officiel', () {
    test('insère un deck absent avec toutes ses cartes', () async {
      final report = await seed(deckJson());

      expect(report.inserted, 1);
      expect(report.cardsWritten, 2);
      expect(report.hasProblems, isFalse);

      final decks = await repo.byMode(Audience.family);
      expect(decks.single.id, 'animaux');
      expect(await repo.cardsOfDeck('animaux'), hasLength(2));
    });

    test('ignore un deck dont la version en base est déjà à jour', () async {
      await seed(deckJson());
      final report = await seed(deckJson());

      expect(report.skipped, 1);
      expect(report.inserted, 0);
      expect(report.updated, 0);
    });

    test('met à jour sur contentVersion supérieure', () async {
      await seed(deckJson());

      final report = await seed(
        deckJson(
          contentVersion: 2,
          cards: const [
            {'text': 'Éléphant', 'difficulty': 1},
            {'text': 'Girafe', 'difficulty': 1},
            {'text': 'Pingouin', 'difficulty': 2},
          ],
        ),
      );

      expect(report.updated, 1);
      expect(await repo.cardsOfDeck('animaux'), hasLength(3));
    });

    test('supprime les cartes officielles disparues du JSON', () async {
      await seed(deckJson());

      final report = await seed(
        deckJson(
          contentVersion: 2,
          cards: const [
            {'text': 'Éléphant', 'difficulty': 1},
          ],
        ),
      );

      expect(report.cardsRemoved, 1);
      expect(await repo.cardsOfDeck('animaux'), hasLength(1));
    });
  });

  group('protection du contenu du joueur', () {
    /// Insère une carte custom, telle que le joueur en créera au lot 6.
    Future<void> insertCustomCard({
      required String id,
      required String text,
      Difficulty difficulty = Difficulty.hard,
    }) async {
      await db
          .into(db.cards)
          .insert(
            CardsCompanion.insert(
              id: id,
              deckId: 'animaux',
              cardText: text,
              audience: Audience.family,
              difficulty: difficulty.value,
              origin: DeckOrigin.custom,
            ),
          );
    }

    test('une carte custom sans collision survit à un re-seed', () async {
      await seed(deckJson());
      await insertCustomCard(id: 'animaux:mon-chat', text: 'Mon chat');

      await seed(
        deckJson(
          contentVersion: 2,
          cards: const [
            {'text': 'Éléphant', 'difficulty': 1},
          ],
        ),
      );

      final card = await cardById('animaux:mon-chat');
      expect(card, isNotNull);
      expect(card!.cardText, 'Mon chat');
      expect(card.origin, DeckOrigin.custom);
    });

    test(
      "une carte custom dont l'id entre en collision n'est pas écrasée",
      () async {
        await seed(deckJson());

        // Le joueur écrit sa propre version d'une carte officielle : le slug
        // est identique, donc l'identifiant aussi. C'est le seul chemin par
        // lequel le contenu du joueur peut être détruit.
        await db.delete(db.cards).go();
        await insertCustomCard(
          id: 'animaux:elephant',
          text: 'Éléphant (ma version)',
        );

        await seed(deckJson(contentVersion: 2));

        final card = await cardById('animaux:elephant');
        expect(card, isNotNull);
        expect(
          card!.cardText,
          'Éléphant (ma version)',
          reason: 'Le texte du joueur a été écrasé par le contenu officiel',
        );
        expect(
          card.origin,
          DeckOrigin.custom,
          reason:
              'La carte du joueur a été convertie en carte officielle, '
              'elle deviendrait supprimable au re-seed suivant',
        );
        expect(card.difficulty, Difficulty.hard.value);
      },
    );

    test(
      'une carte officielle bloquée par le joueur est signalée et non comptée',
      () async {
        await seed(deckJson());
        await db.delete(db.cards).go();
        await insertCustomCard(
          id: 'animaux:elephant',
          text: 'Éléphant (ma version)',
        );

        final report = await seed(deckJson(contentVersion: 2));

        expect(
          report.protectedCards,
          contains('animaux:elephant'),
          reason:
              'Sans trace, la carte officielle disparaît pour toujours : '
              'le bump de contentVersion empêche tout re-seed de la retenter',
        );
        expect(
          report.cardsWritten,
          1,
          reason: 'cardsWritten ne doit pas compter une écriture abandonnée',
        );
        expect(report.hasProblems, isTrue);
      },
    );

    test('un deck custom en collision est protégé et signalé', () async {
      await db
          .into(db.decks)
          .insert(
            DecksCompanion.insert(
              id: 'animaux',
              name: 'Mes animaux à moi',
              audience: Audience.adult,
              minAge: MinAge.eighteen.years,
              origin: DeckOrigin.custom,
            ),
          );

      final report = await seed(deckJson(contentVersion: 2));

      expect(report.protectedDecks, contains('animaux'));
      expect(report.inserted, 0);
      expect(report.updated, 0);

      final deck = (await repo.byMode(Audience.adult)).single;
      expect(deck.name, 'Mes animaux à moi');
      expect(
        deck.origin,
        DeckOrigin.custom,
        reason:
            'Un deck 18+ du joueur basculé en officiel serait tiré en '
            'mode Famille',
      );
      expect(deck.minAge, MinAge.eighteen);
    });
  });

  group('stabilité des identifiants', () {
    test('un id explicite survit à la correction du texte', () async {
      await seed(
        deckJson(
          cards: const [
            {'id': 'animaux:elephant', 'text': 'Elefant', 'difficulty': 1},
          ],
        ),
      );

      // Correction de la faute de frappe, identifiant conservé.
      await seed(
        deckJson(
          contentVersion: 2,
          cards: const [
            {'id': 'animaux:elephant', 'text': 'Éléphant', 'difficulty': 1},
          ],
        ),
      );

      final card = await cardById('animaux:elephant');
      expect(card, isNotNull);
      expect(card!.cardText, 'Éléphant');
      expect(await repo.cardsOfDeck('animaux'), hasLength(1));
    });

    test(
      "sans id explicite, corriger le texte change l'identité de la carte",
      () async {
        // Comportement connu et assumé : le slug dérive du texte. C'est
        // précisément pour ça que le champ `id` existe. Ce test documente la
        // limite plutôt que de la laisser surprendre quelqu'un plus tard.
        await seed(
          deckJson(
            cards: const [
              {'text': 'Elefant', 'difficulty': 1},
            ],
          ),
        );

        await seed(
          deckJson(
            contentVersion: 2,
            cards: const [
              {'text': 'Éléphant', 'difficulty': 1},
            ],
          ),
        );

        expect(await cardById('animaux:elefant'), isNull);
        expect(await cardById('animaux:elephant'), isNotNull);
      },
    );
  });

  group('robustesse des fichiers livrés', () {
    test(
      "un JSON malformé n'empêche pas les autres decks de se seeder",
      () async {
        final report = await seederFor({
          'assets/decks/casse.json': '{ ceci n est pas du JSON',
          'assets/decks/animaux.json': deckJson(),
        }).run();

        expect(report.failures, hasLength(1));
        expect(report.failures.single.assetKey, 'assets/decks/casse.json');
        expect(
          report.inserted,
          1,
          reason: 'Le deck valide doit être installé malgré le fichier cassé',
        );
        expect(await repo.cardsOfDeck('animaux'), hasLength(2));
      },
    );

    test('un deck sans id est signalé sans interrompre le seeding', () async {
      final report = await seederFor({
        'assets/decks/sans-id.json': jsonEncode({'name': 'Orphelin'}),
        'assets/decks/animaux.json': deckJson(),
      }).run();

      expect(report.failures, hasLength(1));
      expect(report.inserted, 1);
    });

    test('une difficulté hors bornes fait échouer ce deck seulement', () async {
      final report = await seederFor({
        'assets/decks/animaux.json': deckJson(
          cards: const [
            {'text': 'Éléphant', 'difficulty': 9},
          ],
        ),
      }).run();

      expect(report.failures, hasLength(1));
      expect(report.inserted, 0);
    });

    test('les textes en doublon sont fusionnés et signalés', () async {
      final report = await seed(
        deckJson(
          cards: const [
            {'text': 'Éléphant', 'difficulty': 1},
            {'text': 'éléphant', 'difficulty': 2},
            {'text': 'Girafe', 'difficulty': 1},
          ],
        ),
      );

      expect(report.duplicateTexts, hasLength(1));
      expect(
        report.cardsWritten,
        2,
        reason:
            'cardsWritten doit compter les lignes écrites, pas les entrées '
            'du JSON — sinon il masque le doublon',
      );
      expect(await repo.cardsOfDeck('animaux'), hasLength(2));
    });
  });
}
