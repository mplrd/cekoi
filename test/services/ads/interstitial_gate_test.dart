import 'package:cekoi/services/ads/interstitial_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un historique piloté par le test.
class _StubLog implements AdImpressionLog {
  _StubLog({this.readFails = false});

  List<DateTime> stored = const [];
  final bool readFails;

  final List<DateTime> recorded = [];
  final List<DateTime> purges = [];
  int reads = 0;

  @override
  Future<List<DateTime>> since(DateTime since) async {
    reads++;
    if (readFails) throw StateError('base illisible');
    return [
      for (final d in stored)
        if (d.isAfter(since)) d,
    ];
  }

  @override
  Future<void> record(
    DateTime shownAt, {
    required DateTime expiredBefore,
  }) async {
    recorded.add(shownAt);
    purges.add(expiredBefore);
  }
}

void main() {
  final now = DateTime.utc(2026, 8, 12, 20);

  late _StubLog log;
  late int tentatives;
  late Duration? delaiRecu;

  setUp(() {
    log = _StubLog();
    tentatives = 0;
    delaiRecu = null;
  });

  InterstitialGate gate({
    bool canRequestAds = true,
    bool vue = true,
    bool showThrows = false,
    AdImpressionLog? historique,
  }) => InterstitialGate(
    canRequestAds: canRequestAds,
    show: ({required loadTimeout}) async {
      tentatives++;
      delaiRecu = loadTimeout;
      if (showThrows) throw StateError('SDK absent');
      return vue;
    },
    log: historique ?? log,
    now: () => now,
  );

  test('le cas nominal montre la pub et la compte', () async {
    expect(await gate().present(), isTrue);

    expect(tentatives, 1);
    expect(log.recorded, [now]);
  });

  test('la purge ne touche pas l impression qu on vient d ecrire', () async {
    // Purger a l instant courant supprimerait la ligne ecrite juste avant :
    // l historique serait toujours vide, et une pub tomberait a chaque
    // lancement de partie. La borne doit etre le bord de la fenetre.
    await gate().present();

    expect(log.purges.single, now.subtract(const Duration(hours: 1)));
  });

  test('sans consentement, rien n est meme tenté', () async {
    expect(await gate(canRequestAds: false).present(), isFalse);

    expect(tentatives, 0);
    expect(
      log.reads,
      0,
      reason: "on n'interroge même pas la base : la question ne se pose pas",
    );
  });

  test('le plafond de fréquence bloque avant de charger', () async {
    log.stored = [now.subtract(const Duration(minutes: 2))];

    expect(await gate().present(), isFalse);

    expect(
      tentatives,
      0,
      reason:
          'charger une pub qu on ne montrera pas coûte de la bande passante',
    );
    expect(log.recorded, isEmpty);
  });

  test('une pub non chargée ne consomme pas le quota', () async {
    // MONETISATION.md : si la pub n'est pas là au bout de 3 secondes, la
    // partie démarre sans elle. Le joueur n'a rien subi, il n'y a rien à
    // amortir — le prochain lancement doit pouvoir retenter.
    expect(await gate(vue: false).present(), isFalse);

    expect(tentatives, 1);
    expect(log.recorded, isEmpty);
  });

  test('le délai de chargement est de 3 secondes', () async {
    await gate().present();

    expect(delaiRecu, const Duration(seconds: 3));
  });

  group('rien ne peut retenir une partie', () {
    test('un SDK qui explose est sans conséquence', () async {
      expect(await gate(showThrows: true).present(), isFalse);
      expect(log.recorded, isEmpty);
    });

    test('une base illisible fait renoncer à la pub, pas planter', () async {
      final casse = _StubLog(readFails: true);

      expect(await gate(historique: casse).present(), isFalse);
      expect(
        tentatives,
        0,
        reason:
            'sans historique lisible on s abstient : mieux vaut une pub de '
            'moins qu une pub de trop',
      );
    });
  });
}
