# Cékoi

Jeu de société mobile inspiré de Time's Up : on fait deviner le même paquet de cartes
sur trois manches de plus en plus contraintes. Flutter, Android + iOS, mono-device
(on se passe le téléphone), 100 % hors ligne pour jouer.

## Documents de référence

Ne réimplémente pas ce qui est déjà décidé. Avant de coder, lis le document concerné :

| Document | Quand le lire |
|---|---|
| `docs/RULES.md` | **Toute** logique de gameplay. C'est la source de vérité des règles, y compris les cas limites. |
| `docs/ARCHITECTURE.md` | Structure du code, modèle de données, packages, conventions de couches. |
| `docs/SPEC.md` | Parcours utilisateur, écrans, comportements attendus. |
| `docs/MONETISATION.md` | Pub, achat in-app, consentement RGPD, contraintes de publication. |
| `docs/CONTENU.md` | Guide de rédaction des cartes, destiné à l'auteure du contenu. Format de livraison attendu. |
| `docs/ROADMAP.md` | Ce qui est dans la v1 et ce qui est explicitement repoussé. |
| `docs/ADMINISTRATIF.md` | Comptes, validations et arbitrages hors code. À relire avant toute question de délai ou de publication. |

## Règles d'or

1. **Le moteur de jeu est du Dart pur.** `lib/domain/` n'importe jamais `package:flutter`.
   C'est un réducteur déterministe `(State, Event) -> State`, sans I/O ni async, avec un
   RNG injecté. C'est ce qui rendra le multi-device de la v2 peu coûteux : le même
   réducteur tournera sur le serveur et les clients.
2. **Un seul chemin de lecture pour les cartes.** Les JSON de `assets/decks/` sont un format
   de livraison, seedé dans SQLite au lancement. À l'exécution, tout passe par la base —
   officiel et custom confondus, distingués par la colonne `origin`. Ne jamais merger deux
   sources à chaud.
3. **Jamais de pub pendant un tour chronométré.** Le seul emplacement interstitiel autorisé
   est le lancement de la partie, au tap sur « Lancer la partie » — il n'y a pas d'écran
   dédié, la pub recouvre la dernière étape de la configuration. Voir `docs/MONETISATION.md`.
4. **Les cartes custom restent locales au device en v1.** Aucun partage, aucun upload. C'est
   ce qui nous exempte de la guideline Apple 1.2 sur le contenu généré par les utilisateurs.
5. **Le français est la langue de référence.** Le contenu des cartes est écrit en français et
   pensé pour un public francophone. L'i18n de l'interface est prévue, pas celle des cartes.

## Commandes

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed, riverpod, drift
flutter gen-l10n                                            # après toute modif des ARB
dart format lib test tool                                   # la CI le vérifie, cf. ci.yml
flutter test                                                # tests domaine + widgets
flutter test tool/apercus/apercu.dart --update-goldens       # banc de rendu : un PNG par écran
flutter analyze
flutter run

python tool/fumee.py    # AVANT de livrer un APK : construit, installe, lance sur le téléphone
```

`tool/fumee.py` n'est pas optionnel avant de donner un artefact à quelqu'un. R8 ne tourne
qu'en release, et il ne casse pas la compilation — il casse l'**exécution** : la CI construit
la release, donc elle voit une règle mal écrite, mais elle ne voit rien de ce qui ne se
manifeste qu'au lancement. Un APK de release qu'on n'a pas lancé soi-même n'est pas un APK
vérifié.

`dart format` n'est pas un confort : la CI lance `--set-exit-if-changed` et rougit sur un
fichier écrit à la main. `flutter analyze` ne le voit pas.

L'import de contenu est en Python, hors de l'application :

```bash
# Une feuille par catégorie
python tool/import_decks.py livraison.csv --out assets/decks/animaux.json \
    --id animaux --name Animaux --audience family --min-age 6

# Une feuille unique avec une colonne « catégorie » : un fichier par catégorie
python tool/import_decks.py livraison.csv --out-dir assets/decks \
    --audience family --min-age 6

python -m unittest discover -s tool -t tool    # tests de l'import
```

Après toute modification d'une classe `@freezed`, `@riverpod` ou d'une table Drift, il faut
relancer `build_runner` — sinon la compilation échoue sur des fichiers `.g.dart` obsolètes.
Le code généré n'est pas versionné : après un clone ou un changement de branche, `build_runner`
avant tout le reste.

**Les versions de `freezed`, `json_serializable`, `riverpod_generator` et `drift_dev` sont
solidaires** — elles doivent tourner sur la même version d'`analyzer`. Ne jamais en monter une
seule : la résolution casse. Voir le bloc de commentaires des `dev_dependencies`.

## Conventions

- Lints : `very_good_analysis`. `flutter analyze` doit être vert avant tout commit.
- Nommage des fichiers en `snake_case`, un widget public par fichier.
- Les tests du domaine sont purs et rapides : pas de `WidgetTester`, pas de base, pas de mock
  de temps réel. Le temps est une dépendance injectée.
- Les textes affichés passent par l'ARB de `lib/l10n/`, jamais en dur dans un widget.

## Workflow git

Gitflow allégé. **Ne jamais committer directement sur `main` ni sur `develop`.**

| Branche | Rôle |
|---|---|
| `main` | Ce qui est publié sur les stores. N'avance que par PR depuis `develop`, et chaque avancée est taguée `vX.Y.Z`. Protégée. |
| `develop` | Branche d'intégration. C'est la base de départ et d'arrivée de tout travail courant. |
| `feature/*` | Une par unité de travail : `feature/lot-2-moteur`, `feature/lot-3-config`. Part de `develop`, y retourne par PR. |
| `hotfix/*` | Correction urgente en production. Part de `main`, et se merge dans `main` **et** `develop` — oublier le second fait réapparaître le bug à la release suivante. |

Commits en **Conventional Commits**, en français : `feat(engine): tirage équilibré du paquet`,
`fix(timer): pause à la mise en arrière-plan (R3.7)`. Portées usuelles : `engine`, `data`,
`ui`, `decks`, `ci`, `docs`. Un comportement par commit ; pas de commit fourre-tout de fin de
lot. Quand un commit implémente une règle, cite son numéro.

Cycle d'une unité de travail :

1. `git switch develop && git pull` puis `git switch -c feature/<nom>`.
2. Implémenter, avec les numéros de `RULES.md` dans les noms de test.
3. Lancer l'agent `flutter-reviewer` et traiter ses remarques avant d'ouvrir la PR.
4. `gh pr create --base develop`, en remplissant honnêtement la section
   *Ce que je n'ai pas fait* du template.
5. CI verte + revue propre → merge dans `develop`.
6. La remontée de `develop` vers `main` est un arbitrage humain, jamais automatique.

Le code généré (`*.g.dart`, `*.freezed.dart`) n'est pas versionné : après tout clone ou tout
changement de branche qui touche une classe générée, relancer `build_runner`.
