import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/tables/preferences.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

/// Les réglages de l'appareil.
///
/// Deux booléens aujourd'hui. Un objet plutôt que deux appels séparés parce
/// qu'ils se lisent toujours ensemble, au même moment, par le même écran.
@immutable
class AppPreferences {
  const AppPreferences({this.soundEnabled = true, this.hapticsEnabled = true});

  /// Ce que voit un joueur qui n'a jamais rien réglé.
  ///
  /// Tout activé : le bip des dix dernières secondes est une information de
  /// jeu, pas un agrément. Il doit être là par défaut, et pouvoir se couper.
  static const AppPreferences defaults = AppPreferences();

  final bool soundEnabled;
  final bool hapticsEnabled;

  AppPreferences copyWith({bool? soundEnabled, bool? hapticsEnabled}) =>
      AppPreferences(
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      );

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.soundEnabled == soundEnabled &&
      other.hapticsEnabled == hapticsEnabled;

  @override
  int get hashCode => Object.hash(soundEnabled, hapticsEnabled);
}

/// Lit et écrit les réglages de l'appareil.
class PreferencesRepository {
  const PreferencesRepository(this._db);

  final AppDatabase _db;

  /// Les réglages, ou les valeurs par défaut si rien n'a jamais été écrit.
  Future<AppPreferences> read() async {
    final row = await (_db.select(
      _db.preferences,
    )..where((p) => p.id.equals(Preferences.singleRowId))).getSingleOrNull();

    if (row == null) return AppPreferences.defaults;

    return AppPreferences(
      soundEnabled: row.soundEnabled,
      hapticsEnabled: row.hapticsEnabled,
    );
  }

  /// Écrit les réglages, en écrasant les précédents.
  Future<void> write(AppPreferences preferences) => _db
      .into(_db.preferences)
      .insertOnConflictUpdate(
        PreferencesCompanion.insert(
          id: const Value(Preferences.singleRowId),
          soundEnabled: Value(preferences.soundEnabled),
          hapticsEnabled: Value(preferences.hapticsEnabled),
        ),
      );
}
