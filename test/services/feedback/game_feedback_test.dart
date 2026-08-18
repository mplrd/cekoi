import 'dart:io';

import 'package:cekoi/services/feedback/game_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

/// La somme des durées de vibration d'un motif.
///
/// Un motif alterne attente et vibration en commençant par l'attente : ce sont
/// donc les indices impairs qui vibrent.
int _dureeVibree(List<int> motif) {
  var total = 0;
  for (var i = 1; i < motif.length; i += 2) {
    total += motif[i];
  }
  return total;
}

void main() {
  group('les deux signaux ne se confondent pas', () {
    // Rien de tout ça n'est observable depuis un test d'écran : celui-ci
    // vérifie que l'écran demande « le buzzer », pas ce que le buzzer est.
    // Intervertir les deux fichiers, ou les deux motifs, laisserait toute la
    // suite au vert et rendrait la fin de tour indiscernable du décompte.

    test('chaque signal a son fichier', () {
      expect(assetOf(GameSound.tick), isNot(assetOf(GameSound.buzzer)));
      expect(assetOf(GameSound.tick), contains('tick'));
      expect(assetOf(GameSound.buzzer), contains('buzzer'));
    });

    test('le buzzer vibre plus longtemps, et en deux temps', () {
      final tic = vibrationPatternOf(GameSound.tick);
      final buzzer = vibrationPatternOf(GameSound.buzzer);

      expect(_dureeVibree(tic), lessThan(50), reason: 'le tic reste discret');
      expect(
        _dureeVibree(buzzer),
        greaterThan(5 * _dureeVibree(tic)),
        reason: 'un buzzer qui ressemble au décompte ne se remarque pas',
      );
      expect(
        buzzer.length,
        greaterThan(tic.length),
        reason: 'deux impulsions contre une : le rythme avant le timbre',
      );
    });
  });

  group('les sons sont réellement livrés avec l application', () {
    // Le service avale ses erreurs de lecture, et il le doit : une exception
    // depuis l'écouteur du chrono arrêterait le tour. La contrepartie est
    // qu'un chemin faux ne se signale nulle part — le jeu se tait, et c'est
    // exactement le défaut que cette couche a été écrite pour corriger.

    for (final sound in GameSound.values) {
      test('${sound.name} — le fichier existe', () {
        final chemin = 'assets/${assetOf(sound)}';
        expect(
          File(chemin).existsSync(),
          isTrue,
          reason: '$chemin est introuvable : le jeu se taira en silence',
        );
      });
    }

    test('le dossier est déclaré dans le pubspec', () {
      // Présent sur le disque ne veut pas dire embarqué dans le paquet.
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/audio/'),
        reason:
            "un asset non déclaré n'est pas livré, et la lecture échoue "
            'sur l appareil alors que tout est vert ici',
      );
    });
  });
}
