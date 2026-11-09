// Arrowtile — seviye doğrulayıcı (v1.5, docs/15 §5). Kullanım: node tools/validate-levels.js [levels.js yolu] [--md] [--no-sample]
// 1) Paketteki hazır seviyeler (game/js/levels.js, ilk 200): seviye başına yapı (≤22x31, uzunluk 1–8, komşu hücreler, çakışma yok,
//    baş kendi gövdesine bakmaz), bağımsız açgözlü çözücüyle çözülebilirlik, par = ok sayısı, öğretici 1–3 düz ve küçük,
//    ızgara = specFor(id), etiket = SEVİYE kademesi (bölümde 3 Kolay / 3 Orta / 2 Zor / 2 Aşırı zor), doluluk kademe bandında,
//    başta çıkabilen ≤ kademe sınırı (en az 1), seviye 4'te kıvrımlı ok; paket == oyun içi üretici (özet karşılaştırması).
// 2) Bölüm kuralları: bölüm içi Kolay < Orta < Zor < Aşırı zor (ortalama puan), kademe başına kıvrımlı oran.
// 3) Rapor: bölüm 1–12 ayrıntılı; 13–500 arasında örneklenmiş bölümler oyunun üreticisiyle üretilip aynı denetimlerden geçirilir.
//    Tüm 5.000 seviyenin doğrulaması: tools/verify-5000.js.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const LG = require('../game/js/levelgen.js');
const { checkLevelData, CURVE_TOL } = require('./level-checks');

const args = process.argv.slice(2), MD = args.includes('--md'), SAMPLE = !args.includes('--no-sample');
const file = args.find(a => !a.startsWith('--')) || path.join(__dirname, '..', 'game', 'js', 'levels.js');
const ctx = { window: {} };
vm.runInNewContext(fs.readFileSync(file, 'utf8'), ctx);
const L = ctx.window.LEVELS;
let fail = 0;
const bad = (msg) => { console.log('KALDI: ' + msg); fail++; };
if (!Array.isArray(L) || L.length !== LG.PREBUILT) bad(`${LG.PREBUILT} seviye gerekli (bulunan ${L && L.length})`);

const TR = { easy: 'Kolay', medium: 'Orta', hard: 'Zor', extreme: 'Aşırı zor' };
const ORDER = ['easy', 'medium', 'hard', 'extreme'];

// bölümdeki kademe dizilimi sabit: 3 Kolay, 3 Orta, 2 Zor, 2 Aşırı zor
const want = ['easy', 'easy', 'easy', 'medium', 'medium', 'medium', 'hard', 'hard', 'extreme', 'extreme'];
want.forEach((t, k) => { if (LG.tierOf(k + 1) !== t || LG.tierOf(k + 11) !== t) bad(`kademe dizilimi bozuk (bölüm sırası ${k + 1})`); });

const rows = []; // { lv, m, ch, tier }
function addRow(lv, source) {
  const c = checkLevelData(lv);
  if (c.errs.length) bad(`${source} seviye ${lv.id} (${lv.w}x${lv.h}, ${TR[c.tier]}): ${c.errs.join('; ')}`);
  rows.push({ lv, m: c.m, ch: LG.chapterOf(lv.id), tier: c.tier, inWindow: c.inWindow, src: source });
}
(L || []).forEach((lv, i) => {
  if (lv.id !== i + 1) bad(`id sırası bozuk (${lv.id} ≠ ${i + 1})`);
  addRow(lv, 'paket');
  // paket == oyun içi üretici
  if (file.endsWith('levels.js') && lv.id > 0 && LG.levelHash(lv) !== LG.levelHash(LG.makeLevel(lv.id))) bad(`paket seviye ${lv.id} oyun içi üreticiyle aynı değil (levels.js yeniden üretilmeli)`);
});
// örneklenmiş bölümler (üreticiden)
const SAMPLED = SAMPLE ? [13, 17, 21, 30, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500] : [];
const t0 = Date.now();
SAMPLED.forEach(ch => { for (let k = 1; k <= LG.PER_CHAPTER; k++) { const id = (ch - 1) * LG.PER_CHAPTER + k; if (id > LG.PREBUILT) addRow(Object.assign({}, LG.makeLevel(id)), 'örnek'); } });

// bölüm raporu
const chapters = [];
const chNums = [...new Set(rows.map(r => r.ch))].sort((a, b) => a - b);
for (const ch of chNums) {
  const R = rows.filter(r => r.ch === ch && r.lv.id > LG.TUTORIAL.length);
  const c = { ch, grid: `${R[0].lv.w}x${R[0].lv.h}`, by: {}, mean: {} };
  for (const t of ORDER) {
    const Rt = R.filter(r => r.tier === t); c.by[t] = Rt;
    c.mean[t] = Rt.length ? Rt.reduce((s, r) => s + r.m.score, 0) / Rt.length : null;
  }
  const avg = f => R.reduce((s, r) => s + f(r), 0) / R.length;
  c.arrows = avg(r => r.m.arrows); c.fill = avg(r => r.m.fill); c.free = avg(r => r.m.freeRatio); c.depth = avg(r => r.m.depth); c.curved = avg(r => r.m.curvedRatio);
  c.inWin = R.filter(r => r.inWindow).length; c.cnt = R.length;
  let prev = null;
  for (const t of ORDER) {
    if (c.mean[t] == null) continue;
    if (prev && !(c.mean[t] > c.mean[prev])) bad(`bölüm ${ch}: ${TR[t]} (${c.mean[t].toFixed(1)}) ${TR[prev]} (${c.mean[prev].toFixed(1)}) ortalamasından zor değil`);
    prev = t;
  }
  chapters.push(c);
}
// kademe başına kıvrımlı oran (tüm incelenen seviyeler)
for (const t of ORDER) {
  const Rt = rows.filter(r => r.tier === t && r.lv.id > LG.TUTORIAL.length); if (!Rt.length) continue;
  const cv = Rt.reduce((s, r) => s + r.m.curvedRatio, 0) / Rt.length;
  if (cv < LG.TIERS[t].curve - CURVE_TOL[t]) bad(`${TR[t]}: kıvrımlı oran %${(cv * 100).toFixed(0)} hedefin (%${LG.TIERS[t].curve * 100}) çok altında`);
}
// aynı kademe, tahta büyürken gevşek monoton: bölüm 1–21 (büyüme) boyunca ilk üç bölümün ortalaması < son üç bölümün ortalaması
for (const t of ORDER) {
  const cs = chapters.filter(c => c.ch >= 2 && c.ch <= 21 && c.mean[t] != null);
  if (cs.length >= 6) {
    const a = cs.slice(0, 3).reduce((s, c) => s + c.mean[t], 0) / 3, b = cs.slice(-3).reduce((s, c) => s + c.mean[t], 0) / 3;
    if (!(b > a)) bad(`${TR[t]}: tahta büyürken zorluk artmıyor (${a.toFixed(1)} → ${b.toFixed(1)})`);
  }
}

const f = (c) => ({ ch: c.ch, grid: c.grid, arrows: c.arrows.toFixed(0), fill: (c.fill * 100).toFixed(1), free: (c.free * 100).toFixed(1), depth: c.depth.toFixed(1), curved: (c.curved * 100).toFixed(0),
  scores: ORDER.map(t => (c.mean[t] == null ? '-' : c.mean[t].toFixed(1))), win: `${c.inWin}/${c.cnt}` });
const detail = chapters.filter(c => c.ch <= 12), sampled = chapters.filter(c => c.ch > 12);
if (MD) {
  const head = '| Bölüm | Izgara | Ok (ort.) | Doluluk | Başta çıkabilen | Derinlik | Kıvrımlı | Puan K / O / Z / A | Derinlik penceresi |\n|---|---|---|---|---|---|---|---|---|';
  console.log('\n' + head);
  chapters.forEach(c => { const x = f(c); console.log(`| ${x.ch} | ${x.grid} | ${x.arrows} | %${x.fill} | %${x.free} | ${x.depth} | %${x.curved} | ${x.scores.join(' / ')} | ${x.win} |`); });
} else {
  const hdr = 'bölüm  ızgara  ok   doluluk  başta-çıkabilen  derinlik  kıvrımlı   puan Kolay/Orta/Zor/Aşırı   pencere';
  const line = (c) => { const x = f(c); return `${String(x.ch).padStart(5)}  ${x.grid.padEnd(6)} ${x.arrows.padStart(4)}   %${x.fill.padStart(4)}   %${x.free.padStart(4)}        ${x.depth.padStart(6)}    %${x.curved.padStart(3)}      ${x.scores.map(s => s.padStart(6)).join(' ')}    ${x.win}`; };
  console.log('\nBÖLÜM 1–12 (paket)\n' + hdr);
  detail.forEach(c => console.log(line(c)));
  if (sampled.length) { console.log('\nÖRNEKLENMİŞ BÖLÜMLER 13–500 (oyun içi üreticiyle üretildi, ' + ((Date.now() - t0) / 1000).toFixed(0) + ' sn)\n' + hdr); sampled.forEach(c => console.log(line(c))); }
}
const total = rows.length, notWin = rows.filter(r => !r.inWindow && r.lv.id > LG.TUTORIAL.length).length;
console.log(`\ninceleme: ${total} seviye (paket ${L ? L.length : 0} + örnek ${total - (L ? L.length : 0)}); derinlik penceresi dışında: ${notWin}`);
console.log(fail ? `\n${fail} denetim KALDI` : `\nTüm ${total} seviye GEÇTİ (yapı, çözülebilirlik, ızgara planı, kademe bandı, başta çıkabilen, paket == üretici); bölüm içi Kolay < Orta < Zor < Aşırı zor sırası doğru`);
process.exit(fail ? 1 : 0);
