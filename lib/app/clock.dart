import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

/// Une lecture de temps **monotone**, comptée depuis un instant arbitraire.
///
/// Seuls les écarts entre deux lectures ont un sens ; leur valeur absolue n'en
/// a aucune. C'est ce qui distingue cette source de l'horloge système : un
/// joueur qui change l'heure de son téléphone en plein tour ne doit pas faire
/// bondir le chrono, et un passage à l'heure d'hiver ne doit pas offrir une
/// heure de jeu.
typedef MonotonicClock = Duration Function();

/// La source de temps de l'application.
///
/// Isolée derrière un provider pour qu'un test puisse la piloter : le cas
/// limite 8 de `RULES.md` — arrière-plan à 1 s de la fin — se vérifie sinon en
/// attendant réellement une minute.
@Riverpod(keepAlive: true)
MonotonicClock monotonicClock(Ref ref) {
  final stopwatch = Stopwatch()..start();
  ref.onDispose(stopwatch.stop);
  return () => stopwatch.elapsed;
}

/// Fournit les graines d'aléatoire de l'application.
///
/// Le domaine n'a pas le droit de lire l'horloge ; la couche d'interface, si.
/// Vit dans `app/` et non chez `setup` : la configuration en a besoin pour
/// composer les équipes, le jeu pour retirer un paquet en rejouant — une
/// feature ne peut pas emprunter le provider d'une autre.
typedef SeedSource = int Function();

@Riverpod(keepAlive: true)
SeedSource seedSource(Ref ref) =>
    () => DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
