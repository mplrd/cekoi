import 'package:cekoi/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Thèmes clair et sombre.
///
/// Le contexte d'usage guide tout : téléphone tenu à bout de bras, souvent
/// debout, lu par des joueurs à un mètre. D'où des cibles tactiles larges et
/// une typographie généreuse plutôt que les valeurs Material par défaut.
abstract final class AppTheme {
  /// Hauteur minimale d'une zone tactile principale.
  ///
  /// Material recommande 48. On monte à 64 parce qu'on vise le pouce d'une
  /// personne debout qui ne regarde pas l'écran en permanence.
  static const double minTouchTarget = 64;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(minTouchTarget),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(minTouchTarget),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
    );
  }
}
