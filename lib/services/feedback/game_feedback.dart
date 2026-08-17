import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

/// Les deux signaux sonores du jeu.
enum GameSound {
  /// Chacune des dix dernières secondes du tour.
  ///
  /// Discret : il informe le narrateur que la fin approche pendant qu'il
  /// regarde la carte, il ne l'alarme pas. On l'entend dix fois de suite.
  tick,

  /// La fin du tour au chrono (R3.6 bis).
  ///
  /// Franc, et d'un **autre timbre** que le tic : au milieu d'une table qui
  /// crie, deux sons de la même famille ne se distinguent pas.
  buzzer,
}

/// Ce que le joueur entend et sent pendant un tour.
///
/// Une interface, comme la pub et les achats : le jeu ne doit pas dépendre
/// d'un lecteur audio pour tourner, et un test ne doit pas avoir à en démarrer
/// un. Le son et la vibration sont deux gestes séparés parce que les deux
/// réglages le sont — ce service exécute, il ne consulte rien.
abstract interface class GameFeedback {
  Future<void> play(GameSound sound);

  Future<void> vibrate(GameSound sound);

  /// Libère le lecteur audio.
  Future<void> dispose();
}

/// L'implémentation réelle : un asset joué sur le canal média, et le service
/// de vibration de l'appareil.
///
/// **Ni `SystemSound.play` ni `HapticFeedback`.** Les deux passent par la
/// couche de retour tactile d'Android, que les réglages « sons des touches »
/// et « vibration au toucher » éteignent — ils le sont chez beaucoup de monde,
/// et le tic n'a jamais sonné sur ces appareils-là. Pire pour le buzzer :
/// `SystemSoundType.alert` est documenté par Flutter comme ignoré sur Android
/// **et** iOS, il ne pouvait donc rien produire du tout.
class DeviceGameFeedback implements GameFeedback {
  DeviceGameFeedback();

  /// Un seul lecteur : le tic et le buzzer sont séparés d'au moins une
  /// seconde, ils ne se chevauchent jamais.
  final AudioPlayer _player = AudioPlayer();

  /// `mixWithOthers` : une table qui joue a souvent de la musique. Prendre le
  /// focus audio la couperait à chacune des dix dernières secondes — le remède
  /// serait pire que le mal.
  static final AudioContext _contexte = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  bool _pret = false;

  @override
  Future<void> play(GameSound sound) => _jouer(switch (sound) {
    GameSound.tick => 'audio/tick.wav',
    GameSound.buzzer => 'audio/buzzer.wav',
  });

  @override
  Future<void> vibrate(GameSound sound) => _vibrer(switch (sound) {
    GameSound.tick => const [0, 18],
    // Deux impulsions, comme les deux coups du son : c'est le rythme qu'on
    // reconnaît avant le timbre, y compris dans la paume.
    GameSound.buzzer => const [0, 160, 80, 260],
  });

  @override
  Future<void> dispose() => _player.dispose();

  /// Joue un asset, et n'échoue jamais bruyamment.
  ///
  /// Un son qui ne sort pas est un désagrément ; une exception remontée depuis
  /// l'écouteur du chrono arrêterait le tour. Le premier appel configure le
  /// lecteur — le faire au démarrage de l'application coûterait une ouverture
  /// de session audio à des joueurs qui n'ont peut-être pas lancé de partie.
  Future<void> _jouer(String asset) async {
    try {
      if (!_pret) {
        await _player.setAudioContext(_contexte);
        await _player.setPlayerMode(PlayerMode.lowLatency);
        await _player.setReleaseMode(ReleaseMode.stop);
        _pret = true;
      }
      await _player.stop();
      await _player.play(AssetSource(asset));
    } on Object {
      // Rien. Le jeu continue sans son.
    }
  }

  Future<void> _vibrer(List<int> motif) async {
    try {
      if (!await Vibration.hasVibrator()) return;
      await Vibration.vibrate(pattern: motif);
    } on Object {
      // Idem : un appareil sans vibreur, ou qui refuse, ne bloque rien.
    }
  }
}

/// Le service qui ne fait rien.
///
/// Pour le banc de rendu et pour les tests qui ne vérifient pas le son : ni
/// canal de plateforme, ni session audio.
class SilentGameFeedback implements GameFeedback {
  const SilentGameFeedback();

  @override
  Future<void> play(GameSound sound) async {}

  @override
  Future<void> vibrate(GameSound sound) async {}

  @override
  Future<void> dispose() async {}
}
