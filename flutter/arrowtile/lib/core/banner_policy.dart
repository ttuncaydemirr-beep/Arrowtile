// Arrowtile — banner_policy.dart: banner yerleştirmelerinin uzaktan aç/kapa anahtarı + %50 kontrol grubu (1.2.1, docs/27). Saf Dart.
//
// Parametreler (Firebase Remote Config; yapılandırma/bağlantı yoksa koddaki varsayılanlar geçerlidir):
//   banner_menu_enabled (bool, true)   — ana menü banner'ı
//   banner_map_enabled  (bool, true)   — harita banner'ı
//   banner_holdout_pct  (int, 50)      — kontrol grubu yüzdesi (0..100): bu gruptakiler HİÇ banner görmez
// Grup kurulum başına SABİTTİR: ilk açılışta 0..99 arası rastgele bir kova üretilip kalıcı yazılır (SaveStore, `arrowtile.bb.v1`);
// kova < yüzde ise "holdout". Geçiş/ödüllü reklam kuralları bu sınıftan ETKİLENMEZ (yalnızca banner).
// Değerler oturum boyunca değişmez: Remote Config değerleri yalnızca açılışta etkinleştirilir (bkz. services/remote_flags_firebase.dart),
// böylece oyuncu menüdeyken yerleşim kaymaz.
import 'ads_rules.dart' show AdScreen;

/// Uzaktan ayar kaynağı (Firebase Remote Config ya da varsayılanlar). Eksik anahtarda [fallback] döner.
abstract class RemoteFlags {
  const RemoteFlags();
  bool getBool(String key, bool fallback);
  int getInt(String key, int fallback);

  /// Tanılama için: 'default' (Firebase yok / değer gelmedi) | 'remote' (Remote Config etkin değer verdi) | 'static'.
  String get source;
}

/// Koddaki varsayılanlar (Firebase yapılandırması yoksa, CI/debug, testler).
class DefaultRemoteFlags extends RemoteFlags {
  const DefaultRemoteFlags();
  @override
  bool getBool(String key, bool fallback) => fallback;
  @override
  int getInt(String key, int fallback) => fallback;
  @override
  String get source => 'default';
}

/// Testler / sabit değerler için.
class StaticRemoteFlags extends RemoteFlags {
  final Map<String, Object> values;
  const StaticRemoteFlags(this.values);
  @override
  bool getBool(String key, bool fallback) {
    final Object? v = values[key];
    return v is bool ? v : fallback;
  }

  @override
  int getInt(String key, int fallback) {
    final Object? v = values[key];
    return v is int ? v : fallback;
  }

  @override
  String get source => 'static';
}

const String kRcBannerMenu = 'banner_menu_enabled';
const String kRcBannerMap = 'banner_map_enabled';
const String kRcBannerHoldoutPct = 'banner_holdout_pct';

/// Koddaki varsayılanlar (docs/27 §A6).
const bool kDefaultBannerMenu = true;
const bool kDefaultBannerMap = true;
const int kDefaultBannerHoldoutPct = 50;

/// Remote Config `setDefaults` için (Firebase konsolunda parametre olmasa da aynı değerler).
const Map<String, Object> kRemoteDefaults = <String, Object>{
  kRcBannerMenu: kDefaultBannerMenu,
  kRcBannerMap: kDefaultBannerMap,
  kRcBannerHoldoutPct: kDefaultBannerHoldoutPct,
};

class BannerPolicy {
  final bool menuEnabled;
  final bool mapEnabled;

  /// 0..100 (kırpılmış).
  final int holdoutPct;

  /// Kurulum kovası 0..99.
  final int bucket;

  /// Ayarların kaynağı (tanılama): default | remote | static.
  final String source;

  const BannerPolicy({
    required this.menuEnabled,
    required this.mapEnabled,
    required this.holdoutPct,
    required this.bucket,
    this.source = 'default',
  });

  /// Kısıt yok (tüm yerleştirmeler açık, kontrol grubu yok). [Monetization] varsayılanı; testler.
  static const BannerPolicy allOn = BannerPolicy(menuEnabled: true, mapEnabled: true, holdoutPct: 0, bucket: 99, source: 'static');

  factory BannerPolicy.from(RemoteFlags f, int bucket) {
    int pct = kDefaultBannerHoldoutPct;
    try {
      pct = f.getInt(kRcBannerHoldoutPct, kDefaultBannerHoldoutPct);
    } catch (_) {}
    bool menu = kDefaultBannerMenu, map = kDefaultBannerMap;
    try {
      menu = f.getBool(kRcBannerMenu, kDefaultBannerMenu);
      map = f.getBool(kRcBannerMap, kDefaultBannerMap);
    } catch (_) {}
    return BannerPolicy(
      menuEnabled: menu,
      mapEnabled: map,
      holdoutPct: pct.clamp(0, 100).toInt(),
      bucket: bucket.clamp(0, 99).toInt(),
      source: f.source,
    );
  }

  /// Kontrol grubunda mı (hiç banner görmez)?
  bool get holdout => bucket < holdoutPct;

  /// Analiz kullanıcı özelliği `banner_group`: holdout | banner.
  String get group => holdout ? 'holdout' : 'banner';

  /// Bu yerleştirmede banner'a izin var mı (kontrol grubu + uzaktan anahtar)? Reklamsız satın alma ayrıca bakılır.
  bool allows(AdScreen s) {
    if (holdout) return false;
    switch (s) {
      case AdScreen.menu:
        return menuEnabled;
      case AdScreen.map:
        return mapEnabled;
      default:
        return false;
    }
  }

  /// Tanılama ekranı satırı.
  Map<String, Object?> toDiag() => <String, Object?>{
        'banner_group': group,
        'banner_bucket': bucket,
        'banner_holdout_pct': holdoutPct,
        'banner_menu': menuEnabled,
        'banner_map': mapEnabled,
        'banner_cfg': source,
      };
}
