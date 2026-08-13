import 'package:cekoi/data/providers.dart';
import 'package:cekoi/data/repositories/preferences_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preferences.g.dart';

/// Les réglages de l'appareil, lus une fois et gardés à jour à l'écriture.
///
/// Dans `app/` parce que deux features s'en servent : les réglages les
/// modifient, le jeu les applique. Ce qui est partagé entre deux features
/// remonte, et une feature n'en importe jamais une autre.
@Riverpod(keepAlive: true)
class AppPreferencesController extends _$AppPreferencesController {
  @override
  Future<AppPreferences> build() =>
      ref.watch(preferencesRepositoryProvider).read();

  Future<void> setSound({required bool enabled}) =>
      _update((p) => p.copyWith(soundEnabled: enabled));

  Future<void> setHaptics({required bool enabled}) =>
      _update((p) => p.copyWith(hapticsEnabled: enabled));

  /// Attend la lecture, écrit, puis publie.
  ///
  /// **Attendre d'abord** : tant que la lecture en base n'a pas répondu, les
  /// interrupteurs affichent les valeurs par défaut, tout activé. Composer sur
  /// ce défaut ferait qu'un joueur ouvrant les réglages pendant l'ouverture de
  /// la base, coupant la vibration, réactiverait un son qu'il avait coupé la
  /// veille — silencieusement. La fenêtre est étroite, la base étant ouverte
  /// paresseusement, mais elle existe.
  ///
  /// Et publier en dernier : publier avant d'écrire ferait basculer
  /// l'interrupteur à l'écran alors que la base peut refuser, et le réglage
  /// reviendrait au lancement suivant sans que personne comprenne pourquoi.
  Future<void> _update(AppPreferences Function(AppPreferences) change) async {
    AppPreferences courant;
    try {
      courant = await future;
    } on Object {
      // Base illisible : on part du défaut, faute de mieux. Ce que le joueur
      // vient de demander vaut mieux que rien.
      courant = AppPreferences.defaults;
    }

    final suivant = change(courant);

    await ref.read(preferencesRepositoryProvider).write(suivant);
    state = AsyncValue<AppPreferences>.data(suivant);
  }
}

/// Les réglages tels qu'ils sont connus à cet instant.
///
/// Le défaut — tout activé — s'applique tant que la lecture n'a pas répondu.
/// C'est le bon sens de l'erreur : le bip des dix dernières secondes est une
/// information de jeu, mieux vaut l'entendre une fois de trop que le rater.
@Riverpod(keepAlive: true)
AppPreferences currentPreferences(Ref ref) =>
    ref.watch(appPreferencesControllerProvider).value ??
    AppPreferences.defaults;
