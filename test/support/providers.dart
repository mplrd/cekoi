import 'package:cekoi/app/screen_awake.dart';

/// Un maintien d'écran inoffensif, pour les tests widget.
///
/// L'implémentation réelle passe par un canal de plateforme, absent du binding
/// de test : sans cette substitution, tout écran qui monte `PlayController`
/// échoue sur une `MissingPluginException` sans rapport avec ce qu'il teste.
///
/// [onCall] permet d'observer les ordres reçus quand c'est le maintien
/// d'écran lui-même qu'on vérifie.
ScreenAwake fakeScreenAwake([void Function({required bool enable})? onCall]) =>
    ({required enable}) async => onCall?.call(enable: enable);
