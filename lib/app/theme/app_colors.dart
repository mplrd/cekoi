import 'package:flutter/material.dart';

/// Palette de l'application.
///
/// Les couleurs d'équipe sont exposées par index : le domaine ne connaît qu'un
/// `colorId` entier, la conversion se fait ici et nulle part ailleurs.
abstract final class AppColors {
  static const Color seed = Color(0xFF6A4C93);

  /// Action *Trouvé* de l'écran de jeu. Volontairement franche : elle doit se
  /// lire à un mètre, sur un téléphone tenu à bout de bras.
  static const Color found = Color(0xFF2E9E5B);

  /// Dix dernières secondes du chrono.
  static const Color urgent = Color(0xFFD1495B);

  static const List<Color> teamColors = [
    Color(0xFF6A4C93),
    Color(0xFF1982C4),
    Color(0xFF2E9E5B),
    Color(0xFFFF924C),
    Color(0xFFD1495B),
    Color(0xFF8AC926),
    Color(0xFF00B4D8),
    Color(0xFFB5179E),
  ];

  /// Couleur d'une équipe à partir de son `colorId`.
  ///
  /// Le modulo est volontaire : le nombre d'équipes n'a pas de limite haute
  /// (R8.1), la palette si.
  static Color team(int colorId) =>
      teamColors[colorId.abs() % teamColors.length];
}
