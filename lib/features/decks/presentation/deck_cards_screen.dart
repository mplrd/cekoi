import 'dart:async';

import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/app/theme/app_theme.dart';
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
  bool _doublon = false;

  /// Le niveau reste sur son dernier choix d'une carte à l'autre.
  ///
  /// On saisit par séries — dix faciles, puis quelques difficiles — et
  /// remettre « moyen » après chaque ajout obligerait à le repositionner à
  /// chaque fois. Le champ de texte se vide, le niveau non : c'est le texte
  /// qui change à chaque carte, pas le classement.
  Difficulty _difficulty = Difficulty.medium;

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
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Le formulaire se lit de haut en bas et **finit par son action** : le
    // texte, puis le bouton. Il n'y a plus rien après lui — c'est ce qui rend
    // évident que taper « Ajouter » envoie exactement ce qu'on vient d'écrire.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              errorText: _doublon ? l10n.cardAlreadyThere : null,
            ),
          ),
          const SizedBox(height: 12),
          // Le niveau est **dans le formulaire**, entre le texte et l'action :
          // il se lit comme celui de la carte qu'on est en train d'écrire. En
          // tête d'écran, il aurait eu l'air de classer la catégorie entière.
          _DifficultyPicker(
            value: _difficulty,
            onChanged: (d) => setState(() => _difficulty = d),
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
      // Même hauteur que les autres commandes de l'écran : le sélecteur
      // arrivait douze pixels plus bas que le champ et le bouton, ce qui
      // suffisait à le faire lire comme un accessoire.
      style: SegmentedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppTheme.minTile),
        backgroundColor: AppColors.groundSoft,
        selectedBackgroundColor: AppColors.secondary,
        foregroundColor: AppColors.ink,
        selectedForegroundColor: AppColors.ink,
        // Depuis le thème, et non un `TextStyle` nu : celui-ci n'emporte pas
        // la famille, et le libellé retombe sur la police par défaut de la
        // plateforme — seul élément de l'écran à ne pas se composer comme le
        // reste. C'est le défaut que `test/app/theme_test.dart` surveille.
        textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
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

    // Une carte blanche par carte : c'est bien ce que c'est, et le reste de
    // l'application pose ses listes sur des surfaces.
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final card = cards[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            title: Text(card.text),
            subtitle: Text(card.difficulty.label(l10n)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.actionDelete,
              onPressed: () => unawaited(_delete(context, ref, card)),
            ),
            onTap: () => unawaited(_edit(context, ref, card)),
          ),
        );
      },
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
