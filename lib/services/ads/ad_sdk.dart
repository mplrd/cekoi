import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Démarre le SDK publicitaire.
///
/// N'est appelé qu'**après** une réponse au formulaire de consentement.
///
/// Un typedef et non une interface, comme `ScreenAwake` : le démarrage est un
/// seul appel natif, et ce qu'on veut de l'indirection est de pouvoir le
/// remplacer en test. Le chargement et l'affichage des formats arriveront avec
/// leurs emplacements, dans un `AdService` qui, lui, aura plusieurs méthodes.
typedef AdSdkStart = Future<void> Function();

/// Le SDK de Google, configuré pour une app qu'on sort en famille.
Future<void> startGoogleAdSdk() async {
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      // La note de contenu est plafonnée à PG (`MONETISATION.md`). Une pub
      // pour un jeu d'argent ou un film d'horreur au milieu d'une partie avec
      // des enfants autour de la table ne gêne pas un utilisateur, elle en
      // gêne six et fait désinstaller l'application.
      maxAdContentRating: MaxAdContentRating.pg,

      // Ni enfant, ni adolescent : l'audience déclarée est 13 ans et plus. Le
      // mode « En famille » veut dire jouable avec des enfants autour de la
      // table, pas destiné aux enfants — déclarer autre chose ferait basculer
      // l'app sous la politique Families et COPPA, avec un inventaire
      // publicitaire nettement plus pauvre.
      ageRestrictedTreatment: AgeRestrictedTreatment.unspecified,
    ),
  );

  await MobileAds.instance.initialize();
}

/// Le démarrage des builds sans publicité : il ne fait rien.
Future<void> startNoAdSdk() async {}
