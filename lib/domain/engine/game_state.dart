import 'dart:math';

import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/turn.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/entities/team.dart';
import 'package:cekoi/domain/rules/round.dart';
import 'package:cekoi/domain/rules/scoring.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_state.freezed.dart';
part 'game_state.g.dart';

/// L'état complet d'une partie, à un instant donné.
///
/// Immuable, sans `Random` ni fonction stockée : seule la **graine** est
/// conservée, et chaque mélange en dérive de façon reproductible. C'est ce qui
/// permet de sérialiser l'état pour la reprise de partie (R9.1) et de rejouer
/// une partie à l'identique depuis son journal d'événements.
@freezed
abstract class GameState with _$GameState {
  const factory GameState({
    required GameConfig config,
    required List<Team> teams,

    /// Le paquet figé au tirage. Modifier une catégorie en cours de partie ne
    /// doit pas altérer une partie déjà lancée.
    required List<Card> deck,
    required List<Round> rounds,

    /// Les cartes qui restent à faire deviner dans la manche en cours. La
    /// première est la carte affichée.
    required List<String> pile,
    required GamePhase phase,
    required int seed,
    @Default(0) int roundIndex,
    @Default(0) int activeTeamIndex,

    /// Le tour en cours ou en attente de validation. `null` entre deux tours :
    /// un tour validé rejoint [history], et ne peut donc pas être compté deux
    /// fois dans les scores.
    PlayedTurn? turn,
    @Default(<PlayedTurn>[]) List<PlayedTurn> history,

    /// Les équipes à égalité en tête, pendant le départage (R5.3).
    @Default(<String>[]) List<String> tieBreakTeamIds,

    /// Cartes neuves réservées au départage, écartées du paquet au tirage.
    @Default(<Card>[]) List<Card> tieBreakReserve,
    @Default(0) int tieBreakCardIndex,
    String? tieBreakWinnerId,
  }) = _GameState;

  const GameState._();

  factory GameState.fromJson(Map<String, dynamic> json) =>
      _$GameStateFromJson(json);

  /// Le paquet d'une manche, remélangé (R4.2).
  ///
  /// La graine dérive du numéro de manche : deux manches d'une même partie ne
  /// doivent pas retomber sur le même ordre, et la partie reste rejouable.
  static List<String> shufflePileFor({
    required List<Card> deck,
    required int seed,
    required int roundIndex,
  }) =>
      [for (final card in deck) card.id]
        ..shuffle(Random(seed * 31 + roundIndex));

  /// Le paquet **restant**, rebattu à l'ouverture d'un tour (R4.7).
  ///
  /// Ne remet aucune carte trouvée en jeu : il rebat ce qui reste. Sans ça,
  /// l'équipe suivante recevrait le paquet dans l'ordre exact où la précédente
  /// vient de buter dessus.
  ///
  /// [turnIndex] fait varier la graine d'un tour à l'autre : sans lui, tous
  /// les tours d'une même manche retomberaient sur le même ordre, ce qui est
  /// pire que pas de mélange du tout — le paquet ferait des allers-retours
  /// entre deux dispositions.
  static List<String> reshuffleRemaining({
    required List<String> pile,
    required int seed,
    required int roundIndex,
    required int turnIndex,
  }) => [...pile]
    ..shuffle(
      Random(seed * 31 + roundIndex * 7919 + turnIndex * 104729),
    );

  Round get round => rounds[roundIndex];

  Team get activeTeam => teams[activeTeamIndex];

  bool get isLastRound => roundIndex == rounds.length - 1;

  bool get isOver => phase == GamePhase.finished;

  String? get currentCardId => pile.isEmpty ? null : pile.first;

  Card? get currentCard {
    final id = currentCardId;
    return id == null ? null : cardById(id);
  }

  Card? cardById(String id) {
    for (final card in deck) {
      if (card.id == id) return card;
    }
    return null;
  }

  /// Temps restant au tour en cours, jamais négatif.
  Duration get remaining {
    final elapsed = turn?.elapsed;
    if (elapsed == null) return Duration.zero;
    final left = config.turnDuration - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  bool get isPaused => turn?.isPaused ?? false;

  /// Le narrateur peut agir : le tour est en cours et n'est pas en pause
  /// (R3.8).
  bool get canAct => phase == GamePhase.playing && !isPaused;

  /// Passer n'existe pas en manche 1 (R3.9), et pas sur la dernière carte
  /// (R3.4) — elle reviendrait aussitôt et le tour ne pourrait plus avancer.
  bool get canPass => canAct && round.allowsPass && pile.length > 1;

  /// Vrai tant que **rien n'a été joué** : on est sur l'annonce du tout
  /// premier tour, et personne n'a encore touché une carte.
  ///
  /// Sert à savoir si quitter coûte quelque chose. Tant que c'est vrai, le
  /// retour ramène simplement à la configuration — il n'y a pas de partie à
  /// perdre, seulement un paquet tiré qu'un nouveau tirage remplacera.
  bool get isUntouched =>
      phase == GamePhase.turnIntro &&
      roundIndex == 0 &&
      history.isEmpty &&
      (turn?.isEmpty ?? true);

  /// Les tours joués, le tour courant compris tant qu'il n'est pas validé.
  List<PlayedTurn> get allTurns => [...history, ?turn];

  Map<String, int> get scores => tallyScores(turns: allTurns, teams: teams);

  int scoreOf(String teamId) => scores[teamId] ?? 0;

  Map<Round, Map<String, int>> get scoresByRound =>
      tallyScoresByRound(turns: allTurns, teams: teams);

  List<String> get leadingTeamIds => leadingTeamIdsOf(scores);

  /// La carte à mimer pour départager (R5.3).
  ///
  /// Prise dans la réserve de cartes neuves. Le repli sur le paquet joué n'a
  /// lieu que si le vivier n'a pas permis d'en constituer une : départager sur
  /// une carte déjà vue trois fois vaut mieux que ne pas départager.
  Card? get tieBreakCard {
    final source = tieBreakReserve.isNotEmpty ? tieBreakReserve : deck;
    return source.isEmpty ? null : source[tieBreakCardIndex % source.length];
  }

  /// Les vainqueurs, une fois la partie terminée. Vide avant.
  List<String> get winnerIds {
    if (phase != GamePhase.finished) return const [];
    final byTieBreak = tieBreakWinnerId;
    return byTieBreak == null ? leadingTeamIds : [byTieBreak];
  }
}
