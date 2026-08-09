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
   est l'écran de lancement de partie. Voir `docs/MONETISATION.md`.
4. **Les cartes custom restent locales au device en v1.** Aucun partage, aucun upload. C'est
   ce qui nous exempte de la guideline Apple 1.2 sur le contenu généré par les utilisateurs.
5. **Le français est la langue de référence.** Le contenu des cartes est écrit en français et
   pensé pour un public francophone. L'i18n de l'interface est prévue, pas celle des cartes.

## Commandes

Le projet Flutter n'est pas encore scaffoldé. Une fois en place :

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed, riverpod, drift
flutter test                                                # tests domaine + widgets
flutter analyze
flutter run
```

Après toute modification d'une classe `@freezed`, `@riverpod` ou d'une table Drift, il faut
relancer `build_runner` — sinon la compilation échoue sur des fichiers `.g.dart` obsolètes.

## Conventions

- Lints : `very_good_analysis`. `flutter analyze` doit être vert avant tout commit.
- Nommage des fichiers en `snake_case`, un widget public par fichier.
- Les tests du domaine sont purs et rapides : pas de `WidgetTester`, pas de base, pas de mock
  de temps réel. Le temps est une dépendance injectée.
- Les textes affichés passent par l'ARB de `lib/l10n/`, jamais en dur dans un widget.
