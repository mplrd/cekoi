import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/tables/entitlements.dart';
import 'package:cekoi/domain/rules/ownership.dart';

/// Ce que le joueur possède, lu et écrit sur cet appareil.
///
/// Le dépôt rend directement un [Ownership] : c'est la forme dont tout le
/// reste a besoin, et la traduire ailleurs disperserait la connaissance du
/// stockage.
class EntitlementRepository {
  const EntitlementRepository(this._db);

  final AppDatabase _db;

  /// La possession courante.
  Future<Ownership> read() async =>
      _toOwnership(await _db.select(_db.entitlements).get());

  /// Enregistre l'achat de la version complète.
  Future<void> grantFullVersion(DateTime at) =>
      _grant(EntitlementKind.purchase, fullVersionProductId, at);

  /// Enregistre le déblocage définitif d'une catégorie par vidéo récompensée.
  Future<void> grantDeck(String deckId, DateTime at) =>
      _grant(EntitlementKind.reward, deckId, at);

  /// Efface tout. Sert à la restauration, et aux tests.
  ///
  /// Ne touche **que** les achats : une catégorie débloquée par une pub n'est
  /// connue d'aucun magasin, et la restauration ne doit pas la faire
  /// disparaître.
  Future<void> forgetPurchases() =>
      (_db.delete(_db.entitlements)..where(
            (row) => row.kind.equals(EntitlementKind.purchase),
          ))
          .go();

  Future<void> _grant(String kind, String reference, DateTime at) => _db
      .into(_db.entitlements)
      .insertOnConflictUpdate(
        EntitlementsCompanion.insert(
          kind: kind,
          reference: reference,
          grantedAt: at,
        ),
      );

  Ownership _toOwnership(List<EntitlementRow> rows) => Ownership(
    hasFullVersion: rows.any(
      (row) =>
          row.kind == EntitlementKind.purchase &&
          row.reference == fullVersionProductId,
    ),
    unlockedDeckIds: {
      for (final row in rows)
        if (row.kind == EntitlementKind.reward) row.reference,
    },
  );
}
