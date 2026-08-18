import 'dart:async';

import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/launch_ad.dart';
import 'package:cekoi/app/ownership.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/domain/engine/draw.dart';
import 'package:cekoi/domain/entities/card.dart' as domain;
import 'package:cekoi/domain/entities/game_config.dart';
import 'package:cekoi/domain/setup/game_launch.dart';
import 'package:cekoi/domain/setup/game_setup.dart';
import 'package:cekoi/features/setup/presentation/deck_catalog.dart';
import 'package:cekoi/features/setup/presentation/setup_controller.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Les noms d'équipe par défaut, « Équipe 1 », « Équipe 2 »… (R8.3).
///
/// Ils vivent ici et non dans le domaine, qui ne fabrique aucun libellé : c'est
/// la présentation qui comble les noms laissés vides, au moment de construire
/// les équipes.
List<String> _fallbackTeamNames(GameSetup setup, AppLocalizations l10n) => [
  for (var i = 0; i < setup.teamCount; i++) l10n.teamDefaultName(i + 1),
];

/// *Lancer la partie* : le tirage du paquet, l'interstitiel, et la partie.
///
/// Posé au pied de la dernière étape de la configuration.
///
/// Il a eu un écran pour lui — un récapitulatif qui listait le mode, les
/// catégories, la durée et les équipes — puis un second, « Installez-vous, la
/// partie commence », pour porter la publicité. Les deux ont été retirés : le
/// premier n'apprenait rien à qui venait de tout choisir, le second redisait ce
/// que l'annonce du tour affiche juste après. Une pub interstitielle est un
/// plein écran, elle recouvre ce qui est dessous et n'a besoin de personne.
class LaunchButton extends ConsumerStatefulWidget {
  const LaunchButton({super.key});

  @override
  ConsumerState<LaunchButton> createState() => _LaunchButtonState();
}

class _LaunchButtonState extends ConsumerState<LaunchButton> {
  /// Le portillon travaille : trois secondes au pire, et le plus souvent rien.
  ///
  /// Sans cet état, le bouton reste inerte le temps du chargement de la pub et
  /// on tape deux fois — donc deux tirages et deux parties.
  bool _enCours = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final setup = ref.watch(setupControllerProvider);
    final catalog = switch (ref.watch(deckCatalogProvider(setup.mode))) {
      AsyncData<DeckCatalog>(:final value) => value,
      _ => null,
    };
    final pool = catalog?.cards;

    if (pool == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Aucun tirage ici : seulement un décompte des cartes éligibles. Le paquet
    // définitif est tiré au clic, avec une graine prise à cet instant.
    final available = catalog!.availableCards(
      deckIds: setup.deckIds.toSet(),
      difficulties: setup.difficulties,
      adultOnly: setup.adultOnly,
    );
    final verdict = PoolVerdict(
      available: available,
      requested: setup.resolvedCardCount,
    );

    // La mention ne dépend que de ce que le joueur possède : la version
    // complète retire la publicité, tout le monde l'a.
    //
    // Et de rien d'autre. Le consentement refusé et le plafond de fréquence
    // sont des raisons de ne pas *charger* une pub à cet instant — pas des
    // raisons de laisser croire qu'on en est débarrassé.
    //
    // Le repli tait la mention plutôt que de l'afficher : c'est la convention
    // de `launch_ad.dart`, où l'absence de réponse ne doit jamais valoir
    // autorisation. Il est de toute façon inatteignable ici — le garde sur
    // `pool` ci-dessus a déjà attendu `deckCatalogProvider`, qui attend
    // lui-même la possession — mais l'afficher par défaut ferait clignoter la
    // ligne chez qui a payé si cet ordre changeait.
    final avecPub = ref.watch(ownershipProvider).value?.showsAds ?? false;

    return PopScope(
      // Le retour est fermé le temps du chargement — trois secondes au pire.
      //
      // Sans ça, un retour pendant l'attente ramène à l'étape précédente et la
      // pub s'affiche par-dessus un écran de configuration, ce que
      // `MONETISATION.md` interdit nommément ; le quota serait en plus
      // consommé pour une pub que personne n'a demandée.
      canPop: !_enCours,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!verdict.isPlayable)
            _Notice(
              text: l10n.launchImpossible(
                available,
                GameConfig.minimumCardCount,
              ),
              isError: true,
            ),
          if (verdict.mustWarnShortage)
            _Notice(text: l10n.launchTruncated(available)),
          if (avecPub && verdict.isPlayable) _Notice(text: l10n.launchAdNotice),
          FilledButton(
            onPressed: verdict.isPlayable && setup.canStart && !_enCours
                ? () => unawaited(_launch(pool))
                : null,
            child: _enCours
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(l10n.actionStartGame),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(List<domain.Card> pool) async {
    // Le bouton grisé ne protège du double tap que si une frame est rendue
    // entre les deux — vrai en pratique, 16 ms contre une centaine pour un
    // appui réel, mais la closure de `onPressed` ne relit pas `_enCours`. Cette
    // ligne le relit, et deux taps dans la même frame ne lancent qu'une partie.
    //
    // Elle ne couvre pas la transition de route : `_enCours` est déjà retombé
    // quand `push` s'exécute. Là, c'est la route entrante qui recouvre l'écran.
    if (_enCours) return;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final setup = ref.read(setupControllerProvider);
    final outcome = launchGame(
      setup: setup,
      teams: setup.teamsNamed(_fallbackTeamNames(setup, l10n)),
      pool: pool,
      seed: ref.read(seedSourceProvider)(),
    );

    final game = outcome.game;
    if (game == null) {
      // Inatteignable tant que le bouton est grisé au bon moment. Mais un
      // bouton qui ne fait rien sans un mot est le pire des états si cet
      // invariant bouge : mieux vaut dire pourquoi.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.launchImpossible(
              outcome.draw.available,
              GameConfig.minimumCardCount,
            ),
          ),
        ),
      );
      return;
    }

    // Le paquet est tiré **avant** la pub : au retour de l'interstitiel, il
    // n'y a plus rien à attendre.
    ref.read(currentGameProvider.notifier).game = game;

    // L'interstitiel se déclenche ici, au tap sur « Lancer la partie ». C'est
    // le seul emplacement autorisé par `MONETISATION.md`, parce que le temps
    // mort existe déjà — le groupe s'installe et se passe le téléphone.
    setState(() => _enCours = true);
    await ref.read(interstitialGateProvider).present();
    if (!mounted) return;
    setState(() => _enCours = false);

    // `push` et non `go` : la configuration reste sous la partie, pour que le
    // retour y ramène tant que le premier tour n'a pas commencé.
    unawaited(context.push(AppRoutes.game));
  }
}

/// Une ligne d'avertissement au-dessus du bouton.
class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isError
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
