// Arrowtile — daily.dart: daily.js'in Dart karşılığı. Günlük bulmaca (tarih tohumlu) + seri/kupa kuralları.
// Saf Dart. Haftanın gününe göre kademe (docs/09): Pzt–Çar Kolay, Per–Cum Orta, Cmt Zor, Paz Aşırı zor.
import 'levelgen.dart';
import 'models.dart';
import 'rng.dart';

/// Haftanın günü (Pzt=0 … Paz=6) → kademe.
const List<String> kDailyPlan = <String>['easy', 'easy', 'easy', 'medium', 'medium', 'hard', 'extreme'];
const int kDailyW = 12;
const int kDailyH = 16;

GenSpec dailySpecOf(String tier) {
  final Tier T = kTiers[tier]!;
  final bool extreme = tier == 'extreme';
  return GenSpec(
      w: kDailyW,
      h: kDailyH,
      fill: T.fill,
      fillMax: T.band[1],
      maxFree: T.maxFree,
      curve: T.curve,
      maxLen: 7,
      tries: 3,
      effort: extreme ? 40 : 24,
      passes: extreme ? 20 : 12,
      cycles: extreme ? 6 : 4);
}

DateTime _parse(String ymd) {
  final List<int> p = ymd.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

String _fmt(DateTime d) {
  String two(int v) => v < 10 ? '0$v' : '$v';
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

/// Pzt=0 … Paz=6 (JS: (getUTCDay() + 6) % 7).
int weekdayIndex(String ymd) => _parse(ymd).weekday - 1;

String addDays(String ymd, int n) {
  final DateTime d = _parse(ymd);
  return _fmt(DateTime.utc(d.year, d.month, d.day + n));
}

/// b − a gün (tam sayı).
int diffDays(String a, String b) => _parse(b).difference(_parse(a)).inDays;

/// Günün bulmacası; tarih tohumlu, her cihazda aynı. Üretilemezse null.
Level? puzzleFor(String ymd) {
  final String tier = kDailyPlan[weekdayIndex(ymd)];
  final GenSpec sp = dailySpecOf(tier);
  GenResult? r;
  for (int round = 0; round < 8 && !(r != null && r.ok); round++) {
    // koşullar (kademe bandı, başta çıkabilen, kıvrımlı oran) sağlanana dek farklı tohum
    final GenResult? c = generate(sp, fnv32('arrowtile-daily-v13-$ymd-$round'));
    if (c != null && (r == null || (c.ok && !r.ok))) r = c;
  }
  if (r == null) return null;
  return Level(
      id: 0,
      daily: ymd,
      ok: r.ok,
      w: r.w,
      h: r.h,
      par: r.arrows.length,
      diff: tier,
      arrows: <Arrow>[
        for (final Arrow a in r.arrows) Arrow(<List<int>>[for (final List<int> c in a.cells) <int>[c[0], c[1]]], a.dir)
      ]);
}

/// Günlük bulmaca ilerlemesi (kayıttaki `dp`).
class DailyProgress {
  Map<String, int> done;
  int streak;
  int best;
  String? last;
  int trophies;
  DailyProgress({Map<String, int>? done, this.streak = 0, this.best = 0, this.last, this.trophies = 0})
      : done = done ?? <String, int>{};

  Map<String, dynamic> toJson() => <String, dynamic>{
        'done': done,
        'streak': streak,
        'best': best,
        'last': last,
        'trophies': trophies,
      };
}

class StreakInfo {
  final int current;
  final int best;
  final int trophies;
  final bool doneToday;
  const StreakInfo(this.current, this.best, this.trophies, this.doneToday);
}

/// Seri durumu (yalnızca okuma): bugün ya da dün çözülmüşse seri sürüyor.
StreakInfo streakInfo(DailyProgress dp, String today) {
  final String? last = dp.last;
  int cur = dp.streak;
  if (last == null || last.isEmpty) {
    cur = 0;
  } else {
    final int dd = diffDays(last, today);
    if (dd > 1) cur = 0;
  }
  return StreakInfo(cur, dp.best, dp.trophies, (dp.done[today] ?? 0) > 0);
}

class SolveRecord {
  final bool first;
  final bool clockBack;
  final int streak;
  const SolveRecord({required this.first, required this.streak, this.clockBack = false});
}

/// Bugünün bulmacası çözüldü: [dp] güncellenir. Saat geri alınmışsa (bugün < son) seri değişmez.
SolveRecord recordSolve(DailyProgress dp, String today, int stars) {
  final String? last = (dp.last == null || dp.last!.isEmpty) ? null : dp.last;
  if (last != null && diffDays(last, today) < 0) {
    return SolveRecord(first: false, clockBack: true, streak: dp.streak); // saat geri: kupa/seri yok
  }
  final bool first = (dp.done[today] ?? 0) == 0;
  final int prev = dp.done[today] ?? 0;
  final int m = prev > stars ? prev : stars;
  dp.done[today] = m == 0 ? 1 : m; // JS: Math.max(...) || 1
  if (first) {
    if (last == null) {
      dp.streak = 1;
    } else {
      final int dd = diffDays(last, today);
      if (dd == 1) {
        dp.streak = dp.streak + 1;
      } else if (dd > 1) {
        dp.streak = 1;
      }
      // dd <= 0: saat geri alınmış ya da aynı gün → seri korunur
    }
    if (last == null || diffDays(last, today) > 0) dp.last = today;
    dp.best = dp.best > dp.streak ? dp.best : dp.streak;
    dp.trophies = dp.trophies + 1;
  }
  // kayıt boyutunu sınırla: en fazla son 400 gün
  final List<String> keys = dp.done.keys.toList()..sort();
  while (keys.length > 400) {
    dp.done.remove(keys.removeAt(0));
  }
  return SolveRecord(first: first, streak: dp.streak);
}
