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

/// Les noms de repli, tels que la présentation les fournirait.
List<String> _fallbacks(int count) => [
  for (var i = 1; i <= count; i++) 'Équipe $i',
];

void main() {
  group('R6 — les défauts dépendent du mode choisi', () {
    test('le mode Famille ouvre sur 60 secondes et un nombre auto', () {
      final setup = setupForMode(Audience.family);

      expect(setup.mode, Audience.family);
      expect(setup.turnDuration, const Duration(seconds: 60));
      expect(setup.cardCount, isNull, reason: 'auto');
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

    test('les équipes survivent au changement de mode', () {
      // On revient à la première étape depuis n'importe où. Reperdre les noms
      // d'équipe parce qu'on a touché au mode serait une punition : ils n'ont
      // rien à voir avec le contenu.
      final composed = setupForMode(
        Audience.family,
      ).withTeamCount(3).renameTeam(0, 'Les Rouges').renameTeam(2, 'Les Verts');

      final switched = composed.withMode(Audience.adult);

      expect(switched.teamCount, 3);
      expect(switched.teamNames, ['Les Rouges', '', 'Les Verts']);
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

    test("les équipes déjà nommées survivent au choix d'un profil", () {
      // On peut revenir en arrière depuis l'écran des équipes : reperdre les
      // noms à cette occasion serait rageant.
      final setup = setupForMode(Audience.family)
          .withTeamCount(3)
          .renameTeam(1, 'Les Bleus')
          .withProfile(_profile('mix'), _decks);

      expect(setup.teamCount, 3);
      expect(setup.teamNames[1], 'Les Bleus');
    });

    test('les réglages du profil sont appliqués, pas que ses filtres', () {
      // Profil de test et non profil livré : les trois profils intégrés ont
      // `cardCount: null`, soit exactement le défaut du mode Famille. Sur eux,
      // ne pas appliquer ce champ serait inobservable — et R7.5 promet qu'un
      // profil s'ajoute en donnée seule.
      const dense = GameProfile(
        id: 'dense',
        mode: Audience.family,
        maxDeckAge: MinAge.ten,
        difficulties: {Difficulty.hard},
        turnDuration: Duration(seconds: 30),
        cardCount: 24,
      );

      final setup = setupForMode(Audience.family).withProfile(dense, _decks);

      expect(setup.cardCount, 24);
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

    test('un nombre de cartes sous le minimum de R6.2 est refusé', () {
      final setup = setupForMode(Audience.family);

      expect(() => setup.withCardCount(11), throwsArgumentError);
      expect(setup.withCardCount(12).cardCount, 12);
    });

    test('le mode auto se rétablit en repassant à null', () {
      final setup = setupForMode(Audience.adult).withCardCount(null);

      expect(setup.cardCount, isNull);
      expect(setup.resolvedCardCount, GameConfig.autoCardCount(2));
    });

    test("R6.1 — le nombre de cartes résolu suit le nombre d'équipes", () {
      final setup = setupForMode(Audience.family).withTeamCount(4);

      expect(setup.resolvedCardCount, GameConfig.autoCardCount(4));
      expect(
        setup.resolvedCardCount,
        isNot(setupForMode(Audience.family).resolvedCardCount),
        reason: 'Quatre équipes ne jouent pas le même paquet que deux',
      );
      expect(setup.withCardCount(24).resolvedCardCount, 24);
    });
  });

  group('R8.3 — les équipes tiennent en un nombre et des noms', () {
    test('une configuration neuve ouvre sur deux équipes sans nom', () {
      final setup = setupForMode(Audience.family);

      expect(setup.teamCount, 2);
      expect(setup.teamNames, ['', '']);
    });

    test('un nom vide prend son libellé par défaut', () {
      final teams = setupForMode(
        Audience.family,
      ).renameTeam(0, 'Les Rouges').teamsNamed(_fallbacks(2));

      expect(teams.map((t) => t.name), ['Les Rouges', 'Équipe 2']);
    });

    test("un nom fait uniquement d'espaces vaut un nom vide", () {
      final teams = setupForMode(
        Audience.family,
      ).renameTeam(0, '   ').teamsNamed(_fallbacks(2));

      expect(teams.first.name, 'Équipe 1');
    });

    test('les espaces de bord sont mangés au lancement', () {
      // Ils ne le sont pas à la frappe : couper l'espace qu'on vient de taper
      // entre deux mots ferait sauter le curseur du champ.
      final teams = setupForMode(
        Audience.family,
      ).renameTeam(0, '  Les Rouges  ').teamsNamed(_fallbacks(2));

      expect(teams.first.name, 'Les Rouges');
    });

    test('renommer hors des équipes existantes est refusé', () {
      final setup = setupForMode(Audience.family);

      expect(() => setup.renameTeam(2, 'Trop loin'), throwsArgumentError);
      expect(() => setup.renameTeam(-1, 'Trop tôt'), throwsArgumentError);
    });

    test('il faut un nom de repli par équipe', () {
      final setup = setupForMode(Audience.family).withTeamCount(3);

      expect(() => setup.teamsNamed(_fallbacks(2)), throwsArgumentError);
    });
  });

  group("R8.4 — les noms survivent au changement de nombre d'équipes", () {
    test('cas limite 14 : passer de 2 à 3 garde les deux noms', () {
      final setup = setupForMode(
        Audience.family,
      ).renameTeam(0, 'Les Rouges').renameTeam(1, 'Les Bleus').withTeamCount(3);

      expect(setup.teamNames, ['Les Rouges', 'Les Bleus', '']);
      expect(
        setup.teamsNamed(_fallbacks(3)).map((t) => t.name),
        ['Les Rouges', 'Les Bleus', 'Équipe 3'],
      );
    });

    test('redescendre coupe la dernière, et elle ne revient pas', () {
      // La retenir ferait réapparaître un nom que le joueur a cru supprimer.
      final setup = setupForMode(Audience.family)
          .withTeamCount(3)
          .renameTeam(2, 'Les Verts')
          .withTeamCount(2)
          .withTeamCount(3);

      expect(setup.teamNames, ['', '', '']);
    });

    test('moins de deux équipes est refusé (R8.5)', () {
      final setup = setupForMode(Audience.family);

      expect(() => setup.withTeamCount(1), throwsArgumentError);
      expect(() => setup.withTeamCount(0), throwsArgumentError);
    });

    test("R8.1 — le nombre d'équipes n'a pas de plafond", () {
      final setup = setupForMode(Audience.family).withTeamCount(12);

      expect(setup.teamCount, 12);
      expect(setup.teamsNamed(_fallbacks(12)), hasLength(12));
    });
  });

  group('conditions de lancement', () {
    GameSetup ready() => setupForMode(Audience.family).toggleDeck('animaux');

    test('une configuration complète peut démarrer', () {
      expect(ready().canStart, isTrue);
    });

    test('sans catégorie sélectionnée, rien ne démarre', () {
      final setup = setupForMode(Audience.family);

      expect(setup.deckIds, isEmpty);
      expect(setup.canStart, isFalse);
    });

    test('la configuration produite reprend tous les réglages', () {
      final config = ready()
          .withTurnDuration(const Duration(seconds: 45))
          .withCardCount(24)
          .toConfig();

      expect(config.mode, Audience.family);
      expect(config.deckIds, ['animaux']);
      expect(config.turnDuration, const Duration(seconds: 45));
      expect(config.cardCount, 24);
      expect(config.profileId, isNull);
      expect(config.difficulties, Difficulty.values.toSet());
    });

    test('les difficultés du profil sont figées dans la configuration', () {
      // « Rejouer avec les mêmes réglages » retire un paquet : sans cette
      // copie, il faudrait retrouver un profil qui a pu changer de définition
      // entre deux versions de l'application.
      final config = setupForMode(
        Audience.family,
      ).withProfile(_profile('minis'), _decks).toConfig();

      expect(config.difficulties, {Difficulty.easy});
    });

    test('le profil retenu est reporté dans la configuration', () {
      final config = setupForMode(
        Audience.family,
      ).withProfile(_profile('mix'), _decks).toConfig();

      expect(config.profileId, 'mix');
    });
  });
}
