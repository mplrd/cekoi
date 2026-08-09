---
name: flutter-feature
description: Implémente une fonctionnalité verticale de Cékoi — domaine, données, interface et tests. À utiliser pour construire un écran, un parcours, une règle de jeu ou une couche de persistance, en respectant l'architecture du projet.
---

Tu implémentes une fonctionnalité de bout en bout dans Cékoi : logique de domaine,
persistance si nécessaire, interface, et tests.

## Avant d'écrire du code

Charge la skill `flutter-conventions`. Si la tâche touche aux manches, tours, chrono, tirage,
scoring ou composition d'équipes, charge aussi `game-engine` et lis `docs/RULES.md`.

Lis ensuite le code voisin. Le projet a des patterns établis — providers Riverpod générés,
entités Freezed, DAO Drift — et une fonctionnalité qui s'en écarte coûtera plus cher à relire
qu'à réécrire.

## Contraintes non négociables

**`lib/domain/` n'importe jamais `package:flutter`.** Si tu as besoin d'une couleur ou d'une
icône dans le domaine, stocke un identifiant et fais la conversion en présentation.

**La logique de jeu vit dans le réducteur, pas dans les contrôleurs ni les widgets.** Si tu
écris un `if` sur une règle de manche dans un `ConsumerWidget`, c'est au mauvais endroit.

**Les règles viennent de `docs/RULES.md`.** Si le comportement demandé n'y figure pas, complète
la spec d'abord et signale-le — n'invente pas une règle silencieusement dans le code.

**Aucune chaîne affichable en dur.** Tout passe par les ARB de `lib/l10n/`.

**Aucune fonctionnalité de jeu ne dépend du réseau ni de la pub.** Si un chargement
publicitaire échoue, la partie démarre quand même.

## Tests

Le domaine se teste en priorité, en Dart pur, avec les numéros de règles dans les noms de test
(`test('R4.1 — ...')`). Les widget tests sont réservés aux parcours critiques : configuration
complète d'une partie, et un tour de jeu.

Utilise des constructeurs de test partagés plutôt que de monter un `GameState` à la main dans
chaque test.

## Avant de rendre

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze     # zéro avertissement
flutter test
```

Si `flutter analyze` remonte quelque chose, corrige le code — ne désactive pas la règle de
lint. Si une règle te paraît réellement inadaptée au projet, signale-le plutôt que de la
contourner.

## Compte rendu

Indique les fichiers créés et modifiés, les règles de `RULES.md` couvertes, les tests ajoutés,
et surtout **ce que tu n'as pas fait** : cas limites laissés de côté, hypothèses prises sur
une spec ambiguë, dette assumée. Un rapport qui cache une approximation coûte plus cher que
l'approximation elle-même.
