import 'dart:async';

import 'package:cekoi/app/router.dart';
import 'package:cekoi/domain/decks/deck_exchange.dart';
import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/features/decks/presentation/custom_decks_controller.dart';
import 'package:cekoi/features/decks/presentation/deck_transfer.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Les catégories écrites par le joueur.
///
/// Elles ne quittent jamais l'appareil : aucun partage, aucun upload. C'est ce
/// qui nous exempte de la guideline Apple 1.2 sur le contenu généré par les
/// utilisateurs, et c'est dit à l'écran plutôt que seulement dans une
/// politique de confidentialité.
class MyDecksScreen extends ConsumerWidget {
  const MyDecksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final decks = ref.watch(customDecksProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeMyDecks),
        actions: [
          IconButton(
            onPressed: () => unawaited(_importDeck(context, ref)),
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l10n.actionImportDeck,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_createDeck(context, ref)),
        icon: const Icon(Icons.add),
        label: Text(l10n.actionCreateDeck),
      ),
      body: SafeArea(
        child: switch (decks) {
          AsyncLoading<Object?>() => const Center(
            child: CircularProgressIndicator(),
          ),
          AsyncError<Object?>() => Center(child: Text(l10n.errorGeneric)),
          _ => _DeckList(decks: decks.requireValue),
        },
      ),
    );
  }

  Future<void> _createDeck(BuildContext context, WidgetRef ref) async {
    final saisie = await showDialog<_DeckDraft>(
      context: context,
      builder: (context) => const _DeckDialog(),
    );
    if (saisie == null) return;

    await ref
        .read(customDecksProvider.notifier)
        .create(name: saisie.name, audience: saisie.audience);
  }

  /// Importe une catégorie depuis un fichier choisi par le joueur.
  ///
  /// Un fichier illisible n'est pas une erreur d'application : il vient de le
  /// choisir lui-même, et le message lui dit ce qui cloche plutôt que de
  /// remonter une trace technique.
  Future<void> _importDeck(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final exchange = await ref.read(deckTransferProvider).pick();
      if (exchange == null) return;

      final deck = await ref
          .read(customDecksProvider.notifier)
          .importDeck(exchange);

      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.importDone(deck.name, exchange.cards.length)),
        ),
      );
    } on DeckExchangeException catch (erreur) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importFailed(erreur.message))),
      );
    }
  }
}

class _DeckList extends ConsumerWidget {
  const _DeckList({required this.decks});

  final List<Deck> decks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (decks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.myDecksEmpty,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.myDecksEmptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [for (final deck in decks) _DeckTile(deck: deck)],
    );
  }
}

class _DeckTile extends ConsumerWidget {
  const _DeckTile({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cards = ref.watch(deckCardsProvider(deck.id));

    return ListTile(
      title: Text(deck.name),
      subtitle: Text(
        '${deck.audience == Audience.adult ? l10n.modeAdult : l10n.modeFamily}'
        ' · ${l10n.cardCount(cards.value?.length ?? 0)}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) => unawaited(_onAction(context, ref, action)),
        itemBuilder: (context) => [
          PopupMenuItem(value: 'rename', child: Text(l10n.actionRenameDeck)),
          PopupMenuItem(value: 'export', child: Text(l10n.actionExportDeck)),
          PopupMenuItem(value: 'delete', child: Text(l10n.actionDeleteDeck)),
        ],
      ),
      onTap: () => unawaited(context.push(AppRoutes.deckCards(deck.id))),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    if (action == 'export') {
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);

      if (await ref.read(deckTransferProvider).export(deck)) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.exportDone(deck.name))),
        );
      }
      return;
    }

    if (action == 'rename') {
      final saisie = await showDialog<_DeckDraft>(
        context: context,
        builder: (context) => _DeckDialog(deck: deck),
      );
      if (saisie == null) return;
      await ref.read(customDecksProvider.notifier).rename(deck.id, saisie.name);
      return;
    }

    final cards = await ref.read(deckCardsProvider(deck.id).future);
    if (!context.mounted) return;

    final confirme = await _confirmDelete(context, cards.length);
    if (confirme) {
      await ref.read(customDecksProvider.notifier).delete(deck.id);
    }
  }

  /// La suppression emporte les cartes : `SPEC.md` demande une confirmation,
  /// et elle annonce ce qui est perdu plutôt qu'un « êtes-vous sûr » creux.
  Future<bool> _confirmDelete(BuildContext context, int cardCount) async {
    final l10n = AppLocalizations.of(context);

    final reponse = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteDeckTitle(deck.name)),
        content: Text(l10n.deleteDeckBody(cardCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );

    return reponse ?? false;
  }
}

/// Ce qu'une boîte de dialogue de catégorie rend.
class _DeckDraft {
  const _DeckDraft(this.name, this.audience);

  final String name;
  final Audience audience;
}

class _DeckDialog extends StatefulWidget {
  const _DeckDialog({this.deck});

  /// `null` pour une création, la catégorie pour un renommage.
  final Deck? deck;

  @override
  State<_DeckDialog> createState() => _DeckDialogState();
}

class _DeckDialogState extends State<_DeckDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.deck?.name ?? '',
  );
  late Audience _audience = widget.deck?.audience ?? Audience.family;
  bool _vide = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final propre = _name.text.trim();
    if (propre.isEmpty) {
      setState(() => _vide = true);
      return;
    }
    Navigator.of(context).pop(_DeckDraft(propre, _audience));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final creation = widget.deck == null;

    return AlertDialog(
      title: Text(creation ? l10n.actionCreateDeck : l10n.actionRenameDeck),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.deckNameHint,
              errorText: _vide ? l10n.deckNameRequired : null,
            ),
          ),
          // Le mode se choisit à la création et ne bouge plus : il décide de
          // l'endroit où la catégorie apparaît, et le changer sous les pieds
          // d'une partie en cours la ferait disparaître de sa sélection.
          if (creation) ...[
            const SizedBox(height: 24),
            Text(
              l10n.deckAudienceLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<Audience>(
              segments: [
                ButtonSegment(
                  value: Audience.family,
                  label: Text(l10n.modeFamily),
                ),
                ButtonSegment(
                  value: Audience.adult,
                  label: Text(l10n.modeAdult),
                ),
              ],
              selected: {_audience},
              onSelectionChanged: (choix) =>
                  setState(() => _audience = choix.first),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.actionSave)),
      ],
    );
  }
}
