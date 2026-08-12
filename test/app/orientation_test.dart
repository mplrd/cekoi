import 'package:cekoi/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le jeu se joue en portrait, et rien d'autre.
///
/// Ce test couvre exactement une chose : ce que [lockPortrait] demande. Deux
/// trous assumés — il ne relit pas le manifeste ni l'`Info.plist`, qui sont
/// pourtant le verrou qui compte, et il ne vérifie pas que `main()` appelle
/// bien la fonction : l'appeler ici démarrerait la vraie application, base de
/// données comprise.
void main() {
  testWidgets("l'application ne demande que le portrait à l'endroit", (
    tester,
  ) async {
    final appels = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        appels.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await lockPortrait();

    expect(appels, hasLength(1));
    expect(appels.single.method, 'SystemChrome.setPreferredOrientations');
    // Le retourné est exclu volontairement : l'écran pivoterait au moment où
    // le téléphone change de main.
    expect(appels.single.arguments, ['DeviceOrientation.portraitUp']);
  });
}
