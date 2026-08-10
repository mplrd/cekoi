import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/seed/deck_seeder.dart';
import 'package:cekoi/data/repositories/deck_repository.dart';
import 'package:cekoi/data/repositories/game_repository.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

/// Base locale, ouverte une seule fois pour toute la durée de vie de l'app.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase(openAppDatabase());
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
DeckRepository deckRepository(Ref ref) =>
    DeckRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
GameRepository gameRepository(Ref ref) =>
    GameRepository(ref.watch(appDatabaseProvider));

/// Remplit la base à partir de `assets/decks/` au démarrage.
///
/// Les lancements suivants ne font qu'une comparaison de versions : ce provider
/// est donc rapide dès la deuxième ouverture.
@Riverpod(keepAlive: true)
Future<SeedReport> deckSeeding(Ref ref) async {
  final seeder = DeckSeeder(
    database: ref.watch(appDatabaseProvider),
    loadAsset: rootBundle.loadString,
    listAssets: () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest
          .listAssets()
          .where((k) => k.startsWith('assets/decks/') && k.endsWith('.json'))
          .toList();
    },
  );

  return seeder.run();
}
