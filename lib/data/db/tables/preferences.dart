import 'package:drift/drift.dart';

/// Les réglages de l'application (`SPEC.md`).
///
/// Une seule ligne, d'où [id] figé à [singleRowId] : ce sont les préférences
/// de l'appareil, il n'y en a pas plusieurs jeux. Même forme que
/// `SavedGames`, pour la même raison — une table qui pourrait en contenir
/// plusieurs obligerait chaque lecture à choisir laquelle.
///
/// En base et non en mémoire : couper le son doit rester coupé au lancement
/// suivant, sinon le réglage ne sert à rien.
@DataClassName('PreferencesRow')
class Preferences extends Table {
  static const int singleRowId = 1;

  IntColumn get id => integer()();

  /// Le bip des dix dernières secondes.
  BoolColumn get soundEnabled => boolean().withDefault(const Constant(true))();

  /// La vibration qui l'accompagne.
  BoolColumn get hapticsEnabled =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
