import 'dart:math';

import 'package:cekoi/domain/engine/draw.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

DrawResult draw(
  List<Card> pool, {
  int requested = 40,
  Audience mode = Audience.family,
  int seed = 42,
  Set<Difficulty>? allowedDifficulties,
}) => drawCards(
  pool: pool,
  requested: requested,
  mode: mode,
  random: Random(seed),
  allowedDifficulties: allowedDifficulties,
);

void main() {
  group('R7.1 — le vivier dépend du mode de contenu', () {
    test('le mode Famille ne tire aucune carte adulte', () {
      final pool = [
        ...testCards(30, prefix: 'tout public'),
        ...testCards(30, prefix: 'adulte', audience: Audience.adult),
      ];

      final result = draw(pool);

      expect(result.cards, isNotEmpty);
      expect(
        result.cards.every((c) => c.audience == Audience.family),
        isTrue,
        reason:
            'Une carte adulte tirée en mode Famille est une régression '
            'visible par le joueur, pas un détail de tri',
      );
    });

    test('le mode Entre adultes tire aussi dans le contenu tout public', () {
      final pool = [
        ...testCards(30, prefix: 'tout public'),
        ...testCards(30, prefix: 'adulte', audience: Audience.adult),
      ];

      final result = draw(pool, mode: Audience.adult, requested: 60);

      expect(result.cards, hasLength(60));
      expect(
        result.cards.any((c) => c.audience == Audience.family),
        isTrue,
      );
      expect(result.cards.any((c) => c.audience == Audience.adult), isTrue);
    });
  });

  group('R6.4 — le tirage ne produit jamais de doublon de texte', () {
    test(
      "deux catégories contenant la même entrée ne la tirent qu'une fois",
      () {
        // Cas limite 10. Les identifiants diffèrent (`a:elephant` et
        // `b:elephant`) : dédoublonner sur l'id ne suffirait pas.
        final pool = [
          testCard('Éléphant', deckId: 'a'),
          testCard('Éléphant', deckId: 'b'),
          ...testCards(30, prefix: 'autre'),
        ];

        final result = draw(pool, requested: 32);

        expect(
          result.cards.where((c) => c.normalizedText == 'elephant'),
          hasLength(1),
        );
        expect(result.available, 31, reason: '32 entrées, une en double');
      },
    );

    test('le dédoublonnage passe par le texte normalisé', () {
      final pool = [
        testCard('Éléphant', deckId: 'a'),
        testCard('elephant', deckId: 'b'),
        testCard('ÉLÉPHANT', deckId: 'c'),
        ...testCards(20, prefix: 'autre'),
      ];

      final result = draw(pool, requested: 40);

      expect(
        result.cards.where((c) => c.normalizedText == 'elephant'),
        hasLength(1),
      );
      expect(result.cards, hasLength(21));
    });
  });

  group('R6.2 — vivier plus petit que le nombre demandé', () {
    test(
      '48 demandées pour 30 disponibles : on joue à 30 et on le signale',
      () {
        // Cas limite 9.
        final result = draw(testCards(30), requested: 48);

        expect(result.cards, hasLength(30));
        expect(result.requested, 48);
        expect(result.available, 30);
        expect(result.isTruncated, isTrue);
        expect(
          result.isPlayable,
          isTrue,
          reason: '30 cartes dépassent le minimum de 12, la partie doit partir',
        );
      },
    );

    test('un tirage complet ne se signale pas comme tronqué', () {
      final result = draw(richPool(), requested: 40);

      expect(result.cards, hasLength(40));
      expect(result.isTruncated, isFalse);
    });

    test("sous 12 cartes, le tirage n'est pas jouable", () {
      final result = draw(testCards(11), requested: 32);

      expect(result.cards, hasLength(11));
      expect(result.isPlayable, isFalse);
    });

    test('12 cartes pile suffisent', () {
      expect(draw(testCards(12), requested: 32).isPlayable, isTrue);
    });
  });

  group('R6.3 — équilibrage en difficulté', () {
    test('à volume suffisant, la répartition visée est 30 / 50 / 20', () {
      final result = draw(richPool(), requested: 40);

      expect(countOf(result.cards, Difficulty.easy), 12);
      expect(countOf(result.cards, Difficulty.medium), 20);
      expect(countOf(result.cards, Difficulty.hard), 8);
    });

    test('le compte demandé est toujours honoré', () {
      for (var requested = 12; requested <= 80; requested++) {
        final result = draw(richPool(), requested: requested);
        expect(
          result.cards,
          hasLength(requested),
          reason: 'Tirage de $requested cartes',
        );
      }
    });

    test('un quota fractionnaire va à la difficulté au plus fort reste', () {
      // 30 / 50 / 20 tombe rarement juste. Sur 26 cartes la cible vaut
      // 7,8 / 13 / 5,2 : le reste doit aller aux faciles.
      //
      // Ce test ne peut pas se contenter de compter les cartes : la
      // complétion du vivier rattrape n'importe quel déficit de quota, donc
      // un tirage de 26 reste un tirage de 26 même sans arbitrage des restes.
      // Seule la répartition trahit l'erreur.
      final result = draw(richPool(), requested: 26);

      expect(countOf(result.cards, Difficulty.easy), 8);
      expect(countOf(result.cards, Difficulty.medium), 13);
      expect(countOf(result.cards, Difficulty.hard), 5);
    });

    test('le plus fort reste peut bénéficier aux cartes difficiles', () {
      // Sur 14 cartes : 4,2 / 7 / 2,8. Le reste revient cette fois aux
      // difficiles — une implémentation qui donnerait toujours le reste aux
      // faciles passerait le test précédent et échouerait ici.
      final result = draw(richPool(), requested: 14);

      expect(countOf(result.cards, Difficulty.easy), 4);
      expect(countOf(result.cards, Difficulty.medium), 7);
      expect(countOf(result.cards, Difficulty.hard), 3);
    });

    test('un vivier sans cartes difficiles complète avec ce qui existe', () {
      final pool = [
        ...testCards(50, prefix: 'facile', difficulty: Difficulty.easy),
        ...testCards(50, prefix: 'moyen', difficulty: Difficulty.medium),
      ];

      final result = draw(pool, requested: 20);

      expect(
        result.cards,
        hasLength(20),
        reason: "R6.3 complète plutôt que d'échouer",
      );
      expect(countOf(result.cards, Difficulty.hard), 0);
    });

    test('un vivier presque vide dans une difficulté ne bloque pas', () {
      final pool = [
        ...testCards(50, prefix: 'facile', difficulty: Difficulty.easy),
        ...testCards(50, prefix: 'moyen', difficulty: Difficulty.medium),
        ...testCards(2, prefix: 'dur', difficulty: Difficulty.hard),
      ];

      final result = draw(pool, requested: 40);

      expect(result.cards, hasLength(40));
      expect(countOf(result.cards, Difficulty.hard), 2);
    });
  });

  group("R7.7 — la restriction de difficulté précède l'équilibrage", () {
    test('une seule difficulté autorisée : tirage uniforme dans ce vivier', () {
      final result = draw(
        richPool(),
        requested: 40,
        allowedDifficulties: {Difficulty.easy},
      );

      expect(
        result.cards,
        hasLength(40),
        reason:
            'Appliquer les quotas 30/50/20 puis filtrer ne rendrait que '
            "12 cartes — c'est l'inversion que cette règle interdit",
      );
      expect(countOf(result.cards, Difficulty.easy), 40);
    });

    test('deux difficultés autorisées : la cible est renormalisée', () {
      // Profil « Ados & co » : 1 et 2 autorisées. 0,3 et 0,5 renormalisés sur
      // 0,8 donnent 0,375 et 0,625, soit 15 et 25 cartes sur 40.
      final result = draw(
        richPool(),
        requested: 40,
        allowedDifficulties: {Difficulty.easy, Difficulty.medium},
      );

      expect(countOf(result.cards, Difficulty.easy), 15);
      expect(countOf(result.cards, Difficulty.medium), 25);
      expect(countOf(result.cards, Difficulty.hard), 0);
    });

    test('les cartes exclues ne comptent pas dans le vivier disponible', () {
      final result = draw(
        richPool(perDifficulty: 10),
        requested: 40,
        allowedDifficulties: {Difficulty.hard},
      );

      expect(result.available, 10);
      expect(result.isPlayable, isFalse);
    });

    test('un ensemble de difficultés vide est refusé', () {
      expect(
        () => draw(richPool(), allowedDifficulties: const {}),
        throwsArgumentError,
      );
    });
  });

  group('R5.3 — la réserve de départage', () {
    test('les cartes réservées sont éligibles mais hors du paquet', () {
      final result = draw(richPool(), requested: 40);

      expect(result.tieBreakReserve, hasLength(tieBreakReserveSize));
      for (final card in result.tieBreakReserve) {
        expect(result.cards, isNot(contains(card)));
        expect(card.audience, Audience.family);
      }
    });

    test('la réserve respecte les difficultés autorisées', () {
      final result = draw(
        richPool(),
        requested: 20,
        allowedDifficulties: {Difficulty.easy},
      );

      expect(
        result.tieBreakReserve.every((c) => c.difficulty == Difficulty.easy),
        isTrue,
      );
    });

    test('un vivier tout juste suffisant ne laisse pas de réserve', () {
      final result = draw(testCards(20), requested: 20);

      expect(result.cards, hasLength(20));
      expect(
        result.tieBreakReserve,
        isEmpty,
        reason: 'Le paquet passe avant le départage',
      );
    });

    test("un vivier à peine plus grand ne réserve que ce qu'il peut", () {
      final result = draw(testCards(23), requested: 20);

      expect(result.tieBreakReserve, hasLength(3));
    });
  });

  group('déterminisme du tirage', () {
    test('deux tirages de même graine sont identiques', () {
      final a = draw(richPool(), seed: 7);
      final b = draw(richPool(), seed: 7);

      expect(ids(a), ids(b));
    });

    test('deux graines différentes ne donnent pas le même paquet', () {
      expect(
        ids(draw(richPool(), seed: 1)),
        isNot(ids(draw(richPool(), seed: 2))),
      );
    });

    test("l'ordre d'écriture des difficultés autorisées n'influe pas", () {
      // Un `Set` conserve son ordre d'insertion : itérer dessus directement
      // ferait dépendre le tirage de la façon dont l'appelant a écrit son
      // littéral, et deux profils identiques ne tireraient pas pareil.
      expect(
        ids(
          draw(
            richPool(),
            allowedDifficulties: {Difficulty.hard, Difficulty.easy},
          ),
        ),
        ids(
          draw(
            richPool(),
            allowedDifficulties: {Difficulty.easy, Difficulty.hard},
          ),
        ),
      );
    });

    test("le paquet rendu n'est pas rangé par difficulté", () {
      // Les cartes sont prélevées vivier par vivier : sans mélange final, le
      // paquet sortirait trié, et la réserve de départage comme tout aperçu
      // du paquet commenceraient par douze cartes faciles.
      final result = draw(richPool(), requested: 40);

      expect(
        result.cards.take(12).map((c) => c.difficulty).toSet().length,
        greaterThan(1),
      );
    });

    test("l'ordre du vivier n'influence pas le résultat", () {
      // Le vivier arrive d'une requête SQL : son ordre n'est pas garanti. Si
      // le tirage en dépend, une partie n'est plus rejouable depuis sa graine.
      final pool = richPool();
      final shuffled = [...pool]..shuffle(Random(99));

      expect(ids(draw(pool, seed: 7)), ids(draw(shuffled, seed: 7)));
    });

    test('un nombre de cartes nul ou négatif est refusé', () {
      expect(() => draw(richPool(), requested: 0), throwsArgumentError);
      expect(() => draw(richPool(), requested: -3), throwsArgumentError);
    });
  });
}

List<String> ids(DrawResult result) => [for (final c in result.cards) c.id];
