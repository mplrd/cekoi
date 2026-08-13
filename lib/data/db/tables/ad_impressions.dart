import 'package:drift/drift.dart';

/// Les interstitiels réellement présentés au joueur (`MONETISATION.md`).
///
/// En base et non en mémoire : le plafond — une fois par partie, trois par
/// heure, cinq minutes d'écart — doit survivre à un redémarrage. Tenu en
/// mémoire, il se contournerait en tuant l'application, ce qui est exactement
/// ce que fait quelqu'un qu'une pub agace.
///
/// Une ligne par impression, et non un compteur : le plafond horaire est une
/// fenêtre **glissante**, qui a besoin des instants et pas d'un total. Les
/// lignes sorties de la fenêtre sont purgées à chaque écriture — cette table
/// ne grandit pas.
///
/// Seule une pub **vue** est enregistrée. Un échec de chargement ne consomme
/// pas le quota : le joueur n'a rien subi, il n'y a rien à amortir.
@DataClassName('AdImpressionRow')
class AdImpressions extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get shownAt => dateTime()();
}
