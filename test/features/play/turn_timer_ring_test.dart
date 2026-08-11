import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/features/play/presentation/widgets/turn_timer_ring.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une manche sombre : encre claire sur fond foncé.
const Color _encre = Colors.white;
const Color _fond = AppColors.accent;

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  Future<Text> pumpRing(
    WidgetTester tester, {
    required Duration remaining,
    Duration total = const Duration(seconds: 60),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TurnTimerRing(
            remaining: remaining,
            total: total,
            ink: _encre,
            ground: _fond,
          ),
        ),
      ),
    );
    return tester.widget<Text>(find.byType(Text));
  }

  group('les dix dernières secondes se renversent', () {
    // Depuis que chaque manche a sa couleur de fond, une teinte d'urgence
    // fixe se noyait dedans — le rouge était invisible sur le rouge de la
    // manche 3, au moment exact où il compte. L'anneau se remplit donc de
    // l'encre et le nombre passe en négatif : le contraste ne dépend plus du
    // fond.
    testWidgets('au-dessus du seuil, le nombre est dans l encre', (
      tester,
    ) async {
      final texte = await pumpRing(
        tester,
        remaining: const Duration(seconds: 11),
      );

      expect(texte.style?.color, _encre);
    });

    testWidgets('à dix secondes pile, le renversement est déjà là', (
      tester,
    ) async {
      // Le seuil est inclusif : `SPEC.md` parle des dix dernières secondes,
      // pas des neuf dernières.
      final texte = await pumpRing(
        tester,
        remaining: const Duration(seconds: 10),
      );

      expect(texte.style?.color, _fond);
    });
  });

  group('le nombre affiché', () {
    testWidgets('arrondit vers le haut', (tester) async {
      // Afficher 0 alors qu'il reste 400 ms ferait croire à un chrono cassé
      // quand la dernière carte tombe juste après.
      await pumpRing(tester, remaining: const Duration(milliseconds: 400));

      expect(find.text(l10n.gameSecondsLeft(1)), findsOneWidget);
    });

    testWidgets('ne descend à zéro qu’une fois le temps réellement écoulé', (
      tester,
    ) async {
      await pumpRing(tester, remaining: Duration.zero);

      expect(find.text(l10n.gameSecondsLeft(0)), findsOneWidget);
    });
  });
}
