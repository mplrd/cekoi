# Monétisation et contraintes de publication

## Principe directeur

Le jeu se joue à plusieurs autour d'une table. Une pub qui tombe au mauvais moment ne gêne pas
un utilisateur, elle gêne **six personnes en même temps** et casse l'ambiance — c'est le genre
de chose qui fait désinstaller une app de soirée. La monétisation est donc placée
exclusivement sur les temps morts réels du jeu.

## Emplacements publicitaires

### Interstitiel au lancement de la partie — le seul autorisé

Il se déclenche au tap sur **Lancer la partie**, depuis l'écran de récapitulatif. C'est le
moment où le groupe s'installe, se répartit autour de la table et se passe le téléphone : le
temps mort existe déjà, on ne le fabrique pas.

L'écran affiche pendant ce temps « Installez-vous, la partie commence » et le rappel de la
contrainte de la manche 1. Si la pub n'est pas chargée au bout de 3 secondes, **on démarre la
partie sans elle** — jamais d'attente imposée.

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

Aucune bannière nulle part. Aucun interstitiel entre les manches, entre les tours, ni sur
aucun écran de configuration. Aucune pub pendant qu'un chrono tourne. Ces interdictions sont
structurantes, pas des préférences — elles doivent survivre aux futures tentations
d'optimisation de revenu.

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
