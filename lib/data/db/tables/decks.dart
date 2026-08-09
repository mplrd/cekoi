import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:drift/drift.dart';

/// Catégories de cartes, officielles et custom confondues.
///
/// Les deux origines partagent la même table volontairement : à l'exécution,
/// tout passe par la base et rien ne merge deux sources à chaud. [origin] est
/// la seule distinction.
/// La classe de ligne est nommée `DeckRow` : sans ça, Drift générerait `Deck`,
/// qui entrerait en collision avec l'entité du domaine du même nom.
@DataClassName('DeckRow')
@TableIndex(name: 'decks_audience', columns: {#audience})
@TableIndex(name: 'decks_origin', columns: {#origin})
class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get audience => textEnum<Audience>()();

  /// 6, 10, 13 ou 18 (R7.4). Stocké en entier pour rester lisible en SQL.
  IntColumn get minAge => integer()();
  TextColumn get origin => textEnum<DeckOrigin>()();

  /// Pilote le re-seed : un JSON livré avec une version supérieure à celle en
  /// base déclenche la mise à jour des cartes officielles.
  IntColumn get contentVersion => integer().withDefault(const Constant(1))();
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
