import 'package:cekoi/features/home/presentation/home_screen.dart';
import 'package:cekoi/features/play/presentation/game_screen.dart';
import 'package:cekoi/features/setup/presentation/decks_screen.dart';
import 'package:cekoi/features/setup/presentation/mode_screen.dart';
import 'package:cekoi/features/setup/presentation/settings_screen.dart';
import 'package:cekoi/features/setup/presentation/summary_screen.dart';
import 'package:cekoi/features/setup/presentation/teams_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes de l'application.
///
/// Volontairement déclaratif et nommé dès maintenant : la v2 multi-device
/// rejoindra une partie par lien, et rétro-ajouter des routes nommées coûte
/// plus cher que de les tenir dès le départ.
///
/// Les cinq étapes de la configuration s'empilent : le retour de `SPEC.md`
/// est le retour système, sans code de navigation à écrire.
abstract final class AppRoutes {
  static const String home = '/';
  static const String setupMode = '/jouer/mode';
  static const String setupDecks = '/jouer/categories';
  static const String setupSettings = '/jouer/reglages';
  static const String setupTeams = '/jouer/equipes';
  static const String setupSummary = '/jouer/recap';
  static const String game = '/partie';
}

/// Fabrique un routeur neuf.
///
/// Un routeur porte sa pile de navigation : le partager entre deux tests
/// widget ferait démarrer le second là où le premier s'est arrêté.
GoRouter createAppRouter() => GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.setupMode,
      name: 'setup-mode',
      builder: (context, state) => const ModeScreen(),
    ),
    GoRoute(
      path: AppRoutes.setupDecks,
      name: 'setup-decks',
      builder: (context, state) => const DecksScreen(),
    ),
    GoRoute(
      path: AppRoutes.setupSettings,
      name: 'setup-settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.setupTeams,
      name: 'setup-teams',
      builder: (context, state) => const TeamsScreen(),
    ),
    GoRoute(
      path: AppRoutes.setupSummary,
      name: 'setup-summary',
      builder: (context, state) => const SummaryScreen(),
    ),
    GoRoute(
      path: AppRoutes.game,
      name: 'game',
      builder: (context, state) => const GameScreen(),
    ),
  ],
);

final GoRouter appRouter = createAppRouter();
