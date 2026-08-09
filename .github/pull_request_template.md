## Ce que fait cette PR

<!-- En deux ou trois phrases. Le quoi et le pourquoi, pas le comment. -->

## Lot concerné

<!-- Numéro et nom du lot de docs/ROADMAP.md. -->

## Règles couvertes

<!-- Numéros de docs/RULES.md implémentés ou modifiés (R3.4, R4.1…), et les tests
     correspondants. Écrire « aucune » si la PR ne touche pas au gameplay. -->

## Ce que je n'ai pas fait

<!-- Cas limites laissés de côté, hypothèses prises sur une spec ambiguë, dette
     assumée. Cette section est la plus utile de la PR : une approximation
     annoncée coûte moins cher qu'une approximation découverte. -->

## Vérifications

- [ ] `flutter analyze` sans avertissement
- [ ] `flutter test` vert
- [ ] `dart run build_runner build --delete-conflicting-outputs` passé si une classe générée a changé
- [ ] `lib/domain/` n'importe toujours pas `package:flutter`
- [ ] Aucune chaîne affichable en dur — tout passe par les ARB de `lib/l10n/`
- [ ] Revue de l'agent `flutter-reviewer` passée et remarques traitées
