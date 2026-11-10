// Arrowtile — firebase_telemetry.dart: [Telemetry]'nin Firebase Analytics + Crashlytics uygulaması (docs/19).
// Başlatma SAVUNMACIDIR: Android'de `Firebase.initializeApp()` seçeneksiz çağrılır ve yapılandırmayı google-services.json'dan
// (derlemede Gradle eklentisi üretir) okur. Dosya yoksa (CI, fork, PR derlemeleri) ya da başlatma 5 sn'de bitmezse istisna/zaman
// aşımı yakalanır, [init] false döner ve uygulama analiz/çökme raporu olmadan normal çalışır. Gerçek anahtarlar depoda yoktur.
//  - Debug derlemede toplama KAPALI (`--dart-define=TELEMETRY_IN_DEBUG=true` ile cihazda denemek için açılabilir).
//  - Analytics toplaması onay bilinene dek KAPALI başlar; yalnızca [setConsent] analytics_storage'a izin verirse açılır.
//  - Her çağrı try/catch içindedir: telemetri hiçbir zaman oyunu bozmaz.
import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../core/consent_gate.dart' show TelemetryConsent;
import '../core/telemetry.dart';

class FirebaseTelemetry extends Telemetry {
  FirebaseTelemetry();

  static const bool _inDebug = bool.fromEnvironment('TELEMETRY_IN_DEBUG');

  /// Bu derlemede toplama yapılabilir mi (release/profile ya da açıkça istenen debug).
  static bool get collectionAllowed => !kDebugMode || _inDebug;

  FirebaseAnalytics? _fa;
  FirebaseCrashlytics? _fc;
  bool _ready = false;

  bool get ready => _ready;

  static void _log(String m) => debugPrint('TELEMETRY: $m');

  @override
  Future<bool> init() async {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
    } catch (e) {
      _log('Firebase başlatılamadı (yapılandırma yok ya da hata): ${e.runtimeType}');
      return false;
    }
    try {
      final FirebaseCrashlytics fc = FirebaseCrashlytics.instance;
      final FirebaseAnalytics fa = FirebaseAnalytics.instance;
      await fc.setCrashlyticsCollectionEnabled(collectionAllowed);
      await fa.setAnalyticsCollectionEnabled(false); // onay bilinene dek kapalı
      _fc = fc;
      _fa = fa;
      _ready = true;
      _log('init ok (toplama ${collectionAllowed ? 'açık' : 'kapalı: debug'})');
      return true;
    } catch (e) {
      _log('init hata: ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<void> setConsent(TelemetryConsent c) async {
    final FirebaseAnalytics? fa = _fa;
    if (!_ready || fa == null) return;
    try {
      await fa.setConsent(
        analyticsStorageConsentGranted: c.analyticsStorage,
        adStorageConsentGranted: c.adStorage,
        adUserDataConsentGranted: c.adUserData,
        adPersonalizationSignalsConsentGranted: c.adPersonalization,
      );
      await fa.setAnalyticsCollectionEnabled(c.analyticsStorage && collectionAllowed);
      _log('consent: $c');
    } catch (e) {
      _log('setConsent hata: ${e.runtimeType}');
    }
  }

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async {
    final FirebaseAnalytics? fa = _fa;
    if (!_ready || fa == null || !collectionAllowed) return;
    try {
      await fa.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  @override
  Future<void> logPurchase({required String productId, String? currency, double? value}) async {
    final FirebaseAnalytics? fa = _fa;
    if (!_ready || fa == null || !collectionAllowed) return;
    try {
      await fa.logPurchase(
        currency: currency,
        value: value,
        items: <AnalyticsEventItem>[AnalyticsEventItem(itemId: productId, itemName: productId, quantity: 1)],
      );
    } catch (_) {}
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    final FirebaseAnalytics? fa = _fa;
    if (!_ready || fa == null || !collectionAllowed) return;
    try {
      await fa.setUserProperty(name: name, value: value);
    } catch (_) {}
  }

  @override
  void recordFlutterFatal(FlutterErrorDetails details) {
    final FirebaseCrashlytics? fc = _fc;
    if (!_ready || fc == null) return;
    try {
      unawaited(fc.recordFlutterFatalError(details).catchError((Object _) {}));
    } catch (_) {}
  }

  @override
  void recordFatal(Object error, StackTrace stack) {
    final FirebaseCrashlytics? fc = _fc;
    if (!_ready || fc == null) return;
    try {
      unawaited(fc.recordError(error, stack, fatal: true).catchError((Object _) {}));
    } catch (_) {}
  }
}
