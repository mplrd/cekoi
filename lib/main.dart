import 'dart:async';

import 'package:cekoi/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(lockPortrait());
  runApp(ProviderScope(child: CekoiApp()));
}

/// Le jeu ne tourne pas.
///
/// On se passe le téléphone à la verticale, autour d'une table : le paysage
/// n'apporte rien et casse les écrans — l'accueil y déborde de 268 px, ses
/// deux dernières entrées passant sous le bord. Le portrait à l'endroit
/// seulement : accepter le retourné ferait pivoter l'écran au moment même où
/// la carte change de main.
///
/// Le vrai verrou est déclaratif — `android:screenOrientation` dans le
/// manifeste, `UISupportedInterfaceOrientations` dans l'`Info.plist`. Celui-ci
/// le double côté Dart, pour les plateformes où le déclaratif ne s'applique
/// pas.
Future<void> lockPortrait() => SystemChrome.setPreferredOrientations(const [
  DeviceOrientation.portraitUp,
]);
