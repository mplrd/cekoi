# Point de reprise

**État au 24 août 2026** — `develop` à `751f1b3`, arbre propre, CI verte, aucune PR ouverte.

Ce fichier est le récapitulatif du reste à faire, et il est **la source**. L'artefact publié
sur claude.ai n'en est qu'un rendu :
<https://claude.ai/code/artifact/fbde1c17-c062-4b8f-991e-377be55bf091>

Il vivait jusqu'ici uniquement dans cet artefact, hors du dépôt. Deux sessions de suite l'ont
laissé se périmer sans que rien ne le signale — il annonçait encore « aucun build de release
ne tourne nulle part » quatre jours après que la CI en construise un. Un état du projet qui
n'est pas versionné n'est revu par personne, ne passe dans aucune revue de PR, et diverge de
`ROADMAP.md` en silence. D'où ce fichier.

**Toute session qui change l'état du projet met ce fichier à jour d'abord, et republie
l'artefact ensuite.** Le rendu ne se modifie jamais à la main.

Ce document est un digest : il dit **où on en est et ce qui vient**. Le détail technique reste
dans `ROADMAP.md`, les démarches dans `ADMINISTRATIF.md`, les règles dans `RULES.md`.

## En un coup d'œil

| | |
|---|---|
| Lots | 7 sur 8 faits ; le lot 8 est entamé |
| Cartes | 529 sur les 1 200 visées, réparties sur 21 catégories |
| Écrans à risque de débordement | 3, non couverts par un test |
| Géométrie des icônes | hors du cercle garanti par Android, sur les **deux** icônes |
| iOS | compilé à chaque commit, **jamais exécuté** |
| Build de release | construit par la CI et vérifié à la main ; **aucune partie complète jouée dessus** |
| Achat in-app | jamais effectué en vrai |
| Clé de signature | `android/key.properties` absent — les APK sortent signés de la clé de debug |

## Ce qui ne dépend de personne

Les trois seuls travaux que je peux prendre sans compte, sans arbitrage et sans livraison de
contenu — sauf que le premier a désormais besoin d'un arbitrage visuel, voir plus bas.

### 1. La géométrie des icônes ne respecte pas le cercle garanti

Mesuré le 24 août, sur les fichiers du dépôt. `tool/make_icons.py` applique sa marge de deux
tiers au **côté** du canevas ; Android masque sur un **cercle** de deux tiers de diamètre. Un
carré de côté `2/3·c` déborde de 41 % au coin du cercle de rayon `c/3` qu'il est censé tenir.
Le dessin de Cékoi remplit justement ses coins — la bulle en haut à gauche, la carte « 1 » en
haut à droite, les jambes du coureur en bas.

| Fichier | Rayon max du dessin | Rayon garanti | Dépassement | Pixels opaques hors du cercle |
|---|---|---|---|---|
| `drawable-xxxhdpi/splash_icon.png` | 0,4035 du côté | 0,3333 | **+21 %** | 7,6 % |
| `assets/branding/logo_foreground.png` → `ic_launcher_foreground.png` | 0,6042 du côté | 0,4902 | **+23 %** | 8,8 % |

Pour l'icône du lanceur, le rayon garanti tient compte du retrait de 16 % que pose
`mipmap-anydpi-v26/ic_launcher.xml` : l'image atterrit sur 73,44 dp des 108 dp de la couche,
et le masque coupe à 36 dp de rayon, soit 0,4902 du côté de l'image.

**Pourquoi ça n'a jamais crevé les yeux.** Le cercle est ce qu'Android *garantit* ; la forme
réellement découpée est décidée par l'appareil. Pour l'icône du lanceur, le masque est certain
— c'est le mécanisme même de l'icône adaptative — et seule sa forme varie : un lanceur qui
masque en cercle décapite la bulle, tranche la carte « 1 » et coupe la jambe du coureur, là
où le carré arrondi observé sur le Xiaomi du projet laisse tout passer. Pour l'écran de
démarrage, c'est plus flou encore : rien ne dit qu'un appareil donné masque un PNG simple.

Dans les deux cas la conclusion est la même, et elle ne dépend d'aucun détail de MIUI : **tout
ce qui sort du cercle tient par chance, pas par conformité.** Et ça vaut pour l'icône de
l'application, pas seulement pour l'écran de démarrage — ce que la note du 23 août n'avait pas
vu.

Le correctif mécanique est connu : faire porter la règle sur le cercle dans
`tool/make_icons.py`, ce qui revient à multiplier le dessin par 0,826 (splash) et 0,811
(lanceur). L'icône devient visiblement plus petite. **C'est un arbitrage visuel** — voir
« Ce qu'il faut trancher ».

Tant que ce n'est pas tranché, aucune assertion de géométrie n'est ajoutée à
`tool/test_ressources_android.py` : elle rougirait aujourd'hui. Ce fichier ne couvre pour
l'instant que la parité entre variantes de configuration, qui est un autre défaut.

### 2. Trois écrans peuvent mettre une action hors d'atteinte

Inchangé depuis le 19 août ; le détail et le tableau des seuils sont dans `ROADMAP.md`. En
résumé : `turn_summary_view`, `setup_scaffold` et `score_table` sont bâtis sur la même
structure — en-tête fixe, action épinglée, `Expanded` au milieu qui absorbe le débordement
jusqu'à tomber à zéro. Aucun test ne mesure de géométrie dessus, et la recette ne les
trouvera pas : il faut avoir agrandi le texte dans les réglages du système, ce que font
justement ceux qui en ont besoin. `score_table` est le pire, il se dégrade en silence.

### 3. Le contenu des pages légales

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
- **iOS n'a jamais tourné ailleurs qu'en compilation.** Le cycle de vie du chrono (R3.7) et le
  comportement audio et haptique sont les deux points qui divergent réellement entre les
  plateformes, et ce sont ceux du cœur du jeu.
- **Aucun achat in-app réel, aucune vraie publicité.** Le lot 7 tourne de bout en bout sur les
  identifiants de test de Google et un magasin injecté.

## Ce qui t'attend, toi

Dans l'ordre du délai, pas de l'effort. Le détail des démarches est dans `ADMINISTRATIF.md`.

| Démarche | Dépend de | Délai propre |
|---|---|---|
| Générer la clé de signature | rien | 3 minutes |
| Ouvrir le compte Google Play | la structure | **2 à 3 semaines de chrono**, une fois un build déposé |
| Ouvrir le compte Apple | la structure | débloque iOS, rien d'autre ne le fait |
| Créer le compte AdMob | l'arbitrage sur le type de profil | le choix se fige à la création |
| Relancer ta compagne | rien | le vrai goulot : 671 cartes manquantes |

Deux points qui coûtent une demi-journée si on les découvre trop tard :

- **La clé de signature compte dès maintenant.** Tant qu'elle n'existe pas, les APK que je te
  passe sortent signés de la clé de debug, et un téléphone qui en a reçu un **refusera** la
  mise à jour signée de la vraie clé. Désinstallation obligatoire — à savoir avant de
  distribuer aux douze testeurs.
- **Le profil de paiement AdMob, particulier ou organisation, se fige à la création** et aucun
  écran ne permet d'en changer. Play et Apple, eux, se transfèrent à une société : le risque
  n'est pas symétrique.

## Ce qu'il faut trancher

### La géométrie des icônes : rapetisser, ou redessiner ?

La seule décision nouvelle. Deux voies, et elles ne coûtent pas la même chose.

- **Rapetisser** — `tool/make_icons.py` calcule la marge sur le cercle, on régénère, un test
  verrouille la règle. Une heure. L'icône perd 18 % de côté, sur les deux écrans.
- **Redessiner la marque** pour que sa silhouette soit ronde — rapprocher la bulle et la carte
  « 1 » du centre plutôt que de tout réduire. On garde la taille apparente. Ce n'est pas
  mécanisable : `assets/branding/logo.svg` est un tracé aplati, quinze chemins sans groupes,
  donc c'est un travail d'illustration.

Ne rien faire n'est pas une option neutre : l'icône est décapitée sur tout Android non
Xiaomi, et c'est la première chose que voit un testeur.

### Étendre R7.10 au déblocage ?

En mode Sans filtre, l'écran des catégories est inatteignable par construction — c'est un
choix assumé de R7.10, qui évite un écran à traverser pour rien. Conséquence non prévue : une
catégorie adulte marquée premium y serait **invisible et impossible à ouvrir**.

R7.10 prévoit déjà une sortie pour le *décochage* — « un accès depuis l'étape du vivier, pas
un retour des catégories sur le chemin ». Elle ne dit rien du *déblocage*. La question :
ajouter à l'étape du vivier un accès qui ne montre que les catégories verrouillées ?

Le code est prêt à le porter, l'écran de déblocage du mode Famille se réutilise tel quel. Le
trou reste théorique tant qu'aucune catégorie adulte n'est premium — cette décision se prend
donc naturellement avec l'arbitrage premium.

### « Une courte publicité précède la partie » — on la garde affirmative ?

Tu as tranché sa *condition* : elle ne dépend que de ce que le joueur possède, jamais du
consentement ni du plafond de fréquence, et les tests la verrouillent. Reste sa *formulation*,
sur laquelle tu ne t'es pas prononcé : elle promet une pub qui, en pratique, ne sort presque
jamais. Annoncer une pub qui n'arrive pas est sans risque ; l'inverse ne l'est pas. Mais une
phrase qui ne se vérifie jamais finit par ne plus être lue.

### Découper l'achat unique en trois références ?

Aujourd'hui une seule référence, libellée « plus aucune publicité et toutes les catégories
autorisées ». Piste évoquée le 23 août : la découper en « sans pub », « toutes les
catégories » et « tout inclus ». À trancher **avant la première publication** — une référence
publiée ne se retire pas proprement d'un magasin.

## Journal

Depuis le dernier point, le 19 août.

| PR | | |
|---|---|---|
| #40 | Mergée | La dette de géométrie entre dans `ROADMAP.md` : elle ne vivait jusqu'ici que dans une note hors du dépôt. |
| #41 | Mergée | L'application ne meurt plus au lancement en release. R8 en mode complet retirait le constructeur de `WorkDatabase_Impl`, que Room instancie par réflexion. Amène `tool/fumee.py`, son jeu de tests, et un build de release dans la CI. |
| #42 | Mergée | La réponse au formulaire de consentement n'est plus perdue. Une échéance de 10 s bornait l'affichage du formulaire : au-delà, le choix du joueur partait à la poubelle sans un mot. |
| #43 | Mergée | Le splash cesse d'être rogné en thème sombre. `values-night-v31` pointait encore l'icône du lanceur, qui n'a pas de marge. Amène `tool/test_ressources_android.py`. |

**Trois de ces quatre défauts ont la même forme : une correction appliquée à un endroit sur
deux.** Les deux méthodes de la passerelle de consentement, les deux fonctions jamais appelées
du test de fumée, les deux variantes de `styles.xml`. Le dernier cas est désormais couvert par
un test ; les deux autres ne le sont que par la vigilance.

**La machine de développement a été saturée deux fois**, une fois jusqu'à emporter les
instances VS Code ouvertes. Depuis : une commande lourde à la fois, jamais la suite de tests
complète en local, et je préviens avant un build Gradle.
