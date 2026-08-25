/// La longueur au-delà de laquelle une carte devient illisible à bout de bras.
///
/// Soixante, comme `MAX_TEXT_LENGTH` dans `tool/import_decks.py` : la règle
/// existait déjà pour le contenu officiel, `docs/CONTENU.md` la documente, et
/// l'import la refuse depuis toujours. Ce qui manquait, c'est qu'elle
/// s'applique aussi à ce que le joueur écrit lui-même — deux jeux de règles
/// pour les cartes d'une même partie auraient fini par diverger.
///
/// Assez pour une situation — « Se cogner le petit orteil dans le meuble » en
/// fait 39 — et trop peu pour un paragraphe.
///
/// Ce que cette borne **ne** règle **pas** : un mot unique de trente-trois
/// caractères tient dans les soixante et se fait quand même rogner à
/// l'affichage, faute du moindre point de coupure. Borner la saisie et
/// composer le texte sont deux problèmes distincts, et il faut les deux.
const maxCardTextLength = 60;

/// Vrai si ce texte peut devenir une carte, une fois débarrassé de ses blancs.
///
/// Le `trim` est fait ici plutôt que chez l'appelant : c'est la longueur du
/// texte **enregistré** qui compte, et un joueur qui colle un texte suivi de
/// trois espaces ne comprendrait pas d'être refusé.
bool cardTextFits(String texte) => texte.trim().length <= maxCardTextLength;
