// Arrowtile — save_store.dart: kayıt kalıcılığı (shared_preferences). Anahtar web ile aynı: arrowtile.save.v1.
// Her erişim try/catch; bozuk veride güvenli varsayılan. Oyun hiçbir zaman çökmez.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/levelgen.dart';
import '../core/models.dart';
import '../core/save_data.dart';

class SaveStore {
  static const String key = 'arrowtile.save.v1';
  static const String langKey = 'arrowtile.lang';
  static const String endlessKey = 'arrowtile.save.v1.endless';

  final SharedPreferences? _prefs;
  SaveStore._(this._prefs);

  static Future<SaveStore> open() async {
    try {
      return SaveStore._(await SharedPreferences.getInstance());
    } catch (_) {
      return SaveStore._(null); // kalıcılık yok: oyun yine de çalışır
    }
  }

  /// Kaydı yükler. [deviceLang] cihaz dilinden seçilen dil (desteklenmiyorsa 'en').
  SaveData load(String deviceLang) {
    dynamic raw;
    String? lang;
    try {
      final String? txt = _prefs?.getString(key);
      if (txt != null && txt.isNotEmpty) raw = jsonDecode(txt);
    } catch (_) {
      raw = null;
    }
    try {
      lang = _prefs?.getString(langKey);
    } catch (_) {
      lang = null;
    }
    final SaveData s = sanitize(raw, deviceLang);
    if (raw == null && lang != null && kLangs.contains(lang)) s.lang = lang; // sıfırlamadan sonra dil korunur
    return s;
  }

  void save(SaveData s) {
    final SharedPreferences? p = _prefs;
    if (p == null) return;
    try {
      p.setString(key, jsonEncode(s.toJson()));
      p.setString(langKey, s.lang);
    } catch (_) {}
  }

  void clearProgress() {
    try {
      _prefs?.remove(key);
    } catch (_) {}
  }

  // ---- sonsuz seviye önbelleği (en yüksek numaralı 6 seviye; üretici sürümü kGenVersion değişince geçersiz) ----
  Map<int, Level> loadEndless() {
    try {
      final String? txt = _prefs?.getString(endlessKey);
      if (txt == null) return <int, Level>{};
      final dynamic o = jsonDecode(txt);
      if (o is Map && o['v'] == kGenVersion && o['levels'] is Map) {
        final Map<int, Level> out = <int, Level>{};
        (o['levels'] as Map<dynamic, dynamic>).forEach((dynamic k, dynamic v) {
          final int? id = int.tryParse('$k');
          if (id != null && v is Map<String, dynamic>) out[id] = Level.fromJson(v);
        });
        return out;
      }
    } catch (_) {}
    return <int, Level>{};
  }

  void saveEndless(Map<int, Level> levels) {
    final SharedPreferences? p = _prefs;
    if (p == null) return;
    try {
      final List<int> ids = levels.keys.toList()..sort((int a, int b) => b.compareTo(a));
      final Map<String, dynamic> keep = <String, dynamic>{
        for (final int id in ids.take(6)) '$id': levels[id]!.toJson()
      };
      p.setString(endlessKey, jsonEncode(<String, dynamic>{'v': kGenVersion, 'levels': keep}));
    } catch (_) {}
  }
}
