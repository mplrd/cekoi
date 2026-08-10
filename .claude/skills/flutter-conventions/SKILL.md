---
name: flutter-conventions
description: Conventions de code Flutter/Dart du projet Cékoi — découpage en couches, Riverpod, Freezed, Drift, placement des fichiers, widgets, l10n, gestion d'erreur. À charger avant d'écrire ou de modifier du code dans lib/.
---

# Conventions Flutter — Cékoi

Lis `docs/ARCHITECTURE.md` pour la vue d'ensemble. Ce document donne les patterns concrets.

## La règle qui prime sur toutes les autres

**`lib/domain/` n'importe jamais `package:flutter`.** Ni `material.dart`, ni `foundation.dart`,
ni `Color`, ni `IconData`. Le domaine est du Dart pur.

Si tu as besoin d'une couleur d'équipe dans le domaine, stocke un `int` ou un identifiant de
palette et fais la conversion dans la couche présentation. Cette contrainte paraît pénible sur
le moment ; c'est elle qui rend le moteur testable en millisecondes et qui rendra le
multi-device de la v2 réalisable sans réécriture.

Un test d'architecture vérifie cette règle. Ne la contourne pas, signale le besoin.

## Couches

```
domain/      Dart pur. Entités, moteur, règles. Ne dépend de rien.
data/        Drift, JSON, repositories. Dépend de domain.
features/    UI et providers. Dépend de domain et data.
services/    Pub, achats, audio. Derrière des interfaces.
app/         Router, thème, composition.
```

Le sens des dépendances ne s'inverse jamais. Une feature n'importe **jamais** une autre
feature : ce qui doit être partagé remonte d'un cran. `test/architecture_test.dart` le
vérifie, sous les deux formes d'écriture — `package:` et relative. L'état applicatif partagé
entre deux features vit dans `app/` : `currentGameProvider`, `seedSourceProvider`,
`monotonicClockProvider`, `nowProvider`.

## Riverpod

Toujours la génération de code, jamais les constructeurs manuels de providers.

```dart
@Riverpod(keepAlive: true)
class PlayController extends _$PlayController {
  @override
  int? build() => null;

  void found() => _dispatch(const GameEvent.cardFound());

  void _dispatch(GameEvent event) {
    final game = ref.read(currentGameProvider);
    if (game == null) return;
    ref.read(currentGameProvider.notifier).game = reduce(game, event);
  }
}

@riverpod
Future<List<Deck>> availableDecks(Ref ref, Audience audience) {
  return ref.watch(deckRepositoryProvider).byAudience(audience);
}
```

Les contrôleurs **ne contiennent pas de logique de jeu** — ils délèguent au réducteur et
stockent le résultat. Si tu écris un `if` sur des règles de jeu dans un contrôleur, la logique
est au mauvais endroit : elle va dans `domain/engine/`.

Dans les widgets, `ref.watch` pour lire, `ref.read` uniquement dans les callbacks. Préfère
`select` pour éviter les reconstructions inutiles sur l'écran de jeu, qui se rafraîchit
plusieurs fois par seconde à cause du chrono.

## Freezed

Toutes les entités du domaine et tous les états sont des classes `@freezed`. Les événements
sont des unions scellées :

```dart
@freezed
sealed class GameEvent with _$GameEvent {
  const factory GameEvent.turnStarted() = TurnStarted;
  const factory GameEvent.cardFound() = CardFound;
  const factory GameEvent.cardPassed() = CardPassed;
  const factory GameEvent.ticked(Duration elapsed) = Ticked;
  const factory GameEvent.resultCorrected({
    required String cardId,
    required TurnOutcome outcome,
  }) = ResultCorrected;
}
```

Utilise `switch` exhaustif sur les unions, sans branche `default` — c'est ce qui fait échouer
la compilation quand on ajoute un événement sans le traiter, et c'est exactement le filet
qu'on veut.

Après toute modification d'une classe annotée :
`dart run build_runner build --delete-conflicting-outputs`.

## Drift

Les tables sont dans `data/db/tables/`, les requêtes dans des DAO, jamais dans un widget ni
dans un provider d'UI.

Le tirage aléatoire du paquet se fait en SQL, pas en chargeant toutes les cartes en mémoire
pour les mélanger en Dart. Toute requête filtrant sur `audience`, `deck_id` ou `origin` doit
s'appuyer sur un index.

Chaque changement de schéma s'accompagne d'une migration et d'un test de migration. Les
données utilisateur — les lignes `origin = 'custom'` — ne doivent jamais être perdues par une
migration.

## Widgets

- Un widget public par fichier, en `snake_case`.
- `const` partout où c'est possible, en particulier sur l'écran de jeu.
- Pas de widget de plus de 150 lignes environ : extrais en sous-widgets privés du même fichier,
  et en fichiers séparés dès que c'est réutilisé.
- Pas de logique métier dans un `build()`. Pas d'accès à la base depuis un widget.
- `StatelessWidget` par défaut ; `ConsumerWidget` quand il faut lire des providers.

## Textes et i18n

Aucune chaîne affichable en dur dans un widget. Tout passe par les ARB de `lib/l10n/`, en
français d'abord. La structure est en place dès le lot 1 même si une seule langue existe :
rétro-ajouter l'i18n sur cinquante écrans coûte dix fois plus cher que de la tenir dès le
départ.

Le **contenu des cartes** n'est pas concerné : il est en français par nature et vit dans la
base, pas dans les ARB.

## Erreurs

Le domaine ne lance pas d'exception pour des situations de jeu prévues — il renvoie un état ou
un résultat typé. Une exception dans le domaine signale un bug, pas un cas d'usage.

Les couches data et services peuvent échouer pour de vraies raisons (base corrompue, pub
indisponible) : ces erreurs sont typées, remontées via `AsyncValue`, et l'UI prévoit toujours
un état d'erreur exploitable. **Aucune fonctionnalité de jeu ne doit dépendre du succès d'un
appel réseau ou publicitaire** — si la pub échoue, la partie démarre quand même.

## Nommage

- Fichiers en `snake_case`, classes en `UpperCamelCase`, le reste en `lowerCamelCase`.
- Les écrans se terminent par `Screen`, les providers générés par `Provider`, les DAO par `Dao`.
- Le domaine parle le vocabulaire de `docs/RULES.md` : `Round`, `Turn`, `Narrator`, `Deck`,
  `Card`, `Team`. Pas de synonymes inventés — `manche` se dit `round` dans le code, toujours.

## Avant de considérer une tâche terminée

```bash
dart run build_runner build --delete-conflicting-outputs
dart format lib test   # la CI le lance avec --set-exit-if-changed
flutter analyze        # doit être vert, zéro avertissement
flutter test
```

`very_good_analysis` est strict. Ne désactive pas une règle de lint pour faire passer le
build : corrige le code, ou signale le cas si la règle est réellement inadaptée.
