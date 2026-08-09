import 'dart:io';

import 'package:cekoi/data/db/tables/cards.dart';
import 'package:cekoi/data/db/tables/decks.dart';
// Utilisés par database.g.dart pour les colonnes textEnum : le fichier généré
// est un `part` de celui-ci et ne porte pas ses propres imports.
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Decks, Cards])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Base en mémoire, pour les tests. Aucun fichier n'est écrit.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
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
