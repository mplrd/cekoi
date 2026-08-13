import 'package:cekoi/data/db/database.dart';
import 'package:drift/drift.dart';

/// L'historique des interstitiels présentés (`MONETISATION.md`).
///
/// En base parce que le plafond doit survivre à un redémarrage : tenu en
/// mémoire, il se contournerait en tuant l'application.
class AdImpressionRepository {
  const AdImpressionRepository(this._db);

  final AppDatabase _db;

  /// Les impressions postérieures à [since].
  ///
  /// La décision de montrer ou non n'est pas ici : elle est dans
  /// `AdFrequencyPolicy`, qui est du Dart pur. Ce dépôt ne fait que rendre les
  /// instants.
  ///
  /// Ils reviennent en **heure locale** : Drift stocke un horodatage et le
  /// relit dans le fuseau du device. Le moment est le bon, l'objet n'est pas
  /// identique à celui qui a été écrit — d'où la normalisation par `toUtc()`
  /// côté politique, sans laquelle une comparaison serait juste par accident.
  Future<List<DateTime>> since(DateTime since) async {
    final rows = await (_db.select(
      _db.adImpressions,
    )..where((row) => row.shownAt.isBiggerThanValue(since))).get();

    return [for (final row in rows) row.shownAt];
  }

  /// Enregistre une pub **vue**, et purge ce qui est sorti de la fenêtre.
  ///
  /// La purge est faite ici plutôt qu'au démarrage : c'est le seul moment où
  /// la table grandit, donc le seul où elle a besoin d'être taillée. Sans
  /// elle, la base accumulerait une ligne par pub depuis l'installation pour
  /// répondre à une question qui ne regarde que la dernière heure.
  Future<void> record(DateTime shownAt, {required DateTime expiredBefore}) =>
      _db.transaction(() async {
        await _db
            .into(_db.adImpressions)
            .insert(AdImpressionsCompanion.insert(shownAt: shownAt));

        await (_db.delete(
              _db.adImpressions,
            )..where((row) => row.shownAt.isSmallerOrEqualValue(expiredBefore)))
            .go();
      });
}
