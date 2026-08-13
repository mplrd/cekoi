import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/repositories/ad_impression_repository.dart';
import 'package:cekoi/services/ads/interstitial_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le plafond de fréquence, du portillon jusqu'à SQLite.
///
/// Les tests unitaires couvrent chaque pièce ; celui-ci couvre la **couture**,
/// et c'est elle qui portait le défaut : remplacer l'instant de purge par
/// l'instant courant fait supprimer la ligne qu'on vient d'écrire, `since()`
/// rend toujours vide, et une pub tombe à chaque lancement de partie. Aucun
/// test unitaire ne pouvait le voir — le portillon passait par un bouchon, le
/// dépôt recevait sa borne à la main.
class _RepositoryLog implements AdImpressionLog {
  const _RepositoryLog(this._repository);

  final AdImpressionRepository _repository;

  @override
  Future<List<DateTime>> since(DateTime since) => _repository.since(since);

  @override
  Future<void> record(DateTime shownAt, {required DateTime expiredBefore}) =>
      _repository.record(shownAt, expiredBefore: expiredBefore);
}

void main() {
  late AppDatabase db;
  late AdImpressionLog log;
  late int affichages;

  final debut = DateTime.utc(2026, 8, 12, 20);
  var maintenant = debut;

  setUp(() {
    db = AppDatabase.memory();
    log = _RepositoryLog(AdImpressionRepository(db));
    affichages = 0;
    maintenant = debut;
  });
  tearDown(() => db.close());

  InterstitialGate gate() => InterstitialGate(
    canRequestAds: true,
    show: ({required loadTimeout}) async {
      affichages++;
      return true;
    },
    log: log,
    now: () => maintenant,
  );

  Future<bool> lancerPartie() => gate().present();

  test('la deuxième partie de suite ne voit pas de pub', () async {
    expect(await lancerPartie(), isTrue);

    maintenant = debut.add(const Duration(minutes: 2));

    expect(await lancerPartie(), isFalse);
    expect(
      affichages,
      1,
      reason: 'le délai de 5 minutes doit bloquer avant même de charger',
    );
  });

  test('après six minutes, la pub revient', () async {
    await lancerPartie();
    maintenant = debut.add(const Duration(minutes: 6));

    expect(await lancerPartie(), isTrue);
    expect(affichages, 2);
  });

  test('trois pubs dans l heure, et la quatrième est refusée', () async {
    for (final minutes in [0, 10, 20]) {
      maintenant = debut.add(Duration(minutes: minutes));
      expect(await lancerPartie(), isTrue, reason: 'pub à t+$minutes');
    }

    maintenant = debut.add(const Duration(minutes: 30));
    expect(await lancerPartie(), isFalse);

    // La plus ancienne sort de la fenêtre : on redevient sous le plafond.
    maintenant = debut.add(const Duration(minutes: 61));
    expect(await lancerPartie(), isTrue);
    expect(affichages, 4);
  });

  test('la purge ne mange pas l historique dont le plafond a besoin', () async {
    // Le défaut exact que ce fichier existe pour attraper : une purge trop
    // gourmande supprime la ligne qu'elle vient d'écrire, et le plafond
    // n'existe plus.
    await lancerPartie();

    final restantes = await log.since(
      maintenant.subtract(const Duration(hours: 1)),
    );

    expect(
      restantes,
      hasLength(1),
      reason:
          "l'impression qu'on vient d'écrire doit survivre à sa propre "
          'purge',
    );
  });

  test('une pub non affichée ne laisse pas de trace', () async {
    final muet = InterstitialGate(
      canRequestAds: true,
      show: ({required loadTimeout}) async => false,
      log: log,
      now: () => maintenant,
    );

    expect(await muet.present(), isFalse);
    expect(
      await log.since(maintenant.subtract(const Duration(hours: 1))),
      isEmpty,
    );
  });
}
