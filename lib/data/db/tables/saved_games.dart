import 'package:drift/drift.dart';

/// La partie en cours, sauvegardée après chaque événement (R9.1).
///
/// Une seule ligne, d'où [id] figé à [singleRowId] : Cékoi est mono-partie, et
/// une table qui pourrait en contenir plusieurs obligerait chaque lecture à
/// choisir laquelle — un choix qui n'existe pas.
///
/// L'état est stocké en JSON plutôt qu'éclaté en colonnes. `GameState` est
/// déjà sérialisable et le restera pour le multi-device de la v2 ; le déplier
/// en tables imposerait de faire évoluer le schéma à chaque champ ajouté au
/// moteur, pour une donnée que personne ne requête jamais autrement qu'en bloc.
@DataClassName('SavedGameRow')
class SavedGames extends Table {
  /// Identifiant de l'unique ligne.
  static const int singleRowId = 1;

  IntColumn get id => integer()();

  /// `GameState` sérialisé.
  TextColumn get payload => text()();

  /// Sert la fenêtre de 24 heures de R9.2.
  DateTimeColumn get savedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
