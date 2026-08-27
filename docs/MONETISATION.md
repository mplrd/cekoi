# Monétisation et contraintes de publication

## Principe directeur

Le jeu se joue à plusieurs autour d'une table. Une pub qui tombe au mauvais moment ne gêne pas
un utilisateur, elle gêne **six personnes en même temps** et casse l'ambiance — c'est le genre
de chose qui fait désinstaller une app de soirée. La monétisation est donc placée
exclusivement sur les temps morts réels du jeu.

## Emplacements publicitaires

### Interstitiel au lancement de la partie — le seul autorisé

Il se déclenche au tap sur **Lancer la partie**, au pied de la dernière étape de la
configuration — celle des équipes. C'est le moment où le groupe s'installe, se répartit autour
de la table et se passe le téléphone : le temps mort existe déjà, on ne le fabrique pas.

Si la pub n'est pas chargée au bout de 3 secondes, **on démarre la partie sans elle** — jamais
d'attente imposée. Pendant cette attente l'étape des équipes reste à l'écran, le bouton
tourne, et le retour est fermé : sans ça, la pub s'afficherait par-dessus une étape de
configuration que le joueur n'a pas quittée, ce que la section « Ce qui est interdit »
proscrit.

Une ligne discrète au-dessus du bouton prévient qu'une courte publicité précède la partie.
Elle suit ce qui vaut **durablement** sur l'appareil, et rien d'autre : la version complète
retire la publicité, et un consentement refusé la retire aussi longtemps que le joueur ne
rouvre pas le formulaire depuis les réglages. Dans ces deux cas la ligne disparaît — annoncer
une pub qui ne viendra jamais est faux.

Le plafond de fréquence, lui, ne la fait pas disparaître : il vaut pour la partie qui commence,
pas pour l'appareil. L'y mettre ferait clignoter la ligne d'une partie à l'autre, et la tairait
à qui verra une pub dès la suivante. Annoncer une pub qui ne sort pas cette fois-ci est sans
conséquence ; taire une pub qui sort ne l'est pas.

Le pied de la dernière étape et le portillon lisent la **même** valeur, `launchAdPossible` :
la ligne ne peut donc pas promettre ce que l'interstitiel refusera.

**Pas d'écran dédié.** Il y en a eu deux, retirés tous les deux après essai en partie réelle.
Un **récapitulatif** de la configuration — mode, catégories, durée, équipes — qui portait le
bouton de lancement : il n'apprenait rien à qui venait de tout choisir. Puis un écran
« Installez-vous, la partie commence », avec le rappel de la contrainte de la manche 1,
intercalé pour porter l'interstitiel : il redisait ce que l'annonce du tour affiche
immédiatement après, et comme il était traversé même quand aucune pub ne sortait — c'est-à-dire
presque toujours — les joueurs voyaient clignoter un écran de plus entre leur décision et leur
partie. Une pub interstitielle est un plein écran : elle recouvre ce qui est dessous et n'a pas
besoin d'une page à elle.

Fréquence : une seule fois par partie, avec un plafond de 3 par heure et un délai minimum de
5 minutes entre deux. Rejouer avec les mêmes réglages juste après une partie ne doit pas
redéclencher une pub.

### Pub récompensée pour débloquer des catégories

Certaines catégories sont marquées `is_premium`. Un bouton « Débloquer » lance une vidéo
récompensée ; le déblocage est **définitif**, pas limité à une partie. Une récompense qui
expire est perçue comme une arnaque et détruit la confiance sur ce type d'app.

C'est le format au meilleur eCPM du marché, et il est perçu comme un échange équitable parce
que l'utilisateur choisit de le déclencher.

### Ce qui est interdit

Aucune bannière nulle part. Aucun interstitiel entre les manches, entre les tours, ni pendant
qu'un chrono tourne. Aucun interstitiel déclenché depuis une étape de configuration — à la
seule exception du tap sur **Lancer la partie**, qui met fin à la configuration et ouvre le
temps mort décrit plus haut. La nuance n'est pas un assouplissement : ce qui est interdit,
c'est de couvrir de publicité un écran sur lequel le joueur a encore quelque chose à faire.
C'est précisément ce que garantit le `PopScope` du bouton de lancement — sans lui, un retour
pendant le chargement ramènerait à l'étape précédente et la pub s'afficherait par-dessus des
réglages en cours.

Ces interdictions sont structurantes, pas des préférences — elles doivent survivre aux futures
tentations d'optimisation de revenu.

## Achat in-app

Un SKU unique, non consommable.

On vend une **« Version complète »**, pas un « Retirer les pubs ». Elle supprime l'interstitiel
**et** débloque définitivement toutes les catégories premium. Prix cible 3,99 €.

La raison de ce choix : si un utilisateur paie pour retirer les pubs mais doit quand même
regarder des vidéos récompensées pour accéder aux catégories, il a le sentiment d'avoir payé
pour rien. Un seul achat, une seule promesse, valeur perçue nettement supérieure.

Conséquence à ne pas oublier à l'implémentation : posséder la version complète doit masquer
**tous** les points d'entrée publicitaires, y compris les boutons « Débloquer » des catégories
premium — qui deviennent simplement des catégories accessibles.

Prévoir la restauration des achats dans les réglages — c'est obligatoire côté Apple.

## Consentement RGPD

Obligatoire dès lors qu'on affiche de la pub à des utilisateurs européens. On utilise le CMP
**Google UMP**, inclus dans `google_mobile_ads`, ce qui évite d'intégrer un CMP tiers.

Le formulaire de consentement est présenté **au premier lancement, avant toute requête
publicitaire**. Le SDK publicitaire ne s'initialise qu'après une réponse. Le choix doit rester
modifiable à tout moment depuis les réglages — c'est une exigence légale, souvent oubliée, et
un motif de rejet côté stores.

**Un refus ne ferme aucune partie.** Le jeu est intégralement jouable sans consentement et sans
achat : le portillon rend la main immédiatement, la partie se lance sans pub et sans attente. Il
n'existe aucun chemin où il faut accepter une publicité, ou l'avoir achetée, pour jouer — c'est
une contrainte de conformité autant qu'un choix de produit.

Une **politique de confidentialité hébergée publiquement** est obligatoire pour les deux
stores, même sans compte utilisateur. Elle doit mentionner AdMob comme destinataire de
données. À produire avant la première soumission ; une page statique suffit.

## Classification d'âge

Le mode adultes étant grivois sans être explicite, la cible est **12+ sur l'App Store** et
**PEGI 12 sur Google Play**, en déclarant humour grossier et références sexuelles légères
comme peu fréquents.

Cette classification préserve la découvrabilité et l'accès à un inventaire publicitaire
normal. Elle a une conséquence directe sur l'écriture du contenu : le mode adultes doit rester
dans le registre de l'apéro entre amis. Le jour où une carte franchit la ligne de l'explicite,
c'est toute l'app qui bascule en 17+/PEGI 18, avec une perte sèche de visibilité et de eCPM.
La discipline éditoriale est donc un sujet économique, pas seulement un sujet de goût. Voir la
skill `deck-authoring`.

**Point de vigilance sur Google Play.** Malgré son nom, le mode *En famille* signifie
« jouable avec des enfants autour de la table », pas « application destinée aux enfants ». La
déclaration d'audience cible sur Play doit être **13 ans et plus**, sans opt-in au programme
*Designed for Families*. Déclarer une audience enfant ferait basculer l'app sous la politique
Families et COPPA, avec des contraintes publicitaires nettement plus lourdes et un inventaire
restreint.

Configurer par ailleurs la note de contenu publicitaire maximale d'AdMob sur `PG`, pour éviter
qu'une pub inappropriée s'affiche pendant une partie en famille.

## Isolation technique

Pub et achats vivent dans `lib/services/ads/` et `lib/services/purchases/`, derrière des
interfaces (`AdService`, `PurchaseService`). Aucune feature n'importe `google_mobile_ads` ou
`in_app_purchase` directement.

Ça permet de tourner avec des implémentations factices en test et en développement — personne
ne veut regarder de vraies pubs à chaque itération — et de changer de régie sans toucher à
l'interface. Les identifiants de blocs publicitaires passent par `--dart-define`, jamais en
dur dans le code.
