// Arrowtile — 5.000 seviyenin tamamını üretip doğrular (1.2.0, docs/24). Kullanım:
//   node tools/verify-5000.js [--from 1] [--to 5000] [--workers N] [--out tools/level-hashes.json] [--no-write]
// Her seviye oyunun kendi üreticisiyle (LevelGen.makeLevel) üretilir ve BAĞIMLI OLMAYAN çözücüyle (tools/solver.js) denetlenir:
//   yapı (maske dahil), çözülebilirlik (iki çözücü uyuşur), par = ok sayısı, ızgara = specFor(id), tahta biçimi planı, doluluk kademe
//   bandında, başta çıkabilen ≤ kademe sınırı (en az 1), seviye 1-3 öğretici, üretim süresi.
// Bölüm düzeyinde: aynı bölümde Kolay < Orta < Zor < Aşırı zor (ortalama puan, dönüş, uzunluk); büyüme döngüsü içinde aynı kademenin
// ok sayısı bölümden bölüme artar (ok sayısı alanla büyür).
// Çıktı: tools/level-hashes.json — her seviyenin kanonik serileştirmesinin FNV-1a 32 özeti (LevelGen.canon / levelHash);
// Flutter altın testi rastgele örneklenen seviyelerde Dart üreticisinin aynı özeti verdiğini denetler.
// Hazır paket (game/js/levels.js) de aynı özetlerle karşılaştırılır. Çok çekirdekte worker_threads kullanır.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const os = require('os');
const { Worker, isMainThread, parentPort, workerData } = require('worker_threads');
const LG = require('../game/js/levelgen.js');
const { checkLevelData, checkChapter, growTol, tierGrew } = require('./level-checks');

const TIER_ORDER = ['easy', 'medium', 'hard', 'extreme'];
const TR = { easy: 'Kolay', medium: 'Orta', hard: 'Zor', extreme: 'Aşırı zor' };

function checkLevel(id) {
  const t0 = process.hrtime.bigint();
  const lv = LG.makeLevel(id);
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  const full = { id, w: lv.w, h: lv.h, par: lv.par, diff: lv.diff, arrows: lv.arrows };
  if (lv.mask) full.mask = lv.mask;
  const c = checkLevelData(full), m = c.m;
  return { id, hash: LG.levelHash(full), ms, tier: c.tier, w: lv.w, h: lv.h, n: m.arrows, fill: m.fill, free: m.initialFree, depth: m.depth, score: m.score,
    turns: m.meanTurns, len: m.meanLen, maxLen: m.maxLen, shaped: !!lv.mask, ok: !!lv.ok, rounds: lv.rounds, soft: c.soft, errs: c.errs };
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
    const c = { ch, size: `${chMap[ch][chMap[ch].length - 1].w}x${chMap[ch][chMap[ch].length - 1].h}`, by, mean: {}, n: {} };
    TIER_ORDER.forEach(t => { c.mean[t] = by[t].length ? mean(by[t], r => r.score) : null; c.n[t] = by[t].length ? mean(by[t], r => r.n) : null; });
    return c;
  });
  let orderFails = 0, growFails = 0;
  chapters.forEach(c => {
    const e = checkChapter(c.ch, chMap[c.ch]); e.forEach(bad); orderFails += e.length;
  });
  // ok sayısı alanla artar: büyüme döngüsü içinde aynı kademe, bölümden bölüme
  for (let k = 1; k < chapters.length; k++) {
    const a = chapters[k - 1], b = chapters[k];
    if (b.ch !== a.ch + 1 || (b.ch - 1) % LG.GROW_CHAPTERS === 0) continue;
    for (const t of TIER_ORDER) if (a.n[t] != null && b.n[t] != null && a.by[t].length === 5 && tierGrew(t, b.ch) && !(b.n[t] > a.n[t] * growTol(t))) { bad(`${TR[t]}: bölüm ${b.ch} ok sayısı (${b.n[t].toFixed(0)}) bölüm ${a.ch} (${a.n[t].toFixed(0)}) değerinden fazla değil`); growFails++; }
  }
  // şekilli tahtalar: yeterince büyük bölümlerde Aşırı zor seviyelerin en az 3'ü şekilli
  chapters.forEach(c => { if (LG.sizeOfChapter(c.ch).w >= 14 && c.by.extreme.length === 5 && c.by.extreme.filter(r => r.shaped).length < 3) bad(`bölüm ${c.ch}: şekilli Aşırı zor tahta < 3`); });

  // 3) hazır paket == üretici
  try {
    const ctx = { window: {} };
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, '..', 'game', 'js', 'levels.js'), 'utf8'), ctx);
    const P = ctx.window.LEVELS;
    if (!Array.isArray(P) || P.length !== LG.PREBUILT) bad(`levels.js ${LG.PREBUILT} seviye içermeli (${P && P.length})`);
    else P.forEach(lv => { const r = R[lv.id - FROM]; if (r && LG.levelHash(lv) !== r.hash) bad(`levels.js seviye ${lv.id} oyun içi üreticiyle aynı değil`); });
  } catch (e) { bad('levels.js okunamadı: ' + e.message); }

  // 4) belirlenimlilik: temiz bir süreçte (bu iş parçacığında) yeniden üretim aynı özeti verir
  const samples = [4, 17, 38, 96, 100, 101, 176, 180, 777, 2500, 4999, 5000].filter(i => i >= FROM && i <= TO);
  samples.forEach(id => { const h = LG.levelHash(LG.makeLevel(id)); if (h !== R[id - FROM].hash) bad(`seviye ${id} belirlenimli değil (${h} ≠ ${R[id - FROM].hash})`); });

  // 5) süre istatistiği
  const stat = (arr) => { const a = arr.slice().sort((x, y) => x - y); return { n: a.length, avg: a.reduce((s, x) => s + x, 0) / a.length, p50: a[Math.floor(a.length * 0.5)], p95: a[Math.floor(a.length * 0.95)], max: a[a.length - 1] }; };
  const timeBy = {};
  TIER_ORDER.forEach(t => { const rs = R.filter(r => r.tier === t && r.id > 3); if (rs.length) timeBy[t] = stat(rs.map(r => r.ms)); });
  const maxBoard = R.filter(r => { const cs = LG.sizeOfChapter(LG.chapterOf(r.id)); return cs.w === LG.MAX_W && cs.h === LG.MAX_H; }); // en büyük bölüm (1.2.0 #2: Kolay/Orta daha küçük tahtada)
  const maxBy = {}; TIER_ORDER.forEach(t => { const rs = maxBoard.filter(r => r.tier === t); if (rs.length) maxBy[t] = stat(rs.map(r => r.ms)); });
  const extStat = maxBy.extreme || null;
  if (extStat && extStat.p95 > 1500) bad(`Aşırı zor, en büyük tahta: üretim p95 ${extStat.p95.toFixed(0)} ms > 1500 ms`);
  const slowest = R.slice().sort((a, b) => b.ms - a.ms)[0];
  if (slowest.ms > 5000) bad(`seviye ${slowest.id} üretimi ${slowest.ms.toFixed(0)} ms (> 5 sn)`);

  // rapor
  const notOk = R.filter(r => !r.ok && r.id > 3);
  const f1 = (x) => x.toFixed(1).padStart(7);
  console.log(`\nüretilen: ${R.length} seviye (${FROM}–${TO}), işçi: ${WORKERS}, süre: ${wall.toFixed(0)} sn, CPU toplamı ${(R.reduce((s, r) => s + r.ms, 0) / 1000).toFixed(1)} sn`);
  console.log(`seviye hatası (yapı/çözülebilirlik/bant/biçim): ${R.filter(r => r.errs.length).length}; bölüm içi sıra ihlali: ${orderFails}; ok sayısı büyüme ihlali: ${growFails}; yumuşak kısıt (ort. dönüş) dışında kalan: ${notOk.length}; şekilli tahta: ${R.filter(r => r.shaped).length}`);
  console.log('\nüretim süresi (ms)        adet     ort     p50     p95    maks');
  TIER_ORDER.forEach(t => { const s = timeBy[t]; if (s) console.log(`  ${TR[t].padEnd(20)} ${String(s.n).padStart(5)} ${f1(s.avg)} ${f1(s.p50)} ${f1(s.p95)} ${f1(s.max)}`); });
  TIER_ORDER.forEach(t => { const s = maxBy[t], sz = LG.sizeOf((LG.GROW_CHAPTERS - 1) * LG.PER_CHAPTER + TIER_ORDER.indexOf(t) * 5 + 1); if (s) console.log(`  ${(TR[t] + ' ' + sz.w + 'x' + sz.h).padEnd(20)} ${String(s.n).padStart(5)} ${f1(s.avg)} ${f1(s.p50)} ${f1(s.p95)} ${f1(s.max)}`); });
  console.log(`  en yavaş seviye: ${slowest.id} (${slowest.ms.toFixed(0)} ms, ${TR[slowest.tier]}, ${slowest.w}x${slowest.h})`);
  console.log('\nbölüm   ızgara   puan Kolay / Orta / Zor / Aşırı zor        ok sayısı K / O / Z / A');
  const printCh = (c) => console.log(`${String(c.ch).padStart(5)}   ${c.size.padEnd(6)} ${TIER_ORDER.map(t => (c.mean[t] == null ? '-' : c.mean[t].toFixed(1)).padStart(7)).join(' ')}      ${TIER_ORDER.map(t => (c.n[t] == null ? '-' : c.n[t].toFixed(0)).padStart(5)).join(' ')}`);
  chapters.filter(c => c.ch <= LG.GROW_CHAPTERS + 1).forEach(printCh);
  console.log('  ...');
  chapters.filter(c => c.ch > LG.GROW_CHAPTERS + 1 && c.ch % 50 === 0).forEach(printCh);
  const ex = R.filter(r => r.tier === 'extreme' && r.w >= 14), hd = R.filter(r => r.tier === 'hard' && r.w >= 14);
  if (ex.length) console.log(`\nAşırı zor (tahta ≥ 14 sütun): ort. dönüş ${mean(ex, r => r.turns).toFixed(2)}, ort. ok uzunluğu ${mean(ex, r => r.len).toFixed(1)}, en uzun ok ort. ${mean(ex, r => r.maxLen).toFixed(0)}; Zor: ort. dönüş ${hd.length ? mean(hd, r => r.turns).toFixed(2) : '-'}, ort. uzunluk ${hd.length ? mean(hd, r => r.len).toFixed(1) : '-'}`);

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
