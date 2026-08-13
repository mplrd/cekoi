import 'dart:async';

import 'package:cekoi/app/launch_ad.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// L'écran de lancement de partie : le seul emplacement interstitiel autorisé.
///
/// Le temps mort existe déjà — c'est le moment où le groupe s'installe, se
/// répartit autour de la table et se passe le téléphone. On ne le fabrique
/// pas, on l'occupe. D'où le texte, qui est une consigne réelle et non un
/// habillage de pub, et le rappel de la contrainte de la manche 1, qui est ce
/// que la table a besoin de savoir à cette seconde-là.
///
/// **Cet écran ne peut pas retenir une partie.** Le portillon décide seul,
/// n'attend jamais plus de trois secondes un chargement, et rend la main quoi
/// qu'il arrive : consentement refusé, plafond atteint, pub indisponible,
/// SDK en panne — la partie démarre.
class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});

  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen> {
  @override
  void initState() {
    super.initState();
    // Après la première frame : l'écran doit être peint avant que la pub le
    // recouvre, sinon le joueur voit un écran noir se faire remplacer par une
    // pub, et n'a jamais lu la consigne.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  Future<void> _run() async {
    await ref.read(interstitialGateProvider).present();
    if (!mounted) return;

    // `pushReplacement` : l'écran de lancement ne doit pas rester dans la
    // pile. Le retour depuis la partie ramène au récapitulatif, comme avant —
    // le retour reste libre tant que le premier tour n'a pas commencé.
    context.pushReplacement(AppRoutes.game);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Le retour est fermé le temps de la traversée — trois secondes au pire.
    // Sans ça, un retour pendant le chargement ramène au récapitulatif et la
    // pub s'affiche par-dessus : `MONETISATION.md` interdit nommément tout
    // interstitiel sur un écran de configuration, et le quota serait consommé
    // pour une pub que personne n'a demandée.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          // Défilable, comme tous les autres écrans du parcours : sur un
          // 360 × 640 au texte agrandi d'un tiers — le pire cas de référence
          // du projet — la colonne centrée débordait de 223 px, et c'est le
          // rappel de la manche 1 qui se faisait couper. Exactement ce que six
          // personnes viennent lire à cette seconde-là.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.launchSettleIn,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                      ),
                      const SizedBox(height: 32),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                l10n.roundNameFree,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.roundRuleFree,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
