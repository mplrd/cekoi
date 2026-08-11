import 'package:cekoi/domain/rules/round.dart';
import 'package:flutter/material.dart';

/// Palette de l'application, entièrement tirée de `assets/branding/logo.svg`.
///
/// Trois couleurs sortent du dessin et tout le reste en découle :
///
/// * le **fond** du logo — le corail — est la couleur principale ;
/// * ce corail **pastélisé** est le fond de tous les écrans ;
/// * le **personnage** qui court — le vert sauge — est la couleur secondaire,
///   avec le teal des étincelles pour version foncée quand il faut porter du
///   texte clair.
///
/// Rien ici ne passe par `ColorScheme.fromSeed` : la dérivation Material
/// fabriquait un brique boueux à partir du corail, une teinte qui n'est nulle
/// part dans le logo et qu'on retrouvait sur tous les boutons d'action.
abstract final class AppColors {
  /// Le fond du logo. La couleur principale de l'application.
  static const Color main = Color(0xFFFA7567);

  /// Le fond de **tous** les écrans : le corail à 40 % sur blanc.
  ///
  /// Assez pastel pour qu'une liste de vingt catégories reste confortable,
  /// assez teinté pour qu'on reconnaisse l'icône qu'on vient de toucher. Les
  /// écrans ne se distinguent plus par leur fond — ils partagent le même.
  static const Color ground = Color(0xFFFDC8C2);

  /// Le corail à 15 %, pour ce qui doit se détacher du fond sans devenir une
  /// surface à part entière : champs de saisie, tuiles non retenues.
  static const Color groundSoft = Color(0xFFFEEDEB);

  /// Le personnage du logo. La couleur secondaire.
  ///
  /// Trop claire pour porter du blanc : elle se remplit d'encre. C'est la
  /// couleur de ce qui est **choisi** — une case cochée, une catégorie
  /// retenue, une équipe qui vient de marquer.
  static const Color secondary = Color(0xFFBDDDC7);

  /// Le teal des étincelles : la même famille que [secondary], en foncé.
  ///
  /// C'est la seule couleur du logo qui porte du texte blanc sans effort, donc
  /// celle des actions principales. Sur le corail elle tranche sans vibrer.
  static const Color deep = Color(0xFF08686A);

  /// Le rouge de l'explosion. Urgence du chrono, et rien d'autre : une couleur
  /// d'alerte qui sert aussi de décoration n'alerte plus.
  static const Color urgent = Color(0xFFF42B0D);

  /// L'encre du jeu : le noir chaud des contours du dessin.
  static const Color ink = Color(0xFF1A0F0C);

  /// L'encre atténuée, pour les mentions secondaires.
  static Color get inkSoft => ink.withValues(alpha: 0.65);

  /// La surface des vraies cartes — celle qu'on fait deviner, le tableau des
  /// scores, une catégorie de la liste. Blanche parce que c'est du papier.
  ///
  /// À ne pas confondre avec un bouton : aucune action de l'application n'est
  /// blanche, elles sont toutes pleines et colorées.
  static const Color card = Colors.white;

  /// Couleurs d'équipe.
  ///
  /// Les quatre premières viennent du logo — rouge, teal, orange, sauge — et
  /// les suivantes les prolongent à saturation comparable. Elles doivent
  /// rester distinguables entre elles **et** lisibles sur [ground].
  static const List<Color> teamColors = [
    Color(0xFFF42B0D),
    Color(0xFF08686A),
    Color(0xFFF87734),
    Color(0xFF3E8C63),
    Color(0xFF1982C4),
    Color(0xFFB5179E),
    Color(0xFF6A4C93),
    Color(0xFFA37B0C),
  ];

  /// Couleur d'une équipe à partir de son `colorId`.
  ///
  /// Le modulo est volontaire : le nombre d'équipes n'a pas de limite haute
  /// (R8.1), la palette si.
  static Color team(int colorId) =>
      teamColors[colorId.abs() % teamColors.length];

  /// L'accent d'une manche.
  ///
  /// Les trois manches sont l'information qu'on perd le plus vite en jouant —
  /// « on est à la deux ou à la trois ? ». Elle se lit sur l'anneau du chrono
  /// et sur la pastille de manche, pas en repeignant l'écran : le fond reste
  /// le même partout, c'est ce qui tient l'application ensemble.
  static Color round(Round round) => switch (round) {
    Round.freeDescription => main,
    Round.oneWord => deep,
    Round.mime => urgent,
  };

  /// L'encre à poser sur [round].
  ///
  /// Se calcule et ne se devine pas : du blanc sur le corail tombe à 2,6:1,
  /// sous le seuil lisible, alors qu'il passe largement sur les deux autres.
  static Color onRound(Round round) =>
      round == Round.freeDescription ? ink : Colors.white;
}
