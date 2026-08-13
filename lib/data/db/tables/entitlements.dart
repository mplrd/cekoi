import 'package:drift/drift.dart';

/// Ce que le joueur possède, sur cet appareil (`MONETISATION.md`).
///
/// Une ligne par chose acquise, et un [kind] pour distinguer un achat d'un
/// déblocage par récompense. Deux tables auraient dit la même chose en deux
/// fois : les deux se lisent toujours ensemble, pour construire un unique
/// `Ownership`.
///
/// **En base et non déduit du magasin à chaque lancement.** Le jeu se joue
/// hors ligne : une soirée sans réseau ne doit pas faire disparaître une
/// catégorie payée. Le magasin reste la source de vérité de l'achat, mais il
/// n'est consulté qu'au démarrage et à la restauration ; entre les deux, c'est
/// cette table qui répond.
@DataClassName('EntitlementRow')
class Entitlements extends Table {
  /// `purchase` pour un achat, `reward` pour une vidéo récompensée.
  TextColumn get kind => text()();

  /// L'identifiant du produit acheté, ou celui de la catégorie débloquée.
  TextColumn get reference => text()();

  DateTimeColumn get grantedAt => dateTime()();

  /// Le couple, et non un identifiant technique : réinsérer le même
  /// déblocage ne doit pas créer une seconde ligne.
  @override
  Set<Column<Object>> get primaryKey => {kind, reference};
}

/// Les deux natures de possession.
///
/// Des constantes plutôt qu'une énumération Drift : la colonne est lue par un
/// dépôt qui traduit tout de suite en `Ownership`, et le domaine n'a pas à
/// connaître la forme du stockage.
abstract final class EntitlementKind {
  static const String purchase = 'purchase';
  static const String reward = 'reward';
}

/// Le SKU unique et non consommable de `MONETISATION.md`.
///
/// Même chaîne sur les deux magasins, pour que le code n'ait qu'une constante.
/// À créer dans Play Console et App Store Connect avant tout test réel — voir
/// `docs/ADMINISTRATIF.md`.
const String fullVersionProductId = 'cekoi_version_complete';
