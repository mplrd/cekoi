import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/tables/saved_games.dart';
import 'package:cekoi/data/repositories/game_repository.dart';
import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
// `drift` exporte ses propres `isNull` / `isNotNull`, qui sont des conditions
// SQL et non des matchers : sans préfixe, elles masquent celles de `matcher`.
import 'package:drift/drift.dart' show Migrator, Value;
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

final DateTime _now = DateTime.utc(2026, 8, 10, 14);

void main() {
  late AppDatabase db;
  late GameRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = GameRepository(db);
  });
  tearDown(() => db.close());

  group('R9.1 — la partie en cours survit à la fermeture', () {
    test('sans partie sauvegardée, il n’y a rien à reprendre', () async {
      expect(await repository.load(), isNull);
    });

    test('une partie sauvegardée se relit à l’identique', () async {
      final game = testGame(cardCount: 12).copyWith(
        phase: GamePhase.playing,
        roundIndex: 1,
        activeTeamIndex: 1,
      );

      await repository.save(game, savedAt: _now);
      final saved = await repository.load();

      expect(saved, isNotNull);
      expect(saved!.game, game);
      expect(
        saved.savedAt.isAtSameMomentAs(_now),
        isTrue,
        reason:
            'SQLite rend la date en heure locale : c’est l’instant qui doit '
            'être conservé, pas le fuseau — R9.2 compte des heures écoulées',
      );
    });

    test('sauvegarder deux fois ne garde que la dernière', () async {
      // Une partie à la fois : empiler les sauvegardes obligerait à choisir
      // laquelle proposer, et à les purger un jour.
      await repository.save(testGame(), savedAt: _now);
      await repository.save(
        testGame(cardCount: 20),
        savedAt: _now.add(const Duration(minutes: 5)),
      );

      expect(await db.select(db.savedGames).get(), hasLength(1));
      expect((await repository.load())!.game.deck, hasLength(20));
    });

    test('effacer laisse la base sans partie à reprendre', () async {
      await repository.save(testGame(), savedAt: _now);

      await repository.clear();

      expect(await repository.load(), isNull);
    });
  });

  group('une sauvegarde illisible ne bloque pas le démarrage', () {
    test('elle est ignorée, et la ligne est nettoyée', () async {
      // Le cas réel : une partie écrite par une version antérieure du moteur.
      // Perdre une partie abandonnée est ennuyeux ; empêcher l'application de
      // s'ouvrir l'est beaucoup plus.
      await db
          .into(db.savedGames)
          .insert(
            SavedGamesCompanion.insert(
              id: const Value(SavedGames.singleRowId),
              payload: '{"ceci":"n est pas une partie"}',
              savedAt: _now,
            ),
          );

      expect(await repository.load(), isNull);
      expect(
        await db.select(db.savedGames).get(),
        isEmpty,
        reason: 'Une ligne illisible ne doit pas être reproposée à chaque fois',
      );
    });
  });

  /// Insère une catégorie et une carte écrites par le joueur.
  ///
  /// C'est le contrat des migrations : les lignes `origin = 'custom'` sont du
  /// contenu que le joueur a saisi, et qu'aucune migration n'a le droit de
  /// perdre. Le seeding, lui, ne recrée que l'officiel.
  Future<void> insertCustomContent() async {
    await db
        .into(db.decks)
        .insert(
          DecksCompanion.insert(
            id: 'la-mienne',
            name: 'La mienne',
            audience: Audience.family,
            minAge: 6,
            origin: DeckOrigin.custom,
          ),
        );
    await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            id: 'la-mienne:tonton',
            deckId: 'la-mienne',
            cardText: 'Tonton Bernard',
            audience: Audience.family,
            difficulty: 2,
            origin: DeckOrigin.custom,
          ),
        );
  }

  group('migration de la v1 vers la v2', () {
    /// Redescend la base en v1 avant de migrer.
    ///
    /// `AppDatabase.memory()` déclenche `onCreate`, qui crée **toutes** les
    /// tables au schéma courant, `saved_games` comprise. Migrer par-dessus ne
    /// prouverait rien : `createTable` émet `CREATE TABLE IF NOT EXISTS`, donc
    /// l'appel serait un no-op silencieux et vider le corps de la migration
    /// laisserait le test vert — alors qu'en production, tout appareil mis à
    /// jour depuis la v1 publiée n'aurait pas la table et **chaque
    /// sauvegarde échouerait**.
    Future<void> downgradeToV1() =>
        db.customStatement('DROP TABLE saved_games');

    test('le contenu écrit par le joueur survit', () async {
      await insertCustomContent();

      await downgradeToV1();
      await db.migration.onUpgrade(Migrator(db), 1, 2);

      final decks = await db.select(db.decks).get();
      final cards = await db.select(db.cards).get();
      expect(decks.single.id, 'la-mienne');
      expect(cards.single.cardText, 'Tonton Bernard');
    });

    test('la table de sauvegarde est utilisable après migration', () async {
      await downgradeToV1();
      await db.migration.onUpgrade(Migrator(db), 1, 2);

      await repository.save(testGame(), savedAt: _now);

      expect(await repository.load(), isNotNull);
    });
  });

  group('migration de la v2 vers la v3', () {
    /// Redescend la table des cartes en v2, colonne `taboo` comprise.
    ///
    /// Même piège qu'en v1 : la base de test naît au schéma courant, donc
    /// migrer par-dessus ne prouverait rien. Ici c'est pire qu'un no-op — la
    /// migration recrée la table et recopie les lignes, et un test qui part
    /// d'une table déjà sans la colonne ne verrait jamais si la recopie perd
    /// des données.
    Future<void> downgradeToV2() async {
      await db.customStatement('DROP TABLE cards');
      await db.customStatement('''
        CREATE TABLE cards (
          id TEXT NOT NULL PRIMARY KEY,
          deck_id TEXT NOT NULL REFERENCES decks (id) ON DELETE CASCADE,
          text TEXT NOT NULL,
          audience TEXT NOT NULL,
          difficulty INTEGER NOT NULL,
          taboo TEXT NOT NULL DEFAULT '[]',
          origin TEXT NOT NULL
        )
      ''');
    }

    test(
      'les cartes du joueur survivent à la suppression de la colonne',
      () async {
        await db
            .into(db.decks)
            .insert(
              DecksCompanion.insert(
                id: 'la-mienne',
                name: 'La mienne',
                audience: Audience.family,
                minAge: 6,
                origin: DeckOrigin.custom,
              ),
            );
        await downgradeToV2();
        await db.customStatement(
          "INSERT INTO cards VALUES ('la-mienne:tonton', 'la-mienne', "
          "'Tonton Bernard', 'family', 2, '[\"moustache\"]', 'custom')",
        );

        await db.migration.onUpgrade(Migrator(db), 2, 3);

        final cards = await db.select(db.cards).get();
        expect(cards, hasLength(1));
        expect(cards.single.cardText, 'Tonton Bernard');
        expect(cards.single.origin, DeckOrigin.custom);
      },
    );

    test('la colonne des mots interdits a bien disparu', () async {
      await downgradeToV2();

      await db.migration.onUpgrade(Migrator(db), 2, 3);

      final colonnes = await db.customSelect('PRAGMA table_info(cards)').get();
      expect(
        colonnes.map((r) => r.data['name']),
        isNot(contains('taboo')),
        reason:
            'Laisser la colonne ferait diverger le schéma des installations '
            'neuves de celui des installations migrées',
      );
    });
  });
}
