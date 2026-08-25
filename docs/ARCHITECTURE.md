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
  app/                        # composition, et l'état partagé entre features
    app.dart                  # MaterialApp.router
    router.dart               # go_router
    current_game.dart         # la partie en cours, point de rendez-vous setup ↔ play
    clock.dart                # source monotone du chrono, graine d'aléatoire
    screen_awake.dart         # maintien d'écran, derrière un provider
    game_persistence.dart     # sauvegarde et reprise (R9.1, R9.2)
    theme/                    # design system, couleurs, typo
  domain/                     # ── DART PUR, zéro import flutter ──
    entities/                 # Card, Deck, Team, GameConfig, énumérations
    engine/
      game_state.dart         # état immuable (freezed), sérialisable pour R9.1
      game_event.dart         # union scellée d'événements (freezed)
      game_engine.dart        # startGame() et reduce() — le cœur
      game_phase.dart         # les phases dont dépend l'écran affiché
      turn.dart               # PlayedTurn, CardResult, TurnOutcome
      turn_clock.dart         # temps de jeu net des pauses (R3.7, R3.8)
      draw.dart               # tirage du paquet, équilibrage, PoolVerdict (R6.2)
      team_builder.dart       # équipes à partir de leurs noms (R8.3)
    rules/
      round.dart              # les trois manches et leur ordre (R2.1, R2.2)
      scoring.dart            # cumul, détail par manche, équipes en tête (R5)
      game_profiles.dart      # profils de partie (R7.5) — données, pas de branchements
      resume.dart             # fenêtre de reprise de 24 h (R9.2)
    setup/
      game_setup.dart         # la configuration en cours de construction (R6, R7, R8)
      game_launch.dart        # tirage + ouverture de partie, et rejeu à l'identique
    decks/
      card_length.dart        # borne de longueur d'une carte, partagée avec l'import
      deck_exchange.dart      # format d'échange des catégories du joueur (lot 6)
    text/
      text_normalization.dart # forme comparable d'un texte de carte (R6.4)
  data/
    db/
      database.dart           # Drift, migrations versionnées
      tables/
      seed/                   # lecture des JSON, upsert des lignes officielles
    repositories/             # DeckRepository, GameRepository
  features/                   # feature-first : un dossier = un parcours
    home/
    setup/                    # mode → catégories → réglages → équipes (la partie part d'ici)
    play/                     # jeu, chrono, récap de tour, scores, départage, podium
    decks/                    # CRUD des catégories et cartes du joueur
  l10n/
assets/
  decks/*.json
tool/
  import_decks.py             # conversion des livraisons de contenu, hors application
test/
  domain/                     # l'essentiel des tests, purs et rapides
  data/
  features/                   # widget tests des parcours critiques
  decks_content_test.dart     # contrôle des JSON livrés, dont R6.4 inter-catégories
```

Chaque dossier de `features/` contient sa propre arborescence `presentation/` (écrans,
widgets, providers). **Aucune feature n'importe une autre feature** : ce qui est partagé
remonte dans `domain/`, `data/` ou `app/`. `test/architecture_test.dart` le vérifie, sous les
deux formes d'écriture — `package:` et relative.

Deux écarts assumés par rapport au découpage initial :

- **Pas de dossier `results/`** : les scores de manche, le départage et le podium sont des
  phases du moteur au même titre que le tour, et l'écran de jeu les affiche à partir de la
  même `GamePhase`. Les séparer aurait dupliqué la machine à états.
- **`services/` et `features/settings/` sont arrivés avec le lot 7.** `services/ads/` tient le
  consentement et le SDK publicitaire, derrière des interfaces qu'aucune feature ne contourne —
  `test/architecture_test.dart` interdit tout import d'un SDK de monétisation hors de
  `lib/services/`. L'écran de réglages n'expose pour l'instant que le consentement : c'est le
  seul réglage qui doit légalement rester joignable, les autres de `SPEC.md` s'y ajouteront.
  `services/purchases/` n'existe pas encore.

## Stack

| Besoin | Choix | Pourquoi |
|---|---|---|
| État | `flutter_riverpod` + `riverpod_generator` | Providers typés, testables, invalidation fine. Le domaine n'en dépend pas. |
| Modèles immuables | `freezed` + `json_serializable` | Unions scellées pour `GameEvent`, `copyWith` gratuit, égalité de valeur. |
| Base locale | `drift` + `sqlite3` 3.x | Requêtes typées à la compilation, migrations versionnées, tirage aléatoire en SQL. **`sqlite3_flutter_libs` n'est plus utilisé** : il est en fin de vie depuis que `sqlite3` 3.x embarque lui-même les binaires natifs via les build hooks de Dart. |
| Navigation | `go_router` | Routes déclaratives, deep links pour la v2. |
| Lints | `very_good_analysis` | Strict par défaut, évite les débats de style. |
| Écran allumé | `wakelock_plus` | Indispensable : une partie dure 40 min avec peu d'interactions. Le narrateur mime sans toucher l'écran. |
| Fichiers | `flutter_file_dialog` | Import et export des catégories du joueur. **Pas `file_picker`** : ses versions modernes exigent `win32 ^5` quand `wakelock_plus` exige `win32 ^6`, et sa version compatible appelle `jcenter()`, supprimé de Gradle 9. `flutter_file_dialog` ne cible que le mobile, donc pas de `win32` du tout. |
| Chemins | `path_provider` | Base locale et fichier temporaire d'export. |
| Son du jeu | `audioplayers` | Le tic des dix dernières secondes et le buzzer de fin de tour, joués depuis un asset sur le canal média. **Pas `SystemSound.play`** : voir ci-dessous, c'était le choix précédent et il ne produisait aucun son sur un téléphone. Mode basse latence, et `mixWithOthers` pour ne pas couper la musique de la table. |
| Vibration | `vibration` | Même raison : `HapticFeedback` demande un retour tactile au système, que le réglage « vibration au toucher » coupe. Le service `Vibrator` répond toujours, et accepte un motif — deux impulsions pour le buzzer. Entraîne `device_info_plus`, dont `hasVibrator()` se sert pour reconnaître un émulateur. |

| Pub et consentement | `google_mobile_ads` | Inclut le CMP Google UMP dont on a besoin en Europe. Exige `minSdk 24` et `compileSdk 36`, qui sont les défauts de Flutter. |

Prévu, pas encore installé :

| Besoin | Choix | Pourquoi |
|---|---|---|
| Achat in-app | `in_app_purchase` | Officiel Flutter, couvre les deux stores. |

### Le son est passé par un asset, et pourquoi

Le **son du jeu** a d'abord été celui du système, `SystemSound.play`, sans paquet — au motif
qu'il suivrait le volume et le mode silencieux de l'appareil. **C'était faux**, et personne ne
s'en est aperçu pendant tout un lot : sur Android, `SystemSound.play` et `HapticFeedback`
passent par la couche de retour tactile, que les réglages *sons des touches* et *vibration au
toucher* éteignent — et ils le sont chez beaucoup de monde. Le tic des dix dernières secondes
n'a donc jamais sonné sur ces appareils-là. Quant au buzzer de fin de tour, il avait été écrit
avec `SystemSoundType.alert`, que la documentation de Flutter donne pour **ignoré sur Android
et iOS** : il ne pouvait rien produire du tout.

Aucun test ne pouvait l'attraper : ils vérifiaient que l'appel de canal partait, pas qu'on
entendait quelque chose. Il a fallu une partie réelle.

Les sons sont donc des assets, fabriqués par `tool/make_sounds.py` et versionnés, joués par
`audioplayers` sur le canal média. Le timbre les distingue, pas le volume — au milieu d'une
table qui crie, deux sons de la même famille ne se séparent pas. La vibration passe par le
service `Vibrator`, hors retour tactile.

Un arbitrage y est attaché, et il n'a pas de bonne réponse : `mixWithOthers` — ne pas couper
la musique de la table — et `respectSilence` s'excluent, le paquet l'interdit par une
assertion. On garde le premier, ce qui veut dire qu'**un iPhone en silencieux sonnera quand
même**. Le recours est le réglage *Son* de l'application, qui coupe tout.

## Modèle de données

Les tables sont volontairement uniformes entre contenu officiel et custom — c'est la
conséquence directe de la règle d'or n°2. La colonne `origin` est la seule distinction.

### `decks` — une catégorie de cartes

| Colonne | Type | Note |
|---|---|---|
| `id` | TEXT PK | Slug stable pour l'officiel (`celebrites-fr`), préfixé `custom-` pour le joueur. Le préfixe garantit deux espaces de noms disjoints : le seeder écrit par identifiant, et une catégorie du joueur nommée comme une officielle en ferait l'ombre de l'autre. |
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
| `origin` | TEXT | |

L'ID stable des cartes officielles est important : il permet de corriger une faute de frappe
dans un JSON sans casser l'historique des parties déjà jouées.

### `saved_games` — la partie en cours (R9.1)

Une seule ligne, d'`id` figé à 1 : Cékoi est mono-partie, et une table qui pourrait en
contenir plusieurs obligerait chaque lecture à choisir laquelle — un choix qui n'existe pas.

| Colonne | Type | Note |
|---|---|---|
| `id` | INT PK | Toujours 1. |
| `payload` | TEXT | `GameState` sérialisé, paquet figé compris. |
| `saved_at` | DATETIME | Sert la fenêtre de 24 heures de R9.2. |

**Écart assumé par rapport au découpage initial**, qui prévoyait `games`, `teams`, `players`,
`game_cards`, `turns` et `turn_results` : l'état est stocké en JSON, pas déplié en tables.
`GameState` est déjà sérialisable et le restera pour le multi-device de la v2 ; le déplier
imposerait de faire évoluer le schéma à chaque champ ajouté au moteur, pour une donnée que
personne ne requête jamais autrement qu'en bloc.

L'écriture n'a pas lieu à chaque événement au sens littéral : le chrono en produit dix par
seconde. Seuls les changements qui ne portent pas **que** sur le temps écoulé déclenchent une
sauvegarde. Rien n'est perdu pour autant — passer en arrière-plan met le tour en pause (R3.7),
et cette pause est justement un changement, donc une écriture avec le temps exact.

### Migrations

| Version | Changement |
|---|---|
| 1 | `decks`, `cards`. |
| 2 | Ajout de `saved_games` (R9.1). |
| 3 | Suppression de la colonne des mots interdits de `cards`. |

Chaque migration a son test, et ce test part d'une base **réellement** à l'ancienne version.
La base de test naît au schéma courant : migrer par-dessus ne prouverait rien, et c'est
exactement le piège qui avait rendu décoratif le premier test de migration.

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

L'implémentation s'appuie sur une source **monotone** — un `Stopwatch`, jamais l'horloge
système : changer l'heure de son téléphone en plein tour ne doit pas faire bondir le chrono.
`TurnClock`, du domaine et pur, en dérive le temps de jeu net des pauses, et le réducteur ne
reçoit qu'un `Ticked(elapsed)` déjà nettoyé. Il n'a ainsi jamais à savoir que l'application
est passée en arrière-plan.

Le temps restant est toujours *calculé* depuis le temps consommé, jamais *décrémenté*.

**L'état est la source de vérité du chrono, pas le contrôleur.** Le contrôleur ne survit pas
à la fermeture de l'application : à chaque redémarrage du chrono, il reprend depuis
`turn.elapsed`. Sans ça, une partie reprise offrait à l'équipe active le temps déjà consommé,
et une partie tuée hors pause donnait un tour qui ne se terminait jamais — le réducteur étant
total, rien n'en paraissait anormal.

Le ticker suit l'état et non les seules actions : une partie posée de l'extérieur — reprise
après fermeture, rejeu depuis le podium, lancement depuis la configuration — démarre son
chrono comme les autres.

`inactive` compte comme un arrière-plan. Sur iOS il couvre le centre de contrôle et la
bannière d'appel entrant : se tromper dans ce sens coûte trois secondes de décompte, se
tromper dans l'autre laisse une équipe jouer écran masqué. **À vérifier sur un vrai iPhone.**

## Tests

- `test/domain/` — l'essentiel de l'effort. Tests purs, un fichier par famille de règles, avec
  les numéros de `RULES.md` en référence dans les noms de test. Objectif : les 10 cas limites
  du bas de `RULES.md` sont tous couverts.
- `test/data/` — seeding, migrations, requêtes de tirage sur base en mémoire.
- `test/features/` — widget tests sur les parcours critiques uniquement : configuration d'une
  partie de bout en bout, et un tour de jeu complet.
- Un test d'architecture vérifie qu'aucun fichier de `lib/domain/` n'importe `package:flutter`.
