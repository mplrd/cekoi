import 'package:cekoi/domain/entities/deck.dart';
import 'package:meta/meta.dart';

/// Ce que le joueur possède (`MONETISATION.md`).
///
/// Deux façons d'ouvrir une catégorie premium, et elles ne se valent pas :
/// une vidéo récompensée ouvre **une** catégorie, définitivement ; l'achat de
/// la version complète les ouvre **toutes** et éteint la publicité.
///
/// Une valeur, dans le domaine, parce que la question « cette catégorie est-
/// elle jouable » se pose à chaque écran de sélection et à chaque tirage : la
/// faire dépendre d'un magasin ou d'un réseau la rendrait asynchrone partout,
/// alors que le jeu se joue hors ligne.
@immutable
class Ownership {
  const Ownership({
    this.hasFullVersion = false,
    this.unlockedDeckIds = const {},
  });

  /// Un joueur qui n'a rien acheté ni rien débloqué.
  static const Ownership none = Ownership();

  /// Le SKU unique et non consommable de `MONETISATION.md`.
  final bool hasFullVersion;

  /// Les catégories ouvertes par une vidéo récompensée.
  ///
  /// Le déblocage est **définitif** : une récompense qui expire est perçue
  /// comme une arnaque, et détruit la confiance sur ce type d'application.
  final Set<String> unlockedDeckIds;

  /// Vrai si [deck] peut être sélectionnée et tirée.
  bool allows(Deck deck) =>
      !deck.isPremium || hasFullVersion || unlockedDeckIds.contains(deck.id);

  /// Vrai si l'application a encore le droit de montrer une publicité.
  ///
  /// Acheter la version complète éteint **tout** : l'interstitiel de lancement
  /// comme les boutons « Débloquer ». Regarder une vidéo récompensée, non —
  /// ça n'achète rien.
  bool get showsAds => !hasFullVersion;

  /// Vrai s'il y a lieu de proposer un déblocage pour [deck].
  ///
  /// Faux dès que la catégorie est ouverte, par achat ou par récompense : un
  /// bouton « Débloquer » sous une catégorie déjà accessible est au mieux du
  /// bruit, au pire une proposition de payer deux fois.
  bool canUnlock(Deck deck) => deck.isPremium && !allows(deck);

  // Égalité de valeur écrite à la main plutôt qu'avec `SetEquality` : le
  // domaine ne déclare pas `collection` en dépendance directe, et deux lignes
  // ne valent pas d'en ajouter une.
  @override
  bool operator ==(Object other) =>
      other is Ownership &&
      other.hasFullVersion == hasFullVersion &&
      other.unlockedDeckIds.length == unlockedDeckIds.length &&
      other.unlockedDeckIds.containsAll(unlockedDeckIds);

  @override
  int get hashCode =>
      Object.hash(hasFullVersion, Object.hashAllUnordered(unlockedDeckIds));

  @override
  String toString() =>
      'Ownership(complète: $hasFullVersion, débloquées: $unlockedDeckIds)';
}
