import 'dart:math';

import 'package:cekoi/domain/entities/audience.dart';
import 'package:cekoi/domain/entities/card.dart';
import 'package:cekoi/domain/entities/difficulty.dart';
import 'package:cekoi/domain/entities/game_config.dart';

/// Ce qu'un vivier permet, à demande donnée (R6.2).
///
/// Une seule arithmétique pour deux appelants qui ne font pas le même travail :
/// l'écran de sélection, qui ne fait que compter des cartes éligibles, et le
/// tirage, qui a réellement tiré. Recalculer le comparatif dans les widgets
/// donnait trois implémentations d'une même règle, dont une seule était
/// testée — elles peuvent diverger sans que rien ne rougisse.
class PoolVerdict {
  const PoolVerdict({required this.available, required this.requested});

  /// Cartes réellement éligibles, doublons de R6.4 déduits.
  final int available;

  /// Ce que la configuration demandait.
  final int requested;

  /// Une partie ne démarre pas en dessous de 12 cartes (R6.2).
  bool get isPlayable => available >= GameConfig.minimumCardCount;

  /// Le vivier n'a pas permis d'honorer la demande.
  bool get isTruncated => available < requested;

  /// R6.2 : on joue avec ce qui existe, **et on le signale avant de démarrer**.
  ///
  /// Rien à annoncer quand la partie ne peut pas démarrer du tout : c'est le
  /// refus qu'il faut expliquer, pas la troncature.
  bool get mustWarnShortage => isPlayable && isTruncated;
}

/// Le paquet tiré pour une partie, et de quoi expliquer au joueur ce qui s'est
/// passé si le vivier n'a pas suffi (R6.2).
class DrawResult {
  const DrawResult({
    required this.cards,
    required this.requested,
    required this.available,
    this.tieBreakReserve = const [],
  });

  /// Le paquet, déjà mélangé : c'est l'ordre de la première manche.
  final List<Card> cards;

  /// Quelques cartes éligibles **écartées du paquet**, gardées pour le
  /// départage (R5.3). Les cartes jouées ont été vues trois fois et ne
  /// départageraient plus rien ; celles-ci sont neuves.
  ///
  /// Vide quand le vivier était trop juste : on se rabattra sur le paquet.
  final List<Card> tieBreakReserve;

  /// Ce que la configuration demandait.
  final int requested;

  /// Cartes réellement éligibles, après filtrage par mode et par difficulté
  /// puis dédoublonnage. C'est le chiffre à montrer dans l'avertissement.
  final int available;

  /// Le verdict porte sur le paquet **réellement obtenu**, pas sur le nombre
  /// de cartes éligibles : c'est la même chose ici, puisque le tirage prend
  /// tout ce qu'il peut, et c'est la propriété qui compte.
  PoolVerdict get verdict =>
      PoolVerdict(available: cards.length, requested: requested);

  /// Vrai quand le vivier n'a pas permis d'honorer la demande (R6.2).
  bool get isTruncated => verdict.isTruncated;

  /// Une partie ne démarre pas en dessous de 12 cartes (R6.2).
  bool get isPlayable => verdict.isPlayable;
}

/// Les cartes qu'un mode et un jeu de difficultés autorisent réellement à
/// tirer : filtrées (R7.1, R7.7), dédoublonnées sur le texte normalisé (R6.4),
/// et triées par identifiant.
///
/// Partagé entre le tirage et l'évaluation de disponibilité d'un profil
/// (R7.8) : un profil annoncé jouable dont le tirage ne trouverait pas ses
/// cartes serait un mensonge à l'écran. Une seule implémentation, donc.
List<Card> eligibleCards({
  required List<Card> pool,
  required Audience mode,
  Set<Difficulty>? allowedDifficulties,
  bool adultOnly = false,
}) {
  final allowed = allowedDifficulties ?? Difficulty.values.toSet();
  if (allowed.isEmpty) {
    throw ArgumentError.value(
      allowed,
      'allowedDifficulties',
      'Au moins une difficulté doit être autorisée',
    );
  }

  final drawable = mode.drawablePool(adultOnly: adultOnly);
  final filtered =
      pool
          .where((c) => drawable.contains(c.audience))
          .where((c) => allowed.contains(c.difficulty))
          .toList()
        // Tri par identifiant avant tout usage du hasard : sans lui, deux
        // ordres de vivier différents consommeraient la même suite aléatoire
        // sur des listes différentes.
        ..sort((a, b) => a.id.compareTo(b.id));

  final seen = <String>{};
  return [
    for (final card in filtered)
      if (seen.add(card.normalizedText)) card,
  ];
}

/// Tire le paquet d'une partie.
///
/// Déterministe à [random] donné, et **indifférent à l'ordre de [pool]** : le
/// vivier arrive d'une requête SQL dont l'ordre n'est pas garanti, or une
/// partie doit rester rejouable depuis sa seule graine.
///
/// L'ordre des opérations n'est pas négociable : filtrage par mode (R7.1) puis
/// par difficulté autorisée (R7.7), dédoublonnage (R6.4), et seulement ensuite
/// l'équilibrage (R6.3). Équilibrer avant de filtrer rendrait un paquet
/// incomplet dès qu'un profil restreint les difficultés.
DrawResult drawCards({
  required List<Card> pool,
  required int requested,
  required Audience mode,
  required Random random,
  Set<Difficulty>? allowedDifficulties,
  bool adultOnly = false,
}) {
  if (requested <= 0) {
    throw ArgumentError.value(
      requested,
      'requested',
      'Le nombre de cartes demandé doit être positif',
    );
  }

  final allowed = allowedDifficulties ?? Difficulty.values.toSet();
  final unique = eligibleCards(
    pool: pool,
    mode: mode,
    allowedDifficulties: allowed,
    adultOnly: adultOnly,
  );

  final target = min(requested, unique.length);
  final quotas = _quotas(target, allowed);

  final buckets = <Difficulty, List<Card>>{
    for (final difficulty in _ordered(allowed))
      difficulty: unique.where((c) => c.difficulty == difficulty).toList()
        ..shuffle(random),
  };

  final picked = <Card>[];
  final leftovers = <Card>[];
  for (final entry in buckets.entries) {
    final quota = min(quotas[entry.key]!, entry.value.length);
    picked.addAll(entry.value.take(quota));
    leftovers.addAll(entry.value.skip(quota));
  }

  // Une difficulté trop pauvre pour son quota est compensée par les autres :
  // R6.3 complète avec ce qui existe plutôt que de rendre un paquet court.
  if (picked.length < target) {
    leftovers.shuffle(random);
    picked.addAll(leftovers.take(target - picked.length));
  }

  picked.shuffle(random);

  // Le reliquat du vivier alimente le départage. Calculé après le mélange du
  // paquet pour ne pas décaler la suite aléatoire de ce dernier.
  final chosen = {for (final card in picked) card.id};
  final reserve = [
    for (final card in unique)
      if (!chosen.contains(card.id)) card,
  ]..shuffle(random);

  return DrawResult(
    cards: picked,
    requested: requested,
    available: unique.length,
    tieBreakReserve: reserve.take(tieBreakReserveSize).toList(),
  );
}

/// Nombre de cartes mises de côté pour le départage (R5.3).
///
/// « Répétée jusqu'à départage » : il en faut assez pour plusieurs manches de
/// départage successives, pas de quoi amputer le paquet pour autant.
const int tieBreakReserveSize = 8;

/// Les difficultés autorisées dans l'ordre de l'énumération.
///
/// Itérer directement sur le `Set` reçu ferait dépendre le tirage de son ordre
/// d'insertion, donc de la façon dont l'appelant a écrit son littéral.
List<Difficulty> _ordered(Set<Difficulty> allowed) =>
    Difficulty.values.where(allowed.contains).toList();

/// Répartit [total] cartes entre les difficultés autorisées selon la cible de
/// R6.3, renormalisée sur les seules difficultés retenues (R7.7).
///
/// Méthode du plus fort reste : les quotas somment exactement à [total], sans
/// quoi un paquet de 26 cartes en rendrait 25 ou 27.
Map<Difficulty, int> _quotas(int total, Set<Difficulty> allowed) {
  final difficulties = _ordered(allowed);
  final weightSum = difficulties.fold<double>(
    0,
    (sum, d) => sum + Difficulty.targetDistribution[d]!,
  );

  final exact = <Difficulty, double>{
    for (final d in difficulties)
      d: total * Difficulty.targetDistribution[d]! / weightSum,
  };
  final quotas = <Difficulty, int>{
    for (final d in difficulties) d: exact[d]!.floor(),
  };

  var remainder = total - quotas.values.fold<int>(0, (a, b) => a + b);
  final byLargestRemainder = [...difficulties]
    ..sort((a, b) {
      final byFraction = (exact[b]! - quotas[b]!).compareTo(
        exact[a]! - quotas[a]!,
      );
      // Départage stable : à reste égal, l'ordre de l'énumération tranche.
      return byFraction != 0 ? byFraction : a.index.compareTo(b.index);
    });

  for (var i = 0; remainder > 0; i++, remainder--) {
    final difficulty = byLargestRemainder[i % byLargestRemainder.length];
    quotas[difficulty] = quotas[difficulty]! + 1;
  }

  return quotas;
}
