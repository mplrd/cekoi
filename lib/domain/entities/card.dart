import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck_origin.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
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

    /// Mots interdits au narrateur en manche 1 (description libre).
    ///
    /// Vide pour beaucoup de cartes custom : la saisie de tabous est
    /// optionnelle côté joueur, on ne transforme pas la création en corvée.
    @Default(<String>[]) List<String> taboo,
  }) = _Card;

  const Card._();

  factory Card.fromJson(Map<String, dynamic> json) => _$CardFromJson(json);

  /// Texte normalisé servant à la détection de doublons (R6.4).
  ///
  /// Le tirage ne doit jamais produire deux fois la même carte, même si deux
  /// catégories sélectionnées contiennent la même entrée écrite différemment.
  String get normalizedText {
    const accents = 'àâäáãåçèéêëìíîïñòóôöõùúûüýÿœæ';
    const plain = 'aaaaaaceeeeiiiinooooouuuuyyoa';

    final lowered = text.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final rune in lowered.runes) {
      final char = String.fromCharCode(rune);
      final index = accents.indexOf(char);
      buffer.write(index == -1 ? char : plain[index]);
    }

    return buffer
        .toString()
        .replaceAll(RegExp('[^a-z0-9 ]'), '')
        .replaceAll(RegExp('^(le|la|les|un|une|des|du|de|l) '), '')
        .replaceAll(RegExp(' +'), ' ')
        .trim();
  }
}
