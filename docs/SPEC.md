# Spécification fonctionnelle

Les règles de jeu ne sont pas répétées ici : elles sont dans `RULES.md`, référencées par leur
numéro (R3.4, R6.1…). Ce document décrit les écrans et les parcours.

## Contexte d'usage

C'est ce qui doit guider toutes les décisions d'interface. Le jeu se joue **autour d'une
table**, un téléphone qu'on se passe, avec du bruit et de l'agitation. Concrètement :

- Le narrateur tient le téléphone à bout de bras, souvent debout. Les zones tactiles de
  l'écran de jeu doivent être **énormes** et atteignables au pouce.
- Les autres joueurs regardent le narrateur, pas l'écran. L'information critique (temps
  restant, score) doit être lisible d'un coup d'œil à un mètre.
- Une partie dure 30 à 40 minutes avec de longues périodes sans toucher l'écran →
  `wakelock` actif pendant toute la partie.
- Il y a souvent des enfants. Aucun geste ne doit être irréversible sans confirmation.

## Parcours de configuration

Cinq étapes, avec une barre de progression et un retour possible à chaque niveau. L'objectif
est de pouvoir enchaîner en moins d'une minute quand on relance une partie identique.

### 1. Choix du mode

Deux grandes cartes : **En famille** / **Entre adultes**.

Le mode adultes affiche une confirmation d'âge simple (« Vous avez plus de 18 ans ? ») avant
d'ouvrir la sélection. Le choix n'est pas stocké comme donnée personnelle (R7.3). Le mode
détermine le vivier de cartes (R7.1) et les valeurs par défaut de la configuration.

### 2. Choix des catégories

**L'écran s'ouvre sur les profils, pas sur la grille.** Cocher des catégories une par une est
la corvée typique du début de partie, alors que dans la majorité des cas le groupe sait juste
« on joue avec les petits » ou « on joue tous ensemble ». Les profils répondent à ça.

En haut, une rangée de grandes cartes : **Les minis** (6–9 ans), **Ados & co** (10–14 ans),
**Mix familial**, chacune annonçant sa tranche d'âge et le nombre de cartes qu'elle réunit.
Un tap suffit pour être prêt à jouer : le profil présélectionne les catégories, restreint les
difficultés et ajuste chrono et nombre de cartes (R7.5). Un profil qui ne réunit pas assez de
cartes reste visible mais grisé, avec la raison affichée (R7.8).

En dessous, repliée par défaut derrière **Personnaliser**, la grille complète des catégories
avec pour chacune son nom, son icône et son nombre de cartes disponibles dans le mode courant.
Dès qu'on y touche, l'écran passe en « personnalisé » : les filtres du profil ne s'appliquent
plus mais la sélection en cours est conservée (R7.6). Un compteur permanent en bas indique le
total sélectionné et avertit si on passe sous le minimum de 12 cartes (R6.2).

Les catégories premium affichent un cadenas et un bouton « Débloquer » qui lance une pub
récompensée. Les catégories custom de l'utilisateur apparaissent dans la même grille, avec un
marquage discret, en fin de liste.

### 3. Réglages de partie

Durée du tour, nombre de cartes, nombre de manches — voir le tableau de R6. Chaque réglage
propose des valeurs prédéfinies en gros boutons plus une saisie libre repliée. Les défauts
dépendent du mode choisi à l'étape 1, ce qui doit permettre de traverser cet écran sans y
toucher dans la majorité des cas.

### 4. Équipes

Le point le plus travaillé de la configuration, parce que c'est le moment où tout le monde
attend.

L'utilisateur saisit d'abord la **liste des joueurs** dans un champ unique, une validation par
joueur, avec la liste qui se construit en dessous. Chaque joueur peut être marqué *enfant*
d'un tap, ce qui influencera la répartition (R8.3).

Il choisit ensuite un **nombre d'équipes**, puis « Proposer une composition » répartit
aléatoirement en équilibrant effectifs et enfants. Le résultat est présenté avec un bouton
**Relancer** bien visible — dans la vraie vie, on relance jusqu'à ce que le groupe soit
content. Tout reste modifiable à la main : glisser un joueur d'une équipe à l'autre, renommer
une équipe, changer sa couleur.

Il est aussi possible de composer entièrement à la main sans passer par la proposition.

### 5. Récapitulatif

Mode, catégories, réglages, équipes. Un bouton **Lancer la partie**.

C'est ici que se déclenche l'interstitiel publicitaire (voir `MONETISATION.md`) : pendant que
la pub tourne, l'écran affiche « Installez-vous, la partie commence » avec le rappel des
règles de la manche 1. Le temps mort est réel, on ne le fabrique pas.

## Écran de jeu

L'écran le plus important de l'app. Il ne contient rien d'autre que :

- **Le temps restant**, en très grand, avec un anneau de progression. Les 10 dernières
  secondes passent en rouge, avec un son discret et un retour haptique à chaque seconde.
- **La carte**, texte centré, taille de police adaptative selon la longueur.
- **En manche 1**, les mots tabous de la carte, listés en dessous en plus petit et barrés.
- **Deux zones d'action** occupant la moitié basse : *Trouvé* (verte, à droite) et *Passer*
  (neutre, à gauche). Un glissement horizontal sur la carte fait la même chose, pour ceux qui
  prennent le coup de main.
- Le nom de l'équipe active et son score courant, discrets, en haut.

Le bouton *Passer* se grise quand il ne reste qu'une carte (R3.4). Une pause est accessible
via un bouton discret en haut, qui masque immédiatement la carte.

## Récapitulatif de tour

Liste des cartes vues, chacune avec son résultat et un tap pour le basculer (R3.6). Le score
du tour se met à jour en direct. Un bouton confirme et passe à l'équipe suivante, avec un
écran intermédiaire « Au tour de <équipe> — passez le téléphone à <narrateur> » qui évite que
la manche s'enchaîne avant que le téléphone ait changé de mains.

## Scores et fin de partie

Entre deux manches : tableau des scores par équipe, détail par manche, et rappel de la
contrainte de la manche à venir.

En fin de partie : podium animé, score total, et le détail par manche. Deux actions —
**Rejouer avec les mêmes réglages** (qui saute toute la configuration, c'est le cas d'usage
le plus fréquent) et **Nouvelle partie**.

## Gestion des catégories custom

Accessible depuis l'accueil. Liste des catégories de l'utilisateur, création, renommage,
suppression avec confirmation.

Dans une catégorie : liste des cartes, ajout rapide (un champ, une validation, on enchaîne),
édition, suppression. Chaque carte peut recevoir des mots tabous et une difficulté ; les deux
sont optionnels, avec des défauts raisonnables, pour ne pas transformer la saisie en corvée.

Une catégorie custom est marquée `family` ou `adult` à la création, ce qui détermine dans
quel mode elle apparaîtra.

Import et export en JSON sont prévus pour permettre de récupérer une liste écrite sur un
ordinateur — mais **strictement en local, par le partage de fichiers du système**. Aucun
upload, aucun partage entre utilisateurs en v1 (règle d'or n°4).

## Accueil

Trois entrées : **Jouer**, **Mes catégories**, **Réglages**. Si une partie est en cours et
date de moins de 24 h (R9.2), une bannière « Reprendre la partie » s'affiche en haut.

## Réglages

Sons, retour haptique, thème clair/sombre/système, langue, gestion du consentement
publicitaire (obligatoire et accessible à tout moment), restauration des achats, mentions
légales et politique de confidentialité.

## Ce qui est explicitement hors périmètre v1

Comptes utilisateurs, partage de decks entre utilisateurs, jeu multi-device, classements en
ligne, statistiques de parties passées, i18n du contenu des cartes. Voir `ROADMAP.md`.
