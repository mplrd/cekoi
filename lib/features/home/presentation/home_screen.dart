import 'dart:async';

import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/game_persistence.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/app/theme/app_theme.dart';
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

    // L'accueil prend le corail du logo comme fond, et non le fond neutre du
    // thème. Deux raisons : c'est la couleur qu'on vient de toucher sur
    // l'icône, et le logo porte lui-même ce corail — posé dessus, son cadre
    // disparaît et le dessin flotte, au lieu d'être une image collée sur une
    // page blanche.
    //
    // Le texte passe donc en encre sombre, comme les contours du dessin : du
    // blanc sur ce corail tomberait à 2,6:1, sous le minimum lisible.
    return Scaffold(
      backgroundColor: AppColors.seed,
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
            _ => const _Menu(),
          },
        ),
      ),
    );
  }
}

/// L'encre de l'accueil : le noir chaud des contours du logo.
///
/// Sur le corail, du blanc tomberait à 2,6:1 — sous le seuil lisible, même
/// pour du gros texte.
const Color _encre = Color(0xFF1A0F0C);

/// Une entrée de l'accueil.
///
/// Trois traitements pour une seule forme : plein pour l'action principale,
/// clair pour les autres, effacé pour ce qui n'est pas encore là. Les boutons
/// Material par défaut tiraient leurs couleurs du thème et ressortaient
/// délavés sur ce fond.
class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.label,
    required this.onPressed,
    this.principal = false,
    this.discret = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool principal;
  final bool discret;

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null;
    final fond = principal
        ? AppColors.accent
        : (discret ? Colors.white24 : Colors.white);
    final texte = principal ? Colors.white : _encre;

    return Opacity(
      opacity: actif ? 1 : 0.45,
      child: Material(
        color: fond,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: InkWell(
          onTap: onPressed,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          child: SizedBox(
            height: AppTheme.minTouchTarget,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: texte,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Menu extends ConsumerWidget {
  const _Menu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Une partie de moins de 24 h (R9.2). L'attente n'est pas bloquante : le
    // menu s'affiche tout de suite, la bannière apparaît quand la base a
    // répondu — c'est une reprise, pas une raison de retenir l'écran.
    final resumable = ref.watch(resumableGameProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        // Le logo annonce les trois manches — la bulle qui parle, le « 1 » du
        // mot unique, le personnage qui mime. Son fond est le corail de
        // l'écran : il se confond, et seul le dessin reste.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260, maxWidth: 260),
            child: Image.asset(
              'assets/branding/logo.png',
              semanticLabel: l10n.appTitle,
            ),
          ),
        ),
        Text(
          l10n.appTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: _encre,
            letterSpacing: -1,
          ),
        ),
        const Spacer(),
        if (resumable != null) ...[
          _HomeAction(
            label: l10n.homeResumeGame,
            // La reprise vient en second : c'est le cas rare, et elle ne doit
            // pas prendre la place de « Jouer ».
            discret: true,
            onPressed: () {
              ref.read(currentGameProvider.notifier).game = resumable;
              unawaited(context.push(AppRoutes.game));
            },
          ),
          const SizedBox(height: 12),
        ],
        // L'unique action pleine de l'écran, dans le teal des étincelles du
        // logo : sur ce corail, c'est le seul contraste qui ne vibre pas.
        _HomeAction(
          label: l10n.homePlay,
          principal: true,
          onPressed: () => context.push(AppRoutes.setupMode),
        ),
        const SizedBox(height: 12),
        _HomeAction(
          label: l10n.homeMyDecks,
          onPressed: () => unawaited(context.push(AppRoutes.myDecks)),
        ),
        const SizedBox(height: 12),
        _HomeAction(label: l10n.homeSettings, onPressed: null),
        const SizedBox(height: 24),
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
