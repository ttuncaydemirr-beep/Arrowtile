// Arrowtile — günlük bulmaca birim testi. Kullanım: node tools/test-daily.js
'use strict';
const path = require('path');
const D = require(path.join(__dirname, '..', 'game', 'js', 'daily.js'));
const S = require('./solver');

let pass = 0, fail = 0;
function check(name, cond, extra) { if (cond) pass++; else fail++; console.log(`${cond ? 'GEÇTİ' : 'KALDI'}  ${name}${extra ? '  (' + extra + ')' : ''}`); }

// 1) 366 gün: her bulmaca üretilir, yapısal olarak geçerli, çözülebilir; v1.3: 12x16, haftanın gününün kademe bandında; süre
const LG = require(path.join(__dirname, '..', 'game', 'js', 'levelgen.js'));
const WD = ['easy', 'easy', 'easy', 'medium', 'medium', 'hard', 'extreme'];
{
  let ok = 0, bad = [], maxMs = 0, total = 0;
  for (let i = 0; i < 366; i++) {
    const day = D.addDays('2026-10-01', i);
    const t0 = Date.now(); const p = D.puzzleFor(day); const ms = Date.now() - t0;
    maxMs = Math.max(maxMs, ms); total += ms;
    const m = p && LG.measure(p), tier = WD[D.weekdayIndex(day)], T = LG.TIERS[tier];
    const good = p && S.checkStructure(p).length === 0 && m.solvable && S.solve(p).solvable && p.w === 12 && p.h === 16 && p.diff === tier
      && m.fill >= T.band[0] - 1e-9 && m.fill <= T.band[1] + 1e-9 && m.initialFree <= Math.max(1, Math.floor(T.maxFree * m.arrows + 1e-9)) && p.par === p.arrows.length;
    if (good) ok++; else bad.push(day + ':' + tier + (m ? ` f${m.fill.toFixed(3)} ${m.initialFree}/${m.arrows}` : ''));
  }
  check('366 günün her biri için geçerli, çözülebilir, 12x16, haftanın gününün kademe bandında (doluluk, başta çıkabilen) bulmaca', ok === 366, bad.slice(0, 5).join(','));
  check('üretim süresi makul (gün başına ortalama < 150 ms, en kötü < 1500 ms)', total / 366 < 150 && maxMs < 1500, `ort ${(total / 366).toFixed(0)} ms, en kötü ${maxMs} ms`);
}
// 2) Belirlenimci: aynı gün aynı bulmaca, farklı gün farklı bulmaca
{
  const a = JSON.stringify(D.puzzleFor('2026-10-25')), b = JSON.stringify(D.puzzleFor('2026-10-25')), c = JSON.stringify(D.puzzleFor('2026-10-26'));
  check('aynı tarih → birebir aynı bulmaca (her cihazda aynı)', a === b);
  check('farklı tarih → farklı bulmaca', a !== c);
}
// 3) Haftanın gününe göre kademe (docs/09): Pzt–Çar Kolay, Per–Cum Orta, Cmt Zor, Paz Aşırı zor
{
  const days = ['2026-10-26', '2026-10-27', '2026-10-28', '2026-10-29', '2026-10-30', '2026-10-31', '2026-11-01'];
  check('kademeler: Pzt–Çar easy, Per–Cum medium, Cmt hard, Paz extreme', days.map(d => D.puzzleFor(d).diff).join(',') === WD.join(','));
  const mon = LG.measure(D.puzzleFor('2026-10-26')), sun = LG.measure(D.puzzleFor('2026-11-01'));
  check('Pazar (aşırı zor) Pazartesiden (kolay) daha dolu ve daha derin', sun.fill > mon.fill && sun.depth > mon.depth, `doluluk ${mon.fill.toFixed(2)}→${sun.fill.toFixed(2)}, derinlik ${mon.depth}→${sun.depth}`);
  check('weekdayIndex: 2026-10-26 Pazartesi=0, 2026-11-01 Pazar=6', D.weekdayIndex('2026-10-26') === 0 && D.weekdayIndex('2026-11-01') === 6);
}
// 4) Seri
{
  const dp = {};
  D.recordSolve(dp, '2026-10-20', 3); D.recordSolve(dp, '2026-10-21', 2); D.recordSolve(dp, '2026-10-22', 1);
  check('3 ardışık gün → seri 3, kupa 3', dp.streak === 3 && dp.trophies === 3 && dp.best === 3);
  const again = D.recordSolve(dp, '2026-10-22', 3);
  check('aynı gün tekrar çözmek ikinci kupa vermez, en iyi yıldız saklanır', !again.first && dp.trophies === 3 && dp.done['2026-10-22'] === 3);
  check('streakInfo: ertesi gün (henüz çözülmedi) seri sürüyor', D.streakInfo(dp, '2026-10-23').current === 3);
  check('streakInfo: bir gün atlanınca seri 0 görünür', D.streakInfo(dp, '2026-10-24').current === 0);
  D.recordSolve(dp, '2026-10-25', 3);
  check('gün atlandıktan sonra çözüm → seri 1, en iyi 3 korunur', dp.streak === 1 && dp.best === 3 && dp.trophies === 4);
  const cb = D.recordSolve(dp, '2026-10-23', 3); // saat geri alınmış
  check('saat geri alınınca kupa/seri verilmez, seri bozulmaz, son tarih geri gitmez', cb.clockBack && dp.streak === 1 && dp.last === '2026-10-25' && dp.trophies === 4 && !dp.done['2026-10-23']);
  const big = {}; for (let i = 0; i < 450; i++) D.recordSolve(big, D.addDays('2025-01-01', i), 3);
  check('kayıt boyutu sınırlı (en fazla 400 gün)', Object.keys(big.done).length === 400 && big.streak === 450);
}
console.log(`\n${fail ? fail + ' KALDI, ' : ''}${pass} GEÇTİ (günlük bulmaca birim testi)`);
process.exit(fail ? 1 : 0);
