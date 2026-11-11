// Arrowtile — telemetry.dart: Firebase Analytics + Crashlytics'in TEK giriş noktası (docs/19).
// Uygulamanın geri kalanı Firebase'e hiç dokunmaz; yalnızca bu soyut sınıfı çağırır. Gerçek uygulaması
// services/firebase_telemetry.dart içindedir; yapılandırma (google-services.json) yoksa, başlatma başarısızsa, debug derlemede ve
// testlerde [NoopTelemetry] gibi davranır: oyun etkilenmez. Olay yardımcıları burada (saf Dart) olduğundan test edilir.
//
// Gizlilik kuralları: olay parametreleri yalnızca sayı ve SABİT sözcük kümelerinden gelir (seviye, kademe, yıldız, yerleşim adı…);
// serbest metin, kayıt kodu, e-posta, kullanıcı kimliği ASLA gönderilmez.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'consent_gate.dart' show TelemetryConsent;

abstract class Telemetry {
  const Telemetry();

  // ------------------------------------------------------------------ düşük düzey (uygulamalar bunu doldurur)
  /// Firebase'i başlatır. Başarılıysa true; yapılandırma yok / hata ise false (uygulama normal çalışır).
  Future<bool> init();

  /// Firebase Analytics onay sinyallerini uygular; analytics_storage kapalıysa toplama tümüyle durdurulur.
  Future<void> setConsent(TelemetryConsent c);

  Future<void> logEvent(String name, Map<String, Object> params);

  Future<void> logPurchase({required String productId, String? currency, double? value});

  Future<void> setUserProperty(String name, String? value);

  /// Flutter çerçevesi hatası (Crashlytics: ölümcül).
  void recordFlutterFatal(FlutterErrorDetails details);

  /// Yakalanmamış asenkron/platform hatası (Crashlytics: ölümcül).
  void recordFatal(Object error, StackTrace stack);

  // ------------------------------------------------------------------ olay yardımcıları (hepsi sessizdir, asla istisna fırlatmaz)
  void _log(String name, Map<String, Object> params) {
    try {
      unawaited(logEvent(name, params).catchError((Object _) {}));
    } catch (_) {}
  }

  static String _tier(String? diff) => (diff == null || diff.isEmpty) ? 'unknown' : diff;

  /// 1.2.0: tahta boyu parametresi ("28x45"; yalnızca rakam ve x — kişisel veri değil). Verilmezse alan yazılmaz.
  static Map<String, Object> _board(String? board, bool shaped) => <String, Object>{
        if (board != null && RegExp(r'^\d{1,2}x\d{1,2}$').hasMatch(board)) 'board': board,
        if (board != null) 'shaped': shaped ? 1 : 0,
      };

  /// Seviye (yeniden) başladı. [tier]: easy | medium | hard | extreme; [chapter]: bölüm numarası; [board]: tahta "GxY" (1.2.0).
  void levelStart({required int level, required String? tier, required int chapter, String? board, bool shaped = false}) =>
      _log('level_start', <String, Object>{'level': level, 'tier': _tier(tier), 'chapter': chapter, ..._board(board, shaped)});

  /// Seviye tamamlandı. [mistakes]: çarpışma sayısı; [hintsUsed]: bu denemede kullanılan ipucu; [durationS]: saniye (0..3600).
  void levelComplete({
    required int level,
    required String? tier,
    required int stars,
    required int mistakes,
    required int hintsUsed,
    required int durationS,
    int? chapter,
    String? board,
    bool shaped = false,
  }) =>
      _log('level_complete', <String, Object>{
        'level': level,
        'tier': _tier(tier),
        'stars': stars,
        'mistakes': mistakes,
        'hints_used': hintsUsed,
        'duration_s': durationS.clamp(0, 3600).toInt(),
        if (chapter != null) 'chapter': chapter,
        ..._board(board, shaped),
      });

  /// Canlar bitti (seviye başarısız).
  void levelFail({required int level, required String? tier, int? chapter, String? board, bool shaped = false}) =>
      _log('level_fail', <String, Object>{'level': level, 'tier': _tier(tier), if (chapter != null) 'chapter': chapter, ..._board(board, shaped)});

  void hintUsed({required int level}) => _log('hint_used', <String, Object>{'level': level});

  void dailyPuzzleComplete({required int stars, required int mistakes, required int durationS}) =>
      _log('daily_puzzle_complete', <String, Object>{'stars': stars, 'mistakes': mistakes, 'duration_s': durationS.clamp(0, 3600).toInt()});

  /// [placement]: coins | life; [result]: rewarded | closed | unavailable.
  void rewardedAd({required String placement, required String result}) =>
      _log('rewarded_ad', <String, Object>{'placement': placement, 'result': result});

  /// [result]: shown | skipped | failed | blocked (geçersiz yerleştirme, show() çağrılmadı) | late_blocked (seviye sırasında geç reklam belirdi; docs/20).
  void interstitial({required String result}) => _log('interstitial', <String, Object>{'result': result});

  /// 1.1.4 (docs/21): tam ekran reklam aşaması + gecikme. Olay adı [format] (interstitial_stage | rewarded_stage);
  /// [stage]: show_called | showed | dismissed | failed_to_show | stuck | released | late_blocked; [latencyMs]: show() çağrısından beri (0..600000).
  void adStage({required String format, required String stage, required int latencyMs}) => _log(
      format == 'rewarded' ? 'rewarded_stage' : 'interstitial_stage',
      <String, Object>{'stage': stage, 'latency_ms': latencyMs.clamp(0, 600000).toInt()});

  /// 1.1.4: ses oyuncuları takıldı/bozuldu ve yeniden kuruldu. [reason]: timeout | error | stuck | health_ad_closed | health_resume.
  void audioDeadRecovered({required String reason}) => _log('audio_dead_recovered', <String, Object>{'reason': reason});

  /// 1.1.4: banner olayı. [result]: load | loaded | failed | impression | size_null | exception; [code]: AdMob hata kodu (-1 yoksa);
  /// [screen]: menu | map.
  void banner({required String result, int code = -1, required String screen}) =>
      _log('banner', <String, Object>{'result': result, 'code': code, 'screen': screen});

  /// 1.1.6: oyun alanı beklenenden çok küçük (ekranın <%60'ı, klavye yokken). [screenH]/[boardH]/[insetB]/[padB] tam sayı piksel, [scale] x100.
  void layoutShrunk({required int screenH, required int boardH, required int insetB, required int padB, required int scale}) =>
      _log('layout_shrunk', <String, Object>{'screen_h': screenH, 'board_h': boardH, 'inset_b': insetB, 'pad_b': padB, 'scale': scale});

  /// "Reklamları kaldır" satın alımı BAŞARIYLA tamamlandı (iptal/bekleyen/hata için çağrılmaz).
  void purchaseRemoveAds({String? currency, double? value}) {
    try {
      unawaited(logPurchase(productId: 'remove_ads', currency: currency, value: value).catchError((Object _) {}));
    } catch (_) {}
  }

  /// Tasarım için önemli ayar değişimi. [name]: relaxed_mode | aim_mode | appearance | arrow_theme; [value]: sabit sözcük.
  void settingChanged({required String name, required String value}) =>
      _log('setting_changed', <String, Object>{'name': name, 'value': value});

  /// Kullanıcı özelliği app_lang (tr | en | de | ar).
  void setLanguage(String lang) {
    try {
      unawaited(setUserProperty('app_lang', lang).catchError((Object _) {}));
    } catch (_) {}
  }
}

/// Hiçbir şey yapmaz: yapılandırma yokken, debug'da ve testlerde varsayılan.
class NoopTelemetry extends Telemetry {
  const NoopTelemetry();
  @override
  Future<bool> init() async => false;
  @override
  Future<void> setConsent(TelemetryConsent c) async {}
  @override
  Future<void> logEvent(String name, Map<String, Object> params) async {}
  @override
  Future<void> logPurchase({required String productId, String? currency, double? value}) async {}
  @override
  Future<void> setUserProperty(String name, String? value) async {}
  @override
  void recordFlutterFatal(FlutterErrorDetails details) {}
  @override
  void recordFatal(Object error, StackTrace stack) {}
}

/// Çökme raporlayıcıyı Flutter hata kancalarına bağlar (yalnızca başlatma başarılıysa çağrılır).
/// Önceki işleyici korunur: hata konsola/geliştirici araçlarına yine yazılır.
void installCrashHandlers(Telemetry t) {
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    try {
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    } catch (_) {}
    try {
      t.recordFlutterFatal(details);
    } catch (_) {}
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    try {
      t.recordFatal(error, stack);
    } catch (_) {}
    return true; // işlendi (uygulama bu hatayla kapanmaz; Flutter varsayılanı da zaten yalnızca günlüğe yazar)
  };
}
