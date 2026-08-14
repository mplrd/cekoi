# Roadmap

Découpage en lots pensés pour être livrables et testables indépendamment. Chaque lot laisse
l'app dans un état jouable ou démontrable.

## Où on en est

| Lot | État |
|---|---|
| Prérequis — outillage | Fait ; comptes développeur à confirmer |
| 1 — Fondations | Fait |
| 2 — Moteur de jeu | Fait |
| 3 — Parcours de configuration | Fait |
| 4 — Jouer | Fait, **non vérifié sur iOS** |
| 5 — Contenu | Outillage d'import fait ; 529 cartes livrées sur les 1 200 visées |
| 6 — Catégories custom | Fait, **non vérifié sur iOS** |
| 7 — Monétisation | Fait, **aucun achat réel jamais effectué** |
| 8 — Publication | Non commencé |

**Une partie complète se joue de bout en bout**, se sauvegarde et se reprend.

La **signature de release est câblée** : dès que `android/key.properties` est complet, les
artefacts sortent signés de la vraie clé (`ADMINISTRATIF.md`). Sans lui, on retombe sur la clé
de debug pour que `flutter run --release` reste possible, en le signalant ; incomplet, le build
s'arrête plutôt que de retomber en silence.

**Le build de release ne passe pas sur la machine de développement**, et pas davantage sur
`develop` sans ce câblage — ce n'est donc pas lui qui l'a cassé. `flutter build apk --release`
meurt en R8 sur une allocation de 12 Mo, avec 2 Go de RAM libre et 39 Mo de fichier d'échange
disponible sur 63 Go : c'est un état machine, pas une propriété du dépôt, et rien ne dit qu'il
échouerait sur une machine reposée. Si le cas se répète, l'ajustement de `jvmargs` est
machine-locale et se pose dans `~/.gradle/gradle.properties`, pas dans le fichier versionné.

Ce que cet épisode montre en revanche, et qui tient du dépôt : **aucun build de release n'est
couvert**. La CI ne construit qu'en debug (`ci.yml`), donc R8 ne tourne nulle part
automatiquement, et personne ne s'en apercevrait. À couvrir avant la publication.

Ce qui reste ouvert et ne dépend pas d'un lot :

- **iOS n'a jamais tourné ailleurs qu'en compilation.** La CI le construit à chaque commit,
  rien de plus. Le lot 4 écrit le cycle de vie du chrono, et c'est exactement ce qui se juge
  sur un vrai iPhone — voir la vigilance ci-dessous.
- **Le son des dix dernières secondes** est celui du système, pas un son dessiné.
- **Le contenu est le vrai goulot.** 529 cartes sur 21 catégories, pour une cible de 1 200 :
  de quoi juger l'ergonomie et commencer à juger le rythme, qui est le cœur du jeu.
- **Aucun achat in-app réel n'a jamais eu lieu**, et aucune vraie publicité n'a jamais été
  affichée. Le lot 7 tourne de bout en bout sur les identifiants de test de Google et sur un
  magasin injecté ; le passage en caisse suppose un compte Play et l'application déposée sur
  une piste de test. Voir `docs/ADMINISTRATIF.md`.

## Prérequis — outillage

- ~~SDK Flutter, Android Studio, SDK Android, émulateur~~ — fait.
- ~~`git init`, repo GitHub, `gh` CLI~~ — fait, avec CI GitHub Actions sur Android et iOS.
- **Comptes développeur, compte AdMob, politique de confidentialité, classification :** voir
  `docs/ADMINISTRATIF.md`. Rien de tout cela ne bloque le développement, tout bloque la
  publication, et les délais se comptent en semaines — le test fermé à douze testeurs qu'exige
  Google Play sur un compte personnel est à lui seul le plus long délai du projet.

### Stratégie de développement et de test

La machine de développement est sous Windows. Le développement quotidien et la validation se
font donc sur **émulateur Android et téléphones Android physiques**.

Pour iOS, le point à garder en tête : **disposer d'iPhones ne dispense pas d'une machine
macOS.** Compiler, signer et installer une app iOS — même pour un simple test sur un appareil
personnel — passe obligatoirement par Xcode, qui ne tourne que sur macOS. Le simulateur iOS
également.

L'approche retenue est donc un **runner macOS en intégration continue** : GitHub Actions
propose des runners macOS, Codemagic est une alternative spécialisée Flutter avec un palier
gratuit. Le pipeline produit le build iOS signé et le pousse sur TestFlight ; les iPhones
accessibles servent à la validation fonctionnelle, pas à la compilation.

Conséquence pratique : les régressions spécifiques à iOS se découvrent avec un cycle plus
long qu'en Android. Deux points méritent une vigilance particulière parce qu'ils divergent
réellement entre les plateformes et touchent le cœur du jeu — la **gestion du cycle de vie
pendant le chrono** (R3.7) et le **comportement audio et haptique**. À vérifier sur iOS dès
le lot 4, pas à la veille de la soumission.

## Lot 1 — Fondations

Scaffold Flutter, arborescence de `ARCHITECTURE.md`, dépendances, lints, `build_runner`,
thème et design system de base, base Drift avec ses tables et migrations, seeding depuis les
JSON, CI GitHub Actions qui lance `analyze` et `test`.

Ajouter **dès ce lot** un job macOS qui vérifie que le build iOS compile, même s'il ne produit
encore rien d'utile. Une CI iOS branchée tardivement fait remonter d'un seul coup plusieurs
mois d'accumulation — pods incompatibles, permissions manquantes, signature — au pire moment,
c'est-à-dire juste avant la soumission.

**Livrable :** l'app démarre, la base se remplit au premier lancement, la CI est verte sur les
deux plateformes.

## Lot 2 — Moteur de jeu

Le cœur, en Dart pur, sans interface. Entités, `GameState`, `GameEvent`, `reduce()`, tirage
du paquet avec équilibrage de difficulté, proposition de composition d'équipes, scoring.

**Livrable :** tous les cas limites de `RULES.md` couverts par des tests verts. Une partie
complète se déroule dans un test, sans interface.

C'est le lot à ne pas bâcler : tout le reste s'appuie dessus, et une erreur ici se paie sur
tous les écrans.

## Lot 3 — Parcours de configuration

Les cinq étapes de `SPEC.md` : mode, catégories, réglages, équipes, récapitulatif.

**Livrable :** on configure une partie de bout en bout et on obtient un paquet tiré.

## Lot 4 — Jouer

Écran de jeu, chrono, gestion du cycle de vie, récapitulatif de tour avec correction, écrans
de transition, scores de manche, podium final, persistance et reprise de partie.

**Livrable :** une partie complète est jouable. **C'est la première version testable en
conditions réelles** — à essayer en famille avant d'aller plus loin, les retours de ce test
vaudront plus que n'importe quelle spec.

## Lot 5 — Contenu

Volume cible pour un lancement crédible : au moins 1 200 cartes réparties sur 8 à 10
catégories, dont 2 ou 3 marquées `adult`.

**Le contenu est rédigé hors du repo**, par une personne qui travaille avec Gemini et livre
des tableaux à quatre colonnes — voir `docs/CONTENU.md`, qui contient le guide de rédaction et
le prompt de génération. La chaîne est donc :

1. Rédaction et livraison d'un tableau par catégorie.
2. `tool/import_decks.py` — script d'import, tolérant au format : accepte CSV, TSV et
   point-virgule, absorbe le BOM des exports de feuille de calcul, les en-têtes accentués et
   les espaces insécables, et génère les JSON de `assets/decks/`. Il **échoue bruyamment** sur
   une ligne inexploitable plutôt que de l'ignorer, et liste toutes les fautes d'un coup :
   une carte perdue sans message est invisible jusqu'à ce qu'un joueur la cherche, et
   corriger six cents lignes une faute à la fois est intenable.

   En Python et non en Dart : il tourne sur nos machines, jamais sur le téléphone, et il ne
   fait que du texte vers du JSON — pas de base, pas d'interface. Le seul argument pour Dart
   était le dédoublonnage de R6.4, qui se fait sur un texte normalisé par du code du moteur.
   D'où la répartition : **le script ne normalise rien**, et `test/decks_content_test.dart`
   relit tous les JSON en CI avec la vraie fonction du moteur. Une seule implémentation de la
   règle, et le test attrape en prime les doublons ajoutés à la main.
3. Audit par l'agent `deck-curator` : doublons, calibrage de difficulté, noms propres, ligne
   éditoriale du mode adultes.
4. Arbitrage humain sur ce que l'audit signale, puis intégration.

C'est le lot le plus long en temps humain et le plus sous-estimé. Il est entièrement
parallélisable avec les lots 3 et 4 — la rédaction peut commencer immédiatement, elle ne
dépend d'aucun code.

**Point de séquencement :** écrire le script d'import tôt, dès les premières cartes livrées.
Découvrir au bout de 1 200 cartes que le format de livraison ne se convertit pas proprement
coûte une reprise manuelle très pénible.

## Lot 6 — Catégories custom

CRUD complet des catégories et cartes de l'utilisateur, import et export JSON local.

## Lot 7 — Monétisation

CMP UMP, interstitiel de lancement, pubs récompensées, achat de la version complète,
restauration. Tout derrière les interfaces de `MONETISATION.md`.

## Lot 8 — Publication

Icône, écran de lancement, captures pour les stores, fiches, politique de confidentialité
hébergée, questionnaires de classification, signature, build de release, bêta fermée puis
soumission.

---

## v2 — Multi-device

Chaque joueur sur son téléphone, partie rejointe par code. C'est ce que prépare le réducteur
pur du lot 2 : les clients émettent des `GameEvent`, le serveur les ordonne et rediffuse
l'état.

Backend sur Railway, WebSocket. Les vrais sujets sont la reconnexion, la sortie du créateur de
partie et la résolution des états divergents — pas la logique de jeu, qui est déjà écrite.

## v3 — Communauté

Partage de catégories entre utilisateurs. **Déclenche la guideline Apple 1.2** : signalement
de contenu, modération, blocage d'utilisateurs, et un back-office pour traiter les
signalements sous 24 h. À ne pas sous-estimer — c'est un engagement opérationnel continu, pas
une fonctionnalité qu'on livre et qu'on oublie.

## Idées non arbitrées

À discuter, sans engagement : mode « manche bonus » avec une contrainte tirée au sort, chrono
variable selon la difficulté de la carte, statistiques de parties, thèmes visuels
déblocables, mode deux joueurs sans équipes.
