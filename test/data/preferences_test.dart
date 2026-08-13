import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/repositories/preferences_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PreferencesRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = PreferencesRepository(db);
  });
  tearDown(() => db.close());

  test('sans rien de réglé, tout est actif', () async {
    // Le bip des dix dernières secondes est une information de jeu, pas un
    // agrément : il doit être là par défaut.
    expect(await repository.read(), AppPreferences.defaults);
    expect((await repository.read()).soundEnabled, isTrue);
    expect((await repository.read()).hapticsEnabled, isTrue);
  });

  test('couper le son ne coupe pas la vibration', () async {
    // Deux réglages distincts et non un seul : au restaurant on veut la
    // vibration sans le son.
    await repository.write(
      const AppPreferences(soundEnabled: false),
    );

    final relus = await repository.read();
    expect(relus.soundEnabled, isFalse);
    expect(relus.hapticsEnabled, isTrue);
  });

  test('le réglage survit à la fermeture de la base', () async {
    // Toute la raison d'être de cette table : couper le son doit rester coupé
    // au lancement suivant, sinon le réglage ne sert à rien.
    await repository.write(
      const AppPreferences(soundEnabled: false, hapticsEnabled: false),
    );

    final relus = await PreferencesRepository(db).read();
    expect(relus.soundEnabled, isFalse);
    expect(relus.hapticsEnabled, isFalse);
  });

  test('écrire deux fois ne crée pas deux lignes', () async {
    await repository.write(const AppPreferences(soundEnabled: false));
    await repository.write(const AppPreferences(hapticsEnabled: false));

    expect(await db.select(db.preferences).get(), hasLength(1));
  });

  group('migration de la v5 vers la v6', () {
    /// Même piège que les migrations précédentes : la base de test naît au
    /// schéma courant, donc migrer par-dessus ne prouverait rien.
    Future<void> downgradeToV5() =>
        db.customStatement('DROP TABLE preferences');

    test('la table est utilisable après migration', () async {
      await downgradeToV5();
      await db.migration.onUpgrade(Migrator(db), 5, 6);

      await repository.write(const AppPreferences(soundEnabled: false));

      expect((await repository.read()).soundEnabled, isFalse);
    });

    test('une base migrée garde le comportement d avant', () async {
      // Aucune ligne, donc les valeurs par défaut : c'est exactement l'état
      // d'un appareil qui jouait avant que ce réglage existe.
      await downgradeToV5();
      await db.migration.onUpgrade(Migrator(db), 5, 6);

      expect(await repository.read(), AppPreferences.defaults);
    });
  });
}
