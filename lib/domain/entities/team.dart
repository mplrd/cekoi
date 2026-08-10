import 'package:freezed_annotation/freezed_annotation.dart';

part 'team.freezed.dart';
part 'team.g.dart';

/// Une équipe : un nom et une couleur, rien de plus (R8.2).
///
/// L'application ne connaît pas les joueurs. Qui narre se décide à la table,
/// et l'écran d'annonce se contente de nommer l'équipe (R3.1).
@freezed
abstract class Team with _$Team {
  const factory Team({
    required String id,
    required String name,

    /// Identifiant de couleur dans la palette de l'application.
    ///
    /// Volontairement un `int` et non une `Color` : le domaine est du Dart pur
    /// et n'importe jamais `package:flutter`. La conversion se fait en
    /// présentation.
    @Default(0) int colorId,
  }) = _Team;

  const Team._();

  factory Team.fromJson(Map<String, dynamic> json) => _$TeamFromJson(json);
}
