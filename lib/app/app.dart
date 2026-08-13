import 'package:cekoi/app/game_persistence.dart';
import 'package:cekoi/app/ownership.dart';
import 'package:cekoi/app/preferences.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/ads/ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CekoiApp extends ConsumerWidget {
  CekoiApp({super.key, GoRouter? router}) : router = router ?? appRouter;

  /// Injectable pour les tests widget, qui ont besoin d'un routeur neuf à
  /// chaque parcours.
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      // Branche la sauvegarde automatique (R9.1). Ce provider n'expose rien :
      // il écoute la partie en cours et écrit. Sans cette lecture il ne serait
      // jamais construit, et rien ne serait sauvegardé.
      ..watch(gamePersistenceProvider)
      // Déclenche le consentement publicitaire au lancement, avant toute
      // requête de pub (`MONETISATION.md`). Lu et non attendu : l'accueil
      // s'affiche pendant que le CMP travaille, et une panne du CMP n'empêche
      // pas de jouer.
      //
      // Le notifier et non la valeur : il suffit à maintenir le provider en
      // vie, et il est stable. Écouter la valeur reconstruirait tout le
      // `MaterialApp` à chaque changement d'état du consentement — deux fois
      // au lancement, et à chaque passage par les réglages.
      ..watch(adConsentProvider.notifier)
      // Écoute le magasin pour toute la durée de vie de l'application : un
      // paiement différé se conclut longtemps après l'écran qui l'a lancé.
      ..watch(storeListenerProvider)
      // Charge les réglages au lancement : la lecture est asynchrone, et un
      // premier accès au milieu d'un tour répondrait par les valeurs par
      // défaut. Le notifier et non la valeur, pour la même raison que
      // ci-dessus — sinon chaque bascule d'interrupteur reconstruirait tout
      // le `MaterialApp`.
      ..watch(appPreferencesControllerProvider.notifier);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
