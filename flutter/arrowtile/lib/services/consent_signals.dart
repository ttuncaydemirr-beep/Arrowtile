// Arrowtile — consent_signals.dart: UMP'nin yazdığı IABTCF_* tercihlerini okuyan küçük yerel köprü (MainActivity.kt).
// UMP, TCF dizgelerini uygulamanın VARSAYILAN SharedPreferences'ına yazar; Flutter'ın shared_preferences eklentisi başka bir
// dosyayı ("FlutterSharedPreferences") kullandığından oradan okunamaz. Köprü yoksa ya da hata verirse null döner
// (onay "alındı" ama amaçlar okunamadıysa analiz kapalı kalır: güvenli varsayılan).
import 'package:flutter/services.dart';

import '../core/consent_gate.dart';

class TcfSnapshot {
  final bool gdprApplies;
  final String? purposeConsents;
  const TcfSnapshot({required this.gdprApplies, this.purposeConsents});
}

class ConsentSignals {
  ConsentSignals._();
  static const MethodChannel _ch = MethodChannel('com.arrowtile.puzzle/consent');

  static Future<TcfSnapshot?> readTcf() async {
    try {
      final Map<Object?, Object?>? m = await _ch.invokeMapMethod<Object?, Object?>('tcf');
      if (m == null) return null;
      final Object? g = m['gdprApplies'];
      final Object? p = m['purposeConsents'];
      return TcfSnapshot(gdprApplies: g == 1 || g == '1' || g == true, purposeConsents: p is String && p.isNotEmpty ? p : null);
    } catch (_) {
      return null;
    }
  }

  /// UMP durum adından ([umpStatus]) Firebase onay sinyallerini üretir.
  static Future<TelemetryConsent> resolve(String umpStatus) async {
    TcfSnapshot? tcf;
    if (umpStatus == 'obtained') tcf = await readTcf();
    return deriveTelemetryConsent(
      umpStatus: umpStatus,
      gdprApplies: tcf?.gdprApplies ?? true, // okunamazsa GDPR varsay: amaçlar yoksa kapalı kalır
      purposeConsents: tcf?.purposeConsents,
    );
  }
}
