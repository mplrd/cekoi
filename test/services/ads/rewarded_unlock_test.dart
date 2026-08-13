import 'package:cekoi/services/ads/rewarded_unlock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le déblocage d'une catégorie contre une vidéo.
///
/// Une seule règle, mais elle est le contrat passé avec le joueur : on
/// n'écrit le déblocage que si la récompense est acquise, et le déblocage est
/// définitif.
void main() {
  late List<String> debloquees;
  late int videos;

  setUp(() {
    debloquees = [];
    videos = 0;
  });

  RewardedUnlock unlocker({
    bool canRequestAds = true,
    bool recompense = true,
    bool videoExplose = false,
    bool ecritureExplose = false,
  }) => RewardedUnlock(
    canRequestAds: canRequestAds,
    show: ({required loadTimeout}) async {
      videos++;
      if (videoExplose) throw StateError('SDK absent');
      return recompense;
    },
    grant: (deckId) async {
      if (ecritureExplose) throw StateError('base pleine');
      debloquees.add(deckId);
    },
  );

  test('une vidéo regardée jusqu au bout débloque la catégorie', () async {
    expect(await unlocker().unlock('disney'), isTrue);

    expect(videos, 1);
    expect(debloquees, ['disney']);
  });

  test('fermer la vidéo avant la fin ne débloque rien', () async {
    // Et ne coûte rien : le joueur peut retenter tout de suite, il n'y a
    // aucun plafond sur une vidéo qu'il a lui-même demandée.
    expect(await unlocker(recompense: false).unlock('disney'), isFalse);

    expect(videos, 1);
    expect(debloquees, isEmpty);
  });

  test('sans droit de demander une pub, rien n est tenté', () async {
    // Le cas de la version complète : il n'y a plus rien à débloquer, et
    // proposer une vidéo à quelqu'un qui a payé serait insultant.
    expect(await unlocker(canRequestAds: false).unlock('disney'), isFalse);

    expect(videos, 0);
  });

  test('un SDK qui explose ne débloque rien et ne relance pas', () async {
    expect(await unlocker(videoExplose: true).unlock('disney'), isFalse);

    expect(debloquees, isEmpty);
  });

  test('une écriture qui échoue annonce un échec, pas un déblocage', () async {
    // Dire vrai afficherait un déblocage que la base ne confirme pas : au
    // prochain rendu, le cadenas serait revenu sans explication.
    expect(await unlocker(ecritureExplose: true).unlock('disney'), isFalse);
  });

  test('la vidéo a droit à plus de temps que l interstitiel', () async {
    Duration? recu;
    final gate = RewardedUnlock(
      canRequestAds: true,
      show: ({required loadTimeout}) async {
        recu = loadTimeout;
        return true;
      },
      grant: (_) async {},
    );

    await gate.unlock('disney');

    expect(
      recu,
      greaterThan(const Duration(seconds: 3)),
      reason:
          'trois secondes bornent une pub non sollicitée ; celle-ci, le '
          'joueur vient de la demander et regarde un indicateur d attente',
    );
  });
}
