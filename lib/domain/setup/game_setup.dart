import 'package:cekoi/domain/engine/team_builder.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:cekoi/domain/rules/game_profiles.dart';
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

    /// `null` signifie *auto* (R6.1).
    int? cardCount,

    /// Profil retenu, `null` dès que la sélection est personnalisée (R7.6).
    String? profileId,

    /// Les noms d'équipe **tels qu'ils ont été tapés** : une entrée par équipe,
    /// vide tant que le joueur n'a rien saisi (R8.3).
    ///
    /// Les vides sont conservés au lieu d'être remplacés par « Équipe N » ici :
    /// ce libellé est de la présentation, et le stocker interdirait au champ de
    /// distinguer un nom voulu d'un nom par défaut — donc d'afficher un
    /// placeholder qu'on peut retaper par-dessus sans l'effacer d'abord.
    @Default(<String>['', '']) List<String> teamNames,
  }) = _GameSetup;

  const GameSetup._();

  /// Vrai tant qu'aucun profil ne pilote la sélection (R7.6).
  bool get isCustomSelection => profileId == null;

  int get teamCount => teamNames.length;

  /// Nombre de cartes effectif pour le nombre d'équipes retenu (R6.1).
  int get resolvedCardCount => cardCount ?? GameConfig.autoCardCount(teamCount);

  /// Tout ce que R8.5 et R6.2 exigent avant de lancer.
  ///
  /// Le vivier de cartes, lui, n'est pas connu d'ici : il dépend de la base.
  /// C'est l'appelant qui confronte [resolvedCardCount] au tirage réel.
  bool get canStart => deckIds.isNotEmpty && teamCount >= minimumTeamCount;

  /// Les équipes de la partie, les noms vides comblés par [fallbacks] (R8.3).
  ///
  /// Les libellés par défaut viennent de l'appelant, comme tout ce qui
  /// s'affiche : le domaine ne fabrique pas de texte.
  List<Team> teamsNamed(List<String> fallbacks) {
    if (fallbacks.length < teamCount) {
      throw ArgumentError.value(
        fallbacks.length,
        'fallbacks',
        'Il faut un nom de repli par équipe, soit $teamCount',
      );
    }

    return teamsFromNames([
      for (var i = 0; i < teamCount; i++)
        if (teamNames[i].trim().isEmpty) fallbacks[i] else teamNames[i].trim(),
    ]);
  }

  /// Change le mode de contenu.
  ///
  /// Tout ce qui dépend du vivier repart des défauts du nouveau mode : les
  /// catégories retenues n'y existent peut-être pas, et les réglages par
  /// défaut diffèrent (R6, R7.1). Les **équipes survivent** : elles n'ont rien
  /// à voir avec le contenu, et les resaisir parce qu'on est revenu à la
  /// première étape serait une punition.
  ///
  /// Retaper le mode déjà choisi ne change rien du tout.
  GameSetup withMode(Audience mode) {
    if (mode == this.mode) return this;
    return setupForMode(mode).copyWith(teamNames: teamNames);
  }

  /// Applique un profil : catégories, difficultés et réglages d'un coup
  /// (R7.5). Les équipes déjà nommées sont conservées.
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

  /// Change le nombre d'équipes en **gardant les noms déjà tapés** (R8.4).
  ///
  /// Passer de 2 à 3 ajoute une entrée vide ; redescendre à 2 coupe la
  /// dernière. Un aller-retour perd donc le troisième nom, et c'est voulu :
  /// le retenir ferait réapparaître un nom que le joueur a cru supprimer.
  GameSetup withTeamCount(int count) {
    if (count < minimumTeamCount) {
      throw ArgumentError.value(
        count,
        'count',
        'Une partie demande au moins $minimumTeamCount équipes (R8.5)',
      );
    }
    return copyWith(
      teamNames: [
        for (var i = 0; i < count; i++)
          if (i < teamNames.length) teamNames[i] else '',
      ],
    );
  }

  /// Nomme une équipe. Une chaîne vide rend son nom par défaut (R8.3).
  GameSetup renameTeam(int index, String name) {
    if (index < 0 || index >= teamCount) {
      throw ArgumentError.value(
        index,
        'index',
        "Il n'y a que $teamCount équipes",
      );
    }
    return copyWith(
      teamNames: [
        for (var i = 0; i < teamCount; i++)
          if (i == index) name else teamNames[i],
      ],
    );
  }

  /// Les réglages figés, tels que la partie les emportera.
  GameConfig toConfig() => GameConfig(
    mode: mode,
    deckIds: deckIds,
    turnDuration: turnDuration,
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
  cardCount: GameConfig.defaultCardCount[mode],
);
