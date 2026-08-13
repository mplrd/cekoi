import 'dart:io';

import 'package:cekoi/data/db/tables/ad_impressions.dart';
import 'package:cekoi/data/db/tables/cards.dart';
import 'package:cekoi/data/db/tables/decks.dart';
import 'package:cekoi/data/db/tables/entitlements.dart';
import 'package:cekoi/data/db/tables/preferences.dart';
import 'package:cekoi/data/db/tables/saved_games.dart';
// Utilisés par database.g.dart pour les colonnes textEnum : le fichier généré
// est un `part` de celui-ci et ne porte pas ses propres imports.
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Decks, Cards, SavedGames, AdImpressions, Entitlements, Preferences],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Base en mémoire, pour les tests. Aucun fichier n'est écrit.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // v2 — la reprise de partie (R9.1). Ajout d'une table seule : les
      // catégories et les cartes ne sont pas touchées, et surtout pas les
      // lignes `origin = 'custom'`, qui sont du contenu que le joueur a écrit
      // et qu'aucune migration n'a le droit de perdre.
      if (from < 2) {
        await m.createTable(savedGames);
      }

      // v3 — les mots interdits sortent du jeu. SQLite ne sait pas retirer une
      // colonne en place : Drift recrée la table et recopie les lignes, index
      // et clés étrangères compris. Les cartes écrites par le joueur sont donc
      // déplacées, pas régénérées — le seeding ne recrée que l'officiel.
      if (from < 3) {
        await m.alterTable(TableMigration(cards));
      }

      // v4 — le plafond de fréquence de l'interstitiel (lot 7). Table seule
      // ajoutée, rien de touché ailleurs : une base existante garde ses
      // parties sauvegardées et ses cartes custom, et repart simplement d'un
      // historique publicitaire vide — ce qui est le bon défaut, personne
      // n'ayant encore vu de pub.
      if (from < 4) {
        await m.createTable(adImpressions);
      }

      // v5 — ce que le joueur possède (lot 7). Table seule, rien d'autre
      // touché. Une base existante repart d'une possession vide, et c'est le
      // bon défaut : rien ne se donne gratuitement. Une récompense se regagne,
      // et un achat se retrouve par « Restaurer mes achats » — la restauration
      // est manuelle, exprès (voir `app/ownership.dart`).
      if (from < 5) {
        await m.createTable(entitlements);
      }

      // v6 — les réglages de l'appareil (`SPEC.md`). Table seule. Une base
      // existante n'a pas de ligne : la lecture retombe sur les valeurs par
      // défaut, tout activé, ce qui est exactement l'état d'avant la
      // migration.
      if (from < 6) {
        await m.createTable(preferences);
      }
    },
    beforeOpen: (details) async {
      // Sans cette ligne, la cascade de suppression des cartes d'un deck ne
      // s'applique pas : SQLite désactive les clés étrangères par défaut.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Ouvre la base du device, en différant l'accès disque au premier usage.
///
/// `sqlite3` 3.x embarque lui-même les binaires natifs via les build hooks de
/// Dart : aucun paquet de librairies natives n'est nécessaire.
QueryExecutor openAppDatabase() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'cekoi.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
