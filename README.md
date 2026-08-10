# Cékoi

Jeu de société mobile pour Android et iOS, inspiré de Time's Up : on fait deviner le même
paquet de cartes sur trois manches de plus en plus contraintes — description libre, puis un
seul mot, puis mime.

Le jeu se joue **autour d'une table**, avec un seul téléphone qu'on se passe. Aucune connexion
n'est nécessaire pour jouer.

## Ce qui le distingue

- Deux modes de contenu : **en famille** et **entre adultes**
- Des **profils de partie** qui présélectionnent les cartes selon l'âge des joueurs, pour
  lancer une partie sans rien cocher
- Choix libre des catégories, et création de ses propres cartes et catégories
- Aucune limite au nombre d'équipes, avec proposition automatique de composition
- Durée du tour et nombre de cartes configurables

## État du projet

**Une partie complète se joue de bout en bout** : on la configure en cinq étapes, on joue les
trois manches au chrono, on corrige les résultats de chaque tour, et on va jusqu'au podium.
La partie se sauvegarde après chaque coup et se reprend au redémarrage. Le joueur peut écrire
ses propres catégories, les exporter et les importer.

Lots 1 à 4 et 6 livrés. Restent la monétisation (lot 7) et la publication (lot 8).

Deux limites à connaître avant de juger :

- **Le contenu est le goulot d'étranglement** : une seule catégorie de 16 cartes est livrée
  aujourd'hui. De quoi juger la prise en main, pas le rythme.
- **iOS n'a jamais tourné ailleurs qu'en compilation.** La CI le construit à chaque commit,
  mais aucune partie n'y a été jouée.

Un APK de test s'obtient avec `flutter build apk --release --split-per-abi`. Il est signé avec
la clé de debug : installable à la main, pas publiable — la vraie signature relève du lot 8.

Voir `docs/ROADMAP.md` pour le découpage en lots et l'état détaillé.

## Documentation

| Document | Contenu |
|---|---|
| [`docs/RULES.md`](docs/RULES.md) | Règles canoniques du jeu et cas limites. Source de vérité du gameplay. |
| [`docs/SPEC.md`](docs/SPEC.md) | Parcours utilisateur et écrans. |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Structure du code, modèle de données, stack. |
| [`docs/MONETISATION.md`](docs/MONETISATION.md) | Publicité, achat in-app, RGPD, classification d'âge. |
| [`docs/CONTENU.md`](docs/CONTENU.md) | Guide de rédaction des cartes et prompt de génération. |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Découpage en lots, v2 et v3. |

`CLAUDE.md` et `.claude/` configurent l'assistance IA du projet : conventions, agents
spécialisés et skills.

## Stack

Flutter · Riverpod · Freezed · Drift (SQLite) · go_router

L'import des livraisons de contenu est un script Python, `tool/import_decks.py`, qui tourne
hors de l'application. Il ne normalise volontairement rien : la règle de dédoublonnage de R6.4
vit dans le moteur, en Dart, et `test/decks_content_test.dart` la fait respecter en CI sur
tous les JSON livrés.
