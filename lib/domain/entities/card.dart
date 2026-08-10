import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/text/text_normalization.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'card.freezed.dart';
part 'card.g.dart';

/// Une carte à faire deviner.
///
/// L'identifiant du contenu officiel est stable entre deux versions d'un deck
/// (`<deck_id>:<slug du texte>`) : c'est ce qui permet de corriger une faute de
/// frappe dans un JSON sans casser l'historique des parties déjà jouées.
@freezed
abstract class Card with _$Card {
  const factory Card({
    required String id,
    required String deckId,
    required String text,
    required Audience audience,
    required Difficulty difficulty,
    required DeckOrigin origin,
  }) = _Card;

  const Card._();

  factory Card.fromJson(Map<String, dynamic> json) => _$CardFromJson(json);

  /// Texte normalisé servant à la détection de doublons (R6.4).
  ///
  /// Le tirage ne doit jamais produire deux fois la même carte, même si deux
  /// catégories sélectionnées contiennent la même entrée écrite différemment.
  String get normalizedText => normalizeCardText(text);
}
