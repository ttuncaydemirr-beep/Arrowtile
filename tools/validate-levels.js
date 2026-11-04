// Arrowtile — seviye doğrulayıcı (v1.3, docs/09-bolum-dongusu.md). Kullanım: node tools/validate-levels.js [levels.js yolu] [--md]
// Seviye başına: yapı (≤22x31, uzunluk 1–8, komşu hücreler, çakışma yok, baş kendi gövdesine bakmaz), bağımsız açgözlü
// çözücüyle çözülebilirlik, par = ok sayısı, öğretici 1–3 düz ve küçük, ızgara = specFor(id), etiket = bölüm kademesi,
// doluluk kademe bandında, başta çıkabilen ≤ kademe sınırı (en az 1), seviye 4'te kıvrımlı ok.
// Bölüm başına: kıvrımlı oran ≈ kademe hedefi (en çok 0,12 altında). Döngü içinde Kolay < Orta < Zor < Aşırı zor
// (ortalama puan); aynı kademe 2. döngüde 1. döngüden zor. Sonda bölüm raporu (--md: Markdown tablo).
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const S = require('./solver');
const LG = require('../game/js/levelgen.js');

const args = process.argv.slice(2), MD = args.includes('--md');
const file = args.find(a => !a.startsWith('--')) || path.join(__dirname, '..', 'game', 'js', 'levels.js');
const ctx = { window: {} };
vm.runInNewContext(fs.readFileSync(file, 'utf8'), ctx);
const L = ctx.window.LEVELS;
let fail = 0;
const bad = (msg) => { console.log('KALDI: ' + msg); fail++; };
if (!Array.isArray(L) || L.length !== LG.PREBUILT) bad(`${LG.PREBUILT} seviye gerekli (bulunan ${L && L.length})`);
const isStraight = a => { const c = S.cellsOf(a); return c.length < 3 || !LG.isCurved(a); };
const rows = [];
L.forEach((lv, i) => {
  const errs = S.checkStructure(lv);
  if (lv.id !== i + 1) errs.push(`id sırası bozuk (${lv.id})`);
  const sol = S.solve(lv), m = LG.measure(lv);
  if (!sol.solvable || !m.solvable) errs.push('çözülemez');
  else if (sol.layers !== m.depth || sol.initialFree !== m.initialFree) errs.push(`çözücüler uyuşmuyor (derinlik ${sol.layers}/${m.depth})`);
  if (lv.par !== lv.arrows.length) errs.push(`par (${lv.par}) != ok sayısı (${lv.arrows.length})`);
  const ch = LG.chapterOf(lv.id), tier = LG.tierOf(ch), T = LG.TIERS[tier];
  if (lv.diff !== tier) errs.push(`etiket "${lv.diff}" ama bölüm ${ch} kademesi "${tier}"`);
  if (i < 3) {
    if (lv.w > 5 || lv.h > 5 || lv.arrows.length < 2 || lv.arrows.length > 4 || !lv.arrows.every(isStraight)) errs.push('öğretici seviye sınırı (küçük, düz oklar)');
  } else if (m.solvable) {
    const sp = LG.specFor(lv.id);
    if (lv.w !== sp.w || lv.h !== sp.h) errs.push(`ızgara ${lv.w}x${lv.h} ≠ plan ${sp.w}x${sp.h}`);
    if (m.fill < T.band[0] - 1e-9 || m.fill > T.band[1] + 1e-9) errs.push(`doluluk %${(m.fill * 100).toFixed(1)} bant dışı (%${T.band[0] * 100}–${T.band[1] * 100})`);
    const lim = Math.max(1, Math.floor(T.maxFree * m.arrows + 1e-9));
    if (m.initialFree > lim) errs.push(`başta çıkabilen ${m.initialFree} > ${lim} (%${T.maxFree * 100})`);
    if (lv.id === 4 && !lv.arrows.some(LG.isCurved)) errs.push('seviye 4 kıvrımlı ok içermiyor');
  }
  rows.push({ lv, m, ch, tier });
  if (errs.length) bad(`seviye ${lv.id} (${lv.w}x${lv.h}, ${tier}): ${errs.join('; ')}`);
});

// bölüm raporu
const TR = { easy: 'Kolay', medium: 'Orta', hard: 'Zor', extreme: 'Aşırı zor' };
const chapters = [];
for (let ch = 1; ch <= Math.ceil(L.length / LG.PER_CHAPTER); ch++) {
  const R = rows.filter(r => r.ch === ch && r.lv.id > 3); if (!R.length) continue;
  const avg = f => R.reduce((s, r) => s + f(r), 0) / R.length;
  const c = { ch, tier: R[0].tier, cycle: Math.floor((ch - 1) / LG.CYCLE.length) + 1,
    grid: `${R[0].lv.w}x${R[0].lv.h}–${R[R.length - 1].lv.w}x${R[R.length - 1].lv.h}`,
    arrows: avg(r => r.m.arrows), fill: avg(r => r.m.fill), free: avg(r => r.m.freeRatio), freeN: avg(r => r.m.initialFree),
    depth: avg(r => r.m.depth), score: avg(r => r.m.score), curved: avg(r => r.m.curvedRatio) };
  if (c.curved < LG.TIERS[c.tier].curve - 0.12) bad(`bölüm ${ch}: kıvrımlı oran %${(c.curved * 100).toFixed(0)} hedefin (%${LG.TIERS[c.tier].curve * 100}) çok altında`);
  chapters.push(c);
}
const ORDER = ['easy', 'medium', 'hard', 'extreme'];
const tierMean = (cy, t) => { const C = chapters.filter(c => c.cycle === cy && c.tier === t); return C.length ? C.reduce((s, c) => s + c.score, 0) / C.length : null; };
const cycles = [...new Set(chapters.map(c => c.cycle))];
const summary = [];
for (const cy of cycles) {
  const ms = ORDER.map(t => tierMean(cy, t));
  summary.push(`döngü ${cy}: ` + ORDER.map((t, k) => `${TR[t]} ${ms[k] == null ? '-' : ms[k].toFixed(1)}`).join(' < '));
  for (let k = 1; k < 4; k++) if (ms[k] != null && ms[k - 1] != null && !(ms[k] > ms[k - 1])) bad(`döngü ${cy}: ${TR[ORDER[k]]} (${ms[k].toFixed(1)}) ${TR[ORDER[k - 1]]} (${ms[k - 1].toFixed(1)}) bölümlerinden zor değil`);
  if (cy > 1) for (const t of ORDER) { const a = tierMean(cy - 1, t), b = tierMean(cy, t); if (a != null && b != null && !(b > a)) bad(`${TR[t]}: döngü ${cy} (${b.toFixed(1)}) döngü ${cy - 1}'den (${a.toFixed(1)}) zor değil`); }
}
if (MD) {
  console.log('\n| Bölüm | Kademe | Izgara | Ok (ort.) | Doluluk | Başta çıkabilen | Derinlik | Puan | Kıvrımlı |\n|---|---|---|---|---|---|---|---|---|');
  chapters.forEach(c => console.log(`| ${c.ch} | ${TR[c.tier]} | ${c.grid} | ${c.arrows.toFixed(0)} | %${(c.fill * 100).toFixed(1)} | %${(c.free * 100).toFixed(1)} (${c.freeN.toFixed(1)}) | ${c.depth.toFixed(1)} | ${c.score.toFixed(1)} | %${(c.curved * 100).toFixed(0)} |`));
} else {
  console.log('\nbölüm kademe     ızgara         ok   doluluk  başta-çıkabilen  derinlik   puan  kıvrımlı');
  chapters.forEach(c => console.log(`${String(c.ch).padStart(5)} ${TR[c.tier].padEnd(10)} ${c.grid.padEnd(13)} ${c.arrows.toFixed(0).padStart(4)}   %${(c.fill * 100).toFixed(1).padStart(4)}   %${(c.free * 100).toFixed(1).padStart(4)} (${c.freeN.toFixed(1)})   ${c.depth.toFixed(1).padStart(6)}  ${c.score.toFixed(1).padStart(5)}   %${(c.curved * 100).toFixed(0)}`));
}
console.log('\n' + summary.join('\n'));
console.log(fail ? `\n${fail} denetim KALDI` : `\nTüm ${L.length} seviye GEÇTİ (yapı, çözülebilirlik, ızgara planı, kademe bandı, başta çıkabilen, kıvrımlı oran); döngü içi ve döngüler arası zorluk sırası doğru`);
process.exit(fail ? 1 : 0);
