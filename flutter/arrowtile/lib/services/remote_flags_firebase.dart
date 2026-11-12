// Arrowtile — remote_flags_firebase.dart: [RemoteFlags]'in Firebase Remote Config uygulaması (1.2.1, docs/27).
// YALNIZCA Firebase başarıyla başlatıldıysa kullanılır (main.dart; google-services.json yoksa hiç çağrılmaz → koddaki varsayılanlar).
// Akış (oturum içinde yerleşim kaymasın diye):
//   1) setDefaults(kRemoteDefaults) + activate(): ÖNCEKİ açılışta indirilmiş değerler (yerel, hızlı) bu oturumda geçerli olur.
//   2) fetch() arka planda: yeni değerler indirilir, BİR SONRAKİ açılışta etkinleşir. Bu oturumda hiçbir değer değişmez.
// Her adım try/catch + zaman sınırı; hata/zaman aşımında varsayılanlar. Konsolda parametre hiç tanımlanmamışsa da varsayılanlar geçerlidir.
import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../core/banner_policy.dart';

class FirebaseRemoteFlags extends RemoteFlags {
  final FirebaseRemoteConfig? _rc;
  FirebaseRemoteFlags._(this._rc);

  static void _log(String m) => debugPrint('REMOTE_CONFIG: $m');

  /// Varsayılanları kurar, önceki indirilen değerleri etkinleştirir, arka planda yenilerini indirir. Asla istisna fırlatmaz.
  static Future<RemoteFlags> load() async {
    try {
      final FirebaseRemoteConfig rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kReleaseMode ? const Duration(hours: 12) : const Duration(minutes: 5),
      )).timeout(const Duration(seconds: 2));
      await rc.setDefaults(kRemoteDefaults).timeout(const Duration(seconds: 2));
      try {
        await rc.activate().timeout(const Duration(seconds: 2));
      } catch (e) {
        _log('activate hata: ${e.runtimeType}');
      }
      // bir sonraki açılış için (bu oturumu etkilemez)
      unawaited(rc.fetch().timeout(const Duration(seconds: 15)).catchError((Object e) => _log('fetch hata: ${e.runtimeType}')));
      _log('ok');
      return FirebaseRemoteFlags._(rc);
    } catch (e) {
      _log('kullanılamıyor, varsayılanlar: ${e.runtimeType}');
      return const DefaultRemoteFlags();
    }
  }

  bool _remote(String key) {
    try {
      return _rc?.getValue(key).source == ValueSource.valueRemote;
    } catch (_) {
      return false;
    }
  }

  @override
  bool getBool(String key, bool fallback) {
    try {
      final RemoteConfigValue? v = _rc?.getValue(key);
      if (v == null || v.source == ValueSource.valueStatic) return fallback;
      return v.asBool();
    } catch (_) {
      return fallback;
    }
  }

  @override
  int getInt(String key, int fallback) {
    try {
      final RemoteConfigValue? v = _rc?.getValue(key);
      if (v == null || v.source == ValueSource.valueStatic) return fallback;
      return v.asInt();
    } catch (_) {
      return fallback;
    }
  }

  @override
  String get source => (_remote(kRcBannerMenu) || _remote(kRcBannerMap) || _remote(kRcBannerHoldoutPct)) ? 'remote' : 'default';
}
