import 'package:cekoi/app/theme/app_colors.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que le thème doit garantir, et qu'aucun écran ne vérifie pour lui.
void main() {
  final theme = AppTheme.light();

  group('les styles posés portent leur taille', () {
    // `ThemeData.textTheme` n'emporte pas la géométrie : elle n'est fusionnée
    // qu'au rendu. Un style qu'on en dérive a donc un `fontSize` nul, ce qui
    // reste sans effet tant qu'il est hérité — mais l'`AppBar` *remplace* le
    // style ambiant au lieu de le fusionner, et son titre retombe alors sur
    // les 14 px par défaut de `TextStyle`. Le défaut a survécu à une revue et
    // à une lecture de capture ; il n'est tombé qu'à la mesure.

    test('le titre de la barre n est pas retombé au défaut de TextStyle', () {
      expect(theme.appBarTheme.titleTextStyle?.fontSize, isNotNull);
      expect(
        theme.appBarTheme.titleTextStyle!.fontSize,
        greaterThan(16),
        reason: 'un titre de barre plus petit que le corps du texte',
      );
    });

    test('le libellé des actions non plus', () {
      final style = theme.filledButtonTheme.style?.textStyle?.resolve({});
      expect(style?.fontSize, isNotNull);
      expect(style!.fontSize, greaterThanOrEqualTo(18));
    });

    test('la famille suit la plateforme plutôt qu une police figée', () {
      // Le style vient du `textTheme` du thème, donc de la typographie que
      // `ThemeData` choisit selon la plateforme. Figer `Typography` aurait
      // imposé Roboto sur iOS, à côté de la police système du reste.
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, isNotNull);
    });
  });

  group('l encre se calcule sur la couleur qui la porte', () {
    // La palette a huit couleurs d'équipe : le blanc ne passe pas sur toutes,
    // l'orange du logo tombait à 2,7:1. Le seuil est celui de WCAG pour du
    // texte courant.
    double contraste(Color premier, Color second) {
      final a = premier.computeLuminance();
      final b = second.computeLuminance();
      final clair = a > b ? a : b;
      final sombre = a > b ? b : a;
      return (clair + 0.05) / (sombre + 0.05);
    }

    test('chaque couleur d équipe reste lisible sous son encre', () {
      for (var id = 0; id < AppColors.teamColors.length; id++) {
        expect(
          contraste(AppColors.team(id), AppColors.onTeam(id)),
          greaterThanOrEqualTo(4.5),
          reason: 'équipe $id',
        );
      }
    });

    test('le fond pastel porte l encre du jeu', () {
      expect(
        contraste(AppColors.ground, AppColors.ink),
        greaterThanOrEqualTo(4.5),
      );
      // L'encre atténuée porte de vraies informations — le nombre de cartes
      // restantes, l'étape en cours : elle doit rester au-dessus du seuil.
      expect(
        contraste(AppColors.ground, AppColors.inkSoft),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('les surfaces claires portent l encre, jamais l inverse', () {
      for (final surface in [
        AppColors.card,
        AppColors.groundSoft,
        AppColors.secondary,
      ]) {
        expect(contraste(surface, AppColors.ink), greaterThanOrEqualTo(4.5));
      }
    });
  });
}
