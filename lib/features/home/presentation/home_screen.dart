import 'package:cekoi/app/router.dart';
import 'package:cekoi/data/providers.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Accueil : trois entrées, et la reprise de partie quand il y en a une.
///
/// Tant que le seeding tourne, l'écran affiche un chargement — au premier
/// lancement seulement, les suivants ne comparent que des versions.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final seeding = ref.watch(deckSeedingProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (seeding) {
            AsyncLoading<Object?>() => _Loading(message: l10n.loadingDecks),
            AsyncError<Object?>() => _Error(
              message: l10n.errorGeneric,
              retryLabel: l10n.actionRetry,
              onRetry: () => ref.invalidate(deckSeedingProvider),
            ),
            _ => _Menu(l10n: l10n),
          },
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          l10n.appTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: () => context.push(AppRoutes.setupMode),
          child: Text(l10n.homePlay),
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: null, child: Text(l10n.homeMyDecks)),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: null, child: Text(l10n.homeSettings)),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
