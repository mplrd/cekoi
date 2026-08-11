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

Deux grandes cartes : **En famille** / **Sans filtres**.

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

Durée du tour et nombre de cartes — voir le tableau de R6. Chaque réglage propose des valeurs
prédéfinies en gros boutons plus une saisie libre repliée. Les défauts dépendent du mode choisi
à l'étape 1, ce qui doit permettre de traverser cet écran sans y toucher dans la majorité des
cas.

Le nombre de manches n'y figure pas : une partie, c'est les trois (R2.2).

### 4. Équipes

Deux choses, et rien d'autre : **combien d'équipes**, et **comment elles s'appellent**.

Une rangée de pastilles pour le nombre, puis un champ de nom par équipe. Les noms sont
facultatifs : un champ laissé vide donne « Équipe 1 », « Équipe 2 » (R8.3), et le libellé par
défaut s'affiche dans le champ vide sans qu'il faille l'effacer pour taper le sien. Changer le
nombre d'équipes ne fait pas perdre les noms déjà donnés (R8.4).

**L'application ne demande pas les joueurs** (R8.2). Ni leurs prénoms, ni leur nombre, ni qui
est avec qui. C'est un retour d'usage de la première phase de tests : la saisie était la corvée
du début de partie, alors que le groupe s'était déjà réparti de vive voix avant que le premier
prénom soit tapé. Qui narre se décide à la table, et l'écran d'annonce se contente de nommer
l'équipe (R3.1).

### 5. Récapitulatif

Mode, catégories, réglages, équipes. Un bouton **Lancer la partie**.

C'est ici que se déclenche l'interstitiel publicitaire (voir `MONETISATION.md`) : pendant que
la pub tourne, l'écran affiche « Installez-vous, la partie commence » avec le rappel des
règles de la manche 1. Le temps mort est réel, on ne le fabrique pas.

## Écran de jeu

L'écran le plus important de l'app. Il ne contient rien d'autre que :

- **Le temps restant**, en très grand, avec un anneau de progression. Les 10 dernières
  secondes passent en rouge, avec un son discret et un retour haptique à chaque seconde.
- **La carte**, texte centré, taille de police adaptative selon la longueur. Rien d'autre :
  pas de mots interdits listés, pas d'indice. Le narrateur doit lire la carte d'un coup d'œil,
  à bout de bras, au milieu d'une table qui crie.
- **Les zones d'action** se partageant la moitié de la hauteur sous l'entête : *Trouvé !*
  (verte, à droite) et *Je passe…* (neutre, à gauche). Un glissement horizontal sur la carte
  fait la même chose, pour ceux qui prennent le coup de main.
- Le nom de l'équipe active et son score courant, discrets, en haut.

Les deux libellés sont à la **première personne, au présent** : c'est le narrateur qui parle,
et c'est ce qu'il dirait à voix haute. *Passer* / *Trouvé* mélangeait un infinitif et un
participe — retour d'usage, le changement de temps se remarquait.

**En manche 1, *Passer* n'est pas à l'écran** (R3.9) : *Trouvé !* prend toute la largeur, et le
glissement vers la gauche ne fait rien. L'action est retirée et non grisée — un bouton mort
pendant une manche entière se lit comme une panne, et l'écran de jeu est celui où on ne doit
jamais se demander si l'application a compris.

Seule, cette zone ne garde pas la moitié : elle descend à **un tiers de la hauteur disponible
sous l'entête** — l'entête, avec son anneau de chrono, occupe une hauteur fixe qui ne se
partage pas — et la carte récupère la place. Retour d'usage : pleine largeur **et**
demi-hauteur, elle était démesurée. Elle reste assez grande pour être tapée sans viser, ce qui
est tout l'intérêt d'une zone plutôt que d'un bouton.

Aux manches 2 et 3, l'action de passage se grise quand il ne reste qu'une carte (R3.4). Une
pause est accessible via un bouton discret en haut, qui masque immédiatement la carte.

## Récapitulatif de tour

Liste des cartes vues, chacune avec son résultat et un tap pour le basculer (R3.6). Le score
du tour se met à jour en direct. Un bouton confirme et passe à l'équipe suivante, avec un
écran intermédiaire « Au tour de <équipe> — passez le téléphone à votre narrateur » qui évite
que la manche s'enchaîne avant que le téléphone ait changé de mains. Cet écran **rappelle la
règle de la manche** en toutes lettres (R2.3) : c'est le seul moment de la partie où tout le
monde écoute.

En manche 1, basculer une carte sur « pas trouvée » reste possible bien que *Passer* n'y
existe pas : c'est l'annulation d'un tap de trop, pas un contournement de R3.9.

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
édition, suppression.

**La difficulté appartient à la carte, jamais à la catégorie.** Elle ne se choisit donc pas au
moment de la saisie : une carte entre avec un niveau moyen, et se règle d'un tap sur elle dans
la liste. Retour d'usage — un sélecteur en tête d'écran se lisait comme le niveau de la
catégorie entière, alors qu'une catégorie « Vacances » contient des faciles comme des
difficiles. Sortir le niveau du formulaire allège aussi la saisie en rafale, qui ne demande
plus que du texte.

Le formulaire d'ajout se lit de haut en bas et **finit par son action** : le texte, puis le
bouton *Ajouter*, et plus rien après lui.

Une catégorie custom est marquée `family` ou `adult` à la création, ce qui détermine dans
quel mode elle apparaîtra.

L'import et l'export en JSON permettent de récupérer une liste écrite sur un ordinateur, ou
de passer une catégorie d'un téléphone à un autre — mais **strictement en local, par le
partage de fichiers du système**. Aucun upload, aucun partage entre utilisateurs en v1
(règle d'or n°4).

Le format est celui de `assets/decks/` : un export s'importe tel quel ailleurs, et un fichier
écrit à la main s'importe aussi. L'import **crée une catégorie**, il ne fusionne pas avec une
existante — fusionner demanderait d'arbitrer les cartes modifiées des deux côtés.

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
