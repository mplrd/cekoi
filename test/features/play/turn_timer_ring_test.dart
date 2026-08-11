import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/features/play/presentation/widgets/turn_timer_ring.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'accent d'une manche quelconque : l'anneau le porte, le nombre non.
const Color _accent = AppColors.deep;

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
            accent: _accent,
          ),
        ),
      ),
    );
    return tester.widget<Text>(find.byType(Text));
  }

  group('les dix dernières secondes se renversent', () {
    // Le nombre reste en encre sombre tant qu'il reste du temps, quelle que
    // soit la manche : l'accent d'une manche peut être clair — le corail — et
    // un chiffre de cette teinte serait illisible sur le fond pastel. Sous le
    // seuil, le disque se remplit de rouge et le nombre passe en blanc : le
    // renversement se voit du coin de l'œil, un simple changement de teinte
    // non.
    testWidgets('au-dessus du seuil, le nombre est dans l encre', (
      tester,
    ) async {
      final texte = await pumpRing(
        tester,
        remaining: const Duration(seconds: 11),
      );

      expect(texte.style?.color, AppColors.ink);
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

      expect(texte.style?.color, Colors.white);
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
