import 'package:cekoi/data/db/tables/decks.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:drift/drift.dart';

/// Cartes de toutes les catégories.
///
/// Les index portent sur les colonnes du tirage : il filtre par catégorie,
/// public et difficulté, et doit rester rapide même avec plusieurs milliers
/// de lignes.
/// Nommée `CardRow` pour ne pas entrer en collision avec l'entité du domaine.
///
/// Un seul index composite, dans l'ordre du prédicat de tirage du lot 2 :
/// `deck_id IN (...) AND audience IN (...) AND difficulty = ?`. SQLite ne
/// retient de toute façon qu'un index par table dans une requête ; des index
/// séparés sur `audience` ou `origin`, qui ne portent que deux valeurs, ne
/// seraient quasiment jamais choisis tout en coûtant à chaque écriture du
/// seeder. `deck_id` en tête sert aussi la suppression des cartes disparues.
@DataClassName('CardRow')
@TableIndex(
  name: 'cards_deck_audience_difficulty',
  columns: {#deckId, #audience, #difficulty},
)
class Cards extends Table {
  /// Officiel : `<deck_id>:<slug du texte>`, stable d'une version à l'autre.
  TextColumn get id => text()();

  TextColumn get deckId =>
      text().references(Decks, #id, onDelete: KeyAction.cascade)();

  /// Nommée explicitement `text` en base : le getter ne peut pas s'appeler
  /// ainsi, il masquerait la fonction `text()` de Drift.
  TextColumn get cardText => text().named('text')();

  /// Hérite du deck, surchargeable carte par carte.
  TextColumn get audience => textEnum<Audience>()();

  /// 1 à 3. Utilisée par l'équilibrage du tirage (R6.3).
  IntColumn get difficulty => integer()();

  TextColumn get origin => textEnum<DeckOrigin>()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
