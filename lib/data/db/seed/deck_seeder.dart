import 'dart:convert';

import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/slug.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:drift/drift.dart';

/// Charge le contenu d'un fichier de `assets/decks/`.
typedef DeckAssetLoader = Future<String> Function(String assetKey);

/// Énumère les fichiers de decks disponibles.
typedef DeckAssetLister = Future<List<String>> Function();

/// Un deck qui n'a pas pu être seedé, et pourquoi.
class SeedFailure {
  const SeedFailure(this.assetKey, this.reason);

  final String assetKey;
  final String reason;

  @override
  String toString() => '$assetKey : $reason';
}

/// Résultat d'un passage de seeding.
class SeedReport {
  const SeedReport({
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
    this.cardsWritten = 0,
    this.cardsRemoved = 0,
    this.protectedDecks = const [],
    this.protectedCards = const [],
    this.duplicateTexts = const [],
    this.failures = const [],
  });

  final int inserted;
  final int updated;
  final int skipped;

  /// Lignes réellement écrites — hors doublons fusionnés et hors cartes
  /// bloquées par le joueur. Compter les entrées du JSON masquerait exactement
  /// les deux cas où une écriture est abandonnée.
  final int cardsWritten;
  final int cardsRemoved;

  /// Decks du JSON dont l'identifiant est déjà pris par du contenu créé par le
  /// joueur. On ne les écrase pas : on les signale.
  final List<String> protectedDecks;

  /// Cartes officielles qu'on n'a pas pu écrire parce que le joueur occupe déjà
  /// leur identifiant. Sans cette liste, la carte serait simplement absente du
  /// deck, et le bump de `contentVersion` empêcherait tout re-seed de la
  /// retenter : une disparition définitive et silencieuse.
  final List<String> protectedCards;

  /// Textes apparaissant plusieurs fois dans un même JSON. Ils collapsent sur
  /// un seul identifiant, ce qui rétrécit silencieusement le paquet.
  final List<String> duplicateTexts;

  /// Decks qu'on n'a pas pu lire. Les autres sont seedés quand même.
  final List<SeedFailure> failures;

  bool get hasProblems =>
      failures.isNotEmpty ||
      duplicateTexts.isNotEmpty ||
      protectedDecks.isNotEmpty ||
      protectedCards.isNotEmpty;

  @override
  String toString() =>
      'SeedReport(inserted: $inserted, updated: $updated, skipped: $skipped, '
      'cardsWritten: $cardsWritten, cardsRemoved: $cardsRemoved, '
      'protectedDecks: $protectedDecks, protectedCards: $protectedCards, '
      'duplicateTexts: $duplicateTexts, failures: $failures)';
}

/// Alimente la base à partir des JSON livrés dans `assets/decks/`.
///
/// Les JSON sont un **format de livraison**, pas une source de lecture à
/// l'exécution : une fois seedés, tout passe par la base.
///
/// Deux invariants, tenus par le code et pas seulement par la convention :
///
/// - **Aucune ligne `origin = custom` n'est jamais écrasée ni supprimée.** Le
///   contenu du joueur n'existe nulle part ailleurs, le perdre est
///   irréparable. Les écritures portent une clause qui limite l'`ON CONFLICT`
///   aux lignes officielles.
/// - **Un deck illisible n'emporte pas les autres.** Chaque fichier est isolé :
///   un JSON malformé est signalé dans le rapport, les decks valides
///   s'installent quand même.
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
    final protectedDecks = <String>[];
    final protectedCards = <String>[];
    final duplicateTexts = <String>[];
    final failures = <SeedFailure>[];

    for (final key in assetKeys) {
      try {
        final raw = await loadAsset(key);
        final json = jsonDecode(raw) as Map<String, dynamic>;

        final deckId = json['id'] as String?;
        if (deckId == null || deckId.isEmpty) {
          failures.add(SeedFailure(key, 'champ « id » absent ou vide'));
          continue;
        }

        final version = (json['contentVersion'] as num?)?.toInt() ?? 1;

        final existing = await (database.select(
          database.decks,
        )..where((d) => d.id.equals(deckId))).getSingleOrNull();

        // Un deck créé par le joueur porte le même identifiant : on n'y touche
        // pas. Le contenu officiel manquera, c'est infiniment préférable à
        // écraser une catégorie que le joueur a écrite.
        if (existing != null && existing.origin == DeckOrigin.custom) {
          protectedDecks.add(deckId);
          continue;
        }

        if (existing != null && existing.contentVersion >= version) {
          skipped++;
          continue;
        }

        final outcome = await _writeDeck(json, deckId, version);
        cardsWritten += outcome.written;
        cardsRemoved += outcome.removed;
        duplicateTexts.addAll(outcome.duplicates);
        protectedCards.addAll(outcome.protectedCards);

        if (existing == null) {
          inserted++;
        } else {
          updated++;
        }
      } on Object catch (error) {
        // Volontairement large : un JSON livré peut échouer de mille façons, et
        // aucune ne justifie de priver le joueur des autres catégories.
        failures.add(SeedFailure(key, error.toString()));
      }
    }

    return SeedReport(
      inserted: inserted,
      updated: updated,
      skipped: skipped,
      cardsWritten: cardsWritten,
      cardsRemoved: cardsRemoved,
      protectedDecks: protectedDecks,
      protectedCards: protectedCards,
      duplicateTexts: duplicateTexts,
      failures: failures,
    );
  }

  Future<_DeckOutcome> _writeDeck(
    Map<String, dynamic> json,
    String deckId,
    int version,
  ) async {
    final deckAudience = Audience.values.byName(json['audience'] as String);

    return database.transaction(() async {
      final deckRow = DecksCompanion.insert(
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
      );

      await database
          .into(database.decks)
          .insert(
            deckRow,
            onConflict: DoUpdate<$DecksTable, DeckRow>(
              (_) => deckRow,
              // Défense en profondeur, volontairement redondante : `run()`
              // écarte déjà les decks custom en amont, donc cette clause n'est
              // atteignable par aucun test. Elle reste parce qu'elle protège si
              // la garde amont disparaît un jour dans un refactor.
              where: (old) => old.origin.equalsValue(DeckOrigin.official),
            ),
          );

      final cards = (json['cards'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      if (cards.isEmpty) {
        throw StateError('le deck ne contient aucune carte');
      }

      // Identifiants déjà occupés par du contenu du joueur dans ce deck. On les
      // relève d'avance : sans ça la carte officielle serait simplement absente
      // et rien ne le signalerait.
      final customIds =
          (await (database.select(
                    database.cards,
                  )..where(
                    (c) =>
                        c.deckId.equals(deckId) &
                        c.origin.equalsValue(DeckOrigin.custom),
                  ))
                  .get())
              .map((c) => c.id)
              .toSet();

      final seenIds = <String>{};
      final duplicates = <String>[];
      final protectedCards = <String>[];
      var written = 0;

      for (final card in cards) {
        final text = card['text'] as String;

        // L'identifiant explicite prime sur le slug. C'est ce qui permet de
        // corriger une faute de frappe sans changer l'identité de la carte :
        // sans lui, l'id dérivé du texte changerait et casserait le lien avec
        // les parties déjà jouées — exactement ce que l'id stable doit éviter.
        final id = (card['id'] as String?) ?? '$deckId:${slugify(text)}';

        if (!seenIds.add(id)) {
          duplicates.add(text);
          continue;
        }

        if (customIds.contains(id)) {
          protectedCards.add(id);
          continue;
        }

        final cardRow = CardsCompanion.insert(
          id: id,
          deckId: deckId,
          cardText: text,
          audience: card['audience'] != null
              ? Audience.values.byName(card['audience'] as String)
              : deckAudience,
          // Validé ici plutôt qu'à la lecture : une difficulté hors bornes doit
          // faire échouer le deck fautif, pas surgir au moment du tirage.
          difficulty: Difficulty.fromValue(
            (card['difficulty'] as num?)?.toInt() ?? 2,
          ).value,
          origin: DeckOrigin.official,
        );

        await database
            .into(database.cards)
            .insert(
              cardRow,
              onConflict: DoUpdate<$CardsTable, CardRow>(
                (_) => cardRow,
                where: (old) => old.origin.equalsValue(DeckOrigin.official),
              ),
            );

        written++;
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

      return _DeckOutcome(
        written: written,
        removed: removed,
        duplicates: duplicates,
        protectedCards: protectedCards,
      );
    });
  }
}

class _DeckOutcome {
  const _DeckOutcome({
    required this.written,
    required this.removed,
    required this.duplicates,
    required this.protectedCards,
  });

  final int written;
  final int removed;
  final List<String> duplicates;
  final List<String> protectedCards;
}
