import 'dart:math';

import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/domain/rules/game_profiles.dart';
import 'package:cekoi/domain/setup/game_launch.dart';
import 'package:cekoi/domain/setup/game_setup.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

final List<Deck> _decks = [
  testDeck('animaux'),
  testDeck('metiers', minAge: MinAge.ten),
];

/// Un profil qui exclut réellement quelque chose sur les deux axes : il ne
/// retient qu'`animaux` (R7.4) et interdit les cartes difficiles (R7.7).
///
/// Profil de test et non profil livré : les trois profils intégrés
/// sélectionnent aujourd'hui tout ce qui est installé et autorisent les trois
/// difficultés, donc leurs deux filtres sont des identités. Un test bâti sur
/// eux passerait même si `launchGame` ne filtrait rien.
const GameProfile _restrictif = GameProfile(
  id: 'test-restrictif',
  mode: Audience.family,
  maxDeckAge: MinAge.six,
  difficulties: {Difficulty.easy, Difficulty.medium},
  turnDuration: Duration(seconds: 60),
  cardCount: 24,
);

/// Un vivier qui contient **ce que le tirage doit écarter** : des cartes de la
/// catégorie non retenue, et des cartes difficiles. Sans elles, les assertions
/// ci-dessous seraient vraies pour rien.
List<Card> _pool() => [
  for (final difficulty in Difficulty.values) ...[
    ...testCards(
      20,
      prefix: 'animal ${difficulty.name}',
      difficulty: difficulty,
      deckId: 'animaux',
    ),
    ...testCards(
      20,
      prefix: 'metier ${difficulty.name}',
      difficulty: difficulty,
      deckId: 'metiers',
    ),
  ],
];

/// Une configuration complète, prête à lancer.
GameSetup _ready({GameProfile profile = _restrictif}) {
  var setup = setupForMode(Audience.family).withProfile(profile, _decks);
  for (var i = 0; i < 4; i++) {
    setup = setup.withPlayer(testPlayer('joueur-$i'));
  }
  return setup.withProposedTeams(names: ['Rouges', 'Bleus'], random: Random(1));
}

void main() {
  group('R7.4 — le tirage ne voit que les catégories retenues', () {
    test('une catégorie décochée ne fournit aucune carte', () {
      final pool = _pool();
      expect(
        pool.where((c) => c.deckId == 'metiers'),
        isNotEmpty,
        reason: 'Le vivier doit contenir ce que le tirage est censé écarter',
      );

      final setup = _ready();
      expect(setup.deckIds, ['animaux'], reason: 'point de départ');

      final outcome = launchGame(setup: setup, pool: pool, seed: 7);

      expect(
        {for (final card in outcome.draw.cards) card.deckId},
        {'animaux'},
      );
    });
  });

  group('R7.7 — la restriction de difficulté précède l’équilibrage', () {
    test('aucune carte difficile ne sort quand le profil les exclut', () {
      final pool = _pool();
      expect(
        pool.where((c) => c.difficulty == Difficulty.hard),
        isNotEmpty,
        reason: 'Le vivier doit contenir des cartes difficiles',
      );

      final outcome = launchGame(setup: _ready(), pool: pool, seed: 7);

      expect(
        {for (final card in outcome.draw.cards) card.difficulty},
        {Difficulty.easy, Difficulty.medium},
      );
    });

    test('les deux difficultés retenues sont toutes deux représentées', () {
      // R6.3 s'applique aux difficultés restantes, renormalisé. Un paquet qui
      // ne contiendrait que des faciles respecterait le filtre et raterait
      // l'équilibrage.
      final outcome = launchGame(setup: _ready(), pool: _pool(), seed: 7);

      expect(countOf(outcome.draw.cards, Difficulty.easy), greaterThan(0));
      expect(countOf(outcome.draw.cards, Difficulty.medium), greaterThan(0));
    });
  });

  group('R6.2 — ce qui bloque le lancement', () {
    test('sous 12 cartes éligibles, aucune partie ne démarre', () {
      final maigre = testCards(
        8,
        prefix: 'animal',
        difficulty: Difficulty.easy,
        deckId: 'animaux',
      );

      final outcome = launchGame(setup: _ready(), pool: maigre, seed: 7);

      expect(outcome.isLaunched, isFalse);
      expect(outcome.game, isNull);
      expect(
        outcome.draw.available,
        8,
        reason: "Le tirage est rendu quand même : c'est lui qui porte le "
            'chiffre à afficher au joueur',
      );
      expect(outcome.draw.isPlayable, isFalse);
    });

    test('un vivier trop juste rend un paquet tronqué mais jouable', () {
      final juste = testCards(
        16,
        prefix: 'animal',
        difficulty: Difficulty.easy,
        deckId: 'animaux',
      );

      final outcome = launchGame(setup: _ready(), pool: juste, seed: 7);

      expect(outcome.isLaunched, isTrue);
      expect(outcome.draw.isTruncated, isTrue);
      expect(outcome.draw.cards, hasLength(16));
      expect(outcome.draw.requested, 24);
    });

    test('une configuration incomplète bloque malgré assez de cartes', () {
      // Équipes non composées : le vivier suffit, la partie non.
      final sansEquipes = setupForMode(
        Audience.family,
      ).withProfile(_restrictif, _decks).withPlayer(testPlayer('seul'));

      final outcome = launchGame(
        setup: sansEquipes,
        pool: _pool(),
        seed: 7,
      );

      expect(sansEquipes.canStart, isFalse);
      expect(outcome.isLaunched, isFalse);
      expect(
        outcome.draw.isPlayable,
        isTrue,
        reason: 'Le refus vient de la configuration, pas du vivier',
      );
    });
  });

  group('la partie ouverte reprend la configuration', () {
    test('le paquet, les joueurs et les équipes passent dans la partie', () {
      final setup = _ready();

      final outcome = launchGame(setup: setup, pool: _pool(), seed: 7);
      final game = outcome.game!;

      expect(game.deck, outcome.draw.cards);
      expect(game.players, setup.players);
      expect(game.teams, setup.teams);
      expect(game.config.deckIds, ['animaux']);
      expect(game.config.profileId, 'test-restrictif');
      expect(game.config.difficulties, {Difficulty.easy, Difficulty.medium});
    });

    test('la réserve de départage vient de hors du paquet (R5.3)', () {
      final outcome = launchGame(setup: _ready(), pool: _pool(), seed: 7);

      final joues = {for (final card in outcome.draw.cards) card.id};
      expect(outcome.draw.tieBreakReserve, isNotEmpty);
      for (final card in outcome.draw.tieBreakReserve) {
        expect(joues, isNot(contains(card.id)));
        expect(card.deckId, 'animaux');
        expect(card.difficulty, isNot(Difficulty.hard));
      }
    });

    test('même graine, même paquet ; graine différente, autre paquet', () {
      final setup = _ready();
      List<String> ids(int seed) => [
        for (final card in launchGame(setup: setup, pool: _pool(), seed: seed)
            .draw
            .cards)
          card.id,
      ];

      expect(ids(7), ids(7));
      expect(ids(7), isNot(ids(8)));
    });
  });
}
