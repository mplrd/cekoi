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

**Le premier build de release exercé a planté au lancement**, le 19 août, exactement de la
façon que le paragraphe précédent annonçait. L'application mourait sur l'appui de l'icône,
avant qu'une ligne de Dart ne tourne :

    java.lang.RuntimeException: Unable to get provider androidx.startup.InitializationProvider
    Caused by: java.lang.RuntimeException: Failed to create an instance of androidx.work.impl.WorkDatabase

R8, en mode complet — le défaut depuis AGP 8 —, avait retiré le constructeur sans argument
de `WorkDatabase_Impl`, que Room instancie par réflexion. La base n'est pas la nôtre : elle
arrive par google_mobile_ads → play-services-ads → work-runtime → room-runtime 2.2.5, dont
les règles embarquées gardent la classe sans nommer ses membres. WorkManager s'initialisant
depuis un `ContentProvider`, la panne est au démarrage du processus. Corrigé par
`android/app/proguard-rules.pro`, avec la règle que Room embarque lui-même depuis la 2.4.

Ce qui reste vrai du diagnostic : **rien n'exerce automatiquement un build de release**. La
CI construit désormais l'APK de release, donc R8 tourne et un échec de build se voit — mais
R8 ne casse pas le build, il casse l'exécution, et ce job n'aurait pas attrapé ce crash-là.
Le seul contrôle qui l'attrape est `python tool/fumee.py` : il construit, installe, lance sur
un vrai téléphone et vérifie que le processus tient debout et dessine. Il demande un appareil
branché, donc il ne peut pas vivre dans la CI en l'état — **c'est une étape de la main, à
faire avant de livrer un artefact à qui que ce soit.** Ne pas la sauter était censé aller de
soi ; ça n'a pas suffi.

Une deuxième classe de règles est tombée à la même revue, par le même mécanisme et depuis
la même dépendance : `androidx.work.InputMerger` perdait aussi son constructeur. Là, rien ne
plante — WorkManager journalise « Could not create Input Merger » et marque la tâche en
échec, si bien que le ping hors-ligne du SDK publicitaire ne partait jamais, en silence. La
leçon vaut mieux que la règle : le motif à chercher est **une règle `-keep` qui ne nomme
aucun membre**, et `build/app/outputs/mapping/release/usage.txt` les liste toutes.

**Le `-Xmx8G` d'`android/gradle.properties` est plus gros que le runner de CI.** Le dépôt
étant privé, `ubuntu-latest` donne 2 cœurs et 7 Go : mettre R8 dans la CI avec un tas
versionné plus large que la machine expose à un « Gradle build daemon disappeared » qui n'a
rien à voir avec la PR en cours. Le job pose donc `GRADLE_OPTS` de son côté. La règle reste
celle qui avait été écrite après l'incident mémoire de la machine de développement :
**l'ajustement de `jvmargs` est machine-locale**, il se pose dans `~/.gradle/gradle.properties`
ou dans l'environnement du job, jamais dans le fichier versionné.

Reste ouvert : faire tourner ce test sur un émulateur en CI, sur `main` seulement, comme le
job iOS. C'est un arbitrage de minutes — un runner avec émulateur est lent, et le dépôt est
privé.

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

- **Les deux icônes débordent du cercle que masque Android.** `tool/make_icons.py` applique sa
  marge de deux tiers au **côté** du canevas ; le système masque sur un **cercle** de deux
  tiers de diamètre. Un carré de côté `2/3·c` déborde de 41 % au coin du cercle de rayon `c/3`
  qu'il est censé tenir, et le dessin de Cékoi remplit justement ses coins — la bulle, la carte
  « 1 », les jambes du coureur. Mesuré le 24 août : `splash_icon.png` porte son dessin jusqu'à
  0,4035 du côté en rayon pour 0,3333 garantis, soit **+21 %**, et 7,6 % de ses pixels opaques
  tombent hors du cercle ; `ic_launcher_foreground.png`, retrait de 16 % de l'icône adaptative
  compris, monte à 0,6042 pour 0,4902, soit **+23 %** et 8,8 % dehors.

  Le cercle est ce qu'Android *garantit* ; la forme réellement découpée est décidée par
  l'appareil. Pour l'icône du lanceur, le masque est certain — c'est le mécanisme même de
  l'icône adaptative — et seule sa forme varie : le carré arrondi observé sur le Xiaomi du
  projet laisse tout passer, un masque circulaire décapite la bulle et tranche la carte. Pour
  l'écran de démarrage, rien ne garantit même qu'un appareil donné masque un PNG simple. La
  conclusion ne dépend d'aucun détail de MIUI : **tout ce qui sort du cercle tient par chance,
  pas par conformité**, et ça vaut pour l'icône de l'application autant que pour l'écran de
  démarrage — le correctif du 17 août (`2f8a53f`) n'atteignait donc pas son objectif affiché.

  Le correctif mécanique est de faire porter la règle sur le cercle, soit ×0,826 pour le splash
  et ×0,811 pour le lanceur. L'icône perd 18 % de côté : c'est un **arbitrage visuel**, ouvert
  dans `REPRISE.md`. Tant qu'il n'est pas rendu, aucune assertion de géométrie n'est ajoutée à
  `tool/test_ressources_android.py` — elle rougirait.

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
