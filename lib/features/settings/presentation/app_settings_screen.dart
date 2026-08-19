import 'dart:async';

import 'package:cekoi/app/ownership.dart';
import 'package:cekoi/app/preferences.dart';
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
/// Trois sections : ce qui se passe en partie, ce qu'on peut acheter, et le
/// consentement publicitaire — le seul qui soit légalement obligé d'être
/// joignable à tout moment.
///
/// Manquent encore, faute d'exister : le choix de la langue, tant qu'il n'y a
/// qu'une locale, et les mentions légales et la politique de confidentialité,
/// qui attendent des URL hébergées. Chacun arrivera quand il fera vraiment
/// quelque chose, plutôt qu'en ligne grisée.
class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final consent = ref.watch(adConsentProvider);
    final ownership = ref.watch(currentOwnershipProvider);
    final busy = ref.watch(fullVersionProvider).isLoading;
    final reglages = ref.watch(currentPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeSettings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _SectionTitle(label: l10n.settingsGame),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    value: reglages.soundEnabled,
                    onChanged: (actif) => unawaited(
                      ref
                          .read(appPreferencesControllerProvider.notifier)
                          .setSound(enabled: actif),
                    ),
                    secondary: const Icon(Icons.volume_up_outlined),
                    title: Text(l10n.settingsSound),
                    subtitle: Text(l10n.settingsSoundHint),
                  ),
                  SwitchListTile(
                    value: reglages.hapticsEnabled,
                    onChanged: (actif) => unawaited(
                      ref
                          .read(appPreferencesControllerProvider.notifier)
                          .setHaptics(enabled: actif),
                    ),
                    secondary: const Icon(Icons.vibration),
                    title: Text(l10n.settingsHaptics),
                    subtitle: Text(l10n.settingsHapticsHint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
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
                  allowed: value.canRequestAds,
                  showsAds: ownership.showsAds,
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
            // `cancelled` n'arrive pas sur ce chemin — aucune feuille de
            // paiement ne s'ouvre — mais le dire ici évite un `_` qui
            // avalerait un cas futur en silence.
            PurchaseOutcome.cancelled ||
            PurchaseOutcome.nothing => l10n.settingsRestoreNothing,
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

/// La réponse en cours, telle qu'elle se lit dans les réglages.
///
/// Trois cas et non deux : dire « Publicités autorisées » à qui a acheté la
/// version complète le contredirait deux sections plus haut, où le même écran
/// le remercie de l'avoir achetée — et l'offre lui promettait « Plus aucune
/// publicité ». Son consentement reste vrai et modifiable, il ne décide juste
/// plus de rien.
///
/// « Refusées » couvre les deux autres cas sans les distinguer, et c'est
/// voulu : le participe décrit un état sans désigner qui refuse. Le cas courant
/// est le refus du joueur, mais un SDK qui ne démarre pas — ou un formulaire
/// qui échoue avant d'avoir été montré — aboutit au même endroit, et la phrase
/// y reste vraie.
String _consentStatus(
  AppLocalizations l10n, {
  required bool allowed,
  required bool showsAds,
}) => switch ((allowed, showsAds)) {
  (false, _) => l10n.settingsAdConsentRefused,
  (true, true) => l10n.settingsAdConsentAllowed,
  (true, false) => l10n.settingsAdConsentAllowedFullVersion,
};

/// L'entrée qui rouvre le formulaire de consentement, et dit où on en est.
///
/// Sur sa carte blanche, comme les catégories et les lignes du récapitulatif
/// de tour : une liste posée à même le fond serait le seul endroit de
/// l'application à flotter.
///
/// Le sous-titre porte la réponse en cours, comme n'importe quel réglage porte
/// sa valeur — la ligne rouvrait le formulaire sans jamais dire ce qu'on avait
/// répondu, et rouvrir un formulaire pour lire son propre choix n'est pas une
/// réponse. Le titre reste le nom du réglage, le chevron l'invitation à le
/// changer.
class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.allowed,
    required this.showsAds,
    required this.onTap,
  });

  /// La réponse en cours autorise les publicités.
  final bool allowed;

  /// L'application a encore le droit d'en montrer une.
  final bool showsAds;

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
        subtitle: Text(
          _consentStatus(l10n, allowed: allowed, showsAds: showsAds),
        ),
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
