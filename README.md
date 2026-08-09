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

Spécification écrite, implémentation non commencée. Le SDK Flutter n'est pas encore installé
et le projet n'est pas scaffoldé — voir la section *Prérequis* de `docs/ROADMAP.md`.

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
