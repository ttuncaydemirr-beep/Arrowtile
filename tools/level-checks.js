// Arrowtile — tek seviye için ortak denetimler (tools/validate-levels.js ve tools/verify-5000.js kullanır). 1.2.0 (docs/24).
// BAĞIMLI OLMAYAN çözücü (tools/solver.js) ile yapı, çözülebilirlik, par, ızgara planı, maske (şekilli tahta), kademe bandı, başta çıkabilen.
'use strict';
const S = require('./solver');
const LG = require('../game/js/levelgen.js');

const TIER_ORDER = LG.TIER_ORDER;
const TR = { easy: 'Kolay', medium: 'Orta', hard: 'Zor', extreme: 'Aşırı zor' };

/** lv: { id, w, h, par, diff, arrows, mask? } → { errs: [...], m: LG.measure2(lv), tier, spec, soft } */
function checkLevelData(lv) {
  const errs = [];
  const id = lv.id, tier = LG.tierOf(id), T = LG.TIER2[tier], sp = LG.specFor(id);
  const se = S.checkStructure(lv); if (se.length) errs.push('yapı: ' + se.slice(0, 4).join(', '));
  const sol = S.solve(lv), m = LG.measure2(lv);
  if (!sol.solvable || !m.solvable) errs.push('çözülemez');
  else if (sol.layers !== m.depth || sol.initialFree !== m.initialFree) errs.push(`çözücüler uyuşmuyor (derinlik ${sol.layers}/${m.depth})`);
  if (lv.diff !== tier) errs.push(`etiket "${lv.diff}" ama seviye ${id} kademesi "${tier}"`);
  if (lv.par !== lv.arrows.length) errs.push(`par (${lv.par}) != ok sayısı (${lv.arrows.length})`);
  let soft = true;
  if (id <= LG.TUTORIAL.length) {
    if (lv.w > 5 || lv.h > 5 || lv.arrows.length < 2 || lv.arrows.length > 4 || lv.arrows.some(a => LG.isCurved(a)) || lv.mask) errs.push('öğretici seviye sınırı (küçük, düz oklar, maskesiz)');
  } else if (m.solvable) {
    if (lv.w !== sp.w || lv.h !== sp.h) errs.push(`ızgara ${lv.w}x${lv.h} ≠ plan ${sp.w}x${sp.h}`);
    if ((sp.shape !== 'full') !== !!lv.mask) errs.push(`tahta biçimi planı "${sp.shape}" ama maske ${lv.mask ? 'var' : 'yok'}`);
    if (lv.mask) {
      const cells = LG.maskCount(lv);
      if (cells < lv.w * lv.h * 0.45 || cells >= lv.w * lv.h) errs.push(`maske hücre sayısı ${cells} (tahtanın %45'inden az ya da boş maske)`);
    }
    if (m.fill < T.band[0] - 1e-9 || m.fill > T.band[1] + 1e-9) errs.push(`doluluk %${(m.fill * 100).toFixed(1)} bant dışı (%${(T.band[0] * 100).toFixed(0)}–${(T.band[1] * 100).toFixed(0)})`);
    const lim = LG.freeLimit(tier, m.arrows);
    if (m.initialFree > lim) errs.push(`başta çıkabilen ${m.initialFree} > ${lim}`);
    if (m.initialFree < Math.min(T.minFree, 1)) errs.push('başta çıkabilen ok yok');
    // 1.2.0 üreticisi: baş yönü her zaman son gövde adımıyla aynıdır (ok ucu çizginin devamıdır)
    if (lv.arrows.some(a => { const c = LG.cellsOf(a), n = c.length, d = S.DIRS[a.dir]; return n >= 2 && (c[n - 1][0] - c[n - 2][0] !== d[0] || c[n - 1][1] - c[n - 2][1] !== d[1]); })) errs.push('baş yönü son gövde adımıyla aynı olmayan ok var');
    if (m.maxLen > LG.MAX_ARROW_LEN) errs.push(`en uzun ok ${m.maxLen} > ${LG.MAX_ARROW_LEN}`);
    soft = m.meanTurns >= T.minTurns; // yumuşak kısıt: ok başına ortalama dönüş (üretici 8 turda sağlayamazsa en iyi aday)
  }
  return { errs, m, tier, spec: sp, soft };
}

/**
 * Bölüm kuralları (rows: [{ id, tier, score, n, turns, len }]): bölüm içinde Kolay < Orta < Zor < Aşırı zor (ortalama puan ve ort. dönüş kesin; ort. uzunluk %10 toleranslı).
 * growTol(tier): büyüme döngüsünde ok sayısı artış denetimi toleransı — Aşırı zor şekilli tahtalarda alan değiştiği için 0,85.
 * Dönen: hata metinleri.
 */
function checkChapter(ch, rows) {
  const errs = [], mean = (a, f) => a.reduce((s, x) => s + f(x), 0) / a.length;
  let prev = null;
  for (const t of TIER_ORDER) {
    const R = rows.filter(r => r.tier === t); if (!R.length) continue;
    const cur = { t, score: mean(R, r => r.score), turns: mean(R, r => r.turns), len: mean(R, r => r.len) };
    if (prev) {
      if (!(cur.score > prev.score)) errs.push(`bölüm ${ch}: ${TR[t]} puanı (${cur.score.toFixed(1)}) ${TR[prev.t]} (${prev.score.toFixed(1)}) ortalamasından yüksek değil`);
      if (!(cur.turns > prev.turns)) errs.push(`bölüm ${ch}: ${TR[t]} ort. dönüş (${cur.turns.toFixed(2)}) ${TR[prev.t]} (${prev.turns.toFixed(2)}) değerinden yüksek değil`);
      // uzunluk: %10 tolerans (şekilli/dar tahtada Aşırı zor okları Zor'a yakın kalabilir; dönüş ve puan kesin sıralıdır)
      if (!(cur.len > prev.len * 0.9)) errs.push(`bölüm ${ch}: ${TR[t]} ort. ok uzunluğu (${cur.len.toFixed(1)}) ${TR[prev.t]} (${prev.len.toFixed(1)}) değerinin %90'ından yüksek değil`);
    }
    prev = cur;
  }
  return errs;
}
const growTol = (t) => (t === 'extreme' ? 0.85 : 1);
/** 1.2.0 #2: kademenin tahtası bir önceki bölüme göre büyüdü mü (Kolay/Orta küçük bölümlerde en küçük tahtada kalabilir). */
function tierGrew(t, ch) {
  const first = (c) => (c - 1) * LG.PER_CHAPTER + TIER_ORDER.indexOf(t) * 5 + 1;
  const a = LG.sizeOf(first(ch - 1)), b = LG.sizeOf(first(ch));
  return b.w * b.h >= a.w * a.h * 1.1; // en az %10 büyüme (9x13 → 9x14 gibi tek satırlık artışta ok sayısı dalgalanabilir)
}
module.exports = { growTol, tierGrew, checkLevelData, checkChapter, TIER_ORDER, TR };
