// Arrowtile — main.dart: giriş noktası. Telefonda dikey yön kilidi, kenardan kenara (edge-to-edge) arayüz, kayıt + servisler.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/banner_policy.dart';
import 'core/telemetry.dart';
import 'services/firebase_telemetry.dart';
import 'services/remote_flags_firebase.dart';
import 'state/app_controller.dart';
import 'ui/orientation_policy.dart';

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
  // 1.2.2 (docs/28): yön kilidi yalnızca telefonda (en kısa kenar < 600 dp); tablet/katlanabilir (açık) tüm yönler. Katlanma değişince
  // ArrowtileApp.didChangeMetrics yeniden değerlendirir.
  await applyOrientationPolicy(WidgetsBinding.instance.platformDispatcher.views.first);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // 1.2.2: Android 15+ kullanımdan kalkan setStatusBarColor/setNavigationBarColor API'lerini tetiklememek için çubuk RENKLERİ verilmez
  // (kenardan kenara çubuklar zaten saydam); yalnızca kontrast zorlamasını kapat. Simge parlaklığı ScreenScaffold'da tema ile verilir.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
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
