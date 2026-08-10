import 'dart:math';

import 'package:cekoi/domain/engine/team_builder.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/entities/min_age.dart';
import 'package:cekoi/domain/rules/game_profiles.dart';
import 'package:cekoi/domain/setup/game_setup.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

final List<Deck> _decks = [
  testDeck('animaux'),
  testDeck('metiers', minAge: MinAge.ten),
  testDeck('apero', minAge: MinAge.eighteen, audience: Audience.adult),
];

GameProfile _profile(String id) =>
    builtInProfiles.firstWhere((p) => p.id == id);

/// Six joueurs en deux équipes dont le curseur de narrateur **n'est pas** à
/// zéro, seule façon d'observer qu'une opération le remet bien à zéro.
///
/// Passe par `withTeams`, qui est public : rien dans le parcours ne produit
/// aujourd'hui un curseur décalé, mais la garde existe pour le jour où — et
/// une garde qu'aucun test ne peut voir tomber ne protège rien.
GameSetup _decalees() {
  final players = [for (var i = 0; i < 6; i++) 'joueur-$i'];
  return _withPlayers(setupForMode(Audience.family), 6).withTeams([
    testTeam('A', 3).copyWith(
      playerIds: players.take(3).toList(),
      narratorIndex: 2,
    ),
    testTeam('B', 3).copyWith(
      playerIds: players.skip(3).toList(),
      narratorIndex: 1,
    ),
  ]);
}

/// Une configuration prête à composer les équipes.
GameSetup _withPlayers(GameSetup setup, int count, {int children = 0}) {
  var next = setup;
  for (var i = 0; i < count; i++) {
    next = next.withPlayer(
      testPlayer('joueur-$i', isChild: i < children),
    );
  }
  return next;
}

void main() {
  group('R6 — les défauts dépendent du mode choisi', () {
    test('le mode Famille ouvre sur 60 secondes et un nombre auto', () {
      final setup = setupForMode(Audience.family);

      expect(setup.mode, Audience.family);
      expect(setup.turnDuration, const Duration(seconds: 60));
      expect(setup.cardCount, isNull, reason: 'auto');
      expect(setup.roundCount, 3);
      expect(setup.teamCount, 2);
      expect(setup.difficulties, Difficulty.values.toSet());
      expect(setup.deckIds, isEmpty);
    });

    test('le mode Entre adultes ouvre sur 45 secondes et 32 cartes', () {
      final setup = setupForMode(Audience.adult);

      expect(setup.turnDuration, const Duration(seconds: 45));
      expect(setup.cardCount, 32);
    });

    test('changer de mode repart des défauts du nouveau mode', () {
      // R7.2 : le mode ne change pas en cours de partie. Il peut changer en
      // cours de configuration, et tout ce qui dépend du vivier doit suivre —
      // « apero » n'existe même pas en mode Famille (R7.1).
      final custom = setupForMode(Audience.adult)
          .toggleDeck('apero')
          .withTurnDuration(const Duration(seconds: 90))
          .withCardCount(48);

      final switched = custom.withMode(Audience.family);

      expect(switched.mode, Audience.family);
      expect(switched.deckIds, isEmpty, reason: 'catégorie hors du vivier');
      expect(switched.turnDuration, const Duration(seconds: 60));
      expect(switched.cardCount, isNull, reason: 'auto, défaut famille');
      expect(custom.deckIds, ['apero'], reason: "l'ancienne reste intacte");
    });

    test('un profil ne survit pas au changement de mode', () {
      // Un profil vise un mode (R7.5) et `withProfile` refuse les autres. Le
      // laisser en place afficherait « Les minis » sur une partie adultes, et
      // `toConfig` emporterait ce mensonge dans la partie.
      final switched = setupForMode(
        Audience.family,
      ).withProfile(_profile('minis'), _decks).withMode(Audience.adult);

      expect(switched.profileId, isNull);
      expect(switched.isCustomSelection, isTrue);
      expect(switched.difficulties, Difficulty.values.toSet());
    });

    test('les joueurs et les équipes survivent au changement de mode', () {
      // On revient à la première étape depuis n'importe où. Reperdre huit noms
      // et leur répartition parce qu'on a touché au mode serait une punition :
      // l'effectif n'a rien à voir avec le contenu.
      final composed =
          _withPlayers(setupForMode(Audience.family), 8, children: 2)
              .withTeamCount(3)
              .withProposedTeams(
                names: ['A', 'B', 'C'],
                random: Random(1),
              );

      final switched = composed.withMode(Audience.adult);

      expect(switched.players, composed.players);
      expect(switched.teamCount, 3);
      expect(switched.teams, composed.teams);
    });

    test('rechoisir le mode déjà en cours ne touche à rien', () {
      // L'écran du mode se retraverse en revenant en arrière : retaper le même
      // bouton ne doit pas faire fondre la sélection faite depuis.
      final setup = setupForMode(
        Audience.family,
      ).toggleDeck('animaux').withTurnDuration(const Duration(seconds: 30));

      final again = setup.withMode(Audience.family);

      expect(again.deckIds, ['animaux']);
      expect(again.turnDuration, const Duration(seconds: 30));
    });
  });

  group("R7.5 — choisir un profil configure tout d'un coup", () {
    test('les catégories, les difficultés et le chrono suivent le profil', () {
      final setup = setupForMode(
        Audience.family,
      ).withProfile(_profile('minis'), _decks);

      expect(setup.profileId, 'minis');
      expect(setup.deckIds, ['animaux']);
      expect(setup.difficulties, {Difficulty.easy});
      expect(setup.turnDuration, const Duration(seconds: 90));
    });

    test("les joueurs déjà saisis survivent au choix d'un profil", () {
      // On peut revenir en arrière depuis l'écran des équipes : reperdre la
      // liste des joueurs à cette occasion serait rageant.
      final setup = _withPlayers(
        setupForMode(Audience.family),
        4,
      ).withProfile(_profile('mix'), _decks);

      expect(setup.players, hasLength(4));
    });

    test('les réglages du profil sont appliqués, pas que ses filtres', () {
      // Profil de test et non profil livré : les trois profils intégrés ont
      // `cardCount: null` et `roundCount: 3`, soit exactement les défauts du
      // mode Famille. Sur eux, ne pas appliquer ces deux champs serait
      // inobservable — et R7.5 promet qu'un profil s'ajoute en donnée seule.
      const dense = GameProfile(
        id: 'dense',
        mode: Audience.family,
        maxDeckAge: MinAge.ten,
        difficulties: {Difficulty.hard},
        turnDuration: Duration(seconds: 30),
        cardCount: 24,
        roundCount: 2,
      );

      final setup = setupForMode(Audience.family).withProfile(dense, _decks);

      expect(setup.cardCount, 24);
      expect(setup.roundCount, 2);
      expect(setup.turnDuration, const Duration(seconds: 30));
      expect(setup.difficulties, {Difficulty.hard});
      expect(setup.deckIds, ['animaux', 'metiers']);
    });

    test('R7.6 — cocher une catégorie fait passer en personnalisé', () {
      final setup = setupForMode(
        Audience.family,
      ).withProfile(_profile('minis'), _decks).toggleDeck('metiers');

      expect(setup.profileId, isNull);
      expect(setup.isCustomSelection, isTrue);
      expect(setup.deckIds, ['animaux', 'metiers']);
      expect(setup.difficulties, Difficulty.values.toSet());
      expect(
        setup.turnDuration,
        const Duration(seconds: 90),
        reason: 'Le chrono du profil est un réglage, pas un filtre',
      );
    });

    test('cas limite 12 — décocher une catégorie la retire vraiment', () {
      // L'autre branche de `toggleDeck`. Sans ce test, la rendre purement
      // additive laisse la suite verte : le compteur de cartes de l'écran
      // dédoublonne les identifiants et masque le défaut.
      final setup = setupForMode(
        Audience.family,
      ).withProfile(_profile('ados'), _decks);
      expect(setup.deckIds, ['animaux', 'metiers'], reason: 'point de départ');

      final custom = setup.toggleDeck('animaux');

      expect(custom.deckIds, ['metiers']);
      expect(custom.profileId, isNull);
      expect(
        custom.difficulties,
        Difficulty.values.toSet(),
        reason: "Le profil cesse d'imposer sa restriction de difficulté",
      );
    });

    test('décocher puis recocher remet la catégorie en fin de liste', () {
      // Aller-retour volontairement asymétrique : si les deux appels se
      // compensaient, le test passerait quelle que soit l'implémentation.
      final setup = setupForMode(
        Audience.family,
      ).withProfile(_profile('mix'), _decks);
      expect(setup.deckIds, ['animaux', 'metiers']);

      final custom = setup.toggleDeck('animaux').toggleDeck('animaux');

      expect(custom.deckIds, ['metiers', 'animaux']);
      expect(custom.profileId, isNull);
    });
  });

  group('R6 — les réglages restent dans leurs bornes', () {
    test('une durée hors de 15 à 180 secondes est refusée', () {
      final setup = setupForMode(Audience.family);

      expect(
        () => setup.withTurnDuration(const Duration(seconds: 5)),
        throwsArgumentError,
      );
      expect(
        () => setup.withTurnDuration(const Duration(seconds: 200)),
        throwsArgumentError,
      );
      expect(
        setup.withTurnDuration(const Duration(seconds: 15)).turnDuration,
        const Duration(seconds: 15),
      );
    });

    test('un nombre de manches autre que 2 ou 3 est refusé', () {
      final setup = setupForMode(Audience.family);

      expect(() => setup.withRoundCount(1), throwsArgumentError);
      expect(() => setup.withRoundCount(4), throwsArgumentError);
      expect(setup.withRoundCount(2).roundCount, 2);
    });

    test('un nombre de cartes sous le minimum de R6.2 est refusé', () {
      final setup = setupForMode(Audience.family);

      expect(() => setup.withCardCount(11), throwsArgumentError);
      expect(setup.withCardCount(12).cardCount, 12);
    });

    test('le mode auto se rétablit en repassant à null', () {
      final setup = setupForMode(Audience.adult).withCardCount(null);

      expect(setup.cardCount, isNull);
      expect(setup.resolvedCardCount, GameConfig.autoCardCount(0));
    });

    test('le nombre de cartes résolu suit le nombre de joueurs', () {
      final setup = _withPlayers(setupForMode(Audience.family), 8);

      expect(setup.resolvedCardCount, GameConfig.autoCardCount(8));
      expect(setup.withCardCount(24).resolvedCardCount, 24);
    });
  });

  group('saisie des joueurs', () {
    test("les joueurs s'ajoutent dans leur ordre de saisie", () {
      final setup = _withPlayers(setupForMode(Audience.family), 3);

      expect(setup.players.map((p) => p.name), [
        'joueur-0',
        'joueur-1',
        'joueur-2',
      ]);
    });

    test('un joueur se marque et se démarque enfant', () {
      var setup = _withPlayers(setupForMode(Audience.family), 2);
      setup = setup.toggleChild('joueur-0');

      expect(setup.players.first.isChild, isTrue);
      expect(setup.toggleChild('joueur-0').players.first.isChild, isFalse);
    });

    test('retirer un joueur le retire aussi des équipes déjà composées', () {
      // Une équipe qui référencerait un joueur disparu ferait planter le
      // lancement de la partie, loin d'ici.
      final setup = _withPlayers(setupForMode(Audience.family), 4)
          .withProposedTeams(names: ['A', 'B'], random: Random(1))
          .withoutPlayer('joueur-0');

      expect(setup.players, hasLength(3));
      expect(
        [for (final team in setup.teams) ...team.playerIds],
        isNot(contains('joueur-0')),
      );
      expect(
        setup.canStart,
        isFalse,
        reason: 'Une équipe est tombée à un joueur (R8.5)',
      );
    });

    test('un même joueur ne peut pas être ajouté deux fois', () {
      // Le doublon serait refusé bien plus tard, à la composition, sur un
      // message qui ne désignerait plus l'écran fautif.
      final setup = setupForMode(
        Audience.family,
      ).withPlayer(testPlayer('lea'));

      expect(() => setup.withPlayer(testPlayer('lea')), throwsArgumentError);
    });

    test('deux joueurs de même nom sont acceptés mais distincts', () {
      // Deux « Papa » à la même table, ça arrive. Ce sont les identifiants
      // qui doivent différer, pas les noms.
      final setup = setupForMode(
        Audience.family,
      ).withPlayer(testPlayer('papa-1')).withPlayer(testPlayer('papa-2'));

      expect(setup.players.map((p) => p.id).toSet(), hasLength(2));
    });
  });

  group('R8 — composition des équipes', () {
    test('proposer exige assez de joueurs pour deux équipes de deux', () {
      final short = _withPlayers(setupForMode(Audience.family), 3);
      expect(short.canProposeTeams, isFalse);

      final enough = _withPlayers(setupForMode(Audience.family), 4);
      expect(enough.canProposeTeams, isTrue);
    });

    test('la proposition répartit les joueurs saisis', () {
      final setup = _withPlayers(
        setupForMode(Audience.family),
        8,
        children: 2,
      ).withProposedTeams(names: ['Rouges', 'Bleus'], random: Random(3));

      expect(setup.teams, hasLength(2));
      expect(setup.teams.map((t) => t.name), ['Rouges', 'Bleus']);
      expect(
        [for (final team in setup.teams) ...team.playerIds],
        hasLength(8),
      );
    });

    test("changer le nombre d'équipes invalide la composition", () {
      // La garder afficherait deux équipes alors que le joueur en demande
      // trois : la relance est explicite, l'incohérence ne l'est pas.
      final setup = _withPlayers(setupForMode(Audience.family), 8)
          .withProposedTeams(names: ['A', 'B'], random: Random(1))
          .withTeamCount(3);

      expect(setup.teamCount, 3);
      expect(setup.teams, isEmpty);
    });

    test("un joueur se déplace d'une équipe à l'autre", () {
      final setup = _withPlayers(
        setupForMode(Audience.family),
        6,
      ).withProposedTeams(names: ['A', 'B'], random: Random(1));
      final moved = setup.teams.first.playerIds.first;

      final after = setup.movePlayer(moved, toTeamId: setup.teams.last.id);

      expect(after.teams.first.playerIds, isNot(contains(moved)));
      expect(after.teams.last.playerIds, contains(moved));
      expect(
        [for (final team in after.teams) ...team.playerIds],
        hasLength(6),
        reason: 'Aucun joueur perdu ni dupliqué',
      );
    });

    test('déplacer un joueur dans son équipe actuelle ne change rien', () {
      final setup = _withPlayers(
        setupForMode(Audience.family),
        6,
      ).withProposedTeams(names: ['A', 'B'], random: Random(1));
      final stay = setup.teams.first.playerIds.first;

      expect(setup.movePlayer(stay, toTeamId: setup.teams.first.id), setup);
    });

    test('le curseur de narrateur repart de zéro après un déplacement', () {
      // Sinon un curseur pointerait au-delà d'une équipe qui a rétréci.
      //
      // Fixture volontairement décalée : `withProposedTeams` laisse toujours
      // le curseur à zéro, donc partir d'une composition proposée rendrait
      // l'assertion vraie avant même l'appel, pour une raison mécanique.
      final setup = _decalees();
      expect(
        setup.teams.map((t) => t.narratorIndex),
        [2, 1],
        reason: 'point de départ observable',
      );

      final after = setup.movePlayer('joueur-0', toTeamId: 'B');

      expect(after.teams.map((t) => t.narratorIndex), [0, 0]);
    });

    test('le curseur repart aussi de zéro après un retrait de joueur', () {
      // Même raison : c'est le retrait qui fait rétrécir l'équipe.
      final after = _decalees().withoutPlayer('joueur-0');

      expect(after.teams.map((t) => t.narratorIndex), [0, 0]);
    });

    test('une équipe se renomme', () {
      final setup = _withPlayers(
        setupForMode(Audience.family),
        4,
      ).withProposedTeams(names: ['A', 'B'], random: Random(1));

      final renamed = setup.renameTeam(setup.teams.first.id, 'Les Zèbres');

      expect(renamed.teams.first.name, 'Les Zèbres');
      expect(renamed.teams.last.name, 'B');
    });
  });

  group('conditions de lancement', () {
    GameSetup ready() => _withPlayers(setupForMode(Audience.family), 4)
        .toggleDeck('animaux')
        .withProposedTeams(names: ['A', 'B'], random: Random(1));

    test('une configuration complète peut démarrer', () {
      expect(ready().canStart, isTrue);
    });

    test('sans catégorie sélectionnée, rien ne démarre', () {
      final setup = _withPlayers(
        setupForMode(Audience.family),
        4,
      ).withProposedTeams(names: ['A', 'B'], random: Random(1));

      expect(setup.deckIds, isEmpty);
      expect(setup.canStart, isFalse);
    });

    test('une équipe citant un joueur inconnu bloque le lancement', () {
      // Effectifs volontairement valides : sans ça, c'est la garde de R8.5 qui
      // répond et celle-ci n'est jamais atteinte. Une référence fantôme ferait
      // échouer `startGame` bien plus loin, sur un message qui ne désignerait
      // plus l'écran fautif.
      final setup = _withPlayers(setupForMode(Audience.family), 4)
          .toggleDeck('animaux')
          .withTeams([
            testTeam('A', 2).copyWith(playerIds: ['joueur-0', 'joueur-1']),
            testTeam('B', 2).copyWith(playerIds: ['joueur-2', 'fantome']),
          ]);

      expect(
        setup.teams.every((t) => t.playerIds.length >= minimumTeamSize),
        isTrue,
        reason: "Ce n'est pas R8.5 qui doit répondre ici",
      );
      expect(setup.canStart, isFalse);
    });

    test('sans composition, rien ne démarre', () {
      final setup = _withPlayers(
        setupForMode(Audience.family),
        4,
      ).toggleDeck('animaux');

      expect(setup.teams, isEmpty);
      expect(setup.canStart, isFalse);
    });

    test('une équipe à un seul joueur bloque le lancement (R8.5)', () {
      final setup = ready();
      final lonely = setup.teams.first.playerIds.first;

      final broken = setup.movePlayer(lonely, toTeamId: setup.teams.last.id);

      expect(broken.teams.first.playerIds, hasLength(1));
      expect(broken.canStart, isFalse);
    });

    test('la configuration produite reprend tous les réglages', () {
      final config = ready()
          .withTurnDuration(const Duration(seconds: 45))
          .withRoundCount(2)
          .withCardCount(24)
          .toConfig();

      expect(config.mode, Audience.family);
      expect(config.deckIds, ['animaux']);
      expect(config.turnDuration, const Duration(seconds: 45));
      expect(config.roundCount, 2);
      expect(config.cardCount, 24);
      expect(config.profileId, isNull);
      expect(config.difficulties, Difficulty.values.toSet());
    });

    test('les difficultés du profil sont figées dans la configuration', () {
      // « Rejouer avec les mêmes réglages » retire un paquet : sans cette
      // copie, il faudrait retrouver un profil qui a pu changer de définition
      // entre deux versions de l'application.
      final config = _withPlayers(setupForMode(Audience.family), 4)
          .withProfile(_profile('minis'), _decks)
          .withProposedTeams(names: ['A', 'B'], random: Random(1))
          .toConfig();

      expect(config.difficulties, {Difficulty.easy});
    });

    test('le profil retenu est reporté dans la configuration', () {
      final config = _withPlayers(setupForMode(Audience.family), 4)
          .withProfile(_profile('mix'), _decks)
          .withProposedTeams(names: ['A', 'B'], random: Random(1))
          .toConfig();

      expect(config.profileId, 'mix');
    });
  });
}
