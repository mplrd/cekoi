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
| 8 — Publication | Entamé : icône, écran de lancement et câblage de la signature faits ; tout le reste attend les comptes |

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
couvert**. La CI ne construit qu'en debug — `flutter build apk --debug` et
`flutter build ios --no-codesign --debug` dans `ci.yml` —, donc R8 ne tourne nulle part
automatiquement, et personne ne s'en apercevrait. Deux SDK natifs sont en jeu, et R8 casse
typiquement ce qui passe par la réflexion : la première release construite sera aussi la
première à être exercée. À couvrir avant la publication, pas pendant.

Ce qui reste ouvert et ne dépend pas d'un lot :

- **Trois écrans peuvent déborder, et rien ne le voit.** Un écran qui déborde met une partie de
  lui-même hors d'atteinte ; quand c'est une action, elle devient intouchable. Trois correctifs
  sont partis en une semaine sur des cas trouvés par hasard, dont le départage, qui débordait
  **à taille de texte normale** sur un 360 × 800 : plus aucun bouton pour trancher R5.3, donc
  une partie à égalité qui ne pouvait plus se terminer, alors que R8.1 promet dix équipes.
  Restent trois écrans bâtis sur la même structure — en-tête fixe, action épinglée, `Expanded`
  au milieu qui absorbe jusqu'à tomber à zéro :

  | Fichier | Ce qui devient inatteignable | Seuil estimé |
  |---|---|---|
  | `lib/features/play/presentation/widgets/turn_summary_view.dart` | la correction du récapitulatif de tour (R3.6) | ×2 d'agrandissement du texte |
  | `lib/features/setup/presentation/widgets/setup_scaffold.dart` | le pied des quatre étapes de configuration | ×2,5 |
  | `lib/features/play/presentation/widgets/score_table.dart` | débordement **horizontal** : un score à deux chiffres est rogné sans exception levée | ×1,8 |

  Aucun test ne mesure de géométrie sur ces trois-là, et la recette ne les trouvera pas : il
  faut avoir agrandi le texte dans les réglages du système, ce que font justement ceux qui en
  ont besoin. Le troisième est le pire, parce qu'il se dégrade en silence.

- **iOS n'a jamais tourné ailleurs qu'en compilation.** La CI le construit à chaque commit,
  rien de plus. Le lot 4 écrit le cycle de vie du chrono, et c'est exactement ce qui se juge
  sur un vrai iPhone — voir la vigilance ci-dessous.
- **Les deux sons du jeu sont synthétisés**, pas dessinés : `tool/make_sounds.py` fabrique un
  blip et deux coups graves à partir de quelques lignes de trigonométrie. Ils remplacent les
  sons système, qui ne sortaient sur aucun téléphone dont les *sons des touches* sont coupés
  — voir `ARCHITECTURE.md`. Ils tiennent leur rôle ; un vrai travail sonore reste à faire.
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

Les quatre étapes de `SPEC.md` : mode, catégories, réglages, équipes — la partie part du pied
de la dernière. Un récapitulatif fermait la marche ; il a été retiré après essai en partie
réelle, il n'apprenait rien à qui venait de tout choisir.

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
