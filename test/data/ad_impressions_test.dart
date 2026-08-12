import 'dart:io';

import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/repositories/ad_impression_repository.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Compare des instants, pas des objets `DateTime`.
///
/// Drift stocke un horodatage et le relit en **heure locale** : le moment est
/// le même, mais `DateTime.==` compare aussi le fuseau. C'est sans conséquence
/// — `AdFrequencyPolicy` normalise par `toUtc()` — mais une assertion sur
/// l'objet échouerait pour une raison qui n'a rien à voir avec ce qu'on teste.
Matcher moment(DateTime attendu) => predicate<DateTime>(
  (reel) => reel.isAtSameMomentAs(attendu),
  'au même instant que $attendu',
);

void main() {
  late AppDatabase db;
  late AdImpressionRepository repository;

  final now = DateTime.utc(2026, 8, 12, 20);
  DateTime ago(Duration d) => now.subtract(d);

  setUp(() {
    db = AppDatabase.memory();
    repository = AdImpressionRepository(db);
  });
  tearDown(() => db.close());

  test('une impression écrite se relit', () async {
    await repository.record(now, expiredBefore: ago(const Duration(hours: 1)));

    final relues = await repository.since(ago(const Duration(hours: 1)));
    expect(relues.single, moment(now));
  });

  test('la fenêtre exclut ce qui est plus ancien', () async {
    await db
        .into(db.adImpressions)
        .insert(
          AdImpressionsCompanion.insert(shownAt: ago(const Duration(hours: 3))),
        );
    await db
        .into(db.adImpressions)
        .insert(
          AdImpressionsCompanion.insert(
            shownAt: ago(const Duration(minutes: 10)),
          ),
        );

    final recentes = await repository.since(ago(const Duration(hours: 1)));

    expect(recentes.single, moment(ago(const Duration(minutes: 10))));
  });

  test('écrire purge ce qui est sorti de la fenêtre', () async {
    // Sinon la table accumule une ligne par pub depuis l'installation pour
    // répondre à une question qui ne regarde que la dernière heure.
    await db
        .into(db.adImpressions)
        .insert(
          AdImpressionsCompanion.insert(shownAt: ago(const Duration(days: 4))),
        );

    await repository.record(now, expiredBefore: ago(const Duration(hours: 1)));

    final toutes = await db.select(db.adImpressions).get();
    expect(toutes.single.shownAt, moment(now));
  });

  test('le plafond survit à la fermeture de l application', () async {
    // C'est toute la raison d'être de cette table : tenu en mémoire, le
    // plafond se contournerait en tuant l'application.
    //
    // Sur un vrai fichier, et pas sur une base mémoire : rouvrir une base
    // mémoire, c'est relire la même RAM par la même connexion. Le test ne
    // pourrait échouer que sur un plantage, et il porterait un nom qui promet
    // beaucoup plus que ça.
    final dossier = await Directory.systemTemp.createTemp('cekoi_ads');
    addTearDown(() => dossier.delete(recursive: true));
    final fichier = File(p.join(dossier.path, 'cekoi.sqlite'));

    final avant = AppDatabase(NativeDatabase(fichier));
    await AdImpressionRepository(
      avant,
    ).record(now, expiredBefore: ago(const Duration(hours: 1)));
    await avant.close();

    final apres = AppDatabase(NativeDatabase(fichier));
    addTearDown(apres.close);
    final relues = await AdImpressionRepository(
      apres,
    ).since(ago(const Duration(hours: 1)));

    expect(relues.single, moment(now));
  });

  group('migration de la v3 vers la v4', () {
    /// Redescend la base en v3.
    ///
    /// Même piège qu'en v1 et v2 : `AppDatabase.memory()` déclenche
    /// `onCreate`, qui crée **toutes** les tables au schéma courant,
    /// `ad_impressions` comprise. Migrer par-dessus ne prouverait rien —
    /// `createTable` émet `CREATE TABLE IF NOT EXISTS`, donc vider le corps de
    /// la migration laisserait le test vert, alors qu'en production tout
    /// appareil mis à jour depuis la v3 publiée n'aurait pas la table et
    /// **chaque lancement de partie échouerait** sur la lecture du plafond.
    Future<void> downgradeToV3() =>
        db.customStatement('DROP TABLE ad_impressions');

    test('le contenu écrit par le joueur survit', () async {
      await db
          .into(db.decks)
          .insert(
            DecksCompanion.insert(
              id: 'la-mienne',
              name: 'La mienne',
              audience: Audience.family,
              minAge: MinAge.six.years,
              origin: DeckOrigin.custom,
            ),
          );

      await downgradeToV3();
      await db.migration.onUpgrade(Migrator(db), 3, 4);

      expect((await db.select(db.decks).get()).single.id, 'la-mienne');
    });

    test('la table est utilisable après migration', () async {
      await downgradeToV3();
      await db.migration.onUpgrade(Migrator(db), 3, 4);

      await repository.record(
        now,
        expiredBefore: ago(const Duration(hours: 1)),
      );

      final relues = await repository.since(ago(const Duration(hours: 1)));
      expect(relues.single, moment(now));
    });
  });
}
