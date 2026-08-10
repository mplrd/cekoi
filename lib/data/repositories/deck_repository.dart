import 'dart:convert';

import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:drift/drift.dart';

/// Accès aux catégories et aux cartes.
///
/// Unique porte d'entrée vers le contenu : officiel et custom sortent d'ici,
/// jamais de deux sources mergées à chaud.
class DeckRepository {
  const DeckRepository(this._db);

  final AppDatabase _db;

  /// Catégories tirables dans le mode donné (R7.1), triées pour l'affichage.
  Future<List<Deck>> byMode(Audience mode) async {
    final allowed = mode.drawableAudiences.toList();
    final rows =
        await (_db.select(_db.decks)
              ..where((d) => d.audience.isInValues(allowed))
              ..orderBy([
                (d) => OrderingTerm(expression: d.sortOrder),
                (d) => OrderingTerm(expression: d.name),
              ]))
            .get();

    return rows.map(_toDeck).toList();
  }

  /// Nombre de cartes disponibles par catégorie dans le mode donné.
  ///
  /// Compté en SQL : l'écran de sélection affiche ce nombre pour chaque
  /// catégorie, et charger les cartes pour les compter serait absurde.
  Future<Map<String, int>> cardCountsByDeck(Audience mode) async {
    final allowed = mode.drawableAudiences.toList();
    final count = _db.cards.id.count();

    final query = _db.selectOnly(_db.cards)
      ..addColumns([_db.cards.deckId, count])
      ..where(_db.cards.audience.isInValues(allowed))
      ..groupBy([_db.cards.deckId]);

    final rows = await query.get();
    return {
      for (final row in rows) row.read(_db.cards.deckId)!: row.read(count) ?? 0,
    };
  }

  /// Toutes les cartes tirables dans le mode donné (R7.1).
  ///
  /// Chargées d'un bloc parce que l'écran de sélection en a besoin pour
  /// évaluer la disponibilité de chaque profil (R7.8), et que cette évaluation
  /// doit passer par le même filtrage que le tirage — un décompte fait en SQL
  /// ne saurait pas dédoublonner les textes de R6.4.
  Future<List<domain.Card>> cardsForMode(Audience mode) async {
    final allowed = mode.drawableAudiences.toList();
    final rows = await (_db.select(
      _db.cards,
    )..where((c) => c.audience.isInValues(allowed))).get();
    return rows.map(_toCard).toList();
  }

  Future<List<domain.Card>> cardsOfDeck(String deckId) async {
    final rows = await (_db.select(
      _db.cards,
    )..where((c) => c.deckId.equals(deckId))).get();
    return rows.map(_toCard).toList();
  }

  Deck _toDeck(DeckRow row) => Deck(
    id: row.id,
    name: row.name,
    audience: row.audience,
    minAge: MinAge.fromYears(row.minAge),
    origin: row.origin,
    contentVersion: row.contentVersion,
    description: row.description,
    icon: row.icon,
    isPremium: row.isPremium,
    sortOrder: row.sortOrder,
  );

  domain.Card _toCard(CardRow row) => domain.Card(
    id: row.id,
    deckId: row.deckId,
    text: row.cardText,
    audience: row.audience,
    difficulty: Difficulty.fromValue(row.difficulty),
    origin: row.origin,
    taboo: (jsonDecode(row.taboo) as List<dynamic>).cast<String>(),
  );
}
