import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/domain/rules/game_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

final List<Deck> _decks = [
  testDeck('bebe', minAge: MinAge.six),
  testDeck('ado', minAge: MinAge.ten),
  testDeck('collegien', minAge: MinAge.thirteen),
  testDeck('majeur', minAge: MinAge.eighteen, audience: Audience.adult),
];

GameProfile profile(String id) => builtInProfiles.firstWhere((p) => p.id == id);

/// Autant de cartes par difficulté que demandé, dans chaque catégorie citée.
List<Card> cardsFor(
  Iterable<String> deckIds, {
  int easy = 10,
  int medium = 10,
  int hard = 10,
}) => [
  for (final deckId in deckIds) ...[
    ...testCards(
      easy,
      prefix: '$deckId facile',
      difficulty: Difficulty.easy,
      deckId: deckId,
    ),
    ...testCards(
      medium,
      prefix: '$deckId moyen',
      deckId: deckId,
    ),
    ...testCards(
      hard,
      prefix: '$deckId dur',
      difficulty: Difficulty.hard,
      deckId: deckId,
    ),
  ],
];

List<String> idsOf(Iterable<Deck> decks) => [for (final d in decks) d.id];

void main() {
  group('R7.4 — un profil ne retient que les catégories de son âge', () {
    test('« Les minis » ne voit que les catégories 6 ans', () {
      expect(idsOf(decksForProfile(profile('minis'), _decks)), ['bebe']);
    });

    test('« Ados & co » voit aussi les catégories 6 ans', () {
      // Le filtre est « inférieur ou égal », pas « égal » : un profil 10 ans
      // qui perdrait les catégories 6 ans n'aurait presque rien à jouer.
      expect(idsOf(decksForProfile(profile('ados'), _decks)), [
        'bebe',
        'ado',
      ]);
    });

    test("« Mix familial » va jusqu'à 13 ans, jamais au-delà", () {
      expect(idsOf(decksForProfile(profile('mix'), _decks)), [
        'bebe',
        'ado',
        'collegien',
      ]);
    });

    test('R7.1 — aucun profil famille ne retient une catégorie adulte', () {
      for (final p in builtInProfiles.where((p) => p.mode == Audience.family)) {
        expect(
          idsOf(decksForProfile(p, _decks)),
          isNot(contains('majeur')),
          reason: 'Profil ${p.id}',
        );
      }
    });
  });

  group('R7.5 — les réglages des trois profils du mode Famille', () {
    test('« Les minis » : difficulté 1 seule, 90 secondes, cartes auto', () {
      final minis = profile('minis');

      expect(minis.difficulties, {Difficulty.easy});
      expect(minis.turnDuration, const Duration(seconds: 90));
      expect(minis.cardCount, isNull, reason: 'auto');
      expect(minis.maxDeckAge, MinAge.six);
    });

    test('« Ados & co » : difficultés 1 et 2, 60 secondes', () {
      final ados = profile('ados');

      expect(ados.difficulties, {Difficulty.easy, Difficulty.medium});
      expect(ados.turnDuration, const Duration(seconds: 60));
      expect(ados.maxDeckAge, MinAge.ten);
    });

    test('« Mix familial » : les trois difficultés, 60 secondes', () {
      final mix = profile('mix');

      expect(mix.difficulties, Difficulty.values.toSet());
      expect(mix.turnDuration, const Duration(seconds: 60));
      expect(mix.maxDeckAge, MinAge.thirteen);
    });

    test('les trois profils famille sont proposés dans cet ordre', () {
      expect(
        [
          for (final p in builtInProfiles)
            if (p.mode == Audience.family) p.id,
        ],
        ['minis', 'ados', 'mix'],
      );
    });
  });

  group('R7.8 — un profil trop pauvre est désactivé, jamais caché', () {
    test('cas limite 11 : pas assez de cartes en difficulté 1', () {
      // La seule catégorie 6 ans n'a que 5 cartes faciles. « Les minis » ne
      // peut pas réunir les 12 cartes de R6.2 ; « Ados & co », qui accepte
      // aussi la difficulté 2, le peut.
      final cards = cardsFor(['bebe'], easy: 5, medium: 20, hard: 20);

      final minis = evaluateProfile(
        profile: profile('minis'),
        decks: _decks,
        cards: cards,
      );

      expect(minis.availableCards, 5);
      expect(minis.isPlayable, isFalse);
      expect(minis.unavailability, ProfileUnavailability.notEnoughCards);

      final ados = evaluateProfile(
        profile: profile('ados'),
        decks: _decks,
        cards: cards,
      );
      expect(ados.isPlayable, isTrue);
      expect(ados.unavailability, isNull);
    });

    test('un profil sans aucune catégorie éligible le dit autrement', () {
      // Distinguer les deux raisons compte : « aucune catégorie pour cet âge »
      // et « pas assez de cartes » n'appellent pas le même message.
      final availability = evaluateProfile(
        profile: profile('minis'),
        decks: [testDeck('ado', minAge: MinAge.ten)],
        cards: cardsFor(['ado']),
      );

      expect(availability.deckIds, isEmpty);
      expect(availability.availableCards, 0);
      expect(availability.unavailability, ProfileUnavailability.noEligibleDeck);
    });

    test('12 cartes tout juste suffisent', () {
      final availability = evaluateProfile(
        profile: profile('minis'),
        decks: _decks,
        cards: cardsFor(['bebe'], easy: 12, medium: 0, hard: 0),
      );

      expect(availability.availableCards, 12);
      expect(availability.isPlayable, isTrue);
    });

    test('les doublons de texte ne gonflent pas le compte disponible', () {
      // R6.4 : le tirage n'en prendrait qu'une. Annoncer un profil jouable
      // sur des cartes que le tirage refusera serait un mensonge à l'écran.
      final availability = evaluateProfile(
        profile: profile('minis'),
        decks: [
          testDeck('bebe'),
          testDeck('bis'),
        ],
        cards: [
          ...testCards(
            12,
            prefix: 'commune',
            difficulty: Difficulty.easy,
            deckId: 'bebe',
          ),
          ...testCards(
            12,
            prefix: 'commune',
            difficulty: Difficulty.easy,
            deckId: 'bis',
          ),
        ],
      );

      expect(availability.availableCards, 12);
    });

    test('tous les profils sont évalués, y compris les injouables', () {
      final all = evaluateProfiles(
        profiles: builtInProfiles,
        decks: _decks,
        cards: cardsFor(['bebe'], easy: 2, medium: 2, hard: 2),
      );

      expect(all, hasLength(builtInProfiles.length));
      expect(
        all.every((a) => !a.isPlayable),
        isTrue,
        reason: 'Six cartes ne suffisent nulle part',
      );
    });
  });

  group('R7.6 — un profil est un point de départ, pas une contrainte', () {
    test('choisir un profil présélectionne ses catégories et ses filtres', () {
      final selection = selectionFor(profile('ados'), _decks);

      expect(selection.profileId, 'ados');
      expect(selection.deckIds, ['bebe', 'ado']);
      expect(selection.difficulties, {Difficulty.easy, Difficulty.medium});
      expect(selection.turnDuration, const Duration(seconds: 60));
    });

    // Ce que devient cette sélection quand le joueur y touche appartient à
    // `GameSetup`, seul porteur de la règle depuis la suppression du
    // `toggleDeck` jumeau — voir `test/domain/setup/game_setup_test.dart`.
  });

  group('les profils sont de la donnée, pas des branchements', () {
    test('un profil adulte inédit traverse le même mécanisme', () {
      // R7.5 : « ses profils sont de la donnée de configuration, pas du code,
      // et peuvent être ajoutés sans modifier le moteur ».
      const apero = GameProfile(
        id: 'apero',
        mode: Audience.adult,
        maxDeckAge: MinAge.eighteen,
        difficulties: {Difficulty.medium, Difficulty.hard},
        turnDuration: Duration(seconds: 45),
        cardCount: 32,
      );

      final availability = evaluateProfile(
        profile: apero,
        decks: _decks,
        cards: cardsFor(['bebe', 'ado', 'collegien', 'majeur']),
      );

      expect(
        availability.deckIds,
        ['bebe', 'ado', 'collegien', 'majeur'],
        reason: 'Le mode adultes tire aussi dans le contenu famille (R7.1)',
      );
      expect(availability.isPlayable, isTrue);

      final selection = selectionFor(apero, _decks);
      expect(selection.mode, Audience.adult);
      expect(selection.cardCount, 32);
    });
  });
}
