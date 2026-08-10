# Écrire le contenu des cartes

Ce document s'adresse à la personne qui rédige les cartes. Aucune connaissance technique n'est
nécessaire : tu travailles avec Gemini et tu nous transmets un tableau, on s'occupe du reste.

## Le jeu en trente secondes

Une même carte est jouée **trois fois de suite**, avec une contrainte différente à chaque fois :

1. **Description libre** — on fait deviner en parlant, sans prononcer les mots de la carte.
2. **Un seul mot** — un seul mot, qu'on peut répéter autant qu'on veut. Rien d'autre.
3. **Mime** — en silence, uniquement avec des gestes.

## La règle qui élimine la plupart des mauvaises cartes

**Une carte doit fonctionner sur les trois manches.** C'est le seul critère vraiment
éliminatoire, et c'est celui qu'on oublie le plus.

« La nostalgie » est un joli mot, mais impossible à mimer : refusée. « Une chaise » se mime
très bien, mais en manche 2 tous les mots utiles sont déjà interdits : refusée. Avant de
retenir une carte, imagine-la aux trois manches.

Deuxième critère, presque aussi important : **la carte doit être connue d'au moins trois
personnes sur quatre autour d'une table**. Le jeu se joue entre générations, souvent avec des
enfants et des grands-parents dans la même partie. Une référence excellente mais que seul le
plus jeune connaît casse le rythme et frustre tout le monde.

## Ce qu'on te demande de produire

Pour chaque catégorie, un tableau à trois colonnes :

| texte | difficulte | note |
|---|---|---|
| Zinédine Zidane | 1 | |
| Le trac | 2 | |

**texte** — ce qui s'affichera sur la carte.

**difficulte** — de 1 à 3 :

| | |
|---|---|
| **1** | Connu de quasiment tout le monde, mime évident. *Un chat, une brosse à dents.* |
| **2** | Connu de la majorité, mime demandant un peu d'ingéniosité. *Un phare, le trac.* |
| **3** | Connu d'une bonne partie du groupe, mais difficile à faire passer. *Le vertige, un huissier.* |

Calibre toujours **en pensant à la manche 3** : c'est le mime qui révèle la vraie difficulté
d'une carte. Et en cas d'hésitation entre 1 et 2, choisis 2 — la difficulté 1 alimente le mode
réservé aux 6-9 ans, et une carte trop dure y gâche une partie entière.

**note** — vide la plupart du temps. C'est là que tu signales un doute : notoriété discutable,
orthographe incertaine, carte à la limite du ton demandé.

## Les deux publics

**Famille** — compréhensible à partir de 8 ans sans être infantile, puisque les adultes jouent
les mêmes cartes. Personnalités très connues, objets du quotidien, animaux, métiers, lieux,
films et dessins animés grand public.

**Entre adultes** — le registre est celui de **l'apéro entre amis** : grivois, gras, taquin,
mais **jamais explicite**.

Cette limite n'est pas de la pudibonderie, elle a une conséquence très concrète : l'application
vise une classification 12 ans et plus. Une seule carte franchement explicite la ferait
basculer en 18+, ce qui la rendrait beaucoup moins visible sur les stores et diviserait ses
revenus publicitaires. Le ton adulte est donc un vrai budget, à dépenser intelligemment.

Sont autorisés : les doubles sens, les allusions, les situations gênantes, les soirées ratées,
la vie de couple, les petites hontes sociales, les jurons courants.

Sont exclus : les actes sexuels décrits, le vocabulaire pornographique, la violence graphique,
et toute insulte visant une origine, une religion, une orientation ou un handicap. Également
exclu, et c'est un vrai risque juridique : toute allusion sexuelle ou dégradante visant une
**personne réelle nommée**.

Le test simple : est-ce que je dirais cette carte à voix haute devant mes beaux-parents un soir
de réveillon ? Si c'est gênant mais drôle, c'est bon. Si c'est gênant tout court, c'est non.

## Le prompt à donner à Gemini

Copie ce texte, remplace les trois valeurs entre crochets, et envoie-le dans une **nouvelle
conversation** pour chaque catégorie.

```
Tu m'aides à écrire des cartes pour Cékoi, un jeu de société français inspiré de Time's Up.

LE JEU
Une même carte est jouée sur trois manches successives :
1. Description libre — on fait deviner en parlant, sans dire les mots de la carte
2. Un seul mot — un seul mot, répétable autant qu'on veut, rien d'autre
3. Mime — en silence, gestes uniquement

RÈGLE ABSOLUE : chaque carte doit fonctionner sur LES TROIS manches. Si elle ne peut pas être
mimée, elle est refusée. S'il n'existe aucun mot-déclencheur possible pour la manche 2, elle
est refusée. Vérifie les trois manches pour chaque carte avant de la proposer.

DEUXIÈME RÈGLE : la carte doit être connue d'au moins 3 personnes sur 4 autour d'une table
française, toutes générations confondues. Un sportif des années 70, un mème récent, une série
confidentielle : refusés, même excellents.

CATÉGORIE : [NOM DE LA CATÉGORIE]
PUBLIC : [famille OU entre adultes]
NOMBRE DE CARTES : [40 à 60 maximum par envoi]

DIFFICULTÉ
1 = connu de quasiment tout le monde, mime évident (un chat, une brosse à dents)
2 = connu de la majorité, mime demandant de l'ingéniosité (un phare, le trac)
3 = connu d'une bonne partie du groupe, difficile à faire passer (le vertige, un huissier)
Calibre en pensant à la manche 3, c'est le mime qui révèle la vraie difficulté.
En hésitation entre 1 et 2, choisis 2.

ÉCRITURE
- Pas d'article en tête : « Brosse à dents », pas « Une brosse à dents »
- Majuscules et accents corrects sur les noms propres : « Zinédine Zidane », « Élysée »
- 30 caractères maximum environ
- Français de France, sans anglicismes évitables
- Titres d'œuvres en version française quand c'est la plus connue
- Aucun doublon dans la liste

FORMAT DE SORTIE
Un tableau à 3 colonnes, rien avant ni après :
texte | difficulte | note

La colonne « note » reste vide, sauf si tu as un doute : notoriété discutable, orthographe
d'un nom propre incertaine, carte à la limite du ton demandé. Écris alors ton doute en
quelques mots. Ne supprime jamais une carte douteuse en silence — signale-la, on tranchera.

AVANT D'ÉCRIRE
Propose-moi d'abord les sous-thèmes que tu comptes couvrir et le nombre de cartes par
sous-thème. Je validerai avant que tu écrives.
```

Pour le mode adultes, ajoute ce paragraphe juste avant `FORMAT DE SORTIE` :

```
TON
Registre de l'apéro entre amis : grivois, gras, taquin, mais jamais explicite. L'application
vise une classification 12 ans et plus, une seule carte explicite la ferait basculer en 18+.
Autorisé : doubles sens, allusions, situations gênantes, soirées ratées, vie de couple,
petites hontes sociales, jurons courants.
Exclu : actes sexuels décrits, vocabulaire pornographique, violence graphique, insultes visant
une origine, une religion, une orientation ou un handicap, et toute allusion sexuelle ou
dégradante visant une personne réelle nommée.
```

## Deux conseils d'usage

**Demande-lui son plan avant qu'il écrive.** Le prompt le prévoit. Une catégorie qui couvre
cinq sous-thèmes est nettement plus vivante qu'une liste qui déroule un seul angle, et c'est
beaucoup plus facile à corriger à ce stade qu'après 200 cartes.

**Ne dépasse pas 60 cartes par envoi.** Au-delà, la qualité s'effondre en fin de liste : les
références deviennent obscures et les répétitions apparaissent. Mieux vaut quatre envois de 50
qu'un seul de 200. Une catégorie complète fait entre 120 et 200 cartes au total.

## Ce que Gemini rate systématiquement

Ces défauts reviennent à chaque fois. Les connaître fait gagner beaucoup de temps en
relecture.

**Il sous-estime la difficulté.** Ce qui lui paraît évident ne l'est pas pour un enfant de
sept ans. Relis en particulier tout ce qu'il classe en difficulté 1 : c'est le niveau qui
alimente le mode des 6-9 ans, et c'est le plus mal calibré.

**Il se répète sur les longues listes.** Deux formulations proches de la même idée, à vingt
lignes d'écart. On les détecte automatiquement à l'import, mais autant les voir avant.

**Il dérive vers les références anglophones**, même quand on lui demande du français. Séries
américaines, marques internationales, célébrités que personne ne connaît en France.

**Il invente ou déforme les noms propres.** Orthographe approximative, dates fausses,
attributions erronées. Chaque nom propre mérite une vérification, c'est le point où il se
trompe le plus.

**Il devient générique en fin de liste.** Les vingt dernières cartes d'un long envoi sont
presque toujours les plus faibles. C'est la vraie raison de la limite à 60.

**Son curseur sur le ton adulte est instable.** Il alterne entre trop sage et trop loin, sans
prévenir. Sur ces catégories-là, relis tout.

## Nous transmettre le résultat

Un fichier par catégorie, dans le format que tu préfères : export Google Sheets, tableur, ou
simplement le tableau collé dans un document. On s'occupe de la conversion.

Précise pour chaque catégorie : son **nom**, son **public** (famille ou adultes) et, pour les
catégories famille, **l'âge minimum** à partir duquel elle est jouable — 6, 10 ou 13 ans. Ce
dernier point détermine dans quels modes de jeu elle apparaîtra, et il n'y a que toi qui puisses
en juger.

En cas de doute sur cet âge, indique l'âge supérieur. Une catégorie absente d'un mode est un
manque discret ; une catégorie trop difficile pour les enfants qui l'utilisent gâche une partie.
