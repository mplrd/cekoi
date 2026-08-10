import 'package:cekoi/domain/rules/round.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'turn.freezed.dart';
part 'turn.g.dart';

/// Le sort d'une carte pour le narrateur (R3.3).
enum TurnOutcome {
  /// +1 point, la carte quitte le paquet de la manche.
  found,

  /// Aucune pénalité, la carte retourne au fond du paquet.
  ///
  /// Au récapitulatif de tour, c'est aussi ce que vaut « pas trouvée » : la
  /// manche 1 n'offre pas *Passer* (R3.9) mais reste corrigeable (R3.6).
  passed,
}

/// Une ligne du récapitulatif de fin de tour.
@freezed
abstract class CardResult with _$CardResult {
  const factory CardResult({
    required String cardId,
    required TurnOutcome outcome,
  }) = _CardResult;

  factory CardResult.fromJson(Map<String, dynamic> json) =>
      _$CardResultFromJson(json);
}

/// Un tour de jeu, en cours ou terminé.
///
/// Le même type sert au tour courant et aux tours archivés : un tour n'a pas
/// deux natures selon qu'il est fini ou non, et deux types jumeaux finiraient
/// par diverger.
@freezed
abstract class PlayedTurn with _$PlayedTurn {
  const factory PlayedTurn({
    required Round round,
    required String teamId,

    /// Temps consommé depuis le début du tour, **pauses exclues** (R3.7).
    @Default(Duration.zero) Duration elapsed,
    @Default(false) bool isPaused,

    /// Les cartes vues, dans leur ordre d'apparition. Une carte n'y figure
    /// qu'une fois, avec son dernier résultat : une carte passée puis trouvée
    /// dans le même tour est une seule ligne du récapitulatif.
    @Default(<CardResult>[]) List<CardResult> results,
  }) = _PlayedTurn;

  const PlayedTurn._();

  factory PlayedTurn.fromJson(Map<String, dynamic> json) =>
      _$PlayedTurnFromJson(json);

  /// Une carte trouvée vaut un point, dans toutes les manches (R5.1).
  int get score => results.where((r) => r.outcome == TurnOutcome.found).length;

  bool get isEmpty => results.isEmpty;

  /// Enregistre le sort d'une carte, en remplaçant sa ligne si elle a déjà été
  /// vue plutôt qu'en ajoutant une seconde.
  PlayedTurn withResult(String cardId, TurnOutcome outcome) {
    final line = CardResult(cardId: cardId, outcome: outcome);
    final index = results.indexWhere((r) => r.cardId == cardId);
    if (index == -1) {
      return copyWith(results: [...results, line]);
    }
    final updated = [...results];
    updated[index] = line;
    return copyWith(results: updated);
  }

  CardResult? resultFor(String cardId) {
    for (final result in results) {
      if (result.cardId == cardId) return result;
    }
    return null;
  }
}
