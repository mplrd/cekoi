import 'package:cekoi/features/decks/presentation/deck_cards_screen.dart';
import 'package:cekoi/features/decks/presentation/my_decks_screen.dart';
import 'package:cekoi/features/home/presentation/home_screen.dart';
import 'package:cekoi/features/play/presentation/game_screen.dart';
import 'package:cekoi/features/settings/presentation/app_settings_screen.dart';
import 'package:cekoi/features/setup/presentation/decks_screen.dart';
import 'package:cekoi/features/setup/presentation/mode_screen.dart';
import 'package:cekoi/features/setup/presentation/pool_screen.dart';
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
/// Les étapes de la configuration s'empilent : le retour de `SPEC.md` est le
/// retour système, sans code de navigation à écrire. Six routes pour cinq
/// étapes — la deuxième a deux écrans, un par mode (R7.10).
abstract final class AppRoutes {
  static const String home = '/';
  static const String setupMode = '/jouer/mode';
  static const String setupDecks = '/jouer/categories';
  static const String setupPool = '/jouer/vivier';
  static const String setupSettings = '/jouer/reglages';
  static const String setupTeams = '/jouer/equipes';
  static const String setupSummary = '/jouer/recap';
  static const String game = '/partie';
  static const String myDecks = '/mes-categories';

  /// Les réglages de l'application — à ne pas confondre avec [setupSettings],
  /// qui est l'étape 3 de la configuration d'une partie.
  static const String settings = '/reglages';

  /// Cartes d'une catégorie du joueur.
  static String deckCards(String deckId) => '$myDecks/$deckId';
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
      path: AppRoutes.setupPool,
      name: 'setup-pool',
      builder: (context, state) => const PoolScreen(),
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
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (context, state) => const AppSettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.myDecks,
      name: 'my-decks',
      builder: (context, state) => const MyDecksScreen(),
      routes: [
        GoRoute(
          path: ':deckId',
          name: 'deck-cards',
          builder: (context, state) =>
              DeckCardsScreen(deckId: state.pathParameters['deckId']!),
        ),
      ],
    ),
  ],
);

final GoRouter appRouter = createAppRouter();
