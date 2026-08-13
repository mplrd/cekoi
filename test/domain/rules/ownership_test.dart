import 'package:cekoi/domain/rules/ownership.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// Ce que le joueur possède, et ce que ça lui ouvre.
///
/// Du Dart pur : aucun magasin, aucune pub, aucune base. La question « cette
/// catégorie est-elle jouable » se pose à chaque écran de sélection et à
/// chaque tirage, et elle ne doit dépendre de rien d'asynchrone.
void main() {
  final gratuite = testDeck('animaux');
  final payante = testDeck('disney', isPremium: true);

  test('sans rien, seules les catégories gratuites sont ouvertes', () {
    expect(Ownership.none.allows(gratuite), isTrue);
    expect(Ownership.none.allows(payante), isFalse);
  });

  test('une catégorie débloquée par pub s ouvre, et elle seule', () {
    const debloquee = Ownership(unlockedDeckIds: {'disney'});

    expect(debloquee.allows(payante), isTrue);
    expect(
      debloquee.allows(testDeck('autre', isPremium: true)),
      isFalse,
      reason: 'une récompense débloque une catégorie, pas le catalogue',
    );
  });

  group('la version complète', () {
    const complete = Ownership(hasFullVersion: true);

    test('ouvre toutes les catégories premium', () {
      // MONETISATION.md : on vend une « Version complète », pas un « Retirer
      // les pubs ». Payer puis devoir quand même regarder des vidéos pour
      // accéder aux catégories, c'est le sentiment d'avoir payé pour rien.
      expect(complete.allows(payante), isTrue);
      expect(complete.allows(testDeck('autre', isPremium: true)), isTrue);
    });

    test('éteint tous les points d entrée publicitaires', () {
      expect(complete.showsAds, isFalse);
      expect(Ownership.none.showsAds, isTrue);
      expect(
        const Ownership(unlockedDeckIds: {'disney'}).showsAds,
        isTrue,
        reason:
            'regarder une pub récompensée n achète rien : l interstitiel de '
            'lancement reste',
      );
    });

    test('rend inutile de proposer un déblocage', () {
      // « Posséder la version complète doit masquer tous les points d'entrée
      // publicitaires, y compris les boutons Débloquer des catégories
      // premium — qui deviennent simplement des catégories accessibles. »
      expect(complete.canUnlock(payante), isFalse);
      expect(Ownership.none.canUnlock(payante), isTrue);
    });

    test('ne propose pas de débloquer ce qui l est déjà', () {
      const debloquee = Ownership(unlockedDeckIds: {'disney'});

      expect(debloquee.canUnlock(payante), isFalse);
    });

    test('ne propose jamais de débloquer une catégorie gratuite', () {
      expect(Ownership.none.canUnlock(gratuite), isFalse);
    });
  });

  group('égalité de valeur', () {
    // Elle circule dans des providers : sans égalité, chaque reconstruction
    // reconstruirait tous les écrans qui l observent. Et sans **inégalité**,
    // Riverpod cesserait de notifier après un déblocage — c'est la panne que
    // cette égalité est censée éviter.
    test('deux possessions identiques sont égales', () {
      expect(
        const Ownership(hasFullVersion: true, unlockedDeckIds: {'a', 'b'}),
        const Ownership(hasFullVersion: true, unlockedDeckIds: {'b', 'a'}),
      );
    });

    test('une catégorie de plus rend deux possessions différentes', () {
      expect(
        const Ownership(unlockedDeckIds: {'a'}),
        isNot(const Ownership(unlockedDeckIds: {'a', 'b'})),
      );
    });

    test('une catégorie différente aussi', () {
      expect(
        const Ownership(unlockedDeckIds: {'a'}),
        isNot(const Ownership(unlockedDeckIds: {'b'})),
      );
    });

    test('l achat distingue deux possessions par ailleurs identiques', () {
      expect(
        const Ownership(unlockedDeckIds: {'a'}),
        isNot(const Ownership(hasFullVersion: true, unlockedDeckIds: {'a'})),
      );
    });
  });
}
