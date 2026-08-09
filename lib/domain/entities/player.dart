import 'package:freezed_annotation/freezed_annotation.dart';

part 'player.freezed.dart';
part 'player.g.dart';

/// Un joueur, tel que saisi à l'étape de composition des équipes.
@freezed
abstract class Player with _$Player {
  const factory Player({
    required String id,
    required String name,

    /// Marqué *enfant* d'un tap à la saisie. La proposition de composition les
    /// répartit uniformément plutôt que de les concentrer dans une équipe
    /// (R8.3).
    @Default(false) bool isChild,
  }) = _Player;

  factory Player.fromJson(Map<String, dynamic> json) => _$PlayerFromJson(json);
}
