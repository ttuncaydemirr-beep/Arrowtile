// Arrowtile -> Flutter: web sürümünün (game/js) çıktılarından "altın" test verileri üretir.
// Çıktı: flutter/arrowtile/test/golden/*.json — `flutter test` bu dosyalarla Dart çıktısını karşılaştırır.
// Kullanım: node tools/flutter/make-goldens.js
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm');
const ROOT = path.join(__dirname, '..', '..'), GJ = path.join(ROOT, 'game', 'js');
const OUT = path.join(ROOT, 'flutter', 'arrowtile', 'test', 'golden');
fs.mkdirSync(OUT, { recursive: true });
const LG = require(path.join(GJ, 'levelgen.js')), E = require(path.join(GJ, 'engine.js')), D = require(path.join(GJ, 'daily.js'));
const ADS = require(path.join(GJ, 'ads.js'));
const LEVELS = (() => { const c = { window: {} }; vm.runInNewContext(fs.readFileSync(path.join(GJ, 'levels.js'), 'utf8'), c); return c.window.LEVELS; })();
const write = (name, obj) => { const f = path.join(OUT, name); fs.writeFileSync(f, JSON.stringify(obj)); console.log(`${name}: ${(fs.statSync(f).size / 1024).toFixed(1)} KB`); };
const cp = a => ({ cells: LG.cellsOf(a).map(c => [c[0], c[1]]), dir: a.dir });

// ---------------------------------------------------------------- 1) RNG + hash
{
  const seeds = [0, 1, 12345, 2147483647, 2147483648, 4294967295, 3735928559, LG.hash('arrowtile-v15-217-0'), LG.hash('arrowtile-daily-v13-2026-11-02-0')];
  const rng = seeds.map(seed => { const r = LG.rng(seed >>> 0), values = []; for (let i = 0; i < 64; i++) values.push(r()); return { seed, values }; });
  const strs = ['', 'a', 'arrowtile-v15-1-0', 'arrowtile-v15-217-0', 'arrowtile-v15-99999-7', 'arrowtile-daily-v13-2026-11-02-0', 'arrowtile-daily-v13-2027-02-29-3', 'ÇŞĞİÖÜ ok kaçış'];
  write('rng_golden.json', { rng, hash: strs.map(s => ({ s, h: LG.hash(s) })) });
}

// ---------------------------------------------------------------- 2) seviye üretimi
// v1.1 (docs/15 §5): bölüm = 10 seviye. Tam ok listesi altın: her kademeden küçük ve en büyük tahtada örnekler (özet altın testi ayrıca
// tools/level-hashes.json üzerinden rastgele örneklenmiş seviyelerde çalışır).
const GEN_IDS = [4, 7, 9, 38, 201, 204, 207, 209];
const EXTRA_HASH_IDS = [5001, 5002, 5004, 5007, 5009, 5010, 12345, 99999]; // 5.000 sonrası (level-hashes.json'da yok)
{
  const levels = GEN_IDS.map(id => {
    const t0 = Date.now(), L = LG.makeLevel(id), ms = Date.now() - t0;
    const m = LG.measure({ w: L.w, h: L.h, arrows: L.arrows });
    return { id, ms, level: { id: L.id, w: L.w, h: L.h, par: L.par, diff: L.diff, chapter: L.chapter, ok: L.ok, rounds: L.rounds, arrows: L.arrows.map(cp) },
      measure: { depth: m.depth, initialFree: m.initialFree, freeRatio: m.freeRatio, fill: m.fill, arrows: m.arrows, curved: m.curved, curvedRatio: m.curvedRatio, score: m.score } };
  });
  const specs = [1, 3, 4, 7, 9, 10, 11, 20, 21, 38, 100, 200, 201, 209, 210, 1619, 5000, 5001, 99999].map(id => { const s = LG.specFor(id); return { id, spec: { w: s.w, h: s.h, fill: s.fill, fillMax: s.fillMax, maxFree: s.maxFree, curve: s.curve, maxLen: s.maxLen, tries: s.tries, effort: s.effort, passes: s.passes, cycles: s.cycles, tier: s.tier, chapter: s.chapter, index: s.index, minDepth: s.minDepth, maxDepth: s.maxDepth }, seed0: LG.seedFor(id, 0), seed3: LG.seedFor(id, 3) }; });
  const sizes = [1, 2, 3, 4, 5, 10, 15, 20, 21, 22, 30, 100, 500].map(ch => ({ ch, size: LG.sizeOfChapter(ch) }));
  const extraHashes = EXTRA_HASH_IDS.map(id => { const t0 = Date.now(), L = LG.makeLevel(id); return { id, hash: LG.levelHash(L), ms: Date.now() - t0 }; });
  write('levelgen_golden.json', { levels, specs, sizes, extraHashes });
  levels.forEach(l => console.log(`  seviye ${l.id}: ${l.level.w}x${l.level.h} ${l.level.diff} ok=${l.level.ok} ${l.level.arrows.length} ok, tur ${l.level.rounds}, ${l.ms} ms`));
}

// ---------------------------------------------------------------- 3) günlük bulmaca (5 tarih)
{
  const dates = ['2026-11-02', '2026-11-05', '2026-11-06', '2026-11-07', '2026-11-08', '2026-11-10', '2027-02-14'];
  const puzzles = dates.map(d => { const t0 = Date.now(), p = D.puzzleFor(d); return { date: d, weekday: D.weekdayIndex(d), ms: Date.now() - t0, puzzle: { id: 0, daily: p.daily, ok: p.ok, w: p.w, h: p.h, par: p.par, diff: p.diff, arrows: p.arrows.map(cp) } }; });
  const dd = [['2026-10-30', '2026-11-01'], ['2026-12-31', '2027-01-01'], ['2028-02-28', '2028-03-01'], ['2026-11-05', '2026-11-05']].map(([a, b]) => ({ a, b, diff: D.diffDays(a, b) }));
  const add = [['2026-12-31', 1], ['2028-02-28', 2], ['2026-03-01', -1], ['2026-11-02', 400]].map(([d, n]) => ({ d, n, r: D.addDays(d, n) }));
  // seri/kupa senaryosu
  const dp = {}, steps = [];
  [['2026-10-20', 3], ['2026-10-21', 2], ['2026-10-22', 1], ['2026-10-22', 3], ['2026-10-25', 3], ['2026-10-24', 2], ['2026-10-26', 1]].forEach(([d, st]) => { const r = D.recordSolve(dp, d, st); steps.push({ d, st, r, dp: JSON.parse(JSON.stringify(dp)) }); });
  const info = ['2026-10-26', '2026-10-27', '2026-10-28', '2026-11-30'].map(t => ({ today: t, info: D.streakInfo(dp, t) }));
  write('daily_golden.json', { puzzles, dd, add, steps, info });
  puzzles.forEach(p => console.log(`  ${p.date} (gün ${p.weekday}) ${p.puzzle.diff} ok=${p.puzzle.ok} ${p.puzzle.arrows.length} ok, ${p.ms} ms`));
}

// ---------------------------------------------------------------- 4) motor senaryoları
{
  const scen = [];
  const gen = JSON.parse(fs.readFileSync(path.join(OUT, 'levelgen_golden.json'), 'utf8')).levels.map(x => x.level);
  const pool = [2, 4, 50, 100].map(i => LEVELS[i - 1]).concat(gen.slice(3, 4));
  function run(level, opts, policy) {
    const g = new E.Game(level, opts), steps = [];
    for (let n = 0; n < 600 && !g.isWon() && !g.isDead(); n++) {
      let i;
      if (policy === 'lowest') { i = g.alive.indexOf(true); }
      else if (policy === 'hint') { i = g.hint(); }
      else { // 'mixed': 3 kez en düşük indeks, sonra ipucu
        i = (n % 4 === 3) ? g.hint() : g.alive.indexOf(true);
      }
      const r = g.tap(i);
      steps.push({ i, r, remaining: g.remaining(), lives: g.lives, collisions: g.collisions });
    }
    let revived = null;
    if (g.isDead()) revived = { ok: g.revive(), lives: g.lives, revived: g.revived };
    return { steps, won: g.isWon(), dead: g.isDead(), stars: g.stars(), taps: g.taps, lives: g.lives, collisions: g.collisions, revived };
  }
  for (const lv of pool) {
    const L = { id: lv.id, w: lv.w, h: lv.h, par: lv.par, diff: lv.diff, arrows: lv.arrows.map(cp) };
    const sol = E.solve(L);
    const g0 = new E.Game(L);
    const alive = L.arrows.map(() => true);
    scen.push({
      level: L, solve: { solvable: sol.solvable, order: sol.order, layers: sol.layers },
      hint0: g0.hint(), free0: g0.freeArrows(), colors5: E.colorize(L, 5), colors3: E.colorize(L, 3),
      grid0: E.buildGrid(L, alive),
      runs: {
        lowest: run(L, {}, 'lowest'), lowestRelaxed: run(L, { relaxed: true }, 'lowest'), lowestTutorial: run(L, { noLifeLoss: true }, 'lowest'),
        hint: run(L, {}, 'hint'), mixed: run(L, {}, 'mixed')
      }
    });
  }
  write('engine_golden.json', scen);
}

// ---------------------------------------------------------------- 5) ekonomi (storage.js, Node'da sahte localStorage ile)
function loadStore(initial) {
  const mem = {}; if (initial) Object.keys(initial).forEach(k => mem[k] = initial[k]);
  const ls = { getItem: k => (k in mem ? mem[k] : null), setItem: (k, v) => { mem[k] = String(v); }, removeItem: k => { delete mem[k]; } };
  const ctx = { window: { LEVELS }, localStorage: ls, location: { search: '' }, navigator: { languages: ['en-US'], language: 'en-US' }, console, JSON, Math, Date, Object, Array, Number, String, isFinite, TextEncoder, TextDecoder, btoa: s => Buffer.from(s, 'binary').toString('base64'), atob: b => Buffer.from(b, 'base64').toString('binary'), unescape, escape, encodeURIComponent, decodeURIComponent, parseInt, RegExp, Uint8Array };
  ctx.window.window = ctx.window; vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(path.join(GJ, 'storage.js'), 'utf8'), ctx);
  return ctx.window.Store;
}
{
  const snap = S => JSON.parse(JSON.stringify(S.get()));
  const out = {};
  { // ödül tablosu
    const S = loadStore(); out.rewards = [];
    for (const id of [1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 14, 17, 19, 20, 21, 100, 200, 201, 5000, 5001, 99999]) for (let st = 0; st <= 3; st++) out.rewards.push({ id, st, r: S.levelReward(id, st) });
    // v1.1: kademe SEVİYE bazında (1-3 Kolay, 4-6 Orta, 7-8 Zor, 9-10 Aşırı zor); bölüm bonusu tek (150)
    out.tiers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 17, 18, 19, 20, 5000, 99999].map(id => ({ id, chapter: S.chapterOfLevel(id), tier: S.tierOfLevel(id), bonus: S.chapterBonusFor(S.chapterOfLevel(id)) }));
  }
  { // bölüm tamamlama + yıldız artırma + rahat mod
    const S = loadStore(); S.load(); const steps = [];
    const seq = [[1, 3, false], [2, 2, false], [2, 3, false], [2, 1, false], [3, 1, true], [4, 2, true], [4, 3, false], [5, 3, false], [6, 3, false], [7, 3, false], [8, 3, false], [9, 3, false], [10, 3, false], [3, 3, false],
      // bölüm 2 (11-20): son seviye ÖNCE, eksik olan en son tamamlanınca bonus
      [11, 3, false], [12, 3, false], [13, 3, false], [14, 3, false], [15, 3, false], [16, 3, false], [17, 3, false], [18, 3, false], [20, 3, false], [19, 2, true], [19, 3, false],
      [21, 2, false], [21, 3, true], [100, 3, false], [217, 1, false], [5000, 3, false], [5001, 2, false]];
    seq.forEach(([id, st, rl]) => { const r = S.completeLevel(id, st, rl); steps.push({ id, st, rl, r, s: snap(S), total: S.totalStars() }); });
    out.complete = steps;
  }
  { // günlük ödül
    const S = loadStore(); S.load(); const steps = [];
    const days = ['2026-11-01', '2026-11-01', '2026-11-02', '2026-11-03', '2026-11-05', '2026-11-06', '2026-11-07', '2026-11-08', '2026-11-09', '2026-11-10', '2026-11-11', '2026-11-12', '2026-11-13', '2026-11-14', '2026-11-13', '2026-11-15', '2026-12-31', '2027-01-01'];
    days.forEach(d => { const st = S.dailyStatus(d), r = S.claimDaily(d); steps.push({ d, st, r, daily: snap(S).daily, coins: S.get().coins, freeHints: S.get().freeHints }); });
    out.daily = steps;
  }
  { // v1.4: reklam izleyerek jeton (+50, günde en çok 10; saat geri alınırsa hak yenilenmez; sıfırlama hakkı yenilemez)
    const S = loadStore(); S.load(); const steps = [];
    const days = [...Array(11).fill('2026-11-04'), '2026-11-03', '2026-11-04', '2026-11-05', '2026-11-05', '2026-12-31', '2027-01-01'];
    days.forEach(d => { const left = S.coinAdsLeft(d), r = S.grantAdCoins(d); steps.push({ d, left, r, coins: S.get().coins, ads: snap(S).ads }); });
    out.coinAds = steps;
    const before = S.get().ads.coinCount; S.resetProgress();
    out.coinAdsReset = { before, ads: snap(S).ads, coins: S.get().coins };
  }
  { // yardımcı harcama
    const S = loadStore(); S.load(); const steps = [];
    for (let i = 0; i < 6; i++) { const ok = S.spendBooster('hint'); steps.push({ ok, coins: S.get().coins, freeHints: S.get().freeHints }); }
    S.get().coins = 120;
    for (let i = 0; i < 3; i++) { const ok = S.spendBooster('hint'); steps.push({ ok, coins: S.get().coins, freeHints: S.get().freeHints }); }
    S.refundBooster('hint', true); steps.push({ refund: 'free', coins: S.get().coins, freeHints: S.get().freeHints });
    S.refundBooster('hint', false); steps.push({ refund: 'coins', coins: S.get().coins, freeHints: S.get().freeHints });
    out.spend = steps;
  }
  { // sanitize (kayıt göçü ve bozuk veri)
    const S = loadStore();
    const raws = [
      null, 7, 'x', [], {}, { coins: 'abc', freeHints: -4, unlocked: 0 }, { coins: 5000000000, unlocked: 123456 },
      { lang: 'de', sound: false, vibration: 'no', coins: 77.9, freeHints: '3', freeUndos: 4 },
      { freeUndos: 2000, coins: 999999900 }, { freeUndos: null, coins: 10 },
      { stars: { '1': 3, '2': 0, '3': 9, '0': 2, 'x': 1, '99999': 1, '100000': 2 } },
      { themesOwned: ['lokum', 'bogus', 'cini'], theme: 'cini' }, { themesOwned: ['lokum'], theme: 'cini' }, { themesOwned: 'x', theme: 'lokum' },
      { daily: { lastDate: '2026-11-02', streakDay: 9 } }, { daily: { lastDate: '02.11.2026', streakDay: 3 } },
      { tutorialDone: true }, { tutorialDone: [1, '2', 4, 0, 3, 3] }, { chapterBonus: [1, 0, 5, 9000, '7'] }, { chapterBonus: [1, 10000, 10001, 5, 5] },
      { ads: { since: 2000, lastAt: 1e17, adFree: 'true', test: true } }, { ads: { since: 4, lastAt: 1700000000000, adFree: true, test: false } },
      { ads: { since: 1, coinDate: '2026-11-04', coinCount: 7 } }, { ads: { coinDate: '4.11.2026', coinCount: -3 } }, { ads: { coinDate: 20261104, coinCount: 5000 } }, { ads: { coinCount: '4.9' } },
      { appearance: 'dark', relaxed: true, aim: true }, { appearance: 'blue', relaxed: 'y', aim: 1 },
      { dp: { done: { '2026-11-01': 3, '2026-11-02': 7, 'bad': 1, '2026-11-03': 0 }, streak: 5, best: 9, trophies: 12, last: '2026-11-02' } },
      { dp: { done: [1, 2], streak: -3, best: 'z', trophies: 1e9, last: 'x' } },
      { tips: ['aim_suggest', 'BAD', 'zoom_tip', 5, 'a'.repeat(25)] }
    ];
    out.sanitize = raws.map(raw => ({ raw, state: S.sanitize(raw) }));
  }
  { // yedek kodu
    const S = loadStore(); S.load();
    [[1, 3], [2, 2], [3, 1], [4, 3], [15, 2]].forEach(([id, st]) => S.completeLevel(id, st, false));
    S.get().theme = 'emaye'; S.get().themesOwned = ['emaye', 'lokum']; S.get().dp = { done: { '2026-11-01': 3, '2026-11-02': 2 }, streak: 2, best: 4, last: '2026-11-02', trophies: 6 };
    S.get().tips = ['zoom_tip']; S.get().relaxed = true; S.get().tutorialDone = [1, 2, 3]; S.get().ads = { since: 2, lastAt: 5, adFree: true, test: false, coinDate: null, coinCount: 0 };
    const code = S.exportCode();
    const parsed = S.parseCode(code);
    const bad = [code + 'x', code.replace('ARROWTILE1', 'ARROWTILE2'), ' ' + code.slice(0, 20) + '\n ' + code.slice(20) + ' ', '', null, 'ARROWTILE1-e30=-' + 'zzzzzzzz', 'ARROWTILE1-W10=-' + (function () { return ('0000000' + (function (str) { let h = 0x811c9dc5; for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 0x01000193); } return (h >>> 0).toString(16); })('W10=')).slice(-8); })()];
    out.backup = { state: snap(S), code, parsed, bad: bad.map(b => ({ code: b, parsed: S.parseCode(b) })) };
  }
  write('economy_golden.json', out);
}

// ---------------------------------------------------------------- 6) reklam kuralları (ads.js, sahte saat + sahte köprü)
{
  const MIN = 60 * 1000;
  function harness(o) {
    o = o || {}; let t = 1_000_000, timers = [], online = true; const queue = [];
    const bridge = o.noBridge ? null : {
      adFree: !!o.adFree, isAdFree() { return this.adFree; }, isOnline() { return online; }, isRewardedReady() { return true; },
      showInterstitial(id) { queue.push({ id, event: 'closed' }); return true; },
      showRewarded(id) { queue.push({ id, event: 'rewarded' }); queue.push({ id, event: 'closed' }); return true; },
      purchaseRemoveAds(id) { queue.push({ id, event: 'purchased' }); return true; }, restorePurchases(id) { queue.push({ id, event: 'restored', adFree: false }); return true; }
    };
    const env = { now: () => t, bridge: () => bridge, online: () => online, setTimeout: (f, ms) => { const h = { f, at: t + ms }; timers.push(h); return h; }, clearTimeout: h => { timers = timers.filter(x => x !== h); } };
    const M = ADS.create(env), state = { ads: undefined }; M.attach(() => state, () => {});
    const flush = () => { while (queue.length) M.onNative(JSON.stringify(queue.shift())); };
    return { M, state, flush, advance: ms => { t += ms; }, setOnline: v => { online = v; }, now: () => t };
  }
  // senaryo dili: ['c', id] = seviye tamamla + devam et ; ['t', ms] = zaman ilerlet ; ['o', bool] = internet ; ['buy'] = satın al ; ['due', id] = interstitialDue
  const scenarios = {
    steady30s: [...Array(28).keys()].flatMap(i => [['c', i + 1], ['t', 30000]]),
    fast: [...Array(40).keys()].flatMap(i => [['c', i + 10], ['t', 10 * MIN]]),
    offlineMid: [['c', 13], ['c', 14], ['c', 15], ['o', false], ['c', 16], ['c', 17], ['t', 5 * MIN], ['c', 18], ['o', true], ['c', 19], ['t', 4 * MIN], ['c', 20], ['c', 21]],
    purchase: [['c', 13], ['c', 14], ['buy'], ['c', 15], ['t', 10 * MIN], ['c', 16], ['c', 17], ['c', 18], ['due', 18]],
    gap: [['c', 13], ['c', 14], ['c', 15], ['t', MIN], ['c', 16], ['c', 17], ['c', 18], ['t', 2 * MIN + 59999], ['c', 19], ['c', 20], ['c', 21], ['t', 1], ['c', 22], ['c', 23], ['c', 24]]
  };
  const res = {};
  for (const [name, ops] of Object.entries(scenarios)) {
    const h = harness({}), log = [];
    for (const op of ops) {
      if (op[0] === 'c') { h.M.onLevelComplete(op[1]); let shown = null; h.M.continueAfterLevel(op[1], s => { shown = s; }, h.M.openLevelEnd(op[1])); h.flush(); log.push({ op, shown, since: h.state.ads.since | 0, lastAt: h.state.ads.lastAt | 0 }); }
      else if (op[0] === 't') h.advance(op[1]);
      else if (op[0] === 'o') h.setOnline(op[1]);
      else if (op[0] === 'buy') { let r = null; h.M.purchaseRemoveAds(x => { r = x; }); h.flush(); log.push({ op, r, adFree: h.state.ads.adFree }); }
      else if (op[0] === 'due') log.push({ op, due: h.M.interstitialDue(op[1]) });
    }
    res[name] = { start: 1_000_000, ops, log };
  }
  write('ads_golden.json', res);
}
console.log('altın veriler hazır:', OUT);
