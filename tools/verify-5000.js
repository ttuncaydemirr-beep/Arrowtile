// Arrowtile — 5.000 seviyenin tamamını üretip doğrular (docs/15 §5). Kullanım:
//   node tools/verify-5000.js [--from 1] [--to 5000] [--workers N] [--out tools/level-hashes.json] [--no-write]
// Her seviye oyunun kendi üreticisiyle (LevelGen.makeLevel) üretilir ve BAĞIMLI OLMAYAN çözücüyle (tools/solver.js) denetlenir:
//   yapı, çözülebilirlik (iki çözücü uyuşur), par = ok sayısı, ızgara = specFor(id), doluluk kademe bandında, başta çıkabilen
//   ≤ kademe sınırı (en az 1), seviye 1-3 öğretici, seviye 4 kıvrımlı ok içerir, üretim süresi.
// Bölüm düzeyinde: aynı bölümde Kolay < Orta < Zor < Aşırı zor (ortalama puan); aynı kademe bölümden bölüme gevşek monoton
// artar (10 bölümlük pencerelerde, tahta büyüyüp sabitlenene dek); kıvrımlı oran hedefin en çok 0,12 altında.
// Çıktı: tools/level-hashes.json — her seviyenin kanonik serileştirmesinin FNV-1a 32 özeti (LevelGen.canon / levelHash);
// Flutter altın testi rastgele örneklenen seviyelerde Dart üreticisinin aynı özeti verdiğini denetler.
// Hazır paket (game/js/levels.js, ilk 200) de aynı özetlerle karşılaştırılır. Çok çekirdekte worker_threads kullanır.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const os = require('os');
const { Worker, isMainThread, parentPort, workerData } = require('worker_threads');
const LG = require('../game/js/levelgen.js');
const { checkLevelData, CURVE_TOL } = require('./level-checks');

const TIER_ORDER = ['easy', 'medium', 'hard', 'extreme'];
const TR = { easy: 'Kolay', medium: 'Orta', hard: 'Zor', extreme: 'Aşırı zor' };

function checkLevel(id) {
  const t0 = Date.now();
  const lv = LG.makeLevel(id);
  const ms = Date.now() - t0;
  const full = { id, w: lv.w, h: lv.h, par: lv.par, diff: lv.diff, arrows: lv.arrows };
  const c = checkLevelData(full), m = c.m;
  return { id, hash: LG.levelHash(full), ms, tier: c.tier, w: lv.w, h: lv.h, n: m.arrows, fill: m.fill, free: m.initialFree, depth: m.depth, score: m.score,
    curved: m.curvedRatio, ok: !!lv.ok, rounds: lv.rounds, inWindow: c.inWindow, errs: c.errs };
}

if (!isMainThread) {
  // işçi: ids paylaşımlı sıradan (ana iş parçacığı parça parça verir)
  parentPort.on('message', (msg) => {
    if (msg.done) { process.exit(0); }
    const out = [];
    for (let id = msg.from; id <= msg.to; id++) out.push(checkLevel(id));
    parentPort.postMessage({ out });
  });
  parentPort.postMessage({ ready: true });
} else {
  main().catch(e => { console.error(e); process.exit(2); });
}

async function main() {
  const args = process.argv.slice(2);
  const opt = (k, d) => { const i = args.indexOf('--' + k); return i >= 0 ? args[i + 1] : d; };
  const FROM = Number(opt('from', 1)), TO = Number(opt('to', LG.DESIGNED));
  const WORKERS = Math.max(1, Number(opt('workers', Math.max(1, os.cpus().length))));
  const outFile = path.resolve(opt('out', path.join(__dirname, 'level-hashes.json')));
  const full = FROM === 1 && TO === LG.DESIGNED;
  const CHUNK = 20;
  const T0 = Date.now();
  const results = new Array(TO - FROM + 1);
  let next = FROM, finished = 0, doneCount = 0;
  const total = TO - FROM + 1;
  await new Promise((resolve, reject) => {
    const workers = [];
    const feed = (w) => {
      if (next > TO) { w.postMessage({ done: true }); finished++; if (finished === WORKERS) resolve(); return; }
      const from = next, to = Math.min(TO, next + CHUNK - 1); next = to + 1;
      w.postMessage({ from, to });
    };
    for (let k = 0; k < WORKERS; k++) {
      const w = new Worker(__filename);
      workers.push(w);
      w.on('message', (msg) => {
        if (msg.out) {
          msg.out.forEach(r => { results[r.id - FROM] = r; });
          doneCount += msg.out.length;
          if (doneCount % 200 < CHUNK) process.stderr.write(`\r${doneCount}/${total}  ${((Date.now() - T0) / 1000).toFixed(0)} sn   `);
        }
        feed(w);
      });
      w.on('error', reject);
    }
  });
  process.stderr.write('\n');
  const wall = (Date.now() - T0) / 1000;

  let fail = 0;
  const bad = (m) => { if (fail < 60) console.log('KALDI: ' + m); fail++; };
  const R = results;

  // 1) seviye düzeyi
  R.forEach(r => { if (r.errs.length) bad(`seviye ${r.id} (${r.w}x${r.h}, ${TR[r.tier]}): ${r.errs.join('; ')}`); });

  // 2) bölüm düzeyi
  const chMap = {};
  R.forEach(r => { if (r.id > 3) (chMap[LG.chapterOf(r.id)] = chMap[LG.chapterOf(r.id)] || []).push(r); });
  const mean = (a, f) => a.reduce((s, x) => s + f(x), 0) / a.length;
  const chapters = Object.keys(chMap).map(Number).sort((a, b) => a - b).map(ch => {
    const by = {}; TIER_ORDER.forEach(t => { by[t] = chMap[ch].filter(r => r.tier === t); });
    const c = { ch, size: `${chMap[ch][0].w}x${chMap[ch][0].h}`, by, mean: {} };
    TIER_ORDER.forEach(t => { c.mean[t] = by[t].length ? mean(by[t], r => r.score) : null; });
    return c;
  });
  let orderFails = 0;
  chapters.forEach(c => {
    let prev = null;
    for (const t of TIER_ORDER) {
      if (c.mean[t] == null) continue;
      if (prev && !(c.mean[t] > c.mean[prev])) { bad(`bölüm ${c.ch}: ${TR[t]} (${c.mean[t].toFixed(1)}) ${TR[prev]} (${c.mean[prev].toFixed(1)}) ortalamasından zor değil`); orderFails++; }
      prev = t;
    }
  });
  // aynı kademe bölümden bölüme gevşek monoton artar: tahta büyürken (bölüm 1–20) 10 bölümlük pencere ortalamaları %4 toleransla azalmaz;
  // tahta sabitlendikten sonra (bölüm 21+) pencereler plato ortalamasının ±%6'sı içinde kalır (sistematik düşüş/artış yok)
  const WIN = 10, mono = {};
  for (const t of TIER_ORDER) {
    const blocks = [];
    for (let s = 0; s < chapters.length; s += WIN) {
      const rs = []; chapters.slice(s, s + WIN).forEach(c => c.by[t].forEach(r => rs.push(r)));
      if (rs.length >= 8) blocks.push({ from: chapters[s].ch, score: mean(rs, r => r.score), depth: mean(rs, r => r.depth), curved: mean(rs, r => r.curved) });
    }
    mono[t] = blocks;
    const grow = blocks.filter(b => b.from <= 11), plateau = blocks.filter(b => b.from >= 21);
    for (let k = 1; k < grow.length; k++) if (grow[k].score < grow[k - 1].score * 0.96) bad(`${TR[t]}: bölüm ${grow[k].from}+ penceresi (${grow[k].score.toFixed(1)}) önceki pencereden (${grow[k - 1].score.toFixed(1)}) düşük`);
    if (grow.length && plateau.length && plateau[0].score < grow[grow.length - 1].score * 0.96) bad(`${TR[t]}: plato (bölüm 21+) büyüme evresinin gerisine düştü`);
    if (plateau.length) {
      const pm = plateau.reduce((s, b) => s + b.score, 0) / plateau.length;
      plateau.forEach(b => { if (Math.abs(b.score - pm) > pm * 0.06) bad(`${TR[t]}: bölüm ${b.from}+ penceresi (${b.score.toFixed(1)}) plato ortalamasından (${pm.toFixed(1)}) %6'dan fazla sapıyor`); });
    }
    blocks.forEach(b => { if (b.curved < LG.TIERS[t].curve - CURVE_TOL[t]) bad(`${TR[t]}: bölüm ${b.from}+ kıvrımlı oran %${(b.curved * 100).toFixed(0)} hedefin (%${LG.TIERS[t].curve * 100}) çok altında`); });
  }

  // 3) hazır paket == üretici
  try {
    const ctx = { window: {} };
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, '..', 'game', 'js', 'levels.js'), 'utf8'), ctx);
    const P = ctx.window.LEVELS;
    if (!Array.isArray(P) || P.length !== LG.PREBUILT) bad(`levels.js ${LG.PREBUILT} seviye içermeli (${P && P.length})`);
    else P.forEach(lv => { const r = R[lv.id - FROM]; if (r && LG.levelHash(lv) !== r.hash) bad(`levels.js seviye ${lv.id} oyun içi üreticiyle aynı değil`); });
  } catch (e) { bad('levels.js okunamadı: ' + e.message); }

  // 4) belirlenimlilik: temiz bir süreçte (bu iş parçacığında) yeniden üretim aynı özeti verir
  const samples = [4, 17, 38, 99, 150, 201, 777, 2500, 4999, 5000].filter(i => i >= FROM && i <= TO);
  samples.forEach(id => { const h = LG.levelHash(LG.makeLevel(id)); if (h !== R[id - FROM].hash) bad(`seviye ${id} belirlenimli değil (${h} ≠ ${R[id - FROM].hash})`); });

  // 5) süre istatistiği
  const stat = (arr) => { const a = arr.slice().sort((x, y) => x - y); return { n: a.length, avg: a.reduce((s, x) => s + x, 0) / a.length, p50: a[Math.floor(a.length * 0.5)], p95: a[Math.floor(a.length * 0.95)], max: a[a.length - 1] }; };
  const timeBy = {};
  TIER_ORDER.forEach(t => { const rs = R.filter(r => r.tier === t && r.id > 3); if (rs.length) timeBy[t] = stat(rs.map(r => r.ms)); });
  const maxBoard = R.filter(r => r.w === LG.MAX_W && r.h === LG.MAX_H && r.id > 3);
  const extMax = maxBoard.filter(r => r.tier === 'extreme');
  const extStat = extMax.length ? stat(extMax.map(r => r.ms)) : null;
  if (extStat && extStat.avg > 1500) bad(`Aşırı zor, en büyük tahta: ortalama üretim ${extStat.avg.toFixed(0)} ms > 1500 ms`);
  const slowest = R.slice().sort((a, b) => b.ms - a.ms)[0];
  if (slowest.ms > 20000) bad(`seviye ${slowest.id} üretimi ${slowest.ms} ms (> 20 sn)`);

  // rapor
  const notOk = R.filter(r => !r.ok && r.id > 3), outWin = R.filter(r => !r.inWindow && r.id > 3);
  console.log(`\nüretilen: ${R.length} seviye (${FROM}–${TO}), işçi: ${WORKERS}, süre: ${wall.toFixed(0)} sn (${(wall / 60).toFixed(1)} dk), CPU toplamı ${(R.reduce((s, r) => s + r.ms, 0) / 1000).toFixed(0)} sn`);
  console.log(`seviye hatası (yapı/çözülebilirlik/bant): ${R.filter(r => r.errs.length).length}; bölüm içi sıra ihlali: ${orderFails}; yumuşak kısıt (derinlik penceresi/kıvrımlı oran) dışında kalan: ${notOk.length}, derinlik penceresi dışında: ${outWin.length}`);
  console.log('\nüretim süresi (ms)   adet    ort    p50    p95    maks');
  TIER_ORDER.forEach(t => { const s = timeBy[t]; if (s) console.log(`  ${TR[t].padEnd(16)} ${String(s.n).padStart(5)} ${s.avg.toFixed(0).padStart(6)} ${String(s.p50).padStart(6)} ${String(s.p95).padStart(6)} ${String(s.max).padStart(7)}`); });
  if (extStat) console.log(`  Aşırı zor 22x31   ${String(extStat.n).padStart(5)} ${extStat.avg.toFixed(0).padStart(6)} ${String(extStat.p50).padStart(6)} ${String(extStat.p95).padStart(6)} ${String(extStat.max).padStart(7)}`);
  console.log(`  en yavaş seviye: ${slowest.id} (${slowest.ms} ms, ${TR[slowest.tier]}, ${slowest.w}x${slowest.h})`);
  console.log('\nbölüm   ızgara   Kolay   Orta    Zor     Aşırı zor  (ort. puan)');
  const printCh = (c) => console.log(`${String(c.ch).padStart(5)}   ${c.size.padEnd(6)} ${TIER_ORDER.map(t => (c.mean[t] == null ? '-' : c.mean[t].toFixed(1)).padStart(7)).join(' ')}`);
  chapters.filter(c => c.ch <= 12).forEach(printCh);
  console.log('  ...');
  chapters.filter(c => c.ch > 12 && c.ch % 50 === 0).forEach(printCh);
  console.log('\nkademe, 10 bölümlük pencere ortalama puanı (gevşek monoton artış):');
  TIER_ORDER.forEach(t => console.log(`  ${TR[t].padEnd(10)} ` + mono[t].map(b => b.score.toFixed(0)).join(' ')));

  if (full && !args.includes('--no-write')) {
    const doc = { format: 'FNV-1a 32 (UTF-8/ASCII kod birimleri), 8 onaltılık hane, LevelGen.canon(level) üzerinden; hashes[i] = seviye i+1',
      canon: 'id:WxH:tier:x,y;x,y;...>D|x,y;...>D  (oklar üretici sırasında; hücreler kuyruktan başa)',
      generator: LG.VERSION, count: R.length, hashes: R.map(r => r.hash) };
    if (fail === 0) { fs.writeFileSync(outFile, JSON.stringify(doc) + '\n'); console.log(`\n${outFile} yazıldı (${R.length} özet)`); }
    else console.log('\n(hata olduğu için level-hashes.json yazılmadı)');
  }
  console.log(fail ? `\n${fail} denetim KALDI` : `\nTüm ${R.length} seviye GEÇTİ`);
  process.exit(fail ? 1 : 0);
}
