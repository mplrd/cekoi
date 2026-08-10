import 'package:cekoi/domain/engine/game_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_game.g.dart';

/// La partie en cours, une fois le paquet tiré.
///
/// `null` tant qu'aucune partie n'est lancée. L'écran de jeu du lot suivant
/// s'y branchera ; la persistance de R9.1 aussi.
///
/// Vit dans `app/` et non dans une feature : c'est le point de rendez-vous
/// entre celle qui produit la partie (`setup`) et celle qui la consomme
/// (`play`). Le loger chez l'une obligerait l'autre à l'importer, ce
/// qu'`ARCHITECTURE.md` interdit. Il ne peut pas descendre dans `domain/`,
/// qui ne connaît pas Riverpod.
@Riverpod(keepAlive: true)
class CurrentGame extends _$CurrentGame {
  @override
  GameState? build() => null;

  GameState? get game => state;

  /// `null` referme la partie et ramène l'accueil à son état de repos.
  set game(GameState? value) => state = value;
}
