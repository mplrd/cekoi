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

**La marge des icônes a été calculée deux fois sur le mauvais objet.** Le système masque sur
un **cercle** ; la marge, elle, était calculée sur la **boîte** du dessin. Un carré de côté
`2/3·c` déborde de 41 % au coin du cercle de rayon `c/3` qu'il est censé tenir, et le dessin
de Cékoi remplit justement ses coins — la bulle, la carte « 1 », les jambes du coureur. Les
deux consommateurs étaient touchés, par deux chemins différents : `make_icons.py` portait sa
marge sur le côté du canevas pour `splash_icon.png`, et ne mettait **aucune** marge à
`logo_foreground.png`, le retrait de 16 % de `mipmap-anydpi-v26/ic_launcher.xml` étant censé
la fournir. Les deux raisonnements supposaient un dessin tenant dans le cercle inscrit de sa
boîte.

Mesuré avant correction : rayon à 0,4035 du côté pour 0,3333 permis côté splash, et 0,6042
pour 0,4493 côté lanceur. Le correctif du 17 août (`3ebe467`), qui disait sauver la
bulle, la carte et les jambes du coureur, n'atteignait donc pas son objectif.

**Ce n'était pas visible, et ça ne pouvait pas l'être.** La forme réellement découpée est
décidée par le lanceur de l'appareil : un carré arrondi, celui du téléphone de test, n'en
coupe presque rien ; un masque circulaire décapite. Le cercle documenté est la seule limite
qui ne dépende de personne — ce qui en sort ne tient que par chance.

`make_icons.py` mesure désormais le **rayon** du dessin et dimensionne le canevas pour qu'il
tombe sur le cercle du consommateur, puis remesure son propre résultat avant de l'écrire — le
centrage tombe sur un demi-pixel quand les parités diffèrent, ce qui suffit à faire déborder
un carré calculé au plus juste. Le dessin perd 17,4 % de côté au démarrage et 25,7 % sur
l'icône : c'était un arbitrage visuel, rendu par Maxime le 24 août — *réduire, ne pas
redessiner*, puis *viser la zone sûre et non le couperet*.

Les deux cibles ne sont pas symétriques, et le vocabulaire compte. Pour l'écran de
démarrage, le cercle documenté **est** le couperet : deux tiers du diamètre. Pour l'icône
adaptative il y en a deux — le masque circulaire coupe à 36 dp de rayon, mais un masque
plus étroit sur un axe, comme le cylindre, mord en deçà ; la zone que **tout** masque
conforme laisse voir est un cercle de 66 dp, donc 33 dp de rayon. C'est celle qu'on vise,
sinon la bande 66–72 dp resterait à la merci du lanceur — c'est-à-dire le défaut, en plus
fin.

`tool/test_geometrie_icones.py` verrouille les deux cibles, rejoue le calcul depuis
`logo_mark.png` pour vérifier que les fichiers versionnés en descendent bien, et borne les
cinq densités des deux côtés — un dessin qui rétrécit est une régression autant qu'un
dessin qui déborde.

**Les trois écrans qui pouvaient mettre une action hors d'atteinte sont couverts.** Ils
partageaient la même ossature — en-tête fixe, `Expanded` au milieu, action épinglée en bas —
et la même issue : le `Expanded` absorbe jusqu'à zéro, puis c'est la somme des parties fixes
qui déborde, et l'action passe sous le bord. Rien ne le voyait, parce qu'il faut avoir agrandi
le texte dans les réglages du système, ce que font justement ceux qui en ont besoin.

| Fichier | Ce qui cédait | Seuil estimé | Seuil mesuré |
|---|---|---|---|
| `score_table.dart` | un score à deux chiffres rogné, sans exception levée | ×1,8 | **×1,6** sur un 360, ×1,3 sur un 320 |
| `turn_summary_view.dart` | la correction du récapitulatif de tour (R3.6) | ×2 | **×2** sur un 360 × 640 |
| `setup_scaffold.dart` | le pied des quatre étapes de configuration | ×2,5 | **×2,5** avec le pied de l'étape des équipes |

Deux estimations sur trois étaient justes. Celle du tableau des scores était optimiste d'un
cran, et la cause du troisième avait été mal comprise : ce n'est pas la liste qui poussait —
les cinq écrans du parcours passent une `ListView`, elle se contente de ce qu'on lui laisse —
c'est le **titre**. À ×2, « Combien » est un seul mot qui réclame 355 px sur une ligne qui en
fait 312 ; ni le repli ni le défilement n'y peuvent quoi que ce soit.

**Ce que chacun est devenu.** Les colonnes de chiffres du tableau prennent la place qu'il leur
faut, et le détail par manche disparaît quand cette place manquerait au nom d'équipe — sans
quoi la colonne du nom tombe à zéro, où `RenderFlex` ne peint plus **rien**, pas même la
pastille de couleur, pendant que `RenderTable` écrête sa boîte et peint ses cellules
par-dessus, hors de la carte puis hors de l'écran. L'en-tête du récapitulatif rejoint la zone
défilante, ne laissant de fixe que l'action. Et les deux parties fixes de l'ossature de
configuration sont bornées à une part de la hauteur, tandis que le titre n'est réduit que
quand un mot dépasse, et que d'autant qu'il faut — le réglage de l'utilisateur est respecté
partout où il tient.

**Ce que l'outillage n'avait pas, et qui vaut mieux que les trois correctifs.** Un débordement
de `RenderFlex` remonte comme exception ; un texte trop large pour sa boîte ne remonte rien.
`test/support/geometrie.dart` compare donc la boîte de chaque texte au mot insécable le plus
large, vérifie qu'il n'est pas coupé en hauteur, et refuse qu'un texte en `ellipsis` tombe à
zéro — céder est un choix, disparaître n'en est pas un.

Et il refuse de conclure sans les vraies polices : `flutter test` compose en **Ahem**, où
chaque glyphe est un carré de la taille du corps. Mesuré, « 36 » y réclame 79,2 px contre 45,9
en Roboto — un rapport de 1,7, assez pour inventer des débordements qui n'existent pas. C'est
arrivé le 24 août, avant que le lien soit fait avec `tool/apercus/`, qui chargeait les vraies
polices depuis toujours et dont le commentaire disait pourquoi.

**Réserve.** Ces seuils valent pour Roboto, donc pour Android, dont le réglage système plafonne
à ×2. iOS va plus loin — AX4 vaut ×2,35 et AX5 ×3,1 — et n'a jamais été exercé. Les trois
écrans sont désormais testés jusqu'à ×3,1 et sur 320 px de large, mais sur la police d'Android.

Ce qui reste ouvert et ne dépend pas d'un lot :

- **Rien ne borne la longueur d'une carte personnalisée.** Trouvé par le contrôle de géométrie
  le jour où il est entré : un mot unique de 33 caractères est rogné dans le récapitulatif de
  tour **à taille de texte normale** — 188,4 px de boîte pour 253,7 nécessaires. `CONTENU.md`
  cadre le contenu officiel à 30 caractères pour un mot, mais c'est une consigne de rédaction :
  aucun `maxLength` ni `inputFormatters` n'existe sur les champs de `lib/features/decks/`. Le
  contrôle est à poser à la saisie, pas à l'affichage — un texte tronqué à l'écran reste une
  carte qu'on ne peut pas faire deviner.

- **iOS n'a jamais tourné ailleurs qu'en compilation, et n'est même pas compilé à chaque
  commit.** Le job `ios-build` de `ci.yml` ne se déclenche que sur `main`, sur une PR qui vise
  `main`, ou si la PR porte l'étiquette `ios` — c'est un arbitrage de minutes de runner macOS,
  mais il a une conséquence : une régression de pods, de permissions ou de signature
  s'accumule jusqu'à la remontée vers `main`, ce que brancher la CI iOS dès le lot 1 devait
  précisément éviter. Le lot 4 écrit le cycle de vie du chrono, et c'est exactement ce qui se
  juge sur un vrai iPhone — voir la vigilance ci-dessous.
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
