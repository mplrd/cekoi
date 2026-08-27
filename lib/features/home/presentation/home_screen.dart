import 'dart:async';

import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/game_persistence.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/app/widgets/texte_qui_tient.dart';
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

    // Le fond vient du thème — le corail pastélisé, comme partout ailleurs.
    // L'accueil n'a pas de fond à lui : c'est ce qui fait que l'application
    // ressemble à une seule application d'un écran à l'autre.
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
            _ => const _Menu(),
          },
        ),
      ),
    );
  }
}

/// Une entrée de l'accueil.
///
/// Trois traitements pour une seule forme : le teal des étincelles pour
/// l'action principale, le corail plein pour la reprise de partie, et pour les
/// autres un blanc cerné de corail — le même traitement secondaire que partout
/// ailleurs. Elles ont été en vert du personnage : deux pastels voisins, elles
/// ne se détachaient pas du fond.
class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.label,
    required this.onPressed,
    this.principal = false,
    this.reprise = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool principal;
  final bool reprise;

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null;
    final secondaire = !principal && !reprise;
    final (fond, texte) = switch ((principal, reprise)) {
      (true, _) => (AppColors.deep, Colors.white),
      (_, true) => (AppColors.main, AppColors.ink),
      _ => (AppColors.card, AppColors.ink),
    };

    return Opacity(
      opacity: actif ? 1 : 0.4,
      child: Material(
        color: fond,
        // Le liseré corail est ce qui fait d'un aplat blanc une action, et non
        // un trou dans la page.
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppTheme.radius),
          ),
          side: secondaire
              ? const BorderSide(color: AppColors.main, width: 3)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppTheme.radius),
          ),
          // Une hauteur **minimale**, et non une hauteur : 64 px est la cible
          // tactile que le système exige, pas un plafond. Fixée, elle rognait
          // le libellé par le bas — mesuré, « Jouer » réclame 87 px de haut à
          // ×3,1 dans une boîte qui en faisait 64. C'est l'autre façon de
          // perdre un texte, et `aucunTexteRogne` la voit aussi.
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTheme.minTouchTarget,
            ),
            // Le liseré corail est peint **à l'intérieur** de la forme : sans
            // ce rembourrage, un libellé ramené à la largeur exacte du bouton
            // pose ses glyphes dessus.
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                // « Mes catégories » réclamait 324,4 px dans 312 à ×3,1 : le
                // libellé le plus long des quatre, et il ne replie pas — c'est
                // « catégories » seul qui dépasse.
                child: TexteQuiTient(
                  label,
                  alignment: Alignment.center,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: texte,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// En dessous de cette hauteur disponible, le bloc d'identité s'efface.
///
/// Mesuré : il pèse 449 px au naturel — 280 de logo, 8 d'écart, 161 de nom à
/// ×3,1. À 160 px il est encore réduit à un peu plus du tiers, ce qui reste un
/// logo ; en dessous, ce n'est plus qu'une tache.
const double _hauteurMinimaleDeLIdentite = 160;

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
        // Le bloc d'identité prend tout ce que les entrées laissent, et se
        // centre dedans. Deux `Spacer` encadraient le logo : ils le mettaient
        // en concurrence pour l'espace libre, et une taille fixe de 280 px
        // faisait déborder la colonne de 64 px sur un 360 × 640 avec une
        // partie reprenable — la hauteur exacte du bouton qui passait sous le
        // bord. Ici le logo est le seul à pouvoir céder, et il ne cède que
        // quand il n'y a plus le choix : à taille normale, il garde ses 280.
        // Le bloc d'identité prend ce que les entrées laissent, et s'y réduit
        // — logo et nom ensemble, pour qu'ils gardent leurs proportions. Le
        // `Flexible` posé sur le seul logo ne suffisait pas : il laissait
        // rétrécir le dessin, pas le mot, et à ×3,1 « Cékoi » réclame à lui
        // seul 139 px de haut. La colonne débordait alors de 130 px.
        //
        // Le `scaleDown` ne fait rien tant que ça tient : mesuré avec les
        // quatre entrées, la réduction vaut 1,00 à taille normale, 0,87 au
        // maximum d'Android, et 0,46 sur ce réglage et un petit écran.
        //
        // En dessous de [_hauteurMinimaleDeLIdentite], il ne reste plus rien
        // qui vaille d'être regardé : au pire cas mesuré — AX5 sur un
        // 360 × 640 avec quatre entrées — le bloc tombe à **4 %**, soit un
        // logo de 13 px et un nom de 6. Il s'efface alors, et les entrées
        // récupèrent sa place. Un logo illisible ne vaut pas mieux que pas de
        // logo, et ce sont les entrées qui font cet écran.
        Expanded(
          child: LayoutBuilder(
            builder: (context, contraintes) {
              if (contraintes.maxHeight < _hauteurMinimaleDeLIdentite) {
                return const SizedBox.shrink();
              }
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Le logo annonce les trois manches — la bulle qui
                      // parle, le « 1 » du mot unique, le personnage qui
                      // mime. C'est la version détourée : le dessin se pose
                      // sur le fond de l'écran, sans le carré corail qu'il
                      // traînait, qui se serait vu sur ce pastel.
                      //
                      // Pas de `Flexible` : sous un `FittedBox` la colonne
                      // est composée sous une hauteur infinie, donc
                      // `RenderFlex` ne distribue rien et un enfant flexible
                      // reçoit les mêmes contraintes que les autres. C'était
                      // devenu un filet qui ne retenait plus rien.
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 280,
                          maxWidth: 280,
                        ),
                        child: Image.asset(
                          'assets/branding/logo_mark.png',
                          fit: BoxFit.contain,
                          semanticLabel: l10n.appTitle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Pas de `TexteQuiTient` ici : le `FittedBox` le rend
                      // inutile. Il compose son enfant sans borne de largeur
                      // puis réduit l'ensemble — le nom ne peut donc plus
                      // être rogné, alors qu'il réclamait 355,5 px dans 312
                      // à ×3,1.
                      Text(
                        l10n.appTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              letterSpacing: -1,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (resumable != null) ...[
          _HomeAction(
            label: l10n.homeResumeGame,
            // La reprise vient en second : c'est le cas rare, et elle ne doit
            // pas prendre la place de « Jouer ». Le corail la distingue sans
            // la mettre en avant.
            reprise: true,
            onPressed: () {
              ref.read(currentGameProvider.notifier).game = resumable;
              unawaited(context.push(AppRoutes.game));
            },
          ),
          const SizedBox(height: 12),
        ],
        // L'action principale, dans le teal des étincelles du logo : sur ce
        // corail, c'est le seul contraste qui ne vibre pas.
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
        _HomeAction(
          label: l10n.homeSettings,
          onPressed: () => unawaited(context.push(AppRoutes.settings)),
        ),
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
