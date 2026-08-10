import 'package:cekoi/app/router.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CekoiApp extends StatelessWidget {
  CekoiApp({super.key, GoRouter? router}) : router = router ?? appRouter;

  /// Injectable pour les tests widget, qui ont besoin d'un routeur neuf à
  /// chaque parcours.
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
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
