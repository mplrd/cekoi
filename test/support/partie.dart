import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/preferences.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/features/play/presentation/game_screen.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/feedback/feedback.dart';
import 'package:cekoi/services/feedback/game_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'geometrie.dart';
import 'providers.dart';

/// Monte l'écran de partie **comme l'application le monte**.
///
/// Un fichier de mesure ne vaut pas par ce qu'il asserte, mais par ce qu'il
/// monte. Les quatre tests de géométrie du départage ne voyaient rien parce
/// qu'ils posaient l'écran sans le thème livré, et donc sur la typographie
/// Material par défaut ; c'est ce qui a laissé passer un titre rogné à ×2
/// pendant tout le temps où le dépôt se croyait couvert.
///
/// Recopier ce montage dans chaque fichier, c'est laisser la prochaine copie
/// diverger — et paraître verte. Il vit donc ici, en un seul endroit, et
/// `AppTheme.light()` ne peut plus s'y oublier.
///
/// Ne charge pas les polices : c'est à l'appelant d'appeler
/// [exigerLesVraiesPolices] dans son `setUpAll`, parce que c'est une décision
/// de fichier — un test de contenu n'en a pas besoin, un test de mesure ne peut
/// pas s'en passer.
///
/// Rend le conteneur, pour que l'appelant puisse relire la partie ou la rendre.
Future<ProviderContainer> monterLaPartie(
  WidgetTester tester,
  GameState game, {
  required Size taille,
  double echelleTexte = 1,

  /// Le temps, quand le test doit le faire avancer. Une horloge figée par
  /// défaut : sans elle, un `Stopwatch` réel tourne sous un temps simulé.
  MonotonicClock? horloge,

  /// Une graine fixe, pour les écrans qui retirent un paquet — le podium.
  int seed = 7,
}) async {
  poserEcran(tester, taille: taille, echelleTexte: echelleTexte);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        monotonicClockProvider.overrideWithValue(
          horloge ?? () => Duration.zero,
        ),
        seedSourceProvider.overrideWithValue(() => seed),
        screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
        gameFeedbackProvider.overrideWithValue(const SilentGameFeedback()),
        currentPreferencesProvider.overrideWithValue(fakePreferences()),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        home: const GameScreen(),
      ),
    ),
  );

  final container = ProviderScope.containerOf(
    tester.element(find.byType(GameScreen)),
  );
  container.read(currentGameProvider.notifier).game = game;

  // `pump` et non `pumpAndSettle` : le compte à rebours de « C'est parti » et
  // le battement de la zone d'action sont des animations qui ne se stabilisent
  // pas d'elles-mêmes. Aucun des écrans montés ici n'en porte, mais un
  // `pumpAndSettle` posé par habitude se met à tourner indéfiniment le jour où
  // la fixture change de phase.
  await tester.pump();
  return container;
}

/// Rend la partie, et laisse l'écran se démonter proprement.
Future<void> rangerLaPartie(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(currentGameProvider.notifier).game = null;
  await tester.pump();
}
