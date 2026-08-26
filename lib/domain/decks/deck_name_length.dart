import 'package:characters/characters.dart';

/// La longueur au-delà de laquelle le nom d'une catégorie déforme sa liste.
///
/// Trente, et le nombre sort d'une mesure sur un 360 × 640, la géométrie la
/// plus étroite qu'on vise, en comptant la hauteur de la ligne dans « Mes
/// catégories » à l'échelle normale puis au maximum d'Android :
///
/// | Longueur | Ligne ×1 | Ligne ×2 |
/// |---|---|---|
/// | 22 — le plus long nom officiel | 72 px | 192 px |
/// | **30** | **84 px** | **240 px** |
/// | 40 | 84 px | 288 px |
/// | 60 — la borne des cartes | 108 px | 384 px, **et le texte est rogné** |
///
/// Trente laisse donc de la marge au-dessus du plus long nom officiel
/// — « Humour noir et galères » — et garde la ligne à un tiers d'un petit
/// écran dans le pire réglage. Soixante, la borne des cartes, n'aurait pas
/// convenu : un nom n'est pas une carte, il se lit dans une liste au milieu
/// d'autres, pas seul sur un écran.
///
/// Ce que cette borne évite, mesuré sans elle : à trois cents caractères, la
/// ligne fait 288 px de haut, le nom en un seul mot est **rogné**, la boîte de
/// suppression occupe l'écran entier, et au maximum d'Android l'entrée
/// « Supprimer » de son menu devient introuvable — la catégorie n'est alors
/// plus supprimable.
const maxDeckNameLength = 30;

/// Vrai si ce texte peut nommer une catégorie, une fois débarrassé de ses
/// blancs.
///
/// Compté en **grappes de graphèmes**, comme la longueur des cartes et pour la
/// même raison : c'est ce que compte le `maxLength` d'un champ Flutter, et deux
/// compteurs qui divergent laissent l'utilisateur sans recours.
bool deckNameFits(String nom) =>
    nom.trim().characters.length <= maxDeckNameLength;
