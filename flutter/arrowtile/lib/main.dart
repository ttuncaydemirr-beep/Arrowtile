// Arrowtile — main.dart: giriş noktası. Dikey yön kilidi, kenardan kenara (edge-to-edge) arayüz, kayıt + servisler.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/banner_policy.dart';
import 'core/telemetry.dart';
import 'services/firebase_telemetry.dart';
import 'services/remote_flags_firebase.dart';
import 'state/app_controller.dart';

/// 1.2.0: Readex Pro (SIL OFL 1.1) lisansı Flutter lisans kaydına eklenir (Ayarlar → Açık kaynak lisansları).
void registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final String ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(<String>['Readex Pro (font)'], ofl);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicense();
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
  // 1.2.1 (docs/27): banner aç/kapa + kontrol grubu yüzdesi. Firebase yoksa koddaki varsayılanlar (menü/harita açık, %50 kontrol grubu).
  RemoteFlags remote = const DefaultRemoteFlags();
  try {
    final FirebaseTelemetry fb = FirebaseTelemetry();
    if (await fb.init()) {
      telemetry = fb;
      installCrashHandlers(fb);
      remote = await FirebaseRemoteFlags.load();
    }
  } catch (_) {}
  final AppController controller = await AppController.create(telemetry: telemetry, remote: remote);
  runApp(ArrowtileApp(controller: controller));
}
