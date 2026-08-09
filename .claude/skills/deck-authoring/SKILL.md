---
name: deck-authoring
description: Écrire, relire ou corriger le contenu des cartes de Cékoi — catégories officielles, calibrage de difficulté, mots tabous, ligne éditoriale famille/adultes, format JSON des decks. À charger avant toute création ou modification de contenu dans assets/decks/.
---

# Écrire des cartes pour Cékoi

Le contenu est ce qui fait la qualité d'un jeu de ce type. Un moteur parfait avec des cartes
médiocres donne une soirée médiocre.

## Ce qui fait une bonne carte

Une carte doit passer les **trois manches**. C'est le critère qui élimine la plupart des
mauvaises propositions :

1. **Descriptible** sans employer les mots de la carte.
2. **Résumable en un seul mot** — s'il n'existe aucun mot déclencheur, la manche 2 est bloquée.
3. **Mimable** — au moins un geste, une posture ou une situation permet de l'évoquer.

Un concept abstrait comme « la nostalgie » échoue au test du mime. Un objet trop générique
comme « une chaise » échoue au test du mot unique, parce que tous les mots évidents sont
tabous. Vérifie mentalement les trois manches avant de retenir une carte.

Deuxième critère, tout aussi éliminatoire : **la reconnaissance par le groupe**. La carte doit
être connue d'au moins trois personnes sur quatre autour d'une table francophone. Un
footballeur des années 70, un mème de 2019, une série confidentielle : hors sujet, même si
c'est excellent. Le jeu se joue entre générations, et une carte que seul le plus jeune connaît
casse le rythme.

## Ligne éditoriale

### Cartes `family`

Compréhensibles à partir de 8 ans, sans être infantiles — les adultes jouent avec les mêmes
cartes. Personnalités très connues, objets du quotidien, animaux, métiers, lieux, films et
dessins animés grand public, expressions courantes.

### Cartes `adult`

Le registre est celui de **l'apéro entre amis** : grivois, gras, taquin. Pas explicite.

Cette limite n'est pas de la pudibonderie, c'est une contrainte économique directe. L'app vise
une classification 12+ / PEGI 12. Une seule carte franchement explicite fait basculer toute
l'app en 17+ / PEGI 18, avec une perte sèche de visibilité sur les stores et un effondrement
du eCPM publicitaire. Voir `docs/MONETISATION.md`.

**Autorisé :** double sens, allusions, situations gênantes, gueule de bois et soirées ratées,
vie de couple, rencontres, parties du corps dans un registre humoristique, jurons courants,
petites hontes sociales, clichés générationnels assumés.

**Interdit :** actes sexuels décrits, vocabulaire pornographique, violence graphique, apologie
de drogues, toute insulte visant une origine, une religion, une orientation ou un handicap, et
**toute mise en cause sexuelle ou dégradante d'une personne réelle nommée** — c'est un risque
juridique en plus d'un risque de retrait.

Le test simple : est-ce que je dirais cette carte à voix haute devant mes beaux-parents un
soir de réveillon ? Si c'est gênant mais drôle, c'est bon. Si c'est gênant tout court, c'est
non.

## Difficulté

| Niveau | Critère |
|---|---|
| 1 | Connu de quasiment tout le monde, mime évident. *Un chat, Zinédine Zidane, une brosse à dents.* |
| 2 | Connu de la majorité, demande un peu d'ingéniosité au mime. *Un phare, Marie Curie, le trac.* |
| 3 | Connu d'une bonne partie du groupe mais difficile à faire passer, ou nécessitant un détour. *Le vertige, un huissier, la Joconde.* |

Le tirage vise 30 % / 50 % / 20 % (R6.3). Un deck entier en difficulté 1 rend la partie fade,
un deck en difficulté 3 la rend frustrante. **Calibre en pensant à la manche 3** : c'est le
mime qui révèle la vraie difficulté d'une carte.

La difficulté a une seconde fonction, tout aussi importante : les profils de partie s'en
servent pour filtrer. Le profil *Les minis* ne tire que de la difficulté 1 (R7.5). Une carte
mal calibrée en 1 alors qu'elle est inaccessible à un enfant de 7 ans casse directement une
partie — c'est l'erreur de calibrage la plus coûteuse. En cas d'hésitation entre 1 et 2,
choisis 2.

## Âge minimum du deck

Le champ `minAge` détermine dans quels profils la catégorie apparaît (R7.4). Il porte sur
l'**accessibilité du sujet**, pas sur son caractère choquant — c'est la difficulté qui gère le
niveau, le `minAge` gère la pertinence.

| `minAge` | Pour qui | Exemples de catégories |
|---|---|---|
| 6 | Lecteurs débutants, 6–9 ans | Animaux, objets du quotidien, dessins animés, métiers |
| 10 | Collège, 10–14 ans | Films et séries grand public, sport, géographie, musique |
| 13 | Ados et adultes | Célébrités adultes, histoire, actualité, expressions imagées |
| 18 | Réservé au mode adultes | Tout deck `audience: adult` |

Un deck marqué `minAge: 6` doit être jouable **intégralement** par un enfant de 6 ans, cartes
difficiles comprises — sinon le profil *Les minis* servira des cartes injouables. Dans le
doute, monte le `minAge` plutôt que de le baisser : une catégorie absente d'un profil est un
manque discret, une catégorie inadaptée est une partie gâchée.

## Mots tabous

Utilisés en manche 1 uniquement. Liste les mots que le narrateur ne peut pas prononcer : les
mots de la carte elle-même sont implicitement tabous, inutile de les répéter.

Ajoute 2 à 4 mots qui rendraient la description triviale. Pour `Zinédine Zidane` :
`["football", "coup de boule", "Real Madrid", "1998"]`. Sans eux, la carte se devine en deux
secondes et perd tout intérêt.

N'en mets pas dix : au-delà de quatre, le narrateur ne peut plus les mémoriser en un coup
d'œil et la carte devient injouable.

## Format JSON

Un fichier par catégorie dans `assets/decks/`, nommé d'après son `id`.

```json
{
  "id": "celebrites-fr",
  "name": "Célébrités françaises",
  "description": "Des visages que tout le monde connaît, ou presque.",
  "icon": "star",
  "audience": "family",
  "minAge": 10,
  "contentVersion": 1,
  "isPremium": false,
  "sortOrder": 10,
  "cards": [
    {
      "text": "Zinédine Zidane",
      "difficulty": 1,
      "taboo": ["football", "coup de boule", "Real Madrid", "1998"]
    }
  ]
}
```

- `text` est le seul champ obligatoire d'une carte. `difficulty` vaut 2 par défaut, `taboo`
  une liste vide.
- L'identifiant de carte est dérivé de `<id du deck>:<slug du texte>` — il ne figure pas dans
  le JSON, mais **modifier un `text` existant change son identité** et casse le lien avec
  l'historique des parties. Pour corriger une faute de frappe, c'est acceptable ; pour
  remplacer une carte par une autre, supprime et ajoute.
- Incrémente `contentVersion` à **chaque** modification du fichier, sinon le seeding ignore
  les changements sur les appareils déjà installés.
- `audience` au niveau du deck s'applique à toutes ses cartes ; une carte peut le surcharger
  avec son propre champ `audience`.

## Conventions d'écriture

- Pas d'article en tête pour les objets : `Brosse à dents`, pas `Une brosse à dents`.
- Les noms propres portent leurs majuscules et leurs accents : `Zinédine Zidane`, `Élysée`.
- Une carte tient sur une ligne courte. Au-delà de 30 caractères environ, elle passe mal à
  l'écran et se retient mal.
- Français de France, sans anglicismes évitables. Les titres d'œuvres gardent leur titre
  français quand il est le plus connu.
- Aucun doublon à l'intérieur d'un deck ni entre deux decks du même mode — le tirage
  déduplique (R6.4), mais un doublon reste une carte gâchée.

## Méthode pour produire du volume

Quand tu génères une catégorie complète :

1. Annonce d'abord un plan : sous-thèmes visés et volume par sous-thème. Un deck qui pioche
   dans cinq sous-thèmes est plus vivant qu'une liste plate.
2. Produis par blocs de 40 à 60 cartes, pas 300 d'un coup — la qualité s'effondre en fin de
   longue liste, avec des cartes de plus en plus obscures.
3. Relis chaque bloc contre le test des trois manches et retire sans hésiter.
4. Vérifie les doublons contre les decks déjà écrits avant de livrer.
5. Signale ce dont tu n'es pas sûr — notoriété discutable, limite du registre adulte, doute
   sur l'orthographe d'un nom propre — plutôt que de trancher silencieusement.

Une catégorie livrable fait entre 120 et 200 cartes.
