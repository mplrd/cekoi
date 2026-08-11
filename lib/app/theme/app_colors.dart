import 'package:flutter/material.dart';

/// Palette de l'application.
///
/// Les couleurs d'équipe sont exposées par index : le domaine ne connaît qu'un
/// `colorId` entier, la conversion se fait ici et nulle part ailleurs.
abstract final class AppColors {
  /// Le corail du logo (`assets/branding/logo.svg`), dont Material dérive tout
  /// le reste. C'est la couleur qu'on voit d'abord sur l'icône de lanceur :
  /// l'application doit la retrouver en s'ouvrant.
  static const Color seed = Color(0xFFFA7567);

  /// Le teal des étincelles du logo, son seul contrepoint froid. Sert partout
  /// où il faut trancher sur le corail sans le concurrencer.
  static const Color accent = Color(0xFF08686A);

  /// Action *Trouvé !* de l'écran de jeu. Volontairement franche : elle doit
  /// se lire à un mètre, sur un téléphone tenu à bout de bras.
  ///
  /// C'est le teal du logo et non un vert d'usage : sur un fond corail, un
  /// vert franc vibre désagréablement, alors que ces deux teintes se répondent
  /// — c'est exactement le contraste que le logo installe.
  static const Color found = accent;

  /// Dix dernières secondes du chrono : le rouge de l'explosion du logo.
  static const Color urgent = Color(0xFFF42B0D);

  /// Couleurs d'équipe.
  ///
  /// Les quatre premières viennent du logo — corail, teal, rouge, vert d'eau —
  /// et les suivantes les prolongent en gardant la même saturation, pour
  /// qu'une cinquième équipe n'ait pas l'air d'appartenir à une autre
  /// application. Elles doivent rester distinguables entre elles **et** sur
  /// fond clair comme sombre.
  static const List<Color> teamColors = [
    Color(0xFFF42B0D),
    Color(0xFF08686A),
    Color(0xFFF87734),
    Color(0xFF5C9E7F),
    Color(0xFF1982C4),
    Color(0xFFB5179E),
    Color(0xFF6A4C93),
    Color(0xFFC8A415),
  ];

  /// Couleur d'une équipe à partir de son `colorId`.
  ///
  /// Le modulo est volontaire : le nombre d'équipes n'a pas de limite haute
  /// (R8.1), la palette si.
  static Color team(int colorId) =>
      teamColors[colorId.abs() % teamColors.length];
}
