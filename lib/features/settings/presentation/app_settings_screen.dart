import 'dart:async';

import 'package:cekoi/app/ownership.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/consent.dart';
import 'package:cekoi/services/purchases/purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Les réglages de l'application.
///
/// À ne pas confondre avec l'écran de réglages de la configuration de partie,
/// qui est l'étape 3 du parcours et ne concerne qu'une partie.
///
/// Il n'accueille pour l'instant que le consentement publicitaire, parce que
/// c'est lui qui est légalement obligé d'être joignable à tout moment. Les
/// sons, le retour haptique, la langue, la restauration d'achat et les
/// mentions légales de `SPEC.md` viendront s'y ajouter — chacun quand il
/// existera vraiment, plutôt qu'en ligne grisée qui ne fait rien.
class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final consent = ref.watch(adConsentProvider);
    final ownership = ref.watch(currentOwnershipProvider);
    final busy = ref.watch(fullVersionProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeSettings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _SectionTitle(label: l10n.settingsFullVersion),
            const SizedBox(height: 12),
            if (ownership.hasFullVersion)
              _Owned(message: l10n.settingsFullVersionOwned)
            else
              _FullVersionOffer(
                busy: busy,
                onBuy: () => unawaited(_buy(context, ref)),
              ),
            const SizedBox(height: 12),
            // La restauration reste visible même une fois l'achat acquis : un
            // joueur qui doute a besoin de la trouver, et Apple exige qu'elle
            // soit accessible, pas qu'elle soit conditionnelle.
            _RestoreTile(
              busy: busy,
              onTap: () => unawaited(_restore(context, ref)),
            ),
            const SizedBox(height: 28),
            _SectionTitle(label: l10n.settingsPrivacy),
            const SizedBox(height: 12),
            // Le CMP peut encore travailler quand on ouvre l'écran, et il peut
            // avoir échoué. Aucun des deux ne justifie une erreur affichée :
            // dans les deux cas il n'y a simplement pas de choix à proposer.
            switch (consent) {
              AsyncLoading<ConsentState>() => const _Waiting(),
              AsyncData<ConsentState>(:final value)
                  when value.canChangeChoice =>
                _ConsentTile(
                  onTap: () => unawaited(
                    ref.read(adConsentProvider.notifier).changeChoice(),
                  ),
                ),
              _ => _NoChoice(message: l10n.settingsAdConsentNone),
            },
          ],
        ),
      ),
    );
  }

  Future<void> _buy(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final outcome = await ref.read(fullVersionProvider.notifier).buy();

    // Une annulation n'est pas une erreur : le joueur a fermé la feuille de
    // paiement, il le sait, le lui dire serait le sermonner.
    if (outcome == PurchaseOutcome.failed) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.purchaseFailed)));
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final outcome = await ref.read(fullVersionProvider.notifier).restore();

    // Ici, au contraire, le silence serait cruel : le joueur vient de demander
    // qu'on retrouve un achat. Ne rien afficher lui laisserait croire que le
    // bouton est cassé.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          switch (outcome) {
            PurchaseOutcome.owned => l10n.settingsFullVersionOwned,
            PurchaseOutcome.cancelled => l10n.settingsRestoreNothing,
            PurchaseOutcome.failed => l10n.purchaseFailed,
          },
        ),
      ),
    );
  }
}

/// L'offre, tant que l'achat n'est pas fait.
///
/// Une seule promesse — « plus de pub **et** toutes les catégories » — et non
/// deux offres séparées : payer pour retirer les pubs puis devoir regarder des
/// vidéos pour accéder aux catégories, c'est le sentiment d'avoir payé pour
/// rien.
class _FullVersionOffer extends StatelessWidget {
  const _FullVersionOffer({required this.busy, required this.onBuy});

  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: busy ? null : onBuy,
        enabled: !busy,
        leading: const Icon(Icons.workspace_premium_outlined),
        // Le titre de section dit déjà « Version complète » : la ligne porte
        // la promesse, pas une deuxième fois le nom.
        title: Text(l10n.settingsFullVersionPitch),
        // Aucun prix affiché ici : il vient du magasin, qui connaît la devise
        // et la taxe du joueur. La feuille de paiement le montrera.
        trailing: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _Owned extends StatelessWidget {
  const _Owned({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(message),
      ),
    );
  }
}

class _RestoreTile extends StatelessWidget {
  const _RestoreTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: busy ? null : onTap,
        enabled: !busy,
        leading: const Icon(Icons.restore),
        title: Text(l10n.settingsRestore),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// L'entrée qui rouvre le formulaire de consentement.
///
/// Sur sa carte blanche, comme les catégories et les lignes du récapitulatif
/// de tour : une liste posée à même le fond serait le seul endroit de
/// l'application à flotter.
class _ConsentTile extends StatelessWidget {
  const _ConsentTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.privacy_tip_outlined),
        title: Text(l10n.settingsAdConsent),
        subtitle: Text(l10n.settingsAdConsentHint),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// L'attente pendant que le CMP répond.
///
/// La ligne n'a pas de texte visible — il n'y a rien à dire de plus qu'un
/// indicateur d'activité — mais elle en a un pour les lecteurs d'écran, sans
/// quoi ils n'annonceraient rien. Cet état reste affiché tout le temps que le
/// formulaire natif occupe l'écran.
class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: l10n.settingsAdConsentLoading,
      liveRegion: true,
      child: const Card(
        child: ListTile(
          leading: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _NoChoice extends StatelessWidget {
  const _NoChoice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
