// Arrowtile — save_data.dart: storage.js'teki kayıt şeması (anahtar arrowtile.save.v1) ve sanitize() onarımı.
// Şema web ile birebir aynıdır; böylece "Dışa aktar" kodu iki sürüm arasında taşınabilir.
// Bozuk/eksik alanlar tek tek onarılır; oyun hiçbir zaman çökmez.
import 'daily.dart';

const List<String> kLangs = <String>['tr', 'en', 'de', 'ar'];
const List<String> kThemeIds = <String>['emaye', 'lokum', 'cini', 'bakir', 'gece'];
const int kMaxLevel = 99999; // sonsuz devam: kayıtta kabul edilen en büyük seviye no
const int kMaxChapters = 8334; // Math.ceil(99999 / 12)
const int kUndoRefund = 20; // eski ücretsiz geri alma hakkı başına jeton (kayıt göçü)

final RegExp _ymdRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _tipRe = RegExp(r'^[a-z_]{1,24}$');

class AdsState {
  int since;
  int lastAt;
  bool adFree;
  bool test;
  String? coinDate; // v1.4: reklam izleyerek jeton — son kullanım günü (yerel yyyy-aa-gg)
  int coinCount; // o gün kullanılan hak sayısı (günde en çok kMaxCoinAdsPerDay)
  AdsState({this.since = 0, this.lastAt = 0, this.adFree = false, this.test = false, this.coinDate, this.coinCount = 0});
  Map<String, dynamic> toJson() => <String, dynamic>{
        'since': since,
        'lastAt': lastAt,
        'adFree': adFree,
        'test': test,
        'coinDate': coinDate,
        'coinCount': coinCount,
      };
}

class DailyReward {
  String? lastDate;
  int streakDay;
  DailyReward({this.lastDate, this.streakDay = 0});
  Map<String, dynamic> toJson() => <String, dynamic>{'lastDate': lastDate, 'streakDay': streakDay};
}

class SaveData {
  String lang;
  bool sound;
  bool vibration;
  int coins;
  int freeHints;
  Map<int, int> stars;
  int unlocked;
  List<String> themesOwned;
  String theme;
  DailyReward daily;
  List<int> tutorialDone;
  List<int> chapterBonus;
  AdsState ads;
  String appearance; // auto | light | dark
  bool relaxed;
  bool aim;
  List<String> tips;
  DailyProgress dp;

  SaveData({
    required this.lang,
    this.sound = true,
    this.vibration = true,
    this.coins = 50,
    this.freeHints = 2,
    Map<int, int>? stars,
    this.unlocked = 1,
    List<String>? themesOwned,
    this.theme = 'emaye',
    DailyReward? daily,
    List<int>? tutorialDone,
    List<int>? chapterBonus,
    AdsState? ads,
    this.appearance = 'auto',
    this.relaxed = false,
    this.aim = false,
    List<String>? tips,
    DailyProgress? dp,
  })  : stars = stars ?? <int, int>{},
        themesOwned = themesOwned ?? <String>['emaye'],
        daily = daily ?? DailyReward(),
        tutorialDone = tutorialDone ?? <int>[],
        chapterBonus = chapterBonus ?? <int>[],
        ads = ads ?? AdsState(),
        tips = tips ?? <String>[],
        dp = dp ?? DailyProgress();

  /// storage.js defaults(lang)
  factory SaveData.defaults(String lang) => SaveData(lang: kLangs.contains(lang) ? lang : 'en');

  /// JSON.stringify(state) ile aynı alan sırası; tamsayı anahtarlar (stars) artan sırada (JS nesne kuralı).
  Map<String, dynamic> toJson() {
    final List<int> ids = stars.keys.toList()..sort();
    return <String, dynamic>{
      'lang': lang,
      'sound': sound,
      'vibration': vibration,
      'coins': coins,
      'freeHints': freeHints,
      'stars': <String, int>{for (final int k in ids) '$k': stars[k]!},
      'unlocked': unlocked,
      'themesOwned': themesOwned,
      'theme': theme,
      'daily': daily.toJson(),
      'tutorialDone': tutorialDone,
      'chapterBonus': chapterBonus,
      'ads': ads.toJson(),
      'appearance': appearance,
      'relaxed': relaxed,
      'aim': aim,
      'tips': tips,
      'dp': dp.toJson(),
    };
  }
}

// ---- JS sayı dönüşümü (Number(v)) ve int() yardımcısı ----

/// JS'te eksik alan `undefined` (Number → NaN → varsayılan), `null` ise 0'dır.
/// Dart Map'te ikisi de null döndüğü için eksik anahtarı bu nöbetçi değerle ayırırız.
const Object _kUndefined = Object();
dynamic _field(Map<dynamic, dynamic> m, Object key) => m.containsKey(key) ? m[key] : _kUndefined;

/// JS `Number(v)`: null→0, bool→0/1, boş/boşluk dize→0, sayı dizesi→sayı, diğerleri NaN.
double _toNumber(dynamic v) {
  if (identical(v, _kUndefined)) return double.nan; // JS: Number(undefined) → NaN
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  if (v is String) {
    final String s = v.trim();
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? double.nan;
  }
  return double.nan;
}

/// storage.js int(v, d, min, max): Math.floor(Number(v)); sonlu değilse d; sınırlara kırpılır.
int jsInt(dynamic v, int d, [int? min, int? max]) {
  double f = _toNumber(v).floorToDouble();
  if (!f.isFinite) return d;
  if (min != null && f < min) return min;
  if (max != null && f > max) return max;
  if (f > 9.0e18) return 9000000000000000000;
  if (f < -9.0e18) return -9000000000000000000;
  return f.toInt();
}

bool _isMap(dynamic v) => v is Map;

/// Bozuk/eksik alanları tek tek onarır. [raw] jsonDecode çıktısı (ya da herhangi bir değer).
SaveData sanitize(dynamic raw, String defaultLang) {
  final SaveData d = SaveData.defaults(defaultLang);
  if (raw is! Map) return d;
  final Map<dynamic, dynamic> r = raw;
  final SaveData s = d;
  if (r['lang'] is String && kLangs.contains(r['lang'])) s.lang = r['lang'] as String;
  if (r['sound'] is bool) s.sound = r['sound'] as bool;
  if (r['vibration'] is bool) s.vibration = r['vibration'] as bool;
  s.coins = jsInt(_field(r, 'coins'), d.coins, 0, 1000000000);
  s.freeHints = jsInt(_field(r, 'freeHints'), d.freeHints, 0, 999);
  // v1.2 göçü: geri alma kaldırıldı; kalan ücretsiz geri alma hakları jetona çevrilir (hak başı 20).
  if (r.containsKey('freeUndos')) {
    final int c = s.coins + jsInt(_field(r, 'freeUndos'), 0, 0, 999) * kUndoRefund;
    s.coins = c > 1000000000 ? 1000000000 : c;
  }
  final dynamic st = r['stars'];
  if (st is Map) {
    st.forEach((dynamic k, dynamic val) {
      final int id = jsInt(k, 0, 0, kMaxLevel);
      final int v = jsInt(val, 0, 0, 3);
      if (id >= 1 && v >= 1) s.stars[id] = v;
    });
  } else if (st is List) {
    for (int i = 0; i < st.length; i++) {
      final int v = jsInt(st[i], 0, 0, 3);
      if (i >= 1 && v >= 1) s.stars[i] = v;
    }
  }
  s.unlocked = jsInt(_field(r, 'unlocked'), 1, 1, kMaxLevel);
  if (r['themesOwned'] is List) {
    s.themesOwned = <String>[
      for (final dynamic t in (r['themesOwned'] as List<dynamic>))
        if (t is String && kThemeIds.contains(t)) t
    ];
    if (!s.themesOwned.contains('emaye')) s.themesOwned.insert(0, 'emaye');
  }
  if (r['theme'] is String && s.themesOwned.contains(r['theme'])) s.theme = r['theme'] as String;
  final dynamic dl = r['daily'];
  if (_isMap(dl)) {
    final dynamic ld = (dl as Map<dynamic, dynamic>)['lastDate'];
    s.daily.lastDate = (ld is String && _ymdRe.hasMatch(ld)) ? ld : null;
    s.daily.streakDay = jsInt(_field(dl, 'streakDay'), 0, 0, 7);
  }
  final dynamic td = r['tutorialDone'];
  if (td is List) {
    s.tutorialDone = <int>[
      for (final dynamic x in td)
        if (_toNumber(x) >= 1 && _toNumber(x) <= 3 && _toNumber(x) == _toNumber(x).floorToDouble()) _toNumber(x).toInt()
    ];
  } else if (td == true) {
    s.tutorialDone = <int>[1, 2, 3];
  }
  final dynamic cb = r['chapterBonus'];
  if (cb is List) {
    // Not: JS tamsayı olmayan değerleri de tutar; burada yalnızca tamsayılar alınır (kayıt zaten tamsayı yazar).
    s.chapterBonus = <int>[
      for (final dynamic x in cb)
        if (_toNumber(x) >= 1 && _toNumber(x) <= kMaxChapters && _toNumber(x) == _toNumber(x).floorToDouble()) _toNumber(x).toInt()
    ];
  }
  final dynamic ad = r['ads'];
  if (_isMap(ad)) {
    final Map<dynamic, dynamic> a = ad as Map<dynamic, dynamic>;
    s.ads.since = jsInt(_field(a, 'since'), 0, 0, 1000);
    s.ads.lastAt = jsInt(_field(a, 'lastAt'), 0, 0, 8640000000000000);
    s.ads.adFree = a['adFree'] == true;
    s.ads.test = a['test'] == true;
    final dynamic cd = a['coinDate'];
    s.ads.coinDate = (cd is String && _ymdRe.hasMatch(cd)) ? cd : null;
    s.ads.coinCount = jsInt(_field(a, 'coinCount'), 0, 0, 1000);
  }
  if (r['appearance'] is String && <String>['auto', 'light', 'dark'].contains(r['appearance'])) {
    s.appearance = r['appearance'] as String;
  }
  if (r['relaxed'] is bool) s.relaxed = r['relaxed'] as bool;
  if (r['aim'] is bool) s.aim = r['aim'] as bool;
  final dynamic dpr = r['dp'];
  if (_isMap(dpr)) {
    final Map<dynamic, dynamic> p = dpr as Map<dynamic, dynamic>;
    final dynamic dn = p['done'];
    if (dn is Map) {
      final List<dynamic> keys = dn.keys.toList();
      final List<dynamic> tail = keys.length > 400 ? keys.sublist(keys.length - 400) : keys; // slice(-400)
      for (final dynamic k in tail) {
        final int v = jsInt(dn[k], 0, 0, 3);
        if (k is String && _ymdRe.hasMatch(k) && v >= 1) s.dp.done[k] = v;
      }
    }
    s.dp.streak = jsInt(_field(p, 'streak'), 0, 0, 100000);
    s.dp.best = jsInt(_field(p, 'best'), 0, 0, 100000);
    s.dp.trophies = jsInt(_field(p, 'trophies'), 0, 0, 100000);
    final dynamic last = p['last'];
    s.dp.last = (last is String && _ymdRe.hasMatch(last)) ? last : null;
  }
  if (r['tips'] is List) {
    final List<String> tips = <String>[
      for (final dynamic x in (r['tips'] as List<dynamic>))
        if (x is String && _tipRe.hasMatch(x)) x
    ];
    s.tips = tips.length > 20 ? tips.sublist(0, 20) : tips;
  }
  return s;
}
