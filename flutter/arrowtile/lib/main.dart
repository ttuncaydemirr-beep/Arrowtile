// Arrowtile — main.dart: giriş noktası. Dikey yön kilidi, kenardan kenara (edge-to-edge) arayüz, kayıt + servisler.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/telemetry.dart';
import 'services/firebase_telemetry.dart';
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
  // Firebase Analytics + Crashlytics (docs/19): yapılandırma (google-services.json) yoksa ya da başlatma başarısızsa
  // NoopTelemetry kullanılır, çökme kancaları takılmaz ve uygulama normal çalışır.
  Telemetry telemetry = const NoopTelemetry();
  try {
    final FirebaseTelemetry fb = FirebaseTelemetry();
    if (await fb.init()) {
      telemetry = fb;
      installCrashHandlers(fb);
    }
  } catch (_) {}
  final AppController controller = await AppController.create(telemetry: telemetry);
  runApp(ArrowtileApp(controller: controller));
}
