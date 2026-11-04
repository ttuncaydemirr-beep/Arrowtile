/* Arrowtile — daily.js: günlük bulmaca (G5)
 * Tarihten türetilen tohumla cihazda, çevrimdışı üretilir: aynı gün her cihazda aynı bulmaca.
 * Üretim hazır seviyelerle aynı ortak modülü kullanır (game/js/levelgen.js); her bulmaca çözücüyle doğrulanır.
 * Haftanın gününe göre kademe (docs/09): Pzt–Çar Kolay, Per–Cum Orta, Cmt Zor, Paz Aşırı zor.
 * Tarayıcıda window.Daily, Node'da module.exports (tools/test-daily.js).
 */
(function (root) {
  'use strict';

  var LG = root.LevelGen || (typeof require === 'function' ? require('./levelgen.js') : null);
  // v1.3 (docs/09): haftanın günü (Pzt=0 … Paz=6) → kademe: Pzt–Çar Kolay, Per–Cum Orta, Cmt Zor, Paz Aşırı zor; tahta ≈ 12x16
  var PLAN = ['easy', 'easy', 'easy', 'medium', 'medium', 'hard', 'extreme'];
  var DW = 12, DH = 16;
  function specOf(tier) {
    var T = LG.TIERS[tier];
    var sp = { w: DW, h: DH, fill: T.fill, fillMax: T.band[1], maxFree: T.maxFree, curve: T.curve, maxLen: 7, tries: 3, effort: 24, passes: 12, cycles: 4 };
    if (tier === 'extreme') { sp.effort = 40; sp.passes = 20; sp.cycles = 6; }
    return sp;
  }

  function parse(ymd) { var p = String(ymd).split('-').map(Number); return new Date(Date.UTC(p[0], p[1] - 1, p[2])); }
  function weekdayIndex(ymd) { return (parse(ymd).getUTCDay() + 6) % 7; }

  /** Günün bulmacası: { id: 0, daily: 'YYYY-MM-DD', w, h, par, arrows, diff } — tarih tohumlu, her cihazda aynı */
  function puzzleFor(ymd) {
    var tier = PLAN[weekdayIndex(ymd)], sp = specOf(tier);
    var r = null;
    for (var round = 0; round < 8 && !(r && r.ok); round++) { // koşullar (kademe bandı, başta çıkabilen, kıvrımlı oran) sağlanana dek farklı tohum
      var c = LG.generate(sp, LG.hash('arrowtile-daily-v13-' + ymd + '-' + round));
      if (c && (!r || (c.ok && !r.ok))) r = c;
    }
    if (!r) return null;
    return { id: 0, daily: ymd, ok: !!r.ok, w: r.w, h: r.h, par: r.arrows.length, diff: tier,
      arrows: r.arrows.map(function (a) { return { cells: LG.cellsOf(a).map(function (c) { return [c[0], c[1]]; }), dir: a.dir }; }) };
  }

  function addDays(ymd, n) { var d = parse(ymd); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); }
  function diffDays(a, b) { return Math.round((parse(b) - parse(a)) / 864e5); }

  /** Seri durumu (yalnızca okuma): bugün ya da dün çözülmüşse seri sürüyor */
  function streakInfo(dp, today) {
    dp = dp || {};
    var last = dp.last, cur = dp.streak | 0;
    if (!last) cur = 0;
    else { var dd = diffDays(last, today); if (dd > 1) cur = 0; }
    return { current: cur, best: dp.best | 0, trophies: dp.trophies | 0, doneToday: !!(dp.done && dp.done[today]) };
  }
  /** Bugünün bulmacası çözüldü: dp nesnesini günceller. Saat geri alınmışsa (bugün < son) seri değişmez. */
  function recordSolve(dp, today, stars) {
    if (!dp.done) dp.done = {};
    if (dp.last && diffDays(dp.last, today) < 0) return { first: false, clockBack: true, streak: dp.streak | 0 }; // saat geri: kupa/seri yok
    var first = !dp.done[today];
    dp.done[today] = Math.max(dp.done[today] | 0, stars | 0) || 1;
    if (first) {
      if (!dp.last) dp.streak = 1;
      else {
        var dd = diffDays(dp.last, today);
        if (dd === 1) dp.streak = (dp.streak | 0) + 1;
        else if (dd > 1) dp.streak = 1;
        // dd <= 0: saat geri alınmış ya da aynı gün → seri korunur
      }
      if (!dp.last || diffDays(dp.last, today) > 0) dp.last = today;
      dp.best = Math.max(dp.best | 0, dp.streak | 0);
      dp.trophies = (dp.trophies | 0) + 1;
    }
    // kayıt boyutunu sınırla: en fazla son 400 gün
    var keys = Object.keys(dp.done).sort();
    while (keys.length > 400) delete dp.done[keys.shift()];
    return { first: first, streak: dp.streak | 0 };
  }

  var Daily = { puzzleFor: puzzleFor, streakInfo: streakInfo, recordSolve: recordSolve, addDays: addDays, diffDays: diffDays, weekdayIndex: weekdayIndex, PLAN: PLAN };
  root.Daily = Daily;
  if (typeof module !== 'undefined' && module.exports) module.exports = Daily;
})(typeof window !== 'undefined' ? window : globalThis);
