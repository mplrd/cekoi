---
name: game-engine
description: Travailler sur le moteur de jeu de Cékoi — ajouter ou modifier un GameEvent, étendre le réducteur, préserver le déterminisme, tester contre les règles. À charger avant toute modification de lib/domain/engine/ ou de la logique de manches, tours, chrono, tirage et scoring.
---

# Moteur de jeu

Le moteur est un réducteur pur : `GameState reduce(GameState state, GameEvent event)`.

Toute modification passe d'abord par `docs/RULES.md`. Si le comportement demandé n'y figure
pas, **c'est la spec qu'il faut compléter en premier** — pas le code. Une règle qui n'existe
que dans le code est une règle que personne ne pourra vérifier ni retrouver.

## Les quatre invariants

Ils ne se négocient pas. Chacun a une raison précise.

**1. Pureté.** `reduce` ne fait aucune I/O, n'est pas `async`, n'écrit nulle part. Elle prend
un état, rend un état.

**2. Déterminisme.** Aucun appel à `DateTime.now()` ni à `Random()` non initialisé. Le temps
entre par `GameEvent.tick(elapsed)`, l'aléatoire par un `Random(seed)` dont la graine vit dans
l'état. Deux exécutions de la même liste d'événements produisent exactement le même état —
c'est ce qui permet de reproduire un bug à partir d'un log de partie.

**3. Immuabilité.** L'état est `@freezed`. Jamais de mutation en place, jamais de `List.add`
sur une collection de l'état : construis une nouvelle liste.

**4. Totalité.** Tout événement est traité dans tout état. Un événement qui n'a pas de sens
dans l'état courant — *Trouvé* alors qu'aucun tour n'est en cours — renvoie l'état inchangé
sans lever d'exception. L'UI ne doit jamais pouvoir faire planter le moteur.

## Ajouter un événement

1. Ajoute le cas dans l'union `GameEvent`.
2. Lance `build_runner`.
3. La compilation casse sur le `switch` du réducteur : c'est voulu, c'est le filet. Traite le
   cas.
4. Écris le test **avant** de considérer que c'est fini, en référençant le numéro de règle.
5. Vérifie si l'un des dix cas limites de `RULES.md` est affecté.

## Structure de l'état

`GameState` porte l'intégralité de ce qui décrit une partie : configuration, équipes et leurs
curseurs de narrateur, manche courante, paquet restant, cartes trouvées de la manche, tour en
cours avec son temps écoulé, scores cumulés, graine d'aléatoire.

Ne dérive jamais dans l'état ce qui peut être calculé : le score total se calcule depuis les
résultats de tours, il n'est pas stocké en double. Une donnée dupliquée finit toujours par
diverger.

Le paquet est **ordonné**, pas un ensemble : *Passer* remet la carte au fond (R3.3), et cet
ordre est observable par les joueurs.

## Pièges connus

**Fin de manche pendant un tour.** Quand la dernière carte est trouvée, la manche s'arrête
immédiatement et le temps restant est perdu (R4.1). Il est tentant de laisser le tour finir :
c'est faux.

**Rotation après une manche.** La manche suivante démarre avec l'équipe *suivante*, pas celle
qui a vidé le paquet (R4.3). Chaque équipe garde en plus son propre curseur de narrateur
(R3.1) — c'est ce qui permet des équipes de tailles inégales.

**Correction post-tour.** Corriger un résultat (R3.6) peut vider le paquet, donc terminer la
manche, ou au contraire le re-remplir et faire redémarrer une manche qu'on croyait finie. Le
réducteur doit recalculer entièrement la situation, pas appliquer un delta de score.

**Passer la dernière carte.** Interdit (R3.4). Sans ça, la carte revient immédiatement et le
tour tourne en boucle.

**Le chrono.** Le temps restant se calcule depuis le temps écoulé cumulé, il ne se décrémente
jamais. Une pause n'est qu'une absence de `tick` — le réducteur n'a pas besoin de savoir que
l'application est en arrière-plan.

## Tester

Les tests vivent dans `test/domain/` et **citent les numéros de règles dans leur nom** :

```dart
test('R4.1 — la manche se termine dès la dernière carte trouvée, temps restant perdu', () {
  var state = aGameInProgress(cardsRemaining: 1, elapsed: const Duration(seconds: 25));
  state = GameEngine.reduce(state, const GameEvent.cardGuessed());

  expect(state.currentRound.isComplete, isTrue);
  expect(state.currentTurn, isNull);
});
```

Utilise des constructeurs de test (`aGameInProgress`, `aTeam`) plutôt que de monter un état à
la main dans chaque test — sinon un changement de forme de `GameState` casse cinquante tests
d'un coup.

Le test le plus utile du projet fait dérouler **une partie complète** de la configuration au
podium, en n'émettant que des événements, et vérifie les scores finaux. Il attrape les
régressions d'enchaînement que les tests unitaires isolés laissent passer.

Les dix cas limites en bas de `docs/RULES.md` doivent tous avoir leur test. Quand tu en
ajoutes un nouveau, ajoute-le aussi à cette liste.
