import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'build_info.g.dart';

/// Ce qu'un binaire sait de lui-même.
///
/// Rien, par défaut, et c'est le problème qu'on corrige ici. Un APK ne porte
/// aucune trace du commit qui l'a produit : `versionName` vient de
/// `pubspec.yaml` et vaut `1.0.0` sur tous les builds depuis le premier.
/// Jusqu'ici, la seule façon de savoir ce qu'un téléphone exécutait était de
/// le brancher et de comparer une empreinte SHA-256 — praticable pour une
/// personne, intenable pour douze testeurs qui écrivent « ça plante ».
///
/// Les quatre valeurs sont injectées à la compilation par `tool/marque.py`,
/// qui est le chemin de livraison. Un build qui ne passe pas par là ne les a
/// pas et le **dit** : afficher une identité fausse serait pire que de ne pas
/// en afficher. Le `versionCode`, lui, est calculé par Gradle à partir du
/// nombre de commits, donc tout build Android en porte un, y compris ceux
/// qu'on tape à la main.
class BuildInfo {
  const BuildInfo({
    required this.version,
    required this.numero,
    required this.commit,
    required this.date,
  });

  /// Ce que déclare le binaire en train de s'exécuter.
  ///
  /// `String.fromEnvironment` est résolu à la compilation : hors du chemin de
  /// livraison, les quatre valeurs sont vides.
  static const ceBinaire = BuildInfo(
    version: String.fromEnvironment('CEKOI_VERSION'),
    numero: String.fromEnvironment('CEKOI_BUILD'),
    commit: String.fromEnvironment('CEKOI_COMMIT'),
    date: String.fromEnvironment('CEKOI_DATE'),
  );

  /// Le nom de version de `pubspec.yaml`, par exemple `1.0.0`.
  final String version;

  /// Le nombre de commits. C'est aussi ce que Gradle grave dans le
  /// `versionCode` du paquet — sauf s'il n'a pas pu compter, auquel cas il le
  /// crie au build. Les deux nombres se lisent côte à côte le jour où une mise
  /// à jour est refusée, donc autant dire d'où vient celui-ci.
  final String numero;

  /// L'empreinte courte du commit, suffixée `-sale` si l'arbre de travail
  /// portait des modifications non validées au moment du build. Un binaire
  /// construit sur un arbre sale n'est **pas** ce commit, et le taire ferait
  /// chercher un bug dans du code qui n'y était pas.
  final String commit;

  /// La date du build, en `AAAA-MM-JJ`. Volontairement brute : c'est une
  /// donnée technique qu'on recopie dans un signalement, pas une date qu'on
  /// lit. Une date localisée se prêterait à l'ambiguïté 08/09 selon le pays.
  final String date;

  /// Un binaire est identifié dès qu'il porte son commit. Les autres champs
  /// peuvent manquer sans que l'étiquette perde son sens.
  bool get identifie => commit.isNotEmpty;
}

/// L'identité du binaire, injectable pour les tests.
///
/// Un provider plutôt qu'un accès direct à [BuildInfo.ceBinaire] : les tests
/// tournent forcément hors du chemin de livraison, donc sur une identité vide.
/// Sans point d'injection, le cas « identifié » ne serait jamais exercé.
@Riverpod(keepAlive: true)
BuildInfo buildInfo(Ref ref) => BuildInfo.ceBinaire;
