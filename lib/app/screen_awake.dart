import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'screen_awake.g.dart';

/// Maintient l'écran allumé, ou le relâche.
typedef ScreenAwake = Future<void> Function({required bool enable});

/// Le maintien d'écran de l'application (`SPEC.md`, `ARCHITECTURE.md`).
///
/// En manche 3, le narrateur mime sans toucher l'écran. Avec une veille
/// système à 30 secondes et un tour à 90, l'écran s'éteint, le système émet
/// `paused`, et le tour se met en pause tout seul — il faut déverrouiller et
/// se retaper trois secondes de décompte, au milieu d'une partie.
///
/// Derrière un provider parce que c'est un appel natif : un test widget n'a
/// pas de canal de plateforme, et sans cette indirection le maintien d'écran
/// ne serait vérifiable par rien.
@Riverpod(keepAlive: true)
ScreenAwake screenAwake(Ref ref) => WakelockPlus.toggle;
