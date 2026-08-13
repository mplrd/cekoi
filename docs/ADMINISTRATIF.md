# Démarches administratives

Ce que **le code ne peut pas faire avancer**. Comptes à ouvrir, validations à attendre,
arbitrages à rendre. Cette liste existe parce que ces éléments se comptent en jours ou en
semaines de calendrier, pas en heures de développement : les découvrir au moment du lot 8, une
fois l'application prête, c'est attendre à vide.

Tenue à jour au fil des lots. Dernière revue : 13 août 2026.

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
      empêche toute mise à jour ultérieure.
- [ ] **Créer le SKU `cekoi_version_complete`** dans les deux consoles, en produit **non
      consommable** (Play : produit intégré unique ; Apple : *Non-Consumable*). Le prix se
      règle par palier dans la console, jamais dans le code. Tant qu'il n'existe pas, le
      passage en caisse ne peut pas être testé en vrai — le reste du parcours d'achat tourne
      sur des doublures.

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
