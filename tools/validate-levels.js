// Arrowtile — seviye doğrulayıcı (1.2.0, docs/24). Kullanım: node tools/validate-levels.js [levels.js yolu] [--md] [--no-sample]
// 1) Paketteki hazır seviyeler (game/js/levels.js, ilk PREBUILT): seviye başına yapı (≤ 28x45, komşu hücreler, çakışma yok, baş kendi
//    gövdesine bakmaz, hücreler maske içinde), bağımsız açgözlü çözücüyle çözülebilirlik, par = ok sayısı, öğretici 1–3 düz ve küçük,
//    ızgara = specFor(id), etiket = SEVİYE kademesi (bölümde 5 Kolay / 5 Orta / 5 Zor / 5 Aşırı zor), doluluk kademe bandında,
//    başta çıkabilen ≤ kademe sınırı (en az 1), tahta biçimi planı (şekilli Aşırı zor); paket == oyun içi üretici (özet karşılaştırması).
// 2) Bölüm kuralları: bölüm içi Kolay < Orta < Zor < Aşırı zor (ortalama puan, dönüş, uzunluk); büyüme döngüsünde tahta ve ok sayısı
//    bölümden bölüme artar, döngü bitince en küçük tahtaya dönülür.
// 3) Rapor: paketteki bölümler ayrıntılı; sonraki bölümlerden örnekler oyunun üreticisiyle üretilip aynı denetimlerden geçirilir.
//    Tüm 5.000 seviyenin doğrulaması: tools/verify-5000.js.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const LG = require('../game/js/levelgen.js');
const { checkLevelData, checkChapter, TIER_ORDER: ORDER, TR } = require('./level-checks');

const args = process.argv.slice(2), MD = args.includes('--md'), SAMPLE = !args.includes('--no-sample');
const file = args.find(a => !a.startsWith('--')) || path.join(__dirname, '..', 'game', 'js', 'levels.js');
const ctx = { window: {} };
vm.runInNewContext(fs.readFileSync(file, 'utf8'), ctx);
const L = ctx.window.LEVELS;
let fail = 0;
const bad = (msg) => { console.log('KALDI: ' + msg); fail++; };
if (!Array.isArray(L) || L.length !== LG.PREBUILT) bad(`${LG.PREBUILT} seviye gerekli (bulunan ${L && L.length})`);
const PER = LG.PER_CHAPTER, GROW = LG.GROW_CHAPTERS;

// bölümdeki kademe dizilimi sabit: 5 Kolay, 5 Orta, 5 Zor, 5 Aşırı zor
if (PER !== 20) bad(`bölüm ${PER} seviye (20 olmalı)`);
for (let k = 0; k < PER; k++) { const t = ORDER[Math.floor(k / 5)]; if (LG.tierOf(k + 1) !== t || LG.tierOf(k + 1 + PER * 7) !== t) bad(`kademe dizilimi bozuk (bölüm sırası ${k + 1})`); }
// tahta büyümesi: döngü içinde kesin artan, en büyük ≈ 28x45, döngü sonunda en küçüğe dönüş
for (let c = 1; c <= GROW * 2; c++) {
  const a = LG.sizeOfChapter(c), g = (c - 1) % GROW;
  if (g === 0 && (a.w !== LG.MIN_W || a.h !== LG.MIN_H)) bad(`bölüm ${c}: döngü başı ${a.w}x${a.h} en küçük tahta değil`);
  if (g === GROW - 1 && (a.w !== LG.MAX_W || a.h !== LG.MAX_H)) bad(`bölüm ${c}: döngü sonu ${a.w}x${a.h} en büyük tahta değil`);
  if (g > 0) { const p = LG.sizeOfChapter(c - 1); if (!(a.w > p.w && a.h > p.h)) bad(`bölüm ${c}: tahta (${a.w}x${a.h}) önceki bölümden (${p.w}x${p.h}) büyük değil`); }
}
if (LG.MAX_W !== 28 || LG.MAX_H !== 45) bad('en büyük tahta 28x45 olmalı');
if (LG.CHAPTERS * PER !== LG.DESIGNED) bad('5.000 seviye = 250 bölüm olmalı');

const rows = []; // { lv, m, ch, tier }
function addRow(lv, source) {
  const c = checkLevelData(lv);
  if (c.errs.length) bad(`${source} seviye ${lv.id} (${lv.w}x${lv.h}, ${TR[c.tier]}): ${c.errs.join('; ')}`);
  rows.push({ lv, m: c.m, ch: LG.chapterOf(lv.id), tier: c.tier, soft: c.soft, src: source });
}
(L || []).forEach((lv, i) => {
  if (lv.id !== i + 1) bad(`id sırası bozuk (${lv.id} ≠ ${i + 1})`);
  addRow(lv, 'paket');
  if (file.endsWith('levels.js') && LG.levelHash(lv) !== LG.levelHash(LG.makeLevel(lv.id))) bad(`paket seviye ${lv.id} oyun içi üreticiyle aynı değil (levels.js yeniden üretilmeli)`);
});
// örneklenmiş bölümler (üreticiden): ilk büyüme döngüsünün kalanı + ikinci döngü başı + ileri bölümler
const lastPack = Math.floor(LG.PREBUILT / PER);
const SAMPLED = SAMPLE ? [...new Set([...Array.from({ length: Math.max(0, GROW + 1 - lastPack) }, (_, k) => lastPack + 1 + k), 2 * GROW, 50, 100, 177, 250])].filter(c => c > lastPack) : [];
const t0 = Date.now();
SAMPLED.forEach(ch => { for (let k = 1; k <= PER; k++) addRow(Object.assign({}, LG.makeLevel((ch - 1) * PER + k)), 'örnek'); });

// bölüm raporu + bölüm kuralları
const chapters = [];
for (const ch of [...new Set(rows.map(r => r.ch))].sort((a, b) => a - b)) {
  const R = rows.filter(r => r.ch === ch && r.lv.id > LG.TUTORIAL.length);
  const c = { ch, grid: `${R[R.length - 1].lv.w}x${R[R.length - 1].lv.h}`, mean: {}, n: {}, shaped: R.filter(r => r.lv.mask).length };
  for (const t of ORDER) {
    const Rt = R.filter(r => r.tier === t);
    c.mean[t] = Rt.length ? Rt.reduce((s, r) => s + r.m.score, 0) / Rt.length : null;
    c.n[t] = Rt.length ? Rt.reduce((s, r) => s + r.m.arrows, 0) / Rt.length : null;
  }
  const avg = f => R.reduce((s, r) => s + f(r), 0) / R.length;
  c.fill = avg(r => r.m.fill); c.free = avg(r => r.m.freeRatio); c.depth = avg(r => r.m.depth); c.turns = avg(r => r.m.meanTurns); c.len = avg(r => r.m.meanLen);
  c.maxLen = Math.max(...R.map(r => r.m.maxLen)); c.soft = R.filter(r => r.soft).length; c.cnt = R.length;
  checkChapter(ch, R.map(r => ({ id: r.lv.id, tier: r.tier, score: r.m.score, turns: r.m.meanTurns, len: r.m.meanLen }))).forEach(bad);
  if (LG.sizeOfChapter(ch).w >= 14 && c.shaped < 3) bad(`bölüm ${ch}: şekilli Aşırı zor tahta sayısı ${c.shaped} (< 3)`);
  chapters.push(c);
}
// ok sayısı alanla artar: aynı kademe, bir büyüme döngüsü içinde bölümden bölüme
for (const t of ORDER) {
  for (let k = 1; k < chapters.length; k++) {
    const a = chapters[k - 1], b = chapters[k];
    if (b.ch !== a.ch + 1 || (b.ch - 1) % GROW === 0 || a.n[t] == null || b.n[t] == null) continue;
    if (!(b.n[t] > a.n[t])) bad(`${TR[t]}: bölüm ${b.ch} ok sayısı (${b.n[t].toFixed(0)}) bölüm ${a.ch} (${a.n[t].toFixed(0)}) değerinden fazla değil`);
  }
}
// zor kademelerde uzun, çok dönüşlü oklar (docs/17 §12)
const ext = rows.filter(r => r.tier === 'extreme' && r.lv.w >= 14), hard = rows.filter(r => r.tier === 'hard' && r.lv.w >= 14);
const mean = (a, f) => a.reduce((s, x) => s + f(x), 0) / (a.length || 1);
if (ext.length && mean(ext, r => r.m.meanTurns) < 3) bad(`Aşırı zor: ok başına ortalama dönüş ${mean(ext, r => r.m.meanTurns).toFixed(2)} < 3`);
if (ext.length && mean(ext, r => r.m.maxLen) < 20) bad(`Aşırı zor: en uzun ok ortalaması ${mean(ext, r => r.m.maxLen).toFixed(0)} < 20`);
if (hard.length && mean(hard, r => r.m.meanTurns) < 2) bad(`Zor: ok başına ortalama dönüş ${mean(hard, r => r.m.meanTurns).toFixed(2)} < 2`);

const f = (c) => ({ ch: c.ch, grid: c.grid, arrows: ORDER.map(t => (c.n[t] == null ? '-' : c.n[t].toFixed(0))), fill: (c.fill * 100).toFixed(1), free: (c.free * 100).toFixed(1), depth: c.depth.toFixed(1),
  turns: c.turns.toFixed(2), len: c.len.toFixed(1), maxLen: String(c.maxLen), scores: ORDER.map(t => (c.mean[t] == null ? '-' : c.mean[t].toFixed(1))), shaped: String(c.shaped), soft: `${c.soft}/${c.cnt}` });
if (MD) {
  console.log('\n| Bölüm | Izgara | Ok sayısı K / O / Z / A | Doluluk | Başta çıkabilen | Derinlik | Ort. dönüş | Ort. uzunluk | En uzun ok | Puan K / O / Z / A | Şekilli |\n|---|---|---|---|---|---|---|---|---|---|---|');
  chapters.forEach(c => { const x = f(c); console.log(`| ${x.ch} | ${x.grid} | ${x.arrows.join(' / ')} | %${x.fill} | %${x.free} | ${x.depth} | ${x.turns} | ${x.len} | ${x.maxLen} | ${x.scores.join(' / ')} | ${x.shaped} |`); });
} else {
  const hdr = 'bölüm  ızgara   ok sayısı K/O/Z/A     doluluk  başta-çık.  derinlik  dönüş  uzunluk  en-uzun   puan Kolay/Orta/Zor/Aşırı   şekilli  yumuşak';
  const line = (c) => { const x = f(c); return `${String(x.ch).padStart(5)}  ${x.grid.padEnd(6)}  ${x.arrows.map(s => s.padStart(4)).join(' ')}   %${x.fill.padStart(4)}    %${x.free.padStart(4)}     ${x.depth.padStart(6)}   ${x.turns}   ${x.len.padStart(5)}    ${x.maxLen.padStart(3)}     ${x.scores.map(s => s.padStart(6)).join(' ')}      ${x.shaped}     ${x.soft}`; };
  console.log(`\nPAKET (bölüm 1–${lastPack})\n` + hdr);
  chapters.filter(c => c.ch <= lastPack).forEach(c => console.log(line(c)));
  const sampled = chapters.filter(c => c.ch > lastPack);
  if (sampled.length) { console.log('\nÖRNEKLENMİŞ BÖLÜMLER (oyun içi üreticiyle üretildi, ' + ((Date.now() - t0) / 1000).toFixed(1) + ' sn)\n' + hdr); sampled.forEach(c => console.log(line(c))); }
}
const total = rows.length, notSoft = rows.filter(r => !r.soft).length;
console.log(`\ninceleme: ${total} seviye (paket ${L ? L.length : 0} + örnek ${total - (L ? L.length : 0)}); yumuşak kısıt (ort. dönüş) dışında: ${notSoft}`);
console.log(fail ? `\n${fail} denetim KALDI` : `\nTüm ${total} seviye GEÇTİ (yapı, çözülebilirlik, ızgara planı, tahta biçimi, kademe bandı, başta çıkabilen, paket == üretici); bölüm içi Kolay < Orta < Zor < Aşırı zor sırası doğru; ok sayısı alanla artıyor`);
process.exit(fail ? 1 : 0);
