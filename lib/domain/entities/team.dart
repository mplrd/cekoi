import 'package:freezed_annotation/freezed_annotation.dart';

part 'team.freezed.dart';
part 'team.g.dart';

/// Une équipe et son curseur de narrateur.
///
/// La rotation du narrateur est **interne à chaque équipe** (R3.1) : chaque
/// équipe garde son propre curseur, ce qui autorise des effectifs inégaux sans
/// qu'un joueur narre plus souvent que ses coéquipiers.
@freezed
abstract class Team with _$Team {
  const factory Team({
    required String id,
    required String name,
    required List<String> playerIds,

    /// Identifiant de couleur dans la palette de l'application.
    ///
    /// Volontairement un `int` et non une `Color` : le domaine est du Dart pur
    /// et n'importe jamais `package:flutter`. La conversion se fait en
    /// présentation.
    @Default(0) int colorId,

    /// Index du prochain narrateur dans [playerIds].
    @Default(0) int narratorIndex,
  }) = _Team;

  const Team._();

  factory Team.fromJson(Map<String, dynamic> json) => _$TeamFromJson(json);

  String get currentNarratorId => playerIds[narratorIndex % playerIds.length];

  /// Fait tourner le narrateur au sein de l'équipe (R3.1).
  Team withNextNarrator() =>
      copyWith(narratorIndex: (narratorIndex + 1) % playerIds.length);
}
