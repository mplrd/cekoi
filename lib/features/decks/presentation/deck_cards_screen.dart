import 'dart:async';

import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/domain/entities/deck.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/features/decks/presentation/custom_decks_controller.dart';
import 'package:cekoi/features/decks/presentation/widgets/difficulty_labels.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Les cartes d'une catégorie du joueur.
///
/// La saisie est faite pour enchaîner : un champ, une validation, le champ se
/// vide et garde le focus. Quelqu'un qui saisit trente prénoms ne doit pas
/// avoir à retoucher l'écran entre deux cartes.
class DeckCardsScreen extends ConsumerWidget {
  const DeckCardsScreen({required this.deckId, super.key});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final decks = ref.watch(customDecksProvider).value ?? const <Deck>[];
    final deck = decks.where((d) => d.id == deckId).firstOrNull;
    final cards = ref.watch(deckCardsProvider(deckId));

    return Scaffold(
      appBar: AppBar(title: Text(deck?.name ?? l10n.homeMyDecks)),
      body: SafeArea(
        child: Column(
          children: [
            _QuickAdd(deckId: deckId),
            Expanded(
              child: switch (cards) {
                AsyncLoading<Object?>() => const Center(
                  child: CircularProgressIndicator(),
                ),
                AsyncError<Object?>() => Center(child: Text(l10n.errorGeneric)),
                _ => _CardList(deckId: deckId, cards: cards.requireValue),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAdd extends ConsumerStatefulWidget {
  const _QuickAdd({required this.deckId});

  final String deckId;

  @override
  ConsumerState<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends ConsumerState<_QuickAdd> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  Difficulty _difficulty = Difficulty.medium;
  bool _doublon = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final propre = _text.text.trim();
    if (propre.isEmpty) return;

    final ajoutee = await ref
        .read(deckCardsProvider(widget.deckId).notifier)
        .add(propre, difficulty: _difficulty);

    if (!mounted) return;
    setState(() => _doublon = !ajoutee);

    // Le champ ne se vide que si la carte est entrée : sur un refus, le texte
    // reste sous les yeux pour être corrigé plutôt que retapé.
    if (ajoutee) {
      _text.clear();
      // La difficulté, elle, ne se réinitialise pas : on saisit souvent une
      // série de cartes de même niveau.
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Le formulaire se lit de haut en bas et **finit par son action** : la
    // difficulté d'abord, le texte ensuite, le bouton en dernier. Il a d'abord
    // été écrit dans l'autre sens — un « + » collé au champ, la difficulté en
    // dessous — et le retour d'usage a été immédiat : on ne sait pas si la
    // carte part avec le niveau affiché, puisqu'il reste des champs après le
    // bouton.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DifficultyPicker(
            value: _difficulty,
            onChanged: (d) => setState(() => _difficulty = d),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            focusNode: _focus,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_doublon) setState(() => _doublon = false);
            },
            onSubmitted: (_) => unawaited(_add()),
            decoration: InputDecoration(
              labelText: l10n.cardTextHint,
              border: const OutlineInputBorder(),
              errorText: _doublon ? l10n.cardAlreadyThere : null,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => unawaited(_add()),
            icon: const Icon(Icons.add),
            label: Text(l10n.actionAddCard),
          ),
        ],
      ),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.value, required this.onChanged});

  final Difficulty value;
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SegmentedButton<Difficulty>(
      showSelectedIcon: false,
      segments: [
        for (final d in Difficulty.values)
          ButtonSegment(value: d, label: Text(d.label(l10n))),
      ],
      selected: {value},
      onSelectionChanged: (choix) => onChanged(choix.first),
    );
  }
}

class _CardList extends ConsumerWidget {
  const _CardList({required this.deckId, required this.cards});

  final String deckId;
  final List<domain.Card> cards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (cards.isEmpty) {
      return Center(child: Text(l10n.deckCardsEmpty));
    }

    return ListView(
      children: [
        for (final card in cards)
          ListTile(
            title: Text(card.text),
            subtitle: Text(card.difficulty.label(l10n)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.actionDelete,
              onPressed: () => unawaited(_delete(context, ref, card)),
            ),
            onTap: () => unawaited(_edit(context, ref, card)),
          ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    domain.Card card,
  ) async {
    final saisie = await showDialog<_CardDraft>(
      context: context,
      builder: (context) => _CardDialog(card: card),
    );
    if (saisie == null) return;

    await ref
        .read(deckCardsProvider(deckId).notifier)
        .edit(card.id, text: saisie.text, difficulty: saisie.difficulty);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    domain.Card card,
  ) async {
    final l10n = AppLocalizations.of(context);

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCardTitle(card.text)),
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

    if (confirme ?? false) {
      await ref.read(deckCardsProvider(deckId).notifier).delete(card.id);
    }
  }
}

class _CardDraft {
  const _CardDraft(this.text, this.difficulty);

  final String text;
  final Difficulty difficulty;
}

class _CardDialog extends StatefulWidget {
  const _CardDialog({required this.card});

  final domain.Card card;

  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.card.text,
  );
  late Difficulty _difficulty = widget.card.difficulty;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final propre = _text.text.trim();
    if (propre.isEmpty) return;
    Navigator.of(context).pop(_CardDraft(propre, _difficulty));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: l10n.cardTextHint),
          ),
          const SizedBox(height: 24),
          _DifficultyPicker(
            value: _difficulty,
            onChanged: (d) => setState(() => _difficulty = d),
          ),
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
