import 'package:freezed_annotation/freezed_annotation.dart';

part 'consent.freezed.dart';

/// Ce que l'application a besoin de savoir du consentement publicitaire.
///
/// Deux booléens, et rien du vocabulaire de l'UMP — obtenu, requis, inconnu,
/// hors zone réglementée. Ce détail n'intéresse que la passerelle. Ce qui
/// compte au-dessus est d'une part le droit de demander une pub, d'autre part
/// la présence d'une entrée « modifier mon choix » dans les réglages.
@freezed
abstract class ConsentState with _$ConsentState {
  const factory ConsentState({
    /// Le SDK a le droit de demander une pub.
    @Default(false) bool canRequestAds,

    /// Un formulaire de modification existe pour cet appareil, et les réglages
    /// doivent l'exposer.
    @Default(false) bool canChangeChoice,
  }) = _ConsentState;

  /// Aucune pub, aucun choix à proposer.
  ///
  /// C'est l'état d'un build sans publicité, et celui d'un CMP en panne.
  static const ConsentState none = ConsentState();
}

/// L'accès au consentement publicitaire (`MONETISATION.md`).
///
/// Derrière une interface pour deux raisons. Aucune feature ne doit connaître
/// `google_mobile_ads` — c'est la règle d'isolation du lot 7. Et un test n'a
/// pas de canal de plateforme pour répondre à un formulaire natif : sans cette
/// indirection, l'ordre « consentement d'abord, SDK ensuite » ne serait
/// vérifiable par rien, alors que c'est justement l'obligation légale.
abstract interface class ConsentGateway {
  /// Met l'information à jour et présente le formulaire si la zone l'exige.
  ///
  /// Appelée une fois au lancement, **avant toute requête publicitaire**.
  Future<ConsentState> gather();

  /// Rouvre le formulaire depuis les réglages.
  ///
  /// Le choix doit rester modifiable à tout moment : c'est une exigence
  /// légale et un motif de rejet côté stores, pas un confort.
  Future<ConsentState> changeChoice();
}

/// La passerelle des builds sans publicité (`--dart-define=CEKOI_ADS=false`).
///
/// Elle ne demande rien et ne montre rien : personne ne veut répondre à un
/// formulaire de consentement à chaque itération de développement.
class NoConsentGateway implements ConsentGateway {
  const NoConsentGateway();

  @override
  Future<ConsentState> gather() async => ConsentState.none;

  @override
  Future<ConsentState> changeChoice() async => ConsentState.none;
}
