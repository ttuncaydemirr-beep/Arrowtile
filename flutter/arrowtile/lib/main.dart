// Arrowtile — main.dart: giriş noktası. Dikey yön kilidi, kenardan kenara (edge-to-edge) arayüz, kayıt + servisler.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  final AppController controller = await AppController.create();
  runApp(ArrowtileApp(controller: controller));
}
