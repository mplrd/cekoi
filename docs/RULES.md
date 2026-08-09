# Règles canoniques de Cékoi

**Ce document est la source de vérité du gameplay.** Toute implémentation de la logique de
jeu doit s'y conformer ; en cas de contradiction avec du code existant, c'est le code qui a
tort. Chaque règle numérotée est directement testable — les tests du moteur référencent ces
numéros.

---

## 1. Principe

Un paquet de N cartes est tiré au hasard parmi les catégories choisies en début de partie.
**Le même paquet est rejoué intégralement à chaque manche**, avec une contrainte de plus en
plus forte. Les joueurs mémorisent donc progressivement les cartes, ce qui rend les dernières
manches plus rapides — c'est le ressort du jeu, pas un effet de bord.

## 2. Les manches

| # | Nom | Contrainte |
|---|---|---|
| 1 | Description libre | Le narrateur peut dire ce qu'il veut, **sauf** les mots figurant sur la carte et leurs dérivés. Gestes interdits. |
| 2 | Un seul mot | Un unique mot, choisi librement, qu'il peut répéter autant qu'il veut. Aucun autre son, aucun geste. |
| 3 | Mime | Silence total. Gestes uniquement. Aucun bruitage, aucun objet de la pièce désigné du doigt. |

**R2.1** — Les manches se jouent toujours dans cet ordre.

**R2.2** — Le nombre de manches est configurable (2 ou 3). En 2 manches, on joue la 1 et la 3
— la manche « un seul mot » est celle qui bloque le plus les jeunes enfants.

## 3. Déroulé d'un tour

**R3.1** — L'équipe active désigne un narrateur. La rotation est automatique et **interne à
chaque équipe** : chaque équipe garde son propre curseur de narrateur. Des équipes de tailles
inégales sont donc autorisées sans qu'un joueur narre plus souvent que les autres de son
équipe.

**R3.2** — Le chrono démarre à l'affichage de la première carte, pas à l'arrivée sur l'écran.
Un compte à rebours de 3 secondes précède le départ.

**R3.3** — Sur chaque carte, le narrateur dispose de deux actions :
- **Trouvé** : +1 point pour l'équipe active, la carte quitte le paquet de la manche.
- **Passer** : la carte retourne **au fond** du paquet, sans pénalité. Elle peut donc
  ressortir dans le même tour si le paquet fait le tour complet.

**R3.4** — Le bouton *Passer* est **désactivé quand il ne reste qu'une seule carte** dans le
paquet. Sans cette règle, passer la dernière carte la ferait réapparaître immédiatement, ce
qui bloque le tour.

**R3.5** — Le tour se termine quand le chrono atteint zéro, ou quand le paquet est vide.

**R3.6** — À la fin du tour, un écran de récapitulatif liste les cartes vues avec leur
résultat. **Chaque résultat est corrigeable** — c'est indispensable en usage réel, les erreurs
de manipulation sont fréquentes dans le feu de l'action. La correction recalcule le score et
la composition du paquet avant de passer à la suite.

**R3.7** — Si l'application passe en arrière-plan pendant un tour, le chrono se met en pause.
À la reprise, un compte à rebours de 3 secondes précède la reprise du jeu.

## 4. Fin de manche

**R4.1** — Quand la dernière carte du paquet est trouvée, la manche s'arrête **immédiatement**,
même en plein milieu d'un tour. Le temps restant est perdu et n'est pas reporté.

**R4.2** — Toutes les cartes sont remises en jeu et remélangées pour la manche suivante.

**R4.3** — La manche suivante démarre avec **l'équipe qui suit** celle qui a terminé la manche
précédente, et avec le narrateur suivant dans cette équipe. Sans cette règle, l'équipe qui
vide le paquet enchaînerait deux tours d'affilée.

**R4.4** — Un écran de scores intermédiaires est affiché entre deux manches, avec le détail
par manche et le cumul.

## 5. Fin de partie

**R5.1** — Le score final est le cumul des points des trois manches. Une carte vaut 1 point
dans toutes les manches.

**R5.2** — L'équipe avec le plus de points gagne.

**R5.3** — En cas d'égalité en tête, une manche de départage oppose les équipes à égalité :
une carte, en mime, la première équipe qui trouve gagne. Répétée jusqu'à départage.

## 6. Configuration de partie

| Paramètre | Valeurs | Défaut famille | Défaut adultes |
|---|---|---|---|
| Durée du tour | 30 / 45 / 60 / 90 s, ou libre (15–180) | 60 s | 45 s |
| Nombre de cartes | 24 / 32 / 40 / 48, ou auto, ou libre | auto | 32 |
| Nombre de manches | 2 ou 3 | 3 | 3 |
| Nombre d'équipes | 2 à illimité | 2 | 2 |

**R6.1** — Le mode *auto* pour le nombre de cartes calcule `5 × nombre de joueurs`, arrondi au
multiple de 4 supérieur, borné à [16, 80]. C'est le réglage qui donne des parties d'environ
30 à 40 minutes.

**R6.2** — Si les catégories sélectionnées contiennent moins de cartes que le nombre demandé,
la partie utilise tout ce qui est disponible et le signale explicitement avant de démarrer.
Un minimum de 12 cartes est requis pour lancer une partie.

**R6.3** — Le tirage est équilibré en difficulté : à volume suffisant, il vise une répartition
de 30 % faciles, 50 % moyennes, 20 % difficiles. Si le vivier ne le permet pas, il complète
avec ce qui existe plutôt que d'échouer.

**R6.4** — Le tirage ne produit jamais de doublon de texte de carte, même si deux catégories
sélectionnées contiennent la même entrée.

## 7. Modes de contenu

**R7.1** — Le mode **Famille** ne tire que des cartes marquées `family`. Le mode **Entre
adultes** tire dans `family` **et** `adult` — un apéro entre adultes ne veut pas dire qu'on
s'interdit les cartes tout public.

**R7.2** — Le mode est choisi en début de partie et ne change pas en cours de route.

**R7.3** — Le mode Entre adultes est accessible derrière une confirmation d'âge simple, non
bloquante et non stockée en tant que donnée personnelle.

### Profils de partie

Un profil est un **raccourci** : il présélectionne des catégories, restreint les difficultés
et ajuste les réglages par défaut, pour pouvoir lancer une partie sans rien cocher.

**R7.4** — Chaque catégorie porte un âge minimum (`minAge`) valant 6, 10, 13 ou 18. Un profil
ne retient que les catégories dont le `minAge` est inférieur ou égal au sien.

**R7.5** — Profils du mode Famille :

| Profil | Âge | Catégories | Difficultés | Chrono | Cartes |
|---|---|---|---|---|---|
| **Les minis** | 6–9 ans | `minAge ≤ 6` | 1 uniquement | 90 s | auto |
| **Ados & co** | 10–14 ans | `minAge ≤ 10` | 1 et 2 | 60 s | auto |
| **Mix familial** | tous | `minAge ≤ 13` | 1, 2 et 3 | 60 s | auto |

Le mode Entre adultes utilise le même mécanisme ; ses profils sont de la donnée de
configuration, pas du code, et peuvent être ajoutés sans modifier le moteur.

**R7.6** — Un profil est un point de départ, jamais une contrainte. Après l'avoir choisi,
l'utilisateur peut cocher ou décocher des catégories et modifier tous les réglages. Dès qu'il
touche à la sélection, le profil passe en état « personnalisé » et cesse d'imposer ses
filtres — mais les catégories déjà sélectionnées restent en place.

**R7.7** — La restriction de difficulté d'un profil s'applique **avant** l'équilibrage de
R6.3. Si un profil n'autorise qu'une seule difficulté, l'équilibrage ne s'applique pas et le
tirage prend uniformément dans le vivier autorisé.

**R7.8** — Si un profil ne réunit pas les 12 cartes minimum (R6.2), il est affiché mais
désactivé, avec la raison indiquée. Il ne disparaît pas silencieusement de la liste.

## 8. Équipes

**R8.1** — Aucune limite haute sur le nombre d'équipes. L'interface doit rester utilisable
jusqu'à 10 équipes ; au-delà, elle ne doit pas casser.

**R8.2** — Les équipes peuvent avoir des effectifs différents. Voir R3.1 pour la rotation.

**R8.3** — La **proposition de composition** prend la liste des joueurs saisis et un nombre
d'équipes, puis répartit aléatoirement en équilibrant les effectifs (écart maximum de 1
joueur entre deux équipes). Si des joueurs sont marqués *enfant*, elle les répartit
uniformément plutôt que de les concentrer dans une seule équipe.

**R8.4** — La proposition est relançable autant de fois que voulu, et reste entièrement
modifiable à la main ensuite. Ce n'est qu'une suggestion.

**R8.5** — Une partie nécessite au minimum 2 équipes de 2 joueurs.

## 9. Persistance

**R9.1** — L'état d'une partie en cours est sauvegardé après chaque événement. Fermer
l'application puis la rouvrir propose de reprendre là où on en était.

**R9.2** — Une partie abandonnée depuis plus de 24 h n'est plus proposée à la reprise.

---

## Cas limites à couvrir en test

Ces situations sont celles qui cassent les implémentations naïves. Chacune doit avoir un test
dédié dans `test/domain/`.

1. Le paquet se vide sur la dernière carte d'un tour alors qu'il reste 20 s → manche terminée,
   temps perdu, l'équipe suivante ouvre la manche d'après (R4.1, R4.3).
2. Il ne reste qu'une carte et le narrateur essaie de passer → action indisponible (R3.4).
3. Correction post-tour qui marque *trouvée* la dernière carte restante → la manche doit se
   terminer, pas continuer avec un paquet vide (R3.6 + R4.1).
4. Correction post-tour qui annule la dernière carte trouvée d'une manche → la manche doit
   reprendre avec cette carte au paquet.
5. Toutes les cartes passées, aucune trouvée pendant un tour entier → le paquet doit être
   identique en fin de tour, sans boucle infinie.
6. Une équipe de 2 joueurs et une équipe de 5 → chaque équipe fait tourner ses narrateurs
   indépendamment (R3.1).
7. Trois équipes à égalité parfaite en fin de partie → départage à trois (R5.3).
8. Mise en arrière-plan à 1 s de la fin du chrono → au retour, il reste bien 1 s (R3.7).
9. Partie configurée à 48 cartes alors que les catégories n'en contiennent que 30 → on joue à
   30, avec un avertissement (R6.2).
10. Deux catégories sélectionnées contenant la même carte → une seule occurrence tirée (R6.4).
11. Profil *Les minis* alors qu'aucune catégorie `minAge ≤ 6` n'a assez de cartes en difficulté
    1 → profil affiché mais désactivé, avec la raison (R7.8).
12. Profil choisi puis décochage manuel d'une catégorie → passage en « personnalisé », les
    filtres de difficulté du profil ne s'appliquent plus, la sélection restante est conservée
    (R7.6).
