import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/repositories/deck_repository.dart';
import 'package:cekoi/domain/decks/card_length.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DeckRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = DeckRepository(db);
  });
  tearDown(() => db.close());

  /// Une catégorie officielle, pour vérifier qu'elle n'est jamais touchée.
  Future<void> installOfficial(String id) async {
    await db
        .into(db.decks)
        .insert(
          DecksCompanion.insert(
            id: id,
            name: id,
            audience: Audience.family,
            minAge: MinAge.six.years,
            origin: DeckOrigin.official,
          ),
        );
    await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            id: '$id:officielle',
            deckId: id,
            cardText: 'Carte officielle',
            audience: Audience.family,
            difficulty: 2,
            origin: DeckOrigin.official,
          ),
        );
  }

  group('créer une catégorie', () {
    test('elle apparaît dans les catégories du joueur', () async {
      final deck = await repository.createCustomDeck(
        name: 'Blagues de tonton',
        audience: Audience.adult,
      );

      expect(deck.origin, DeckOrigin.custom);
      expect(deck.name, 'Blagues de tonton');
      expect(deck.audience, Audience.adult);
      expect(await repository.customDecks(), [deck]);
    });

    test("l'identifiant ne heurte jamais celui d'une officielle", () async {
      // Le seeder écrit par identifiant : une catégorie du joueur nommée comme
      // une officielle ferait de l'une l'ombre de l'autre.
      await installOfficial('animaux');

      final deck = await repository.createCustomDeck(
        name: 'Animaux',
        audience: Audience.family,
      );

      expect(deck.id, isNot('animaux'));
      expect(deck.id, startsWith('custom-'));
    });

    test('deux catégories de même nom restent distinctes', () async {
      final une = await repository.createCustomDeck(
        name: 'Vacances',
        audience: Audience.family,
      );
      final deux = await repository.createCustomDeck(
        name: 'Vacances',
        audience: Audience.family,
      );

      expect(une.id, isNot(deux.id));
      expect(await repository.customDecks(), hasLength(2));
    });

    test('un nom vide est refusé', () async {
      expect(
        () => repository.createCustomDeck(
          name: '   ',
          audience: Audience.family,
        ),
        throwsArgumentError,
      );
    });

    test('les officielles ne sont pas listées comme siennes', () async {
      await installOfficial('animaux');

      expect(await repository.customDecks(), isEmpty);
    });
  });

  group('renommer et supprimer une catégorie', () {
    test('renommer garde les cartes', () async {
      final deck = await repository.createCustomDeck(
        name: 'Vacances',
        audience: Audience.family,
      );
      await repository.addCustomCard(deckId: deck.id, text: 'Le camping');

      await repository.renameCustomDeck(deck.id, 'Souvenirs de vacances');

      final apres = (await repository.customDecks()).single;
      expect(apres.id, deck.id, reason: "L'identifiant ne bouge pas");
      expect(apres.name, 'Souvenirs de vacances');
      expect(await repository.cardsOfDeck(deck.id), hasLength(1));
    });

    test('supprimer emporte les cartes de la catégorie', () async {
      final deck = await repository.createCustomDeck(
        name: 'Vacances',
        audience: Audience.family,
      );
      await repository.addCustomCard(deckId: deck.id, text: 'Le camping');

      await repository.deleteCustomDeck(deck.id);

      expect(await repository.customDecks(), isEmpty);
      expect(await repository.cardsOfDeck(deck.id), isEmpty);
    });

    test('une catégorie officielle ne se supprime pas', () async {
      // La règle d'or : le contenu officiel se gère par le seeding, et une
      // suppression accidentelle le ferait revenir au prochain lancement en
      // laissant croire à un bug.
      await installOfficial('animaux');

      expect(
        () => repository.deleteCustomDeck('animaux'),
        throwsArgumentError,
      );
      expect(await repository.cardsOfDeck('animaux'), hasLength(1));
    });

    test('une catégorie officielle ne se renomme pas', () async {
      await installOfficial('animaux');

      expect(
        () => repository.renameCustomDeck('animaux', 'Les bêtes'),
        throwsArgumentError,
      );
    });
  });

  group('la longueur des cartes est bornée', () {
    /// Un mot d'un caractère de trop, sans espace : ni le repli sur plusieurs
    /// lignes ni le compteur du champ ne peuvent quoi que ce soit pour lui.
    final tropLongue = 'a' * (maxCardTextLength + 1);

    test('la borne vaut celle du contenu officiel', () {
      // `tool/import_decks.py` refuse au-delà depuis toujours, et
      // `docs/CONTENU.md` la documente. Deux nombres différents pour les
      // cartes d'une même partie auraient fini par diverger.
      expect(maxCardTextLength, 60);
      expect(cardTextFits('a' * maxCardTextLength), isTrue);
      expect(cardTextFits(tropLongue), isFalse);
    });

    test('les blancs ne comptent pas', () {
      // Un texte collé depuis ailleurs traîne souvent des espaces. C'est la
      // longueur de ce qui est **enregistré** qui compte.
      expect(cardTextFits('  ${'a' * maxCardTextLength}  '), isTrue);
    });

    test('une carte trop longue est refusée à l ajout', () async {
      final deck = await repository.createCustomDeck(
        name: 'Apéro',
        audience: Audience.family,
      );

      expect(
        () => repository.addCustomCard(deckId: deck.id, text: tropLongue),
        throwsArgumentError,
      );
      expect(await repository.cardsOfDeck(deck.id), isEmpty);
    });

    test('une carte trop longue est refusée à la correction', () async {
      // Le chemin de correction est distinct de celui de l'ajout : borner le
      // premier seulement laisserait entrer par le second.
      final deck = await repository.createCustomDeck(
        name: 'Apéro',
        audience: Audience.family,
      );
      final carte = await repository.addCustomCard(
        deckId: deck.id,
        text: 'Le rhum arrangé',
      );

      expect(
        () => repository.updateCustomCard(carte.id, text: tropLongue),
        throwsArgumentError,
      );
      final apres = await repository.cardsOfDeck(deck.id);
      expect(apres.single.text, 'Le rhum arrangé');
    });

    test('la borne exacte passe', () async {
      final deck = await repository.createCustomDeck(
        name: 'Apéro',
        audience: Audience.family,
      );
      final carte = await repository.addCustomCard(
        deckId: deck.id,
        text: 'a' * maxCardTextLength,
      );

      expect(carte.text.length, maxCardTextLength);
    });
  });

  group('cartes du joueur', () {
    test('une carte ajoutée hérite du public de sa catégorie', () async {
      final deck = await repository.createCustomDeck(
        name: 'Apéro',
        audience: Audience.adult,
      );

      final card = await repository.addCustomCard(
        deckId: deck.id,
        text: 'Le rhum arrangé',
      );

      expect(card.audience, Audience.adult);
      expect(card.origin, DeckOrigin.custom);
      expect(
        card.difficulty,
        Difficulty.medium,
        reason: 'défaut de CONTENU.md',
      );
    });

    test('la difficulté se choisit', () async {
      final deck = await repository.createCustomDeck(
        name: 'Apéro',
        audience: Audience.family,
      );

      final card = await repository.addCustomCard(
        deckId: deck.id,
        text: 'Le trac',
        difficulty: Difficulty.hard,
      );

      expect(card.difficulty, Difficulty.hard);
    });

    test('deux fois le même texte dans une catégorie est refusé', () async {
      // R6.4 : le tirage n'en garderait qu'une, et le compteur mentirait.
      final deck = await repository.createCustomDeck(
        name: 'Vacances',
        audience: Audience.family,
      );
      await repository.addCustomCard(deckId: deck.id, text: 'Le camping');

      expect(
        () => repository.addCustomCard(deckId: deck.id, text: 'le  camping'),
        throwsArgumentError,
      );
    });

    test('le même texte dans deux catégories est accepté', () async {
      // Le tirage dédoublonne à la volée (R6.4) : rien à interdire ici, et
      // deux catégories du joueur peuvent légitimement se recouper.
      final une = await repository.createCustomDeck(
        name: 'Vacances',
        audience: Audience.family,
      );
      final deux = await repository.createCustomDeck(
        name: 'Été',
        audience: Audience.family,
      );

      await repository.addCustomCard(deckId: une.id, text: 'Le camping');
      await repository.addCustomCard(deckId: deux.id, text: 'Le camping');

      expect(await repository.cardsOfDeck(deux.id), hasLength(1));
    });

    test('un texte vide est refusé', () async {
      final deck = await repository.createCustomDeck(
        name: 'Vacances',
        audience: Audience.family,
      );

      expect(
        () => repository.addCustomCard(deckId: deck.id, text: '  '),
        throwsArgumentError,
      );
    });

    test('aucune carte ne s’ajoute à une catégorie officielle', () async {
      await installOfficial('animaux');

      expect(
        () => repository.addCustomCard(deckId: 'animaux', text: 'Girafon'),
        throwsArgumentError,
      );
    });

    test('modifier une carte garde son identité', () async {
      // Corriger une faute de frappe ne doit pas faire disparaître la carte
      // d'une partie en cours qui la référence par identifiant.
      final deck = await repository.createCustomDeck(
        name: 'Vacances',
        audience: Audience.family,
      );
      final card = await repository.addCustomCard(
        deckId: deck.id,
        text: 'Le campign',
      );

      await repository.updateCustomCard(
        card.id,
        text: 'Le camping',
        difficulty: Difficulty.easy,
      );

      final apres = (await repository.cardsOfDeck(deck.id)).single;
      expect(apres.id, card.id);
      expect(apres.text, 'Le camping');
      expect(apres.difficulty, Difficulty.easy);
    });

    test('supprimer une carte laisse les autres', () async {
      final deck = await repository.createCustomDeck(
        name: 'Vacances',
        audience: Audience.family,
      );
      final une = await repository.addCustomCard(
        deckId: deck.id,
        text: 'Le camping',
      );
      await repository.addCustomCard(deckId: deck.id, text: 'La plage');

      await repository.deleteCustomCard(une.id);

      final restantes = await repository.cardsOfDeck(deck.id);
      expect(restantes.map((c) => c.text), ['La plage']);
    });

    test('une carte officielle ne se modifie ni ne se supprime', () async {
      await installOfficial('animaux');

      expect(
        () => repository.deleteCustomCard('animaux:officielle'),
        throwsArgumentError,
      );
      expect(
        () => repository.updateCustomCard(
          'animaux:officielle',
          text: 'Autre chose',
        ),
        throwsArgumentError,
      );
    });
  });

  group('les catégories du joueur entrent dans le jeu', () {
    test('elles sont tirables dans leur mode', () async {
      final deck = await repository.createCustomDeck(
        name: 'Blagues de tonton',
        audience: Audience.adult,
      );
      await repository.addCustomCard(deckId: deck.id, text: 'Le rhum arrangé');

      final famille = await repository.byMode(Audience.family);
      final adultes = await repository.byMode(Audience.adult);

      expect(famille.map((d) => d.id), isNot(contains(deck.id)));
      expect(adultes.map((d) => d.id), contains(deck.id));
      expect(
        (await repository.cardsForMode(Audience.adult)).map((c) => c.text),
        contains('Le rhum arrangé'),
      );
    });

    test('elles ne sont jamais premium', () async {
      // Le déblocage payant ne concerne que le contenu officiel : verrouiller
      // ce que le joueur a écrit lui-même n'aurait aucun sens.
      final deck = await repository.createCustomDeck(
        name: 'Vacances',
        audience: Audience.family,
      );

      expect(deck.isPremium, isFalse);
    });
  });
}
