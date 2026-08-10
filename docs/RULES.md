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
| 1 | Description libre | Le narrateur dit ce qu'il veut, **sauf** les mots figurant sur la carte, leurs dérivés **et leurs synonymes**. Ni mime, ni geste, ni bruitage. **On ne passe pas** (R3.9). |
| 2 | Un seul mot | Un unique mot, choisi librement. L'équipe **ne se concerte pas** : seule la première proposition compte, sinon on passe. Ni mime, ni geste, ni bruitage. |
| 3 | Mime | Mimes, gestes et bruitages — mais **aucun mot**. Une seule proposition, sans se concerter. |

Le synonyme est explicitement exclu en manche 1 : « le félin qui fait miaou » pour *chat* vide
la manche de sa difficulté, alors que le jeu repose sur le contournement. C'est la règle qui se
discute le plus à la table — elle est donc écrite ici, et rappelée à l'écran d'annonce (R2.3).

**R2.1** — Les manches se jouent toujours dans cet ordre.

**R2.2** — **Une partie, c'est les trois manches.** Le nombre de manches n'est pas un réglage :
c'est la montée en contrainte sur un paquet qu'on mémorise qui fait le jeu, et en retirer une
le vide de son ressort. Retour d'usage d'août 2026 — le réglage n'était jamais touché et
allongeait un écran de configuration qu'on veut traverser sans y penser.

**R2.3** — La règle de la manche est rappelée avant chaque tour, à l'écran d'annonce. Elle est
formulée pour être lue à voix haute par celui qui tient le téléphone : c'est le seul moment où
tout le monde écoute.

## 3. Déroulé d'un tour

**R3.1** — L'équipe active désigne son narrateur **elle-même**, à la table. L'application ne
connaît pas les joueurs et ne suit aucune rotation : elle annonce l'équipe, les joueurs savent
à qui c'est. Retour d'usage d'août 2026 — saisir les prénoms était la corvée du début de
partie, et personne ne consultait le narrateur désigné à l'écran.

**R3.2** — Le chrono démarre à l'affichage de la première carte, pas à l'arrivée sur l'écran.
Un compte à rebours de 3 secondes précède le départ.

**R3.3** — Sur chaque carte, le narrateur dispose de deux actions :
- **Trouvé** : +1 point pour l'équipe active, la carte quitte le paquet de la manche.
- **Passer** : la carte retourne **au fond** du paquet, sans pénalité. Elle peut donc
  ressortir dans le même tour si le paquet fait le tour complet.

**R3.4** — Le bouton *Passer* est **désactivé quand il ne reste qu'une seule carte** dans le
paquet. Sans cette règle, passer la dernière carte la ferait réapparaître immédiatement, ce
qui bloque le tour.

**R3.9** — *Passer* **n'existe pas en manche 1**. Le narrateur a le droit de tout dire sauf les
mots de la carte : il n'y a pas de carte infaisable, seulement une carte qui prend du temps.
Passer y serait un moyen gratuit de trier le paquet à son avantage. En manches 2 et 3, la
contrainte peut rendre une carte réellement impossible, et *Passer* redevient la sortie prévue
— c'est même la règle en manche 2, où une proposition erronée coûte la carte.

L'action est **absente de l'écran**, pas grisée : un bouton grisé pendant toute une manche se
lit comme une panne.

**R3.5** — Le tour se termine quand le chrono atteint zéro, ou quand le paquet est vide.

**R3.6** — À la fin du tour, un écran de récapitulatif liste les cartes vues avec leur
résultat. **Chaque résultat est corrigeable** — c'est indispensable en usage réel, les erreurs
de manipulation sont fréquentes dans le feu de l'action. La correction recalcule le score et
la composition du paquet avant de passer à la suite.

**R3.7** — Si l'application passe en arrière-plan pendant un tour, le chrono se met en pause.
À la reprise, un compte à rebours de 3 secondes précède la reprise du jeu.

**R3.8** — Le jeu est aussi interruptible à la main, par un bouton de pause. Une pause, qu'elle
vienne de l'arrière-plan ou du bouton, **gèle le tour entièrement** : le chrono s'arrête et
aucune action de carte n'est acceptée, ni *Trouvé* ni *Passer*. Sans cette règle, une équipe
peut valider des cartes chrono arrêté. La reprise suit le même compte à rebours que R3.7.

## 4. Fin de manche

**R4.5** — **Une manche dure autant de tours qu'il en faut.** Tant que le paquet n'est pas
vide, un nouveau tour s'ouvre avec l'équipe suivante, dans la même manche. On ne passe à la
manche suivante que lorsque **toutes** les cartes ont été trouvées : le paquet fait le tour de
la table autant de fois que nécessaire.

C'est ce qui fait tenir le principe de la section 1 — le même paquet rejoué intégralement à
chaque manche. Une manche qui s'arrêterait au bout d'un tour laisserait des cartes jamais vues,
et la manche suivante ne serait plus une reprise du même paquet.

**R4.6** — **Une carte non trouvée reste en jeu.** Quand le chrono tombe, la carte affichée
n'est ni perdue ni comptée : elle repart au tour suivant, pour l'équipe suivante. Les cartes
passées, elles, sont déjà revenues au fond du paquet (R3.3). **Rien ne sort du paquet sans
avoir été trouvé** — c'est la formulation qui fait foi, et les trois seuls retraits possibles
sont une carte trouvée pendant le tour, une carte corrigée en *trouvée* au récapitulatif (R3.6)
et le remélange de fin de manche (R4.2).

Sa position : la carte affichée reste **en tête** du paquet, sauf si une correction post-tour
la retire ou en réinsère une autre (R3.6) — le paquet est recalculé avant l'ouverture du tour
suivant.

Sa ligne au récapitulatif dépend de son histoire dans le tour, **pas** du fait qu'elle soit
affichée à la fin :

- jamais tranchée pendant ce tour → **aucune ligne**, il n'y a rien à corriger ;
- déjà passée plus tôt dans le même tour, puis revenue en tête parce que le paquet a fait le
  tour complet (R3.3) → **sa ligne de passage subsiste**, et c'est elle qui la rend corrigeable
  au titre de R3.6.

Le second cas n'est pas théorique : il survient dès qu'il reste peu de cartes en manche 2 ou 3.
Filtrer la carte de tête du récapitulatif rendrait incorrigible une carte passée à tort.

**R4.1** — Quand la dernière carte du paquet est trouvée, la manche s'arrête **immédiatement**,
même en plein milieu d'un tour. Le temps restant est perdu et n'est pas reporté.

**R4.2** — Toutes les cartes sont remises en jeu et **remélangées** pour la manche suivante. Le
mélange est dérivé de la graine de la partie et du numéro de manche : rejouer la même partie
depuis ses événements redonne le même ordre.

**R4.3** — La manche suivante démarre avec **l'équipe qui suit** celle qui a terminé la manche
précédente. Sans cette règle, l'équipe qui vide le paquet enchaînerait deux tours d'affilée.

À deux équipes, cela revient à dire que la manche est ouverte par **celle qui n'a pas terminé
la précédente**. Au-delà de deux, c'est bien « celle qui suit » qui fait foi : « celle qui n'a
pas terminé » n'y désigne plus une équipe unique.

**R4.4** — Un écran de scores intermédiaires est affiché entre deux manches, avec le détail
par manche et le cumul.

## 5. Fin de partie

**R5.1** — Le score final est le cumul des points des trois manches. Une carte vaut 1 point
dans toutes les manches.

**R5.2** — L'équipe avec le plus de points gagne.

**R5.3** — En cas d'égalité en tête, une manche de départage oppose les équipes à égalité :
une carte, en mime, la première équipe qui trouve gagne. Répétée jusqu'à départage.

La carte de départage vient d'une **réserve de cartes écartées au tirage**, jamais du paquet
joué : à ce stade toutes les cartes du paquet ont été vues trois fois et ne départageraient
plus rien. Si le vivier était trop juste pour constituer cette réserve, on se rabat sur le
paquet joué — un départage au réflexe reste préférable à pas de départage.

## 6. Configuration de partie

| Paramètre | Valeurs | Défaut famille | Défaut adultes |
|---|---|---|---|
| Durée du tour | 30 / 45 / 60 / 90 s, ou libre (15–180) | 60 s | 45 s |
| Nombre de cartes | 24 / 32 / 40 / 48, ou auto, ou libre | auto | 32 |
| Nombre d'équipes | 2 à illimité | 2 | 2 |

**R6.1** — Le mode *auto* pour le nombre de cartes calcule `12 × nombre d'équipes`, arrondi au
multiple de 4 supérieur, borné à [16, 80]. C'est le réglage qui donne des parties d'environ
30 à 40 minutes.

Le calcul portait sur le nombre de joueurs jusqu'au retour d'usage d'août 2026, qui a retiré
leur saisie (R8.2). Le facteur 12 vaut `5 × 2,4 joueurs par équipe` : à deux équipes il
donne 24 cartes, là où six joueurs en donnaient 32. La durée d'une partie suit le nombre de
tours à jouer, donc le nombre d'équipes, bien plus que l'effectif exact autour de la table.

Depuis ce changement, le plancher de 16 n'est plus atteignable : le minimum de deux équipes
(R8.5) donne déjà 24. Il reste écrit ici comme garde, et non comme un cas que le joueur peut
rencontrer — seule une baisse du facteur le réveillerait.

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

**R8.2** — L'application **ne connaît pas les joueurs** : ni leur nom, ni leur nombre, ni leur
répartition. Une équipe est un nom et un score. Qui est dans quelle équipe se règle à la table,
en trois secondes, mieux que par un écran.

**R8.3** — La configuration des équipes tient en deux choses : **combien**, et **comment elles
s'appellent**. Un nom laissé vide vaut « Équipe N » — on lance une partie sans rien taper.

**R8.4** — Les noms saisis survivent à un changement du nombre d'équipes : passer de 2 à 3 ne
doit pas effacer les deux noms déjà donnés.

**R8.5** — Une partie nécessite au minimum 2 équipes.

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
6. *Passer* en manche 1, paquet plein → refusé, le paquet ne bouge pas et aucune ligne
   n'apparaît au récapitulatif (R3.9). La même action en manche 2 est acceptée.
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
13. Pause en cours, le narrateur appuie sur *Trouvé* → aucun point, le paquet ne bouge pas
    (R3.8). Le chrono figé rend l'action gratuite, c'est ce qui la rend tentante.
14. Trois équipes demandées après en avoir nommé deux → les deux noms restent, la troisième
    prend son nom par défaut (R8.4). Repasser à deux ne doit pas ressusciter un nom effacé.
15. Le chrono tombe alors qu'une carte jamais tranchée est affichée → elle reste en tête du
    paquet pour le tour suivant et n'a pas de ligne au récapitulatif (R4.6). Variante à couvrir
    aussi : la carte affichée à cet instant avait été **passée** plus tôt dans le même tour et
    est revenue en tête — sa ligne de passage subsiste et reste corrigeable (R3.3, R3.6).
16. Un tour se termine avec des cartes au paquet → la manche continue avec l'équipe suivante,
    et l'écran de scores intermédiaires n'apparaît pas (R4.5).
