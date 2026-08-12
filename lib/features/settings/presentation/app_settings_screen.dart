import 'dart:async';

import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:cekoi/services/ads/consent.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeSettings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
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

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: SizedBox.shrink(),
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
