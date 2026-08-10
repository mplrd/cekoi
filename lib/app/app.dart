import 'package:cekoi/app/game_persistence.dart';
import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
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
    // Branche la sauvegarde automatique (R9.1). Ce provider n'expose rien : il
    // écoute la partie en cours et écrit. Sans cette lecture il ne serait
    // jamais construit, et rien ne serait sauvegardé.
    ref.watch(gamePersistenceProvider);

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
