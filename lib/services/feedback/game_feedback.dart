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

/// L'asset de chaque signal, sous `assets/`.
///
/// Une fonction libre, et non une méthode privée : c'est le seul endroit du
/// service qui puisse se tromper en silence. Un fichier renommé, une lettre en
/// trop, et le jeu se tait — la lecture avale ses erreurs, et c'est voulu.
/// Sortie ici, la table se teste, et `game_feedback_test.dart` vérifie en plus
/// que les deux fichiers existent et sont déclarés dans le `pubspec.yaml`.
String assetOf(GameSound sound) => switch (sound) {
  GameSound.tick => 'audio/tick.wav',
  GameSound.buzzer => 'audio/buzzer.wav',
};

/// Le motif de vibration de chaque signal : attente, vibration, attente…
///
/// Sortie pour la même raison que [assetOf] : intervertir les deux motifs ne
/// casse rien de visible, et le buzzer perdrait sa distinction sans qu'on le
/// sache. Les deux impulsions du buzzer reprennent les deux coups de son
/// fichier — le rythme se reconnaît avant le timbre, y compris dans la paume.
List<int> vibrationPatternOf(GameSound sound) => switch (sound) {
  GameSound.tick => const [0, 18],
  GameSound.buzzer => const [0, 160, 80, 260],
};

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

  /// Le contexte audio, et l'arbitrage qu'il porte.
  ///
  /// `mixWithOthers` parce qu'une table qui joue a souvent de la musique :
  /// prendre le focus audio la couperait à chacune des dix dernières secondes,
  /// et le remède serait pire que le mal.
  ///
  /// **Conséquence assumée sur iOS** : `mixWithOthers` et `respectSilence`
  /// s'excluent — le paquet l'interdit par une assertion — et le premier
  /// impose la catégorie `playback`, qui sonne malgré le commutateur
  /// Silencieux. Un iPhone posé en silencieux sur une table de restaurant
  /// sonnera donc. C'est le mauvais côté d'un choix qui n'en a que deux, et le
  /// recours reste à sa place : le réglage *Son* de l'application, qui lui
  /// coupe tout. Sur Android la question ne se pose pas de la même façon —
  /// `AndroidUsageType.media` suit le volume média, ce qu'on attend d'un jeu.
  static final AudioContext _contexte = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  bool _pret = false;

  @override
  Future<void> play(GameSound sound) => _jouer(assetOf(sound));

  @override
  Future<void> vibrate(GameSound sound) => _vibrer(vibrationPatternOf(sound));

  @override
  Future<void> dispose() async {
    // Protégé comme les deux autres : sur une plateforme sans greffon, la
    // création native a échoué et sa libération échouera aussi. L'exception
    // partirait alors dans une zone sans propriétaire, `ref.onDispose` ne
    // l'attendant pas.
    try {
      await _player.dispose();
    } on Object {
      // Rien à libérer, rien à dire.
    }
  }

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
    } on Object catch (erreur) {
      // Le jeu continue sans son. En debug on le dit quand même : c'est ici
      // qu'atterrirait un asset introuvable, panne définitive et silencieuse.
      assert(() {
        // `print` et non un logueur : le projet n'en a pas, et cette ligne ne
        // vit que dans un build de debug — l'assertion est retirée en release.
        // ignore: avoid_print
        print('Cékoi : lecture de $asset impossible ($erreur)');
        return true;
      }(), '');
    }
  }

  Future<void> _vibrer(List<int> motif) async {
    try {
      // Ne demande rien au vibreur : le greffon répond sur la seule question
      // de savoir si l'appareil est physique. Le garde sert donc aux
      // émulateurs, pas aux téléphones sans moteur.
      if (!await Vibration.hasVibrator()) return;
      await Vibration.vibrate(pattern: motif);
    } on Object {
      // Un appareil qui refuse de vibrer ne bloque rien.
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
