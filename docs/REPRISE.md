# Point de reprise

**État au 27 août 2026** — `develop` au merge de la #51, CI verte dessus.

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
| Écrans à risque de débordement | 0 sur les **six surfaces instrumentées** ; tout le reste plafonne à ×1,3 |
| Lisibilité de la face de carte | corrigée : une situation de 40 caractères passe de 15,5 à **46,6 px** |
| Identification d'un build | commit, numéro et date lisibles dans les réglages, et copiables |
| Longueur des cartes personnalisées | bornée à 60 caractères, comme le contenu officiel |
| Nom d'une catégorie | borné à 30 caractères, mesurés sur la hauteur de ligne à ×2 |
| Géométrie des icônes | dans la **zone sûre documentée** des deux côtés, verrouillée par un test |
| iOS | **jamais exécuté**, et compilé seulement vers `main` ou sur étiquette `ios` |
| Build de release | construit par la CI — sauf sur une PR de prose seule — et vérifié à la main ; **aucune partie complète jouée dessus** |
| Achat in-app | jamais effectué en vrai |
| Jouable sans pub ni achat | oui — un refus de consentement ne ferme aucune partie, et un test le tient |
| Clé de signature | `android/key.properties` absent — les APK sortent signés de la clé de debug |

## Ce qui ne dépend de personne

### 1. Le contenu des pages légales

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
- **Le contrôle de géométrie ne couvre que six surfaces.** Six fichiers de test importent
  `test/support/geometrie.dart` — tableau des scores, récapitulatif de tour, ossature de
  configuration, réglages, et depuis le 26 août la face de carte et le nom d'une catégorie ;
  les quatre premiers vont jusqu'à ×3,1, les deux derniers s'arrêtent à ×2.
  Partout ailleurs, un test de mise en page ne
  rougit que sur une exception de `RenderFlex` ou sur un widget introuvable, jamais sur un
  texte rogné, et s'arrête à ×1,3 : c'est le cas de **l'annonce de tour**, l'écran vu à chaque
  tour, du contenu réel des étapes de configuration, de l'accueil et de la fin de partie. Les
  deux écrans de catégories ne posent même jamais d'échelle de texte. Le détail des fichiers
  est dans `ROADMAP.md`.
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

### Découper l'achat unique en trois références ?

Aujourd'hui une seule référence, libellée « Plus aucune publicité, et toutes les catégories
débloquées. » Piste évoquée le 23 août : la découper en « sans pub », « toutes les catégories »
et « tout inclus ». À trancher **avant la première publication** — une référence publiée ne se
retire pas proprement d'un magasin.

## Journal

Les PR de la série, du 19 au 26 août.

| PR | Ce qui a changé |
|---|---|
| #40 | La dette de géométrie entre dans `ROADMAP.md` : elle ne vivait jusqu'ici que dans une note hors du dépôt. |
| #41 | L'application ne meurt plus au lancement en release. R8 en mode complet retirait le constructeur de `WorkDatabase_Impl`, que Room instancie par réflexion. Amène `tool/fumee.py`, son jeu de tests, et un build de release dans la CI. |
| #42 | La réponse au formulaire de consentement n'est plus perdue. Une échéance de 10 s bornait l'affichage du formulaire : au-delà, le choix du joueur partait à la poubelle sans un mot. |
| #43 | Le splash ne pointe plus l'icône du lanceur en thème sombre. **Vérifié sur les ressources de l'APK, pas à l'écran** — l'appareil s'est débranché avant l'installation. Amène `tool/test_ressources_android.py`. |
| #44 | `docs/REPRISE.md` entre dans le dépôt et devient la source de l'état du projet ; l'artefact n'en est plus qu'un rendu. Corrige au passage quatre faits faux, dont « iOS est compilé à chaque commit ». |
| #45 | Le point de reprise cesse d'épingler le SHA du commit qui le contient — il était faux dès son merge. |
| #46 | Les icônes tiennent dans la zone sûre que le système garantit. `make_icons.py` mesure le rayon du dessin au lieu de sa boîte, recadre sur la boîte opaque avant de mesurer, et remesure son résultat avant de l'écrire. Amène `tool/test_geometrie_icones.py`, qui rejoue le calcul depuis `logo_mark.png` et borne les cinq densités des deux côtés. |
| #47 | Les trois écrans qui pouvaient mettre une action hors d'atteinte sont corrigés, et mesurés plutôt qu'estimés. Amène `test/support/geometrie.dart`, qui voit ce qu'aucune exception ne signale — un texte plus large que sa boîte — et refuse de conclure sans les vraies polices. |
| #48 | Un binaire dit enfin ce qu'il est. Le `versionCode` valait `1` sur tous les builds depuis le premier, et `versionName` `1.0.0` : la seule façon d'établir ce qu'un téléphone exécutait était de le brancher pour comparer une empreinte SHA-256. Gradle compte désormais les commits, `tool/marque.py` grave l'empreinte et la date, et les réglages les affichent — copiables d'un appui. Un build hors du chemin de livraison le dit plutôt que d'inventer. |
| #49 | La longueur d'une carte est bornée à 60 caractères, la borne que l'import du contenu officiel applique depuis toujours — tenue par le dépôt, pas par le seul champ de saisie. Et parce que soixante caractères en un seul mot n'ont aucun point de coupure, le récapitulatif de tour les compose avec `TexteQuiTient` au lieu de les rogner. Le nom d'une catégorie reste ouvert. |
| #50 | Le point de reprise redevient exact — il datait du 24 en décrivant le 25, et annonçait cinq écrans mesurés là où il y en a quatre. Une PR de prose seule ne construit plus d'APK de release. |
| #51 | La face de carte replie son texte au lieu de l'écraser : une situation de 40 caractères passe de 15,5 à **46,6 px**, une carte à la borne de 10,2 à 38,3. Le nom d'une catégorie est borné à 30 caractères, valeur mesurée sur la hauteur de ligne à ×2. Amène `TexteDeCarte`, un aperçu de carte longue au banc de rendu, et deux fichiers de mesure. |

**Deux de ces défauts ont exactement la même forme :** une correction appliquée à un endroit
sur deux. Les deux fonctions jamais appelées du test de fumée, et les deux variantes de
`styles.xml`. Le second cas est désormais couvert par un test ; le premier ne l'est que par la
vigilance. (Le défaut de la #42 est d'une autre nature : un délai de garde posé sur deux étapes
qui n'auraient dû en porter aucune.)

**La machine de développement a été saturée deux fois**, une fois jusqu'à emporter les
instances VS Code ouvertes. Depuis : une commande lourde à la fois, jamais la suite de tests
complète en local, et je préviens avant un build Gradle.
