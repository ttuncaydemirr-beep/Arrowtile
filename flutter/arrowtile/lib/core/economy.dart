// Arrowtile — economy.dart: storage.js içindeki ekonomi, günlük ödül, bölüm bonusu, yardımcı harcama ve yedek kodu kuralları.
// Saf Dart; kalıcılık (SharedPreferences) ayrı katmandadır (services/save_store.dart). Kural kaynağı: docs/01 §6, docs/09.
import 'dart:convert';

import 'levelgen.dart';
import 'rng.dart';
import 'save_data.dart';

const List<int> kDailyRewards = <int>[20, 30, 40, 50, 60, 80, 150];
const int kHintPrice = 50; // v1.2: geri alma kaldırıldı, ipucu pahalandı
const int kAdCoins = kHintPrice; // v1.4: ödüllü reklam başına jeton (= bir ipucu fiyatı)
const int kMaxCoinAdsPerDay = 10; // v1.4: takvim günü başına en çok reklam-jeton hakkı
const Map<String, int> kTierBonus = <String, int>{'easy': 50, 'medium': 75, 'hard': 100, 'extreme': 200};
const Map<String, double> kTierMult = <String, double>{'easy': 1, 'medium': 1.5, 'hard': 2, 'extreme': 3};
const List<int> kStarBase = <int>[0, 10, 15, 20];
const Map<String, int> kThemePrice = <String, int>{'emaye': 0, 'lokum': 300, 'cini': 500, 'bakir': 750, 'gece': 1000};

String tierOfChapterId(int ch) => tierOf(ch);
String tierOfLevel(int id) => tierOf((id + 11) ~/ 12); // Math.ceil(id / 12)
int chapterBonusFor(int ch) => kTierBonus[tierOf(ch)]!;

/// Seviye jetonu: taban 10/15/20 (1/2/3 yıldız) × kademe çarpanı, JS Math.round (yarım yukarı).
int levelReward(int id, int stars) {
  final double v = kStarBase[stars] * kTierMult[tierOfLevel(id)]!;
  return (v + 0.5).floor(); // pozitif değerlerde JS Math.round ile aynı
}

// ---- tarih yardımcıları (cihazın yerel tarihi) ----
String ymd(DateTime d) {
  String two(int v) => v < 10 ? '0$v' : '$v';
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

int dayDiff(String a, String b) {
  final List<int> pa = a.split('-').map(int.parse).toList();
  final List<int> pb = b.split('-').map(int.parse).toList();
  return DateTime.utc(pb[0], pb[1], pb[2]).difference(DateTime.utc(pa[0], pa[1], pa[2])).inDays;
}

/// Günlük ödül durumu.
class DailyStatus {
  final bool canClaim;
  final int day; // 1..7
  final bool claimedToday;
  final bool streakLost;
  final bool clockBack;
  const DailyStatus({
    required this.canClaim,
    required this.day,
    this.claimedToday = false,
    this.streakLost = false,
    this.clockBack = false,
  });
}

DailyStatus dailyStatus(SaveData s, String today) {
  final DailyReward d = s.daily;
  if (d.lastDate == null) return const DailyStatus(canClaim: true, day: 1);
  final int diff = dayDiff(d.lastDate!, today);
  final int cur = d.streakDay == 0 ? 1 : d.streakDay; // JS: d.streakDay || 1
  if (diff < 0) return DailyStatus(canClaim: false, day: cur, clockBack: true);
  if (diff == 0) return DailyStatus(canClaim: false, day: cur, claimedToday: true);
  if (diff == 1) return DailyStatus(canClaim: true, day: (d.streakDay % 7) + 1);
  return DailyStatus(canClaim: true, day: 1, streakLost: d.streakDay > 0);
}

class ClaimResult {
  final int day;
  final int coins;
  final int hint;
  const ClaimResult(this.day, this.coins, this.hint);
}

/// Günlük ödülü al; alınamıyorsa null. (Kaydetme çağıranın işi.)
ClaimResult? claimDaily(SaveData s, String today) {
  final DailyStatus st = dailyStatus(s, today);
  if (!st.canClaim) return null;
  final int coins = kDailyRewards[st.day - 1];
  s.coins += coins;
  final int hint = st.day == 7 ? 1 : 0;
  s.freeHints += hint;
  s.daily = DailyReward(lastDate: today, streakDay: st.day);
  return ClaimResult(st.day, coins, hint);
}

class CompleteResult {
  final int coins;
  final bool newBest;
  final bool firstClear;
  final int bonus;
  final bool chapterDone;
  const CompleteResult(this.coins, this.newBest, this.firstClear, this.bonus, this.chapterDone);
}

/// Seviye bitirme: yıldız + jeton (ilk kez tam ödül, sonra yalnızca fark) + bölüm bonusu.
CompleteResult completeLevel(SaveData s, int id, int stars, bool relaxed) {
  final int prev = s.stars[id] ?? 0;
  int coins = stars > prev ? levelReward(id, stars) - levelReward(id, prev) : 0;
  if (relaxed) coins = coins ~/ 2; // G3: rahat modda jeton yarı (JS Math.floor; değer ≥ 0)
  final bool best = stars > prev;
  if (best) s.stars[id] = stars;
  s.coins += coins;
  if (id >= s.unlocked && id < kMaxLevel) s.unlocked = id + 1;
  final int ch = (id + 11) ~/ 12;
  int bonus = 0;
  bool chapterDone = false;
  if (!s.chapterBonus.contains(ch)) {
    bool all = true;
    for (int k = (ch - 1) * 12 + 1; k <= ch * 12; k++) {
      if ((s.stars[k] ?? 0) == 0) {
        all = false;
        break;
      }
    }
    if (all) {
      chapterDone = true;
      bonus = chapterBonusFor(ch);
      s.coins += bonus;
      s.chapterBonus.add(ch);
    }
  }
  return CompleteResult(coins, best && prev > 0, prev == 0, bonus, chapterDone);
}

int totalStars(SaveData s) {
  int n = 0;
  for (final int v in s.stars.values) {
    n += v;
  }
  return n;
}

/// İpucu harca: önce ücretsiz hak, sonra jeton. Yetmezse false.
bool spendHint(SaveData s) {
  if (s.freeHints > 0) {
    s.freeHints--;
    return true;
  }
  if (s.coins >= kHintPrice) {
    s.coins -= kHintPrice;
    return true;
  }
  return false;
}

void refundHint(SaveData s, bool wasFree) {
  if (wasFree) {
    s.freeHints++;
  } else {
    s.coins += kHintPrice;
  }
}

/// Bugün kalan reklam-jeton hakkı (0..[kMaxCoinAdsPerDay]). Saat geri alınırsa (kayıtlı gün bugünden sonra) sayaç sıfırlanmaz.
int coinAdsLeft(SaveData s, String today) {
  final AdsState a = s.ads;
  final String? d = a.coinDate;
  if (d != null && dayDiff(d, today) <= 0) {
    final int left = kMaxCoinAdsPerDay - a.coinCount;
    return left < 0 ? 0 : left;
  }
  return kMaxCoinAdsPerDay;
}

/// Ödüllü reklam izlendi: hak varsa [kAdCoins] jeton ekler ve sayacı işler; eklenen jetonu döndürür (hak yoksa 0).
/// Kaydetme çağıranın işidir.
int grantAdCoins(SaveData s, String today) {
  if (coinAdsLeft(s, today) <= 0) return 0;
  final AdsState a = s.ads;
  final String? d = a.coinDate;
  if (d != null && dayDiff(d, today) <= 0) {
    a.coinCount += 1;
  } else {
    a.coinDate = today;
    a.coinCount = 1;
  }
  final int c = s.coins + kAdCoins;
  s.coins = c > 1000000000 ? 1000000000 : c;
  return kAdCoins;
}

/// İlerlemeyi sıfırla: dil, satın alma durumu (ads.adFree/test) ve günlük reklam-jeton hakkı korunur.
SaveData resetProgress(SaveData old) {
  final SaveData n = SaveData.defaults(old.lang);
  n.ads.adFree = old.ads.adFree;
  n.ads.test = old.ads.test;
  n.ads.coinDate = old.ads.coinDate; // günlük reklam-jeton hakkı sıfırlamayla yenilenmez
  n.ads.coinCount = old.ads.coinCount;
  return n;
}

// ---- Yedek kodu (G6): "ARROWTILE1-<base64(JSON)>-<sağlama>" ----
// Dil ve satın alma durumu (ads) koda girmez: satın alma Play hesabına bağlıdır, kodla taşınamaz.
const String kCodePrefix = 'ARROWTILE1';

String fnvHex(String str) => fnv32(str).toRadixString(16).padLeft(8, '0');

String exportCode(SaveData s) {
  final Map<String, dynamic> o = s.toJson()
    ..remove('lang')
    ..remove('ads');
  final String body = base64Encode(utf8.encode(jsonEncode(o)));
  return '$kCodePrefix-$body-${fnvHex(body)}';
}

final RegExp _codeRe = RegExp(r'^ARROWTILE1-([A-Za-z0-9+/=]+)-([0-9a-f]{8})$');

/// Kodu çözer ve doğrular; geçersizse null. Geçerliyse onarılmış durum (henüz uygulanmamış).
SaveData? parseCode(String? code, String lang) {
  try {
    final RegExpMatch? m = _codeRe.firstMatch((code ?? '').replaceAll(RegExp(r'\s+'), ''));
    if (m == null || fnvHex(m.group(1)!) != m.group(2)) return null;
    final dynamic o = jsonDecode(utf8.decode(base64.decode(base64.normalize(m.group(1)!))));
    if (o is! Map) return null;
    return sanitize(o, lang);
  } catch (_) {
    return null;
  }
}

/// Yedek kodunu uygular: dil ve reklam/satın alma durumu mevcut kayıttan korunur. Geçersizse null.
SaveData? importCode(SaveData current, String code) {
  final SaveData? o = parseCode(code, current.lang);
  if (o == null) return null;
  o.lang = current.lang;
  o.ads = AdsState(
      since: current.ads.since,
      lastAt: current.ads.lastAt,
      adFree: current.ads.adFree,
      test: current.ads.test,
      coinDate: current.ads.coinDate,
      coinCount: current.ads.coinCount);
  return o;
}
