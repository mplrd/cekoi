import 'dart:convert';
import 'dart:io';

import 'package:cekoi/data/providers.dart';
import 'package:cekoi/domain/decks/deck_exchange.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'deck_transfer.g.dart';

/// L'échange de catégories avec le système de fichiers.
///
/// **Strictement local.** Le fichier est écrit sur l'appareil et confié au
/// sélecteur du système ; c'est le joueur qui décide ensuite d'en faire quelque
/// chose. Aucun upload, aucun partage entre utilisateurs — c'est la règle d'or
/// n°4, et c'est ce qui nous exempte de la guideline Apple 1.2.
///
/// Isolé derrière un provider parce que les boîtes de dialogue du système
/// n'existent pas sous le binding de test : sans cette indirection, tout écran
/// qui les touche deviendrait invérifiable.
@Riverpod(keepAlive: true)
DeckTransfer deckTransfer(Ref ref) => DeckTransfer(ref);

class DeckTransfer {
  const DeckTransfer(this._ref);

  final Ref _ref;

  /// Écrit la catégorie dans un fichier et laisse le joueur choisir où.
  ///
  /// Rend `false` s'il annule — ce n'est pas une erreur.
  Future<bool> export(Deck deck) async {
    final repository = _ref.read(deckRepositoryProvider);
    final cards = await repository.cardsOfDeck(deck.id);

    final contenu = encodeDeckExchange(
      DeckExchange(
        name: deck.name,
        audience: deck.audience,
        cards: [
          for (final card in cards)
            ExchangeCard(text: card.text, difficulty: card.difficulty),
        ],
      ),
    );

    // Fichier temporaire : le sélecteur du système le recopie là où le joueur
    // le décide, et ce qui reste dans le cache sera nettoyé par le système.
    final dossier = await getTemporaryDirectory();
    final fichier = File('${dossier.path}/${deck.id}.json');
    await fichier.writeAsString(
      const JsonEncoder.withIndent('  ').convert(contenu),
    );

    final enregistre = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(sourceFilePath: fichier.path),
    );
    return enregistre != null;
  }

  /// Lit un fichier choisi par le joueur, ou `null` s'il annule.
  ///
  /// Lève [DeckExchangeException] quand le fichier n'est pas exploitable : le
  /// message est destiné au joueur, qui vient de choisir ce fichier lui-même.
  Future<DeckExchange?> pick() async {
    final chemin = await FlutterFileDialog.pickFile(
      params: const OpenFileDialogParams(),
    );
    if (chemin == null) return null;

    final brut = await File(chemin).readAsString();

    Object? json;
    try {
      json = jsonDecode(brut);
    } on FormatException {
      throw const DeckExchangeException("Ce n'est pas un fichier JSON.");
    }

    if (json is! Map<String, dynamic>) {
      throw const DeckExchangeException(
        'Ce fichier ne décrit pas une catégorie.',
      );
    }

    return parseDeckExchange(json);
  }
}
