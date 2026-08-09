# Architecture technique

## Le pari central

Le moteur de jeu est un **réducteur pur, synchrone et déterministe** :

```dart
GameState reduce(GameState state, GameEvent event);
```

Pas de `Future`, pas d'I/O, pas de `DateTime.now()`, pas de `Random()` non injecté. Le temps
et l'aléatoire entrent par la porte : `GameEvent.ticked(elapsed)` porte le temps écoulé, et
l'état ne conserve que la **graine** — pas une instance de `Random`, qui ne serait pas
sérialisable. Chaque mélange en dérive : le remélange de la manche *n* utilise
`Random(seed + n)`.

Trois bénéfices concrets, et c'est ce qui justifie la contrainte :

- Les règles de `RULES.md` se testent en millisecondes, sans `WidgetTester` ni base de données.
- Une partie est rejouable à l'identique depuis sa liste d'événements — ce qui rend les bugs
  reproductibles à partir d'un simple log.
- **Le multi-device de la v2 devient peu coûteux** : le même réducteur tourne côté serveur et
  côté clients, on ne fait circuler que des `GameEvent`. Sans cette discipline, il faudrait
  réécrire toute la logique au moment d'ajouter le réseau.

La règle qui en découle : **`lib/domain/` n'importe jamais `package:flutter`.** Un test
d'architecture vérifie cette contrainte automatiquement.

## Structure

```
lib/
  main.dart
  app/
    app.dart                  # MaterialApp.router
    router.dart               # go_router
    theme/                    # design system, couleurs, typo
  domain/                     # ── DART PUR, zéro import flutter ──
    entities/                 # Card, Deck, Player, Team, GameConfig, énumérations
    engine/
      game_state.dart         # état immuable (freezed), sérialisable pour R9.1
      game_event.dart         # union scellée d'événements (freezed)
      game_engine.dart        # startGame() et reduce() — le cœur
      game_phase.dart         # les phases dont dépend l'écran affiché
      turn.dart               # PlayedTurn, CardResult, TurnOutcome
      draw.dart               # tirage du paquet, équilibrage difficulté
      team_builder.dart       # proposition de composition (R8.3)
    rules/
      round.dart              # les trois manches et leur ordre (R2.1, R2.2)
      scoring.dart            # cumul, détail par manche, équipes en tête (R5)
      game_profiles.dart      # profils de partie (R7.5) — données, pas de branchements
    text/
      text_normalization.dart # forme comparable d'un texte de carte (R6.4)
  data/
    db/
      database.dart           # Drift
      tables/
      daos/
      seed/                   # lecture des JSON, upsert des lignes officielles
    repositories/             # DeckRepository, GameRepository, SettingsRepository
  features/                   # feature-first : un dossier = un parcours
    home/
    setup/                    # mode → catégories → réglages → équipes → récap
    play/                     # écran de jeu, chrono, récap de tour
    results/                  # scores de manche, podium final
    decks/                    # CRUD des catégories et cartes custom
    settings/
  services/
    ads/                      # google_mobile_ads + UMP, isolé derrière une interface
    purchases/                # in_app_purchase, idem
    audio/
  l10n/
assets/
  decks/*.json
test/
  domain/                     # l'essentiel des tests, purs et rapides
  data/
  features/                   # widget tests des parcours critiques
```

Chaque dossier de `features/` contient sa propre arborescence `presentation/` (écrans,
widgets, providers). Aucune feature n'importe une autre feature : ce qui est partagé remonte
dans `domain/`, `data/` ou `app/theme/`.

## Stack

| Besoin | Choix | Pourquoi |
|---|---|---|
| État | `flutter_riverpod` + `riverpod_generator` | Providers typés, testables, invalidation fine. Le domaine n'en dépend pas. |
| Modèles immuables | `freezed` + `json_serializable` | Unions scellées pour `GameEvent`, `copyWith` gratuit, égalité de valeur. |
| Base locale | `drift` + `sqlite3` 3.x | Requêtes typées à la compilation, migrations versionnées, tirage aléatoire en SQL. **`sqlite3_flutter_libs` n'est plus utilisé** : il est en fin de vie depuis que `sqlite3` 3.x embarque lui-même les binaires natifs via les build hooks de Dart. |
| Navigation | `go_router` | Routes déclaratives, deep links pour la v2. |
| Lints | `very_good_analysis` | Strict par défaut, évite les débats de style. |
| Pub | `google_mobile_ads` | Inclut le CMP Google UMP dont on a besoin en Europe. |
| Achat in-app | `in_app_purchase` | Officiel Flutter, couvre les deux stores. |
| Écran allumé | `wakelock_plus` | Indispensable : une partie dure 40 min avec peu d'interactions. |
| Sons | `just_audio` | Fin de chrono, dernières secondes. |

## Modèle de données

Les tables sont volontairement uniformes entre contenu officiel et custom — c'est la
conséquence directe de la règle d'or n°2. La colonne `origin` est la seule distinction.

### `decks` — une catégorie de cartes

| Colonne | Type | Note |
|---|---|---|
| `id` | TEXT PK | Slug stable pour l'officiel (`celebrites-fr`), UUID pour le custom. |
| `name`, `description`, `icon` | TEXT | |
| `audience` | TEXT | `family` \| `adult` |
| `min_age` | INT | 6, 10, 13 ou 18. Filtre les profils de partie (R7.4). |
| `origin` | TEXT | `official` \| `custom` |
| `content_version` | INT | Incrémenté à chaque modification du JSON. Pilote le re-seed. |
| `is_premium` | BOOL | Déblocable par pub récompensée. Toujours faux pour le custom. |
| `sort_order` | INT | |

### `cards`

| Colonne | Type | Note |
|---|---|---|
| `id` | TEXT PK | Officiel : `<deck_id>:<slug du texte>`, stable entre versions. |
| `deck_id` | TEXT FK | |
| `text` | TEXT | Le texte affiché. |
| `audience` | TEXT | Hérite du deck, surchargeable carte par carte. |
| `difficulty` | INT | 1 à 3. Utilisé par l'équilibrage du tirage (R6.3). |
| `taboo` | TEXT | JSON array des mots interdits en manche 1. |
| `origin` | TEXT | |

L'ID stable des cartes officielles est important : il permet de corriger une faute de frappe
dans un JSON sans casser l'historique des parties déjà jouées.

### Partie en cours

`games` (config JSON, statut, manche et équipe courantes), `teams`, `players`,
`game_cards` (le paquet figé au tirage — une partie ne doit pas changer si un deck est
modifié en cours de route), `turns`, `turn_results`.

## Seeding

Au démarrage, pour chaque JSON de `assets/decks/` :

1. Si le deck n'existe pas en base → insertion complète.
2. S'il existe avec un `content_version` inférieur → upsert des cartes officielles par ID,
   suppression de celles qui ont disparu du JSON.
3. **Les lignes `origin = 'custom'` ne sont jamais touchées**, quoi qu'il arrive.

Le seeding tourne dans un isolate au premier lancement pour ne pas bloquer l'UI, derrière un
écran de chargement. Les lancements suivants ne font qu'une comparaison de versions.

## Chrono

Piège classique : `Timer.periodic` dérive et n'est pas fiable en arrière-plan.

L'implémentation s'appuie sur un `Stopwatch` comme source de vérité et un `Ticker` pour le
rafraîchissement d'affichage. Le temps restant est toujours *calculé*, jamais *décrémenté*.
Un `AppLifecycleListener` met le `Stopwatch` en pause sur `paused` et déclenche le compte à
rebours de reprise sur `resumed` (R3.7).

## Tests

- `test/domain/` — l'essentiel de l'effort. Tests purs, un fichier par famille de règles, avec
  les numéros de `RULES.md` en référence dans les noms de test. Objectif : les 10 cas limites
  du bas de `RULES.md` sont tous couverts.
- `test/data/` — seeding, migrations, requêtes de tirage sur base en mémoire.
- `test/features/` — widget tests sur les parcours critiques uniquement : configuration d'une
  partie de bout en bout, et un tour de jeu complet.
- Un test d'architecture vérifie qu'aucun fichier de `lib/domain/` n'importe `package:flutter`.
