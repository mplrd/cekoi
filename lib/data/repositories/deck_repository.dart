import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/slug.dart';
import 'package:cekoi/domain/decks/card_length.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/domain/text/text_normalization.dart';
import 'package:drift/drift.dart';

/// Le refus opposé à une carte trop longue.
///
/// Ici et pas seulement dans le champ de saisie : l'import d'un fichier de
/// catégorie n'en passe pas par lui, et une borne qui ne vit que dans
/// l'interface n'est pas une borne.
const _tropLong =
    'Une carte fait au plus $maxCardTextLength caractères, '
    'sans quoi elle devient illisible à bout de bras';

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

  // --- Contenu écrit par le joueur (lot 6) -------------------------------
  //
  // Tout ce qui suit ne touche **que** les lignes `origin = custom`. Le
  // contenu officiel se gère par le seeding : le modifier d'ici le ferait
  // revenir au prochain lancement, en laissant croire à un bug.

  /// Les catégories du joueur, les plus récentes d'abord.
  Future<List<Deck>> customDecks() async {
    final rows =
        await (_db.select(_db.decks)
              ..where((d) => d.origin.equalsValue(DeckOrigin.custom))
              ..orderBy([
                (d) => OrderingTerm(
                  expression: d.sortOrder,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return rows.map(_toDeck).toList();
  }

  /// Crée une catégorie et rend ce qui a été écrit.
  ///
  /// L'identifiant est préfixé `custom-` : le seeder écrit par identifiant, et
  /// une catégorie du joueur nommée comme une officielle ferait de l'une
  /// l'ombre de l'autre. Le préfixe garantit deux espaces de noms disjoints.
  Future<Deck> createCustomDeck({
    required String name,
    required Audience audience,
  }) async {
    final propre = name.trim();
    if (propre.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Le nom ne peut pas être vide');
    }

    final id = await _freeCustomId(propre);

    // `sortOrder` porte l'ordre d'arrivée : les catégories du joueur n'ont pas
    // d'ordre éditorial, et la dernière écrite est celle qu'il cherche.
    final rang = await _nextCustomSortOrder();

    await _db
        .into(_db.decks)
        .insert(
          DecksCompanion.insert(
            id: id,
            name: propre,
            audience: audience,
            minAge: MinAge.six.years,
            origin: DeckOrigin.custom,
            sortOrder: Value(rang),
          ),
        );

    return (await customDecks()).firstWhere((d) => d.id == id);
  }

  Future<void> renameCustomDeck(String deckId, String name) async {
    final propre = name.trim();
    if (propre.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Le nom ne peut pas être vide');
    }
    await _requireCustomDeck(deckId);

    // L'identifiant ne suit pas le nom : le faire changer orphelinerait les
    // cartes et casserait une partie en cours qui référence la catégorie.
    await (_db.update(_db.decks)..where((d) => d.id.equals(deckId))).write(
      DecksCompanion(name: Value(propre)),
    );
  }

  /// Supprime une catégorie **et ses cartes**, par la cascade de la clé
  /// étrangère.
  Future<void> deleteCustomDeck(String deckId) async {
    await _requireCustomDeck(deckId);
    await (_db.delete(_db.decks)..where((d) => d.id.equals(deckId))).go();
  }

  /// Vrai si la catégorie contient déjà cette carte, au sens de R6.4.
  ///
  /// Exposé pour que l'écran de saisie puisse refuser sans provoquer une
  /// exception : ajouter deux fois la même carte est une maladresse de saisie
  /// quotidienne, pas une situation exceptionnelle.
  Future<bool> customDeckContains(String deckId, String text) async {
    final cle = normalizeCardText(text.trim());
    final existantes = await cardsOfDeck(deckId);
    return existantes.any((c) => c.normalizedText == cle);
  }

  /// Ajoute une carte à une catégorie du joueur.
  ///
  /// Le public est hérité de la catégorie : une carte d'une catégorie adultes
  /// n'a aucune raison d'être tout public, et le demander à chaque saisie
  /// transformerait la création en corvée.
  Future<domain.Card> addCustomCard({
    required String deckId,
    required String text,
    Difficulty difficulty = Difficulty.medium,
  }) async {
    final deck = await _requireCustomDeck(deckId);
    final propre = text.trim();
    if (propre.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Le texte ne peut pas être vide');
    }
    if (!cardTextFits(propre)) {
      throw ArgumentError.value(text, 'text', _tropLong);
    }

    // R6.4 dans une seule catégorie : le tirage n'en garderait qu'une, et le
    // compteur affiché mentirait. Entre deux catégories, en revanche, le
    // recoupement est légitime et le tirage s'en charge.
    final existantes = await cardsOfDeck(deckId);
    final cle = normalizeCardText(propre);
    if (existantes.any((c) => c.normalizedText == cle)) {
      throw ArgumentError.value(
        text,
        'text',
        'Cette carte est déjà dans la catégorie',
      );
    }

    final id = _freeCardId(deckId, propre, existantes);
    await _db
        .into(_db.cards)
        .insert(
          CardsCompanion.insert(
            id: id,
            deckId: deckId,
            cardText: propre,
            audience: deck.audience,
            difficulty: difficulty.value,
            origin: DeckOrigin.custom,
          ),
        );

    return (await cardsOfDeck(deckId)).firstWhere((c) => c.id == id);
  }

  /// Corrige une carte **sans changer son identifiant**.
  ///
  /// Une faute de frappe corrigée ne doit pas faire disparaître la carte d'une
  /// partie en cours, qui la référence par identifiant.
  Future<void> updateCustomCard(
    String cardId, {
    String? text,
    Difficulty? difficulty,
  }) async {
    final avant = await _requireCustomCard(cardId);

    final propre = text?.trim();
    if (text != null && (propre?.isEmpty ?? true)) {
      throw ArgumentError.value(text, 'text', 'Le texte ne peut pas être vide');
    }
    // On refuse d'aggraver, pas de conserver.
    //
    // Une carte saisie avant que la borne existe peut dépasser. La refuser
    // telle quelle la **gèlerait** : la boîte de correction renvoie toujours
    // le texte, donc changer son seul niveau lèverait, et le joueur n'aurait
    // aucun moyen de la reclasser ni même de comprendre pourquoi. Seul un
    // texte qui change doit tenir dans la borne.
    if (propre != null && propre != avant.cardText && !cardTextFits(propre)) {
      throw ArgumentError.value(text, 'text', _tropLong);
    }

    await (_db.update(_db.cards)..where((c) => c.id.equals(cardId))).write(
      CardsCompanion(
        cardText: propre == null ? const Value.absent() : Value(propre),
        difficulty: difficulty == null
            ? const Value.absent()
            : Value(difficulty.value),
      ),
    );
  }

  Future<void> deleteCustomCard(String cardId) async {
    await _requireCustomCard(cardId);
    await (_db.delete(_db.cards)..where((c) => c.id.equals(cardId))).go();
  }

  Future<Deck> _requireCustomDeck(String deckId) async {
    final row = await (_db.select(
      _db.decks,
    )..where((d) => d.id.equals(deckId))).getSingleOrNull();

    if (row == null) {
      throw ArgumentError.value(deckId, 'deckId', 'Catégorie inconnue');
    }
    if (row.origin != DeckOrigin.custom) {
      throw ArgumentError.value(
        deckId,
        'deckId',
        'Le contenu officiel se gère par le seeding, pas par cette API',
      );
    }
    return _toDeck(row);
  }

  Future<CardRow> _requireCustomCard(String cardId) async {
    final row = await (_db.select(
      _db.cards,
    )..where((c) => c.id.equals(cardId))).getSingleOrNull();

    if (row == null) {
      throw ArgumentError.value(cardId, 'cardId', 'Carte inconnue');
    }
    if (row.origin != DeckOrigin.custom) {
      throw ArgumentError.value(
        cardId,
        'cardId',
        'Le contenu officiel se gère par le seeding, pas par cette API',
      );
    }
    return row;
  }

  /// Un identifiant libre, dérivé du nom, préfixé et suffixé si besoin.
  Future<String> _freeCustomId(String name) async {
    final base = 'custom-${slugify(name)}';
    final pris = {
      for (final row in await _db.select(_db.decks).get()) row.id,
    };

    if (!pris.contains(base)) return base;
    for (var n = 2; ; n++) {
      final candidat = '$base-$n';
      if (!pris.contains(candidat)) return candidat;
    }
  }

  Future<int> _nextCustomSortOrder() async {
    final rangs = [
      for (final deck in await customDecks()) deck.sortOrder,
    ];
    return rangs.isEmpty ? 1 : rangs.reduce((a, b) => a > b ? a : b) + 1;
  }

  String _freeCardId(
    String deckId,
    String text,
    List<domain.Card> existantes,
  ) {
    final base = '$deckId:${slugify(text)}';
    final pris = {for (final card in existantes) card.id};

    if (!pris.contains(base)) return base;
    for (var n = 2; ; n++) {
      final candidat = '$base-$n';
      if (!pris.contains(candidat)) return candidat;
    }
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
  );
}
