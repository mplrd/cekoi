import 'package:cekoi/domain/decks/card_length.dart';
import 'package:cekoi/domain/decks/deck_exchange.dart';
import 'package:cekoi/domain/decks/deck_name_length.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le format d'échange d'une catégorie du joueur.
///
/// Volontairement identique à celui de `assets/decks/` : un export s'importe
/// tel quel sur un autre téléphone, et une catégorie officielle bricolée à la
/// main s'importe aussi. Deux formats jumeaux finiraient par diverger.
void main() {
  group('exporter', () {
    test('produit le même format que les decks livrés', () {
      final json = encodeDeckExchange(
        const DeckExchange(
          name: 'Blagues de tonton',
          audience: Audience.adult,
          cards: [
            ExchangeCard(text: 'Le rhum arrangé', difficulty: Difficulty.easy),
            ExchangeCard(text: 'La belle-mère'),
          ],
        ),
      );

      expect(json['name'], 'Blagues de tonton');
      expect(json['audience'], 'adult');
      expect(json['cards'], [
        {'text': 'Le rhum arrangé', 'difficulty': 1},
        {'text': 'La belle-mère', 'difficulty': 2},
      ]);
    });

    test('un aller-retour ne perd rien', () {
      const avant = DeckExchange(
        name: 'Vacances',
        audience: Audience.family,
        cards: [
          ExchangeCard(text: 'Le camping', difficulty: Difficulty.hard),
        ],
      );

      final apres = parseDeckExchange(encodeDeckExchange(avant));

      expect(apres.name, avant.name);
      expect(apres.audience, avant.audience);
      expect(apres.cards.single.text, 'Le camping');
      expect(apres.cards.single.difficulty, Difficulty.hard);
    });
  });

  group('importer', () {
    test('lit un deck officiel tel qu’il est livré', () {
      final deck = parseDeckExchange(const {
        'id': 'animaux',
        'name': 'Animaux',
        'description': 'De la basse-cour à la savane.',
        'icon': 'pets',
        'audience': 'family',
        'minAge': 6,
        'contentVersion': 2,
        'isPremium': false,
        'sortOrder': 10,
        'cards': [
          {'text': 'Girafe', 'difficulty': 1},
        ],
      });

      expect(deck.name, 'Animaux');
      expect(deck.audience, Audience.family);
      expect(deck.cards.single.text, 'Girafe');
    });

    test('une carte trop longue est écartée, pas le fichier', () {
      // Le fichier peut venir d'une version antérieure de l'application, qui
      // ne bornait rien, ou d'un JSON écrit à la main. Refuser les trois cents
      // autres cartes pour une seule de soixante-et-un caractères serait la
      // pire des deux réponses — c'est la politique déjà tenue pour les cartes
      // vides et les doublons.
      final deck = parseDeckExchange({
        'name': 'Vacances',
        'audience': 'family',
        'cards': [
          {'text': 'a' * (maxCardTextLength + 1)},
          {'text': 'a' * maxCardTextLength},
          {'text': 'Le camping'},
        ],
      });

      expect(deck.cards.map((c) => c.text.length), [
        maxCardTextLength,
        'Le camping'.length,
      ]);
    });

    test('la difficulté absente vaut moyen', () {
      final deck = parseDeckExchange(const {
        'name': 'Vacances',
        'audience': 'family',
        'cards': [
          {'text': 'Le camping'},
        ],
      });

      expect(deck.cards.single.difficulty, Difficulty.medium);
    });

    test('les cartes vides sont écartées, pas importées à blanc', () {
      final deck = parseDeckExchange(const {
        'name': 'Vacances',
        'audience': 'family',
        'cards': [
          {'text': 'Le camping'},
          {'text': '   '},
          {'text': 'La plage'},
        ],
      });

      expect(deck.cards.map((c) => c.text), ['Le camping', 'La plage']);
    });

    test('les doublons sont écartés, au sens de R6.4', () {
      // Le fichier vient d'ailleurs : rien ne garantit qu'il a été produit par
      // l'application. Importer deux fois la même carte ferait mentir le
      // compteur, et le tirage n'en garderait qu'une.
      final deck = parseDeckExchange(const {
        'name': 'Vacances',
        'audience': 'family',
        'cards': [
          {'text': 'Le camping'},
          {'text': 'le  CAMPING'},
        ],
      });

      expect(deck.cards, hasLength(1));
    });

    test('une difficulté hors bornes retombe sur moyen', () {
      // Un fichier bricolé à la main ne doit pas faire échouer l'import
      // entier pour une valeur aberrante sur une carte.
      final deck = parseDeckExchange(const {
        'name': 'Vacances',
        'audience': 'family',
        'cards': [
          {'text': 'Le camping', 'difficulty': 9},
        ],
      });

      expect(deck.cards.single.difficulty, Difficulty.medium);
    });
  });

  group('ce qui rend un fichier inexploitable', () {
    test('sans nom', () {
      expect(
        () => parseDeckExchange(const {
          'audience': 'family',
          'cards': [
            {'text': 'Le camping'},
          ],
        }),
        throwsA(isA<DeckExchangeException>()),
      );
    });

    test('avec un nom trop long', () {
      // Le fichier vient d'ailleurs : d'une version antérieure qui ne bornait
      // rien, ou d'un JSON écrit à la main. Sans ce refus, l'import allait
      // jusqu'au dépôt, qui lève un `ArgumentError` — et l'écran ne rattrape
      // que `DeckExchangeException`. Le joueur aurait eu une trace technique
      // au lieu d'un message.
      //
      // Refusé plutôt que tronqué, et c'est la même ligne que le nom vide :
      // strict sur la structure, tolérant sur les cartes. Raccourcir à sa
      // place changerait ce qu'il a écrit sans le lui dire.
      expect(
        () => parseDeckExchange({
          'name': 'a' * (maxDeckNameLength + 1),
          'audience': 'family',
          'cards': const [
            {'text': 'Le camping'},
          ],
        }),
        throwsA(isA<DeckExchangeException>()),
      );
    });

    test('un nom juste à la borne passe', () {
      final deck = parseDeckExchange({
        'name': 'a' * maxDeckNameLength,
        'audience': 'family',
        'cards': const [
          {'text': 'Le camping'},
        ],
      });

      expect(deck.name, 'a' * maxDeckNameLength);
    });

    test('sans aucune carte utilisable', () {
      expect(
        () => parseDeckExchange(const {
          'name': 'Vacances',
          'audience': 'family',
          'cards': [
            {'text': '  '},
          ],
        }),
        throwsA(isA<DeckExchangeException>()),
      );
    });

    test('avec un public inconnu', () {
      expect(
        () => parseDeckExchange(const {
          'name': 'Vacances',
          'audience': 'martiens',
          'cards': [
            {'text': 'Le camping'},
          ],
        }),
        throwsA(isA<DeckExchangeException>()),
      );
    });

    test('avec des cartes qui ne sont pas une liste', () {
      expect(
        () => parseDeckExchange(const {
          'name': 'Vacances',
          'audience': 'family',
          'cards': 'Le camping',
        }),
        throwsA(isA<DeckExchangeException>()),
      );
    });

    test('un public absent vaut famille plutôt que de refuser', () {
      // Le cas du fichier écrit à la main : le mode le plus restrictif est
      // aussi le plus sûr, et il se change après import.
      final deck = parseDeckExchange(const {
        'name': 'Vacances',
        'cards': [
          {'text': 'Le camping'},
        ],
      });

      expect(deck.audience, Audience.family);
    });
  });
}
