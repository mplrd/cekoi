import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck.dart';
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
  @override
  GameSetup build() => setupForMode(Audience.family);

  void chooseMode(Audience mode) => state = state.withMode(mode);

  void chooseProfile(GameProfile profile, List<Deck> decks) =>
      state = state.withProfile(profile, decks);

  void toggleDeck(String deckId) => state = state.toggleDeck(deckId);

  /// Sélectionne toutes les catégories du mode (R7.9).
  void selectAllDecks(List<String> deckIds) =>
      state = state.withAllDecks(deckIds);

  void setTurnDuration(Duration duration) =>
      state = state.withTurnDuration(duration);

  void setCardCount(int count) => state = state.withCardCount(count);

  /// Restreint le vivier aux seules cartes adultes, ou l'ouvre à nouveau
  /// (R7.1).
  void setAdultOnly({required bool actif}) =>
      state = state.withAdultOnly(actif: actif);

  void setTeamCount(int count) => state = state.withTeamCount(count);

  /// Nomme une équipe. Un nom vide la renvoie à son libellé par défaut (R8.3).
  ///
  /// Les espaces de bord ne sont pas mangés ici : le champ est en cours de
  /// frappe, et couper l'espace qu'on vient de taper entre deux mots ferait
  /// sauter le curseur. Le nettoyage a lieu au lancement.
  void renameTeam(int index, String name) =>
      state = state.renameTeam(index, name);
}
