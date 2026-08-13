import 'package:cekoi/services/purchases/purchase_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'purchases.g.dart';

/// Interrupteur de compilation de l'achat in-app.
///
/// ```bash
/// flutter run --dart-define=CEKOI_PURCHASES=false
/// ```
///
/// Vrai par défaut, comme la publicité : c'est l'application livrée qui doit
/// être juste sans drapeau. L'éteindre évite qu'un émulateur sans services de
/// facturation fasse échouer chaque ouverture des réglages.
const bool purchasesEnabled = bool.fromEnvironment(
  'CEKOI_PURCHASES',
  defaultValue: true,
);

@Riverpod(keepAlive: true)
PurchaseService purchaseService(Ref ref) =>
    purchasesEnabled ? StorePurchaseService() : const NoPurchaseService();
