# Point de reprise

**État au 24 août 2026** — sur `develop`, CI verte, aucune PR ouverte.

Pas de SHA ici : un document versionné ne peut pas citer le commit qui le contient sans être
faux dès son merge. Pour l'état exact, `git log -1 develop`.

Ce fichier est le récapitulatif du reste à faire, et il est **la source**. L'artefact publié
sur claude.ai n'en est qu'un rendu :
<https://claude.ai/code/artifact/fbde1c17-c062-4b8f-991e-377be55bf091>

Il vivait jusqu'ici uniquement dans cet artefact, hors du dépôt. Il s'y est périmé sans que
rien ne le signale — il annonçait encore « aucun build de release ne tourne nulle part » alors
que la CI en construisait un depuis plusieurs jours. Un état du projet qui n'est pas versionné
n'est relu par personne, ne passe dans aucune revue de PR, et diverge de `ROADMAP.md` en
silence.

**Toute session qui change l'état du projet met ce fichier à jour d'abord, et republie
l'artefact ensuite.** Le rendu ne se modifie jamais à la main.

Ce document est un digest : il dit **où on en est et ce qui vient**. Le mécanisme technique
reste dans `ROADMAP.md`, les démarches dans `ADMINISTRATIF.md`, les règles dans `RULES.md`.

## En un coup d'œil

| | |
|---|---|
| Lots | 6 sur 8 faits ; le 5 (contenu) et le 8 (publication) sont en cours |
| Cartes | 529 sur les 1 200 visées, réparties sur 21 catégories |
| Écrans à risque de débordement | 3, non couverts par un test |
| Géométrie des icônes | dans la **zone sûre documentée** des deux côtés, verrouillée par un test |
| iOS | **jamais exécuté**, et compilé seulement vers `main` ou sur étiquette `ios` |
| Build de release | construit par la CI et vérifié à la main ; **aucune partie complète jouée dessus** |
| Achat in-app | jamais effectué en vrai |
| Clé de signature | `android/key.properties` absent — les APK sortent signés de la clé de debug |

## Ce qui ne dépend de personne

### 1. Trois écrans peuvent mettre une action hors d'atteinte

Inchangé depuis le 19 août ; le détail et le tableau des seuils sont dans `ROADMAP.md`. En
résumé : `turn_summary_view`, `setup_scaffold` et `score_table` sont bâtis sur la même
structure — en-tête fixe, action épinglée, `Expanded` au milieu qui absorbe le débordement
jusqu'à tomber à zéro. Aucun test ne mesure de géométrie dessus, et la recette ne les
trouvera pas : il faut avoir agrandi le texte dans les réglages du système, ce que font
justement ceux qui en ont besoin. `score_table` est le pire, il se dégrade en silence.

### 2. Le contenu des pages légales

Quelles données partent, AdMob comme destinataire, absence de compte utilisateur, durées,
droits : 90 % du texte ne bouge pas et s'écrit maintenant. Le bloc d'identité de l'éditeur
attend la structure, et c'est lui qui rend la page publiable. Une fois les URL hébergées, le
câblage des deux entrées de réglages est d'une demi-heure.

## Ce qui reste non exercé

Ce ne sont pas des travaux, ce sont des trous de couverture. Ils se referment par de la
recette, pas par du code.

- **Aucune partie complète n'a jamais été jouée sur un build de release.** Le crash du 19 août
  est corrigé et `python tool/fumee.py` vérifie désormais qu'un APK de release démarre,
  dessine et ne lève pas d'exception Dart — mais il s'arrête au démarrage. Or R8 casse ce qui
  passe par la réflexion, et l'achat in-app en fait partie.
- **iOS n'a jamais tourné ailleurs qu'en compilation, et il n'est même pas compilé à chaque
  commit.** Le job `ios-build` de `ci.yml` ne se déclenche que sur `main`, sur une PR qui vise
  `main`, ou si la PR porte l'étiquette `ios`. Une régression de pods, de permissions ou de
  signature s'accumule donc jusqu'à la remontée vers `main` — exactement ce que le lot 1
  voulait éviter en branchant la CI iOS tôt.
- **Aucun achat in-app réel, aucune vraie publicité.** Le lot 7 tourne de bout en bout sur les
  identifiants de test de Google et un magasin injecté.

## Ce qui t'attend, toi

Dans l'ordre du délai, pas de l'effort. Le détail des démarches est dans `ADMINISTRATIF.md`.

| Démarche | Dépend de | Délai propre |
|---|---|---|
| Générer la clé de signature | rien | 3 minutes |
| Ouvrir le compte Google Play | rien — le compte se transfère à une société plus tard | **2 à 3 semaines de chrono**, une fois un build déposé |
| Ouvrir le compte Apple | rien — même raison | débloque iOS, rien d'autre ne le fait |
| Créer le compte AdMob | **l'arbitrage sur le type de profil** | le choix se fige à la création |
| Relancer ta compagne | rien | le vrai goulot : 671 cartes manquantes |

Deux points qui coûtent cher si on les découvre trop tard :

- **La clé de signature compte dès maintenant.** Tant qu'elle n'existe pas, les APK que je te
  passe sortent signés de la clé de debug, et un téléphone qui en a reçu un **refusera** la
  mise à jour signée de la vraie clé. Désinstallation obligatoire — à savoir avant de
  distribuer aux douze testeurs.
- **Seul AdMob est irréversible.** Le type de profil de paiement s'y fige à la création ; les
  comptes de store, eux, se transfèrent à une société. Ne pas faire attendre Play et Apple sur
  cet arbitrage : voir `ADMINISTRATIF.md`, section « Le choix qui ne se rattrape pas ».

## Ce qu'il faut trancher

### Étendre R7.10 au déblocage ?

En mode Sans filtre, l'écran des catégories est inatteignable par construction, et une
catégorie adulte marquée premium y serait donc **invisible et impossible à ouvrir**. Le trou
reste théorique tant qu'aucune catégorie adulte n'est premium : la décision se prend avec
l'arbitrage premium. L'énoncé complet est dans `ADMINISTRATIF.md`, section « Arbitrages
produit en attente ».

### « Une courte publicité précède la partie » — on la garde affirmative ?

Tu as tranché sa *condition* : elle ne dépend que de ce que le joueur possède, jamais du
consentement ni du plafond de fréquence, et les tests la verrouillent. Reste sa *formulation*,
sur laquelle tu ne t'es pas prononcé.

L'argument écrit le 19 août — « elle promet une pub qui, en pratique, ne sort presque
jamais » — **est faux**, et il t'aurait fait trancher dans le mauvais sens. `MONETISATION.md`
pose un plafond de trois par heure et cinq minutes d'écart, `ad_frequency.dart` l'implémente
tel quel, et une partie dure bien plus de cinq minutes : l'interstitiel sortira la plupart du
temps. Ce qui reste, plus étroit : la mention s'affiche aussi dans les cas où la pub ne sortira
pas — consentement refusé, plafond atteint. Annoncer une pub qui n'arrive pas est sans risque ;
l'inverse ne l'est pas.

### Découper l'achat unique en trois références ?

Aujourd'hui une seule référence, libellée « Plus aucune publicité, et toutes les catégories
débloquées. » Piste évoquée le 23 août : la découper en « sans pub », « toutes les catégories »
et « tout inclus ». À trancher **avant la première publication** — une référence publiée ne se
retire pas proprement d'un magasin.

## Journal

Les PR de la série, du 19 au 24 août.

| PR | Ce qui a changé |
|---|---|
| #40 | La dette de géométrie entre dans `ROADMAP.md` : elle ne vivait jusqu'ici que dans une note hors du dépôt. |
| #41 | L'application ne meurt plus au lancement en release. R8 en mode complet retirait le constructeur de `WorkDatabase_Impl`, que Room instancie par réflexion. Amène `tool/fumee.py`, son jeu de tests, et un build de release dans la CI. |
| #42 | La réponse au formulaire de consentement n'est plus perdue. Une échéance de 10 s bornait l'affichage du formulaire : au-delà, le choix du joueur partait à la poubelle sans un mot. |
| #43 | Le splash ne pointe plus l'icône du lanceur en thème sombre. **Vérifié sur les ressources de l'APK, pas à l'écran** — l'appareil s'est débranché avant l'installation. Amène `tool/test_ressources_android.py`. |
| #44 | `docs/REPRISE.md` entre dans le dépôt et devient la source de l'état du projet ; l'artefact n'en est plus qu'un rendu. Corrige au passage quatre faits faux, dont « iOS est compilé à chaque commit ». |
| #45 | Le point de reprise cesse d'épingler le SHA du commit qui le contient — il était faux dès son merge. |
| #46 | Les icônes tiennent dans la zone sûre que le système garantit. `make_icons.py` mesure le rayon du dessin au lieu de sa boîte, recadre sur la boîte opaque avant de mesurer, et remesure son résultat avant de l'écrire. Amène `tool/test_geometrie_icones.py`, qui rejoue le calcul depuis `logo_mark.png` et borne les cinq densités des deux côtés. |

**Deux de ces défauts ont exactement la même forme :** une correction appliquée à un endroit
sur deux. Les deux fonctions jamais appelées du test de fumée, et les deux variantes de
`styles.xml`. Le second cas est désormais couvert par un test ; le premier ne l'est que par la
vigilance. (Le défaut de la #42 est d'une autre nature : un délai de garde posé sur deux étapes
qui n'auraient dû en porter aucune.)

**La machine de développement a été saturée deux fois**, une fois jusqu'à emporter les
instances VS Code ouvertes. Depuis : une commande lourde à la fois, jamais la suite de tests
complète en local, et je préviens avant un build Gradle.
