import 'dart:math';

import 'package:cekoi/domain/engine/team_builder.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/entities/player.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:cekoi/domain/rules/game_profiles.dart';
import 'package:cekoi/domain/rules/round.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_setup.freezed.dart';

/// Une partie en cours de configuration, au fil des cinq étapes.
///
/// Dart pur et immuable, comme le moteur : le parcours de configuration est
/// une suite de transformations testables sans interface. L'écran ne fait
/// qu'appeler ces méthodes et afficher le résultat.
///
/// Les libellés n'y figurent pas — noms d'équipe compris, qui sont fournis par
/// l'appelant depuis l'ARB.
@freezed
abstract class GameSetup with _$GameSetup {
  const factory GameSetup({
    required Audience mode,
    required List<String> deckIds,
    required Set<Difficulty> difficulties,
    required Duration turnDuration,
    required int roundCount,

    /// `null` signifie *auto* (R6.1).
    int? cardCount,

    /// Profil retenu, `null` dès que la sélection est personnalisée (R7.6).
    String? profileId,
    @Default(<Player>[]) List<Player> players,
    @Default(minimumTeamCount) int teamCount,
    @Default(<Team>[]) List<Team> teams,
  }) = _GameSetup;

  const GameSetup._();

  /// Vrai tant qu'aucun profil ne pilote la sélection (R7.6).
  bool get isCustomSelection => profileId == null;

  /// Nombre de cartes effectif pour l'effectif saisi (R6.1).
  int get resolvedCardCount =>
      cardCount ??
      GameConfig.autoCardCount(
        players.length,
      );

  /// Assez de joueurs pour remplir le nombre d'équipes demandé (R8.5).
  bool get canProposeTeams => players.length >= teamCount * minimumTeamSize;

  /// Tout ce que R8.5 et R6.2 exigent avant de lancer.
  ///
  /// Le vivier de cartes, lui, n'est pas connu d'ici : il dépend de la base.
  /// C'est l'appelant qui confronte [resolvedCardCount] au tirage réel.
  bool get canStart {
    if (deckIds.isEmpty) return false;
    if (teams.length < minimumTeamCount) return false;
    if (teams.any((t) => t.playerIds.length < minimumTeamSize)) return false;

    final known = {for (final player in players) player.id};
    return teams.every((t) => t.playerIds.every(known.contains));
  }

  /// Change le mode de contenu.
  ///
  /// Tout ce qui dépend du vivier repart des défauts du nouveau mode : les
  /// catégories retenues n'y existent peut-être pas, et les réglages par
  /// défaut diffèrent (R6, R7.1). Les **joueurs et les équipes survivent** :
  /// ils n'ont rien à voir avec le contenu, et les resaisir parce qu'on est
  /// revenu à la première étape serait une punition.
  ///
  /// Retaper le mode déjà choisi ne change rien du tout.
  GameSetup withMode(Audience mode) {
    if (mode == this.mode) return this;
    return setupForMode(mode).copyWith(
      players: players,
      teamCount: teamCount,
      teams: teams,
    );
  }

  /// Applique un profil : catégories, difficultés et réglages d'un coup
  /// (R7.5). Les joueurs déjà saisis sont conservés.
  GameSetup withProfile(GameProfile profile, List<Deck> decks) {
    if (profile.mode != mode) {
      throw ArgumentError.value(
        profile.id,
        'profile',
        'Le profil vise le mode ${profile.mode.name}, la partie le mode '
            '${mode.name}',
      );
    }

    final selection = selectionFor(profile, decks);
    return copyWith(
      profileId: profile.id,
      deckIds: selection.deckIds,
      difficulties: selection.difficulties,
      turnDuration: selection.turnDuration,
      roundCount: selection.roundCount,
      cardCount: selection.cardCount,
    );
  }

  /// Coche ou décoche une catégorie.
  ///
  /// Fait passer la sélection en « personnalisé » : les filtres du profil ne
  /// s'appliquent plus, ses réglages restent (R7.6).
  GameSetup toggleDeck(String deckId) => copyWith(
    deckIds: deckIds.contains(deckId)
        ? [
            for (final id in deckIds)
              if (id != deckId) id,
          ]
        : [...deckIds, deckId],
    profileId: null,
    difficulties: Difficulty.values.toSet(),
  );

  GameSetup withTurnDuration(Duration duration) {
    if (!GameConfig.isTurnDurationAllowed(duration)) {
      throw ArgumentError.value(
        duration,
        'duration',
        'La durée du tour tient entre '
            '${GameConfig.minimumTurnDuration.inSeconds} et '
            '${GameConfig.maximumTurnDuration.inSeconds} secondes (R6)',
      );
    }
    return copyWith(turnDuration: duration);
  }

  GameSetup withRoundCount(int count) {
    if (!Round.allowedCounts.contains(count)) {
      throw ArgumentError.value(
        count,
        'count',
        'Le nombre de manches vaut ${Round.allowedCounts.join(' ou ')} (R2.2)',
      );
    }
    return copyWith(roundCount: count);
  }

  /// [count] à `null` rétablit le mode auto (R6.1).
  GameSetup withCardCount(int? count) {
    if (count != null && count < GameConfig.minimumCardCount) {
      throw ArgumentError.value(
        count,
        'count',
        'Une partie demande au moins ${GameConfig.minimumCardCount} '
            'cartes (R6.2)',
      );
    }
    return copyWith(cardCount: count);
  }

  GameSetup withPlayer(Player player) {
    if (players.any((p) => p.id == player.id)) {
      throw ArgumentError.value(
        player.id,
        'player',
        'Ce joueur est déjà dans la partie',
      );
    }
    return copyWith(players: [...players, player]);
  }

  /// Retire un joueur, **et le retire des équipes déjà composées**.
  ///
  /// Une équipe qui référencerait un joueur disparu ferait échouer le
  /// lancement bien plus loin, sur un message incompréhensible.
  GameSetup withoutPlayer(String playerId) => copyWith(
    players: [
      for (final player in players)
        if (player.id != playerId) player,
    ],
    teams: [
      for (final team in teams)
        team.copyWith(
          narratorIndex: 0,
          playerIds: [
            for (final id in team.playerIds)
              if (id != playerId) id,
          ],
        ),
    ],
  );

  GameSetup toggleChild(String playerId) => copyWith(
    players: [
      for (final player in players)
        if (player.id == playerId)
          player.copyWith(isChild: !player.isChild)
        else
          player,
    ],
  );

  /// Change le nombre d'équipes et **oublie la composition en cours**.
  ///
  /// La conserver afficherait deux équipes alors que le joueur en demande
  /// trois : mieux vaut une relance explicite qu'une incohérence muette.
  GameSetup withTeamCount(int count) {
    if (count < minimumTeamCount) {
      throw ArgumentError.value(
        count,
        'count',
        'Une partie demande au moins $minimumTeamCount équipes (R8.5)',
      );
    }
    return copyWith(teamCount: count, teams: const []);
  }

  /// Propose une composition, relançable autant de fois que voulu (R8.3, R8.4).
  GameSetup withProposedTeams({
    required List<String> names,
    required Random random,
  }) {
    if (names.length != teamCount) {
      throw ArgumentError.value(
        names.length,
        'names',
        "Il faut exactement $teamCount noms d'équipe",
      );
    }
    return copyWith(
      teams: proposeTeams(players: players, teamNames: names, random: random),
    );
  }

  GameSetup withTeams(List<Team> teams) => copyWith(teams: teams);

  /// Déplace un joueur d'une équipe à l'autre, à la main (R8.4).
  GameSetup movePlayer(String playerId, {required String toTeamId}) {
    final from = teams.where((t) => t.playerIds.contains(playerId));
    if (from.isEmpty || from.first.id == toTeamId) return this;

    return copyWith(
      teams: [
        for (final team in teams)
          team.copyWith(
            // Le curseur repartirait sinon au-delà d'une équipe rétrécie.
            narratorIndex: 0,
            playerIds: switch (team.id) {
              final id when id == toTeamId => [...team.playerIds, playerId],
              _ => [
                for (final current in team.playerIds)
                  if (current != playerId) current,
              ],
            },
          ),
      ],
    );
  }

  GameSetup renameTeam(String teamId, String name) => copyWith(
    teams: [
      for (final team in teams)
        if (team.id == teamId) team.copyWith(name: name) else team,
    ],
  );

  /// Les réglages figés, tels que la partie les emportera.
  GameConfig toConfig() => GameConfig(
    mode: mode,
    deckIds: deckIds,
    turnDuration: turnDuration,
    roundCount: roundCount,
    cardCount: cardCount,
    profileId: profileId,
    difficulties: difficulties,
  );
}

/// Une configuration neuve, aux défauts du mode choisi (table de R6).
///
/// Changer de mode en cours de configuration repart d'ici : les défauts, les
/// catégories retenues et le vivier dépendent tous du mode.
GameSetup setupForMode(Audience mode) => GameSetup(
  mode: mode,
  deckIds: const [],
  difficulties: Difficulty.values.toSet(),
  turnDuration: GameConfig.defaultTurnDuration[mode]!,
  roundCount: GameConfig.defaultRoundCount,
  cardCount: GameConfig.defaultCardCount[mode],
);
