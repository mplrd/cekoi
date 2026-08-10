import 'dart:convert';

import 'package:cekoi/data/db/database.dart';
import 'package:cekoi/data/db/tables/saved_games.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/domain/rules/round.dart';
import 'package:drift/drift.dart';

/// Une partie retrouvée en base, avec la date à laquelle elle a été quittée.
class SavedGame {
  const SavedGame({required this.game, required this.savedAt});

  final GameState game;

  /// Sert la fenêtre de 24 heures de R9.2. La comparaison, elle, appartient au
  /// domaine — voir `isResumable`.
  final DateTime savedAt;
}

/// Sauvegarde et reprise de la partie en cours (R9.1).
class GameRepository {
  const GameRepository(this._db);

  final AppDatabase _db;

  /// Écrit l'état courant, en écrasant le précédent.
  ///
  /// Il n'y a qu'une partie à la fois : garder les anciennes obligerait à
  /// choisir laquelle proposer, et à les purger un jour.
  Future<void> save(GameState game, {required DateTime savedAt}) => _db
      .into(_db.savedGames)
      .insertOnConflictUpdate(
        SavedGamesCompanion.insert(
          id: const Value(SavedGames.singleRowId),
          payload: jsonEncode(game.toJson()),
          savedAt: savedAt,
        ),
      );

  /// La partie sauvegardée, ou `null` s'il n'y en a pas.
  ///
  /// Rend `null` aussi quand la ligne est illisible — une sauvegarde écrite
  /// par une version antérieure du moteur, par exemple. Perdre une partie
  /// abandonnée est ennuyeux ; empêcher l'application de démarrer parce
  /// qu'elle n'arrive pas à la relire l'est beaucoup plus.
  Future<SavedGame?> load() async {
    final row = await (_db.select(
      _db.savedGames,
    )..where((g) => g.id.equals(SavedGames.singleRowId))).getSingleOrNull();

    if (row == null) return null;

    try {
      final game = GameState.fromJson(
        jsonDecode(row.payload) as Map<String, dynamic>,
      );
      if (!_followsCurrentRounds(game)) {
        await clear();
        return null;
      }
      return SavedGame(game: game, savedAt: row.savedAt);
    } on Object {
      await clear();
      return null;
    }
  }

  /// Une partie d'avant R2.2 a pu être sauvegardée avec deux manches, ou dans
  /// un autre ordre : le décodage l'accepterait sans broncher, et les 24 heures
  /// de R9.2 la feraient rejouer sous des règles qui n'existent plus. On la
  /// traite comme une sauvegarde illisible.
  bool _followsCurrentRounds(GameState game) {
    if (game.rounds.length != Round.sequence.length) return false;
    for (var i = 0; i < Round.sequence.length; i++) {
      if (game.rounds[i] != Round.sequence[i]) return false;
    }
    return true;
  }

  /// Efface la partie sauvegardée : elle est finie, ou abandonnée.
  Future<void> clear() => _db.delete(_db.savedGames).go();
}
