# Démarches administratives

Ce que **le code ne peut pas faire avancer**. Comptes à ouvrir, validations à attendre,
arbitrages à rendre. Cette liste existe parce que ces éléments se comptent en jours ou en
semaines de calendrier, pas en heures de développement : les découvrir au moment du lot 8, une
fois l'application prête, c'est attendre à vide.

Tenue à jour au fil des lots. Dernière revue : 13 août 2026, après le lot 7.

## À lancer maintenant

Rien de ce qui suit ne bloque le développement en cours. Tout bloque la publication, et chacun
porte un délai qui court en parallèle du code — d'où l'intérêt de démarrer sans attendre que le
reste soit fini.

- [ ] **Compte Google Play Console** — 25 $, une seule fois.
      C'est le délai le plus long du projet, et de loin. Un compte développeur **personnel**
      créé depuis fin 2023 doit réussir un **test fermé avec 12 testeurs pendant 14 jours
      consécutifs** avant de pouvoir demander l'accès à la production. Il faut donc trouver
      douze personnes qui installent l'application et la gardent deux semaines. Le compteur ne
      démarre qu'une fois le compte créé et un premier build déposé : **deux à trois semaines
      incompressibles**, à faire courir pendant qu'on développe.
      *À vérifier sur la console — cette règle a changé plusieurs fois.*

- [ ] **Compte Apple Developer** — 99 $ par an.
      Nécessaire pour TestFlight, pour l'App Store, et pour installer sur un iPhone autrement
      que par un profil gratuit de 7 jours. La validation d'identité prend quelques jours.

- [ ] **Compte AdMob** — gratuit, sur `admob.google.com`.
      Fournit l'App ID par plateforme, les identifiants de blocs publicitaires, et le CMP qui
      sert le formulaire de consentement. Demande une adresse postale, des informations
      fiscales et un RIB. Seuil de paiement à 70 €.

## Le choix qui ne se rattrape pas

**Le type de profil de paiement AdMob — particulier ou organisation — se fige à la création.**
Il n'existe pas d'écran pour en changer. « Migrer plus tard » veut dire un nouveau profil de
paiement, donc en pratique un nouveau compte AdMob, avec les applications et les blocs
publicitaires à recréer et aucune reprise automatique de l'historique.

Les comptes de store, eux, **se transfèrent** à une société : Google comme Apple prévoient une
procédure de transfert d'application. Le risque n'est donc pas symétrique — c'est AdMob qu'il
faut décider en connaissance de cause, pas Play ni Apple.

Une personne physique suffit partout. Côté français, des revenus publicitaires récurrents
supposent un statut, et les plateformes déclarent les revenus à l'administration : à voir avec
un comptable, pas ici.

À noter pour la fiche de store : Google Play affiche publiquement l'adresse de contact du
développeur, et Apple vend sous le nom légal du vendeur. Pour un particulier, c'est l'adresse
personnelle sur la fiche publique, sauf domiciliation.

- [ ] Arbitrer particulier ou société **avant** de créer le profil de paiement AdMob.

## Ce qui bloque la validation iOS

**Un iPhone ne suffit pas, et c'est le point le plus mal compris du projet.** Installer une
application iOS sur un appareil passe obligatoirement par Xcode, donc par macOS — même pour un
test personnel, même avec un profil gratuit. La machine de développement est sous Windows.

Il n'existe donc que deux portes d'entrée :

1. emprunter une machine macOS ;
2. **TestFlight**, alimenté par le runner macOS de la CI.

La seconde est la stratégie retenue depuis le lot 1, et elle a un coût d'amorçage qui n'est pas
encore payé. Aujourd'hui le job `ios-build` produit un build **non signé** : il prouve que le
projet compile, pods compris, et rien de plus.

- [ ] Compte Apple Developer — prérequis de tout le reste ci-dessous.
- [ ] Certificat de distribution et profil de provisionnement.
- [ ] Fiche de l'application dans App Store Connect.
- [ ] Signature câblée dans la CI, avec les secrets GitHub correspondants.
- [ ] Premier build poussé sur TestFlight.

Tant que ces cinq lignes ne sont pas cochées, **l'iPhone ne peut rien valider**. Et ce qui
attend cette validation n'est pas mince : la gestion du cycle de vie pendant le chrono (R3.7),
le comportement audio et haptique, et désormais deux SDK natifs — publicité et achat in-app —
dont aucune ligne n'a jamais été exécutée sur iOS.

## Sans code, mais nécessaire à la publication

- [ ] **Politique de confidentialité hébergée publiquement.** Obligatoire sur les deux stores,
      même sans compte utilisateur, et elle doit mentionner AdMob comme destinataire de
      données. Une page statique suffit.
- [ ] **Questionnaires de classification d'âge.** Cible : 12+ sur l'App Store, PEGI 12 sur
      Google Play, en déclarant humour grossier et références sexuelles légères comme peu
      fréquents. Voir `MONETISATION.md`.
- [ ] **Déclaration d'audience cible sur Google Play : 13 ans et plus**, sans opt-in au
      programme *Designed for Families*. Le mode « En famille » du jeu veut dire jouable avec
      des enfants autour de la table, pas destiné aux enfants — se tromper ici fait basculer
      l'application sous la politique Families et COPPA, avec un inventaire publicitaire
      nettement plus pauvre.
- [ ] **Note de contenu publicitaire AdMob plafonnée à `PG`.** Se règle dans la console ; le
      code la demande déjà à chaque requête.
- [ ] **Clé de signature Android** et son stockage sûr. Perdre la clé d'une application publiée
      empêche toute mise à jour ultérieure. `android/app/build.gradle.kts` signe encore avec la
      clé de debug : rien n'est publiable en l'état, et c'est volontairement resté ainsi jusqu'à
      ce que la vraie clé existe.
- [ ] **Politique de confidentialité et mentions légales : il faut les URL.** `SPEC.md` prévoit
      les deux entrées dans l'écran de réglages. Elles ne sont pas posées, parce qu'une entrée
      qui n'ouvre rien est pire que pas d'entrée du tout. Dès que les pages sont hébergées, le
      câblage est d'une demi-heure.
- [ ] **Créer le SKU `cekoi_version_complete`** dans les deux consoles, en produit **non
      consommable** (Play : produit intégré unique ; Apple : *Non-Consumable*). Le prix se
      règle par palier dans la console, jamais dans le code. Tant qu'il n'existe pas, le
      passage en caisse ne peut pas être testé en vrai — le reste du parcours d'achat tourne
      sur des doublures.

## Dette de développement assumée

Ni bloquant ni administratif, mais à ne pas redécouvrir dans six mois :

- **Aucun accès au déblocage en mode Sans filtre.** R7.10 rend l'écran des catégories
  inatteignable dans ce mode par construction. Une catégorie adulte marquée premium y serait
  donc invisible **et** impossible à ouvrir. Latent tant que seule `disneypixar`, qui est
  familiale, est premium — donc directement dépendant de l'arbitrage ci-dessous. `RULES.md`
  indique déjà la sortie : un accès depuis l'étape du vivier, pas un retour des catégories sur
  le chemin.
- **Chaque déblocage recharge tout le catalogue**, qui dépend de la possession : l'écran passe
  par un indicateur d'attente le temps de relire les cartes du mode. Acceptable sur une action
  volontaire et rare, à revoir si ça se voit sur un vrai téléphone.
- **Pas de choix de langue dans les réglages**, alors que `SPEC.md` le prévoit. L'application
  n'a qu'une seule locale : un sélecteur à une entrée serait un menu qui ne fait rien.
  L'infrastructure ARB est en place, l'entrée arrivera avec la deuxième langue.

## Arbitrages produit en attente

- [ ] **Quelles catégories passent premium.** Revient à l'auteure du contenu, avec la prochaine
      livraison. En attendant, `disneypixar` est marquée premium à titre provisoire pour que le
      cadenas soit exercé par de vraies données.
- [ ] **Compléter le contenu.** 529 cartes livrées sur les 1 200 visées pour un lancement
      crédible (`ROADMAP.md`, lot 5). C'est le vrai goulot du projet.

## Matériel

- [x] Machine de développement Windows, émulateur et téléphones Android physiques.
- [ ] **iPhone de test** — annoncé pour le vendredi 14 août 2026. Rien de l'application n'a
      jamais tourné sur un appareil iOS : seule la compilation est vérifiée, par la CI. Deux
      points divergent réellement entre les plateformes et touchent le cœur du jeu — la gestion
      du cycle de vie pendant le chrono (R3.7) et le comportement audio et haptique. S'ajoute
      désormais le SDK publicitaire, jamais exécuté sur iOS.
      Rappel : disposer d'un iPhone ne dispense pas d'une machine macOS pour compiler et
      signer. C'est le rôle du runner macOS en CI.
