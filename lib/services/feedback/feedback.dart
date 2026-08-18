import 'dart:async';

import 'package:cekoi/services/feedback/game_feedback.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feedback.g.dart';

/// Le service de retour sensoriel de l'appareil.
///
/// `keepAlive` : le lecteur audio garde son asset décodé entre deux tours. Le
/// recréer à chaque écran ferait payer le décodage au premier tic, celui qui
/// annonce qu'il reste dix secondes — exactement celui qu'il ne faut pas
/// rater.
@Riverpod(keepAlive: true)
GameFeedback gameFeedback(Ref ref) {
  final feedback = DeviceGameFeedback();
  ref.onDispose(() => unawaited(feedback.dispose()));
  return feedback;
}
