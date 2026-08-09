import 'package:cekoi/features/home/presentation/home_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes de l'application.
///
/// Volontairement déclaratif et nommé dès maintenant : la v2 multi-device
/// rejoindra une partie par lien, et rétro-ajouter des routes nommées coûte
/// plus cher que de les tenir dès le départ.
abstract final class AppRoutes {
  static const String home = '/';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
