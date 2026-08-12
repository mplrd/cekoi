import 'dart:async';

import 'package:cekoi/services/ads/ad_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// La moitié que `Future.timeout` ne fait pas.
///
/// Il rend la main au bout du délai, mais laisse le futur d'origine vivre :
/// une pub arrivée en retard reste référencée par le SDK, jamais détruite. Une
/// fuite d'objet plein écran par lancement expiré.
void main() {
  test('une réponse dans les temps passe, sans être jetée', () async {
    final jetes = <String>[];

    final resultat = await awaitOrDiscard(
      Future<String?>.value('pub'),
      timeout: const Duration(seconds: 5),
      discard: jetes.add,
    );

    expect(resultat, 'pub');
    expect(jetes, isEmpty);
  });

  test('un retard rend null', () async {
    final resultat = await awaitOrDiscard(
      Completer<String?>().future,
      timeout: const Duration(milliseconds: 20),
      discard: (_) {},
    );

    expect(resultat, isNull);
  });

  test('ce qui arrive après le délai est détruit', () async {
    final tardif = Completer<String?>();
    final jetes = <String>[];

    final resultat = await awaitOrDiscard(
      tardif.future,
      timeout: const Duration(milliseconds: 20),
      discard: jetes.add,
    );
    expect(resultat, isNull);
    expect(jetes, isEmpty, reason: 'rien n est encore arrivé');

    tardif.complete('pub en retard');
    await Future<void>.delayed(Duration.zero);

    expect(
      jetes,
      ['pub en retard'],
      reason:
          'sans destruction, le SDK garde une pub plein écran référencée pour '
          'toute la durée de vie du processus',
    );
  });

  test('un retard qui échoue ne remonte pas en erreur non gérée', () async {
    final tardif = Completer<String?>();

    final resultat = await awaitOrDiscard(
      tardif.future,
      timeout: const Duration(milliseconds: 20),
      discard: (_) {},
    );
    expect(resultat, isNull);

    tardif.completeError(StateError('chargement impossible'));
    await Future<void>.delayed(Duration.zero);
    // Le test échouerait sur une erreur asynchrone non attrapée.
  });

  test('un null tardif ne déclenche pas de destruction', () async {
    final tardif = Completer<String?>();
    var appels = 0;

    await awaitOrDiscard(
      tardif.future,
      timeout: const Duration(milliseconds: 20),
      discard: (_) => appels++,
    );

    tardif.complete(null);
    await Future<void>.delayed(Duration.zero);

    expect(appels, 0);
  });
}
