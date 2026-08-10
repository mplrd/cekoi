import 'dart:math';

import 'package:cekoi/app/clock.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/player.dart';
import 'package:cekoi/domain/rules/game_profiles.dart';
import 'package:cekoi/domain/setup/game_setup.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setup_controller.g.dart';

/// La configuration en cours, partagée par les cinq écrans.
///
/// Garde-la vivante entre les écrans : revenir en arrière ne doit rien
/// reperdre, c'est tout l'objet de la barre de progression de `SPEC.md`.
@Riverpod(keepAlive: true)
class SetupController extends _$SetupController {
  /// Compteur d'identifiants de joueur.
  ///
  /// Ne se réutilise jamais, même après suppression : recycler `p1` ferait
  /// resurgir un joueur retiré dans une équipe qui le référençait encore.
  int _playerCounter = 0;

  @override
  GameSetup build() => setupForMode(Audience.family);

  void chooseMode(Audience mode) => state = state.withMode(mode);

  void chooseProfile(GameProfile profile, List<Deck> decks) =>
      state = state.withProfile(profile, decks);

  void toggleDeck(String deckId) => state = state.toggleDeck(deckId);

  void setTurnDuration(Duration duration) =>
      state = state.withTurnDuration(duration);

  void setCardCount(int? count) => state = state.withCardCount(count);

  void setRoundCount(int count) => state = state.withRoundCount(count);

  /// Ajoute un joueur ; les espaces de bord sont mangés à la saisie.
  ///
  /// Rend `false` sur un nom vide plutôt que de lever : l'écran valide au
  /// clavier, et une exception sur une entrée vide serait disproportionnée.
  bool addPlayer(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    state = state.withPlayer(
      Player(id: 'p${_playerCounter++}', name: trimmed),
    );
    return true;
  }

  void removePlayer(String playerId) => state = state.withoutPlayer(playerId);

  void toggleChild(String playerId) => state = state.toggleChild(playerId);

  void setTeamCount(int count) => state = state.withTeamCount(count);

  /// Propose une composition, ou la relance (R8.4).
  ///
  /// [names] vient de l'ARB : le domaine ne fabrique pas de libellé.
  void proposeTeams(List<String> names) {
    if (!state.canProposeTeams) return;
    state = state.withProposedTeams(
      names: names,
      random: Random(ref.read(seedSourceProvider)()),
    );
  }

  void movePlayer(String playerId, {required String toTeamId}) =>
      state = state.movePlayer(playerId, toTeamId: toTeamId);

  void renameTeam(String teamId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.renameTeam(teamId, trimmed);
  }
}
