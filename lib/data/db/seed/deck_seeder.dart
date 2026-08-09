import 'dart:convert';

import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/slug.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:drift/drift.dart';

/// Charge le contenu d'un fichier de `assets/decks/`.
typedef DeckAssetLoader = Future<String> Function(String assetKey);

/// Énumère les fichiers de decks disponibles.
typedef DeckAssetLister = Future<List<String>> Function();

/// Résultat d'un passage de seeding, pour l'affichage et les tests.
class SeedReport {
  const SeedReport({
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
    this.cardsWritten = 0,
    this.cardsRemoved = 0,
  });

  final int inserted;
  final int updated;
  final int skipped;
  final int cardsWritten;
  final int cardsRemoved;

  bool get didNothing => inserted == 0 && updated == 0;

  @override
  String toString() =>
      'SeedReport(inserted: $inserted, updated: $updated, skipped: $skipped, '
      'cardsWritten: $cardsWritten, cardsRemoved: $cardsRemoved)';
}

/// Alimente la base à partir des JSON livrés dans `assets/decks/`.
///
/// Les JSON sont un **format de livraison**, pas une source de lecture à
/// l'exécution : une fois seedés, tout passe par la base.
///
/// Les lignes `origin = custom` ne sont jamais touchées, quoi qu'il arrive —
/// c'est le contenu du joueur, et le perdre serait irréparable.
class DeckSeeder {
  DeckSeeder({
    required this.database,
    required this.loadAsset,
    required this.listAssets,
  });

  final AppDatabase database;
  final DeckAssetLoader loadAsset;
  final DeckAssetLister listAssets;

  Future<SeedReport> run() async {
    final assetKeys = await listAssets();

    var inserted = 0;
    var updated = 0;
    var skipped = 0;
    var cardsWritten = 0;
    var cardsRemoved = 0;

    for (final key in assetKeys) {
      final raw = await loadAsset(key);
      final json = jsonDecode(raw) as Map<String, dynamic>;

      final deckId = json['id'] as String;
      final version = (json['contentVersion'] as num?)?.toInt() ?? 1;

      final existing = await (database.select(
        database.decks,
      )..where((d) => d.id.equals(deckId))).getSingleOrNull();

      if (existing != null && existing.contentVersion >= version) {
        skipped++;
        continue;
      }

      final counts = await _writeDeck(json, deckId, version);
      cardsWritten += counts.$1;
      cardsRemoved += counts.$2;

      if (existing == null) {
        inserted++;
      } else {
        updated++;
      }
    }

    return SeedReport(
      inserted: inserted,
      updated: updated,
      skipped: skipped,
      cardsWritten: cardsWritten,
      cardsRemoved: cardsRemoved,
    );
  }

  /// Écrit un deck et ses cartes. Renvoie (cartes écrites, cartes supprimées).
  Future<(int, int)> _writeDeck(
    Map<String, dynamic> json,
    String deckId,
    int version,
  ) async {
    final deckAudience = Audience.values.byName(json['audience'] as String);

    return database.transaction(() async {
      await database
          .into(database.decks)
          .insertOnConflictUpdate(
            DecksCompanion.insert(
              id: deckId,
              name: json['name'] as String,
              audience: deckAudience,
              minAge: MinAge.fromYears((json['minAge'] as num).toInt()).years,
              origin: DeckOrigin.official,
              description: Value(json['description'] as String?),
              icon: Value(json['icon'] as String?),
              contentVersion: Value(version),
              isPremium: Value(json['isPremium'] as bool? ?? false),
              sortOrder: Value((json['sortOrder'] as num?)?.toInt() ?? 0),
            ),
          );

      final cards = (json['cards'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final seenIds = <String>{};

      for (final card in cards) {
        final text = card['text'] as String;
        final id = '$deckId:${slugify(text)}';
        seenIds.add(id);

        await database
            .into(database.cards)
            .insertOnConflictUpdate(
              CardsCompanion.insert(
                id: id,
                deckId: deckId,
                cardText: text,
                audience: card['audience'] != null
                    ? Audience.values.byName(card['audience'] as String)
                    : deckAudience,
                difficulty: (card['difficulty'] as num?)?.toInt() ?? 2,
                taboo: Value(
                  jsonEncode(
                    (card['taboo'] as List<dynamic>? ?? const <dynamic>[])
                        .cast<String>(),
                  ),
                ),
                origin: DeckOrigin.official,
              ),
            );
      }

      // Cartes officielles disparues du JSON. Le filtre sur origin est ce qui
      // protège le contenu du joueur.
      final removed =
          await (database.delete(database.cards)..where(
                (c) =>
                    c.deckId.equals(deckId) &
                    c.origin.equalsValue(DeckOrigin.official) &
                    c.id.isNotIn(seenIds),
              ))
              .go();

      return (cards.length, removed);
    });
  }
}
