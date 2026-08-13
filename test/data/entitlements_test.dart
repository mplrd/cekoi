import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/repositories/entitlement_repository.dart';
import 'package:cekoi/domain/rules/ownership.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EntitlementRepository repository;

  final now = DateTime.utc(2026, 8, 13, 10);

  setUp(() {
    db = AppDatabase.memory();
    repository = EntitlementRepository(db);
  });
  tearDown(() => db.close());

  test('une base neuve ne possède rien', () async {
    expect(await repository.read(), Ownership.none);
  });

  test('l achat ouvre toutes les catégories et éteint la pub', () async {
    await repository.grantFullVersion(now);

    final possession = await repository.read();

    expect(possession.hasFullVersion, isTrue);
    expect(possession.showsAds, isFalse);
  });

  test('une récompense ouvre une catégorie, et elle seule', () async {
    await repository.grantDeck('disney', now);

    final possession = await repository.read();

    expect(possession.unlockedDeckIds, {'disney'});
    expect(
      possession.showsAds,
      isTrue,
      reason: 'regarder une vidéo n achète pas la suppression des pubs',
    );
  });

  test(
    'débloquer deux fois la même catégorie ne crée pas deux lignes',
    () async {
      await repository.grantDeck('disney', now);
      await repository.grantDeck('disney', now.add(const Duration(days: 1)));

      expect(await db.select(db.entitlements).get(), hasLength(1));
    },
  );

  group('migration de la v4 vers la v5', () {
    /// Même piège que les migrations précédentes : la base de test naît au
    /// schéma courant, donc migrer par-dessus ne prouverait rien.
    Future<void> downgradeToV4() =>
        db.customStatement('DROP TABLE entitlements');

    test('la table est utilisable après migration', () async {
      await downgradeToV4();
      await db.migration.onUpgrade(Migrator(db), 4, 5);

      await repository.grantFullVersion(now);

      expect((await repository.read()).hasFullVersion, isTrue);
    });

    test('une base migrée repart sans rien posséder', () async {
      // Le bon défaut : une récompense se regagne, et un achat se retrouve
      // par la restauration. L'inverse — accorder par défaut — donnerait la
      // version complète à qui ne l'a jamais payée.
      await downgradeToV4();
      await db.migration.onUpgrade(Migrator(db), 4, 5);

      expect(await repository.read(), Ownership.none);
    });
  });
}
