// Arrowtile — seviye üretici (v1.3, docs/09-bolum-dongusu.md). Kullanım: node tools/generate-levels.js [--out dosya]
// Bölüm/kademe/boyut kuralları oyunla ortaktır: game/js/levelgen.js specFor()/makeLevel() — 216'dan sonraki sonsuz
// seviyeler oyunda aynı kurallarla, seviye numarasından türetilen sabit tohumla üretilir.
// Döngü: 3 Kolay → 3 Orta → 2 Zor → 1 Aşırı zor bölüm (12'şer seviye); 2 tam döngü = 18 bölüm = 216 seviye hazır.
// Seviye 1–3 öğretici (düz oklar) aynen korunur. Seviye 4 en az bir kıvrımlı ok içerir (ipucu baloncuğuyla tanıtılır).
'use strict';
const fs = require('fs');
const path = require('path');
const G = require('../game/js/levelgen.js');

const TUTORIAL = [ // v1.1 seviye 1-3 (değişmez)
  { w: 3, h: 3, arrows: [{ x: 2, y: 0, dir: 'D', len: 2 }, { x: 2, y: 2, dir: 'L', len: 2 }] },
  { w: 3, h: 3, arrows: [{ x: 0, y: 2, dir: 'R', len: 2 }, { x: 2, y: 2, dir: 'U', len: 1 }, { x: 2, y: 0, dir: 'L', len: 2 }] },
  { w: 4, h: 4, arrows: [{ x: 3, y: 1, dir: 'D', len: 2 }, { x: 2, y: 3, dir: 'R', len: 2 }, { x: 0, y: 2, dir: 'R', len: 2 }, { x: 1, y: 0, dir: 'D', len: 2 }] },
];
const toCells = a => ({ cells: G.cellsOf(a).map(c => [c[0], c[1]]), dir: a.dir });

const levels = TUTORIAL.map((t, k) => ({ id: k + 1, w: t.w, h: t.h, diff: 'easy', arrows: t.arrows.map(toCells) }));
const t0 = Date.now(), times = {};
for (let id = 4; id <= G.PREBUILT; id++) {
  const sp = G.specFor(id), ts = Date.now();
  // Aşırı zor: çok deneme, en derin (en yüksek puanlı) aday; diğerleri: kısıtları sağlayan ilk aday (en çok 5 tur)
  let best = null;
  const rounds = sp.tier === 'extreme' ? 4 : 5;
  let r = 0;
  for (; r < rounds || (best && !best.g.ok && r < 16); r++) { // kısıt sağlanmadıysa en çok 16 tura dek dene
    const g = G.generate(sp, G.seedFor(id, r));
    if (!g) continue;
    if (id === 4 && !g.arrows.some(G.isCurved)) continue; // ilk kıvrımlı ok seviye 4'te
    const key = (g.ok ? 1e6 : 0) + g.m.score;
    if (!best || key > best.key) best = { key, g };
    if (g.ok && sp.tier !== 'extreme') break;
  }
  if (!best) throw new Error(`Seviye ${id} üretilemedi`);
  levels.push({ id, w: sp.w, h: sp.h, diff: sp.tier, arrows: best.g.arrows.map(toCells), ok: best.g.ok });
  (times[sp.tier] = times[sp.tier] || []).push(Date.now() - ts);
  if (process.env.VERBOSE) process.stderr.write(`\r${id}/${G.PREBUILT} ${sp.w}x${sp.h} ${sp.tier} ok=${best.g.ok}   `);
}
levels.forEach(l => { l.m = G.measure(l); l.par = l.arrows.length; });

const out = '// Arrowtile — seviye verisi v1.3 (tools/generate-levels.js ile üretildi, tools/validate-levels.js ile doğrulandı)\n'
  + '// cells = kuyruktan başa komşu hücreler [x,y] (0 tabanlı, sol üst 0,0); dir = baş yönü; par = optimal dokunma = ok sayısı\n'
  + '// diff = bölüm kademesi (easy|medium|hard|extreme), docs/09 döngüsü: game/js/levelgen.js tierOf(bölüm)\n'
  + 'window.LEVELS = [\n'
  + levels.map(l => `  { id: ${l.id}, w: ${l.w}, h: ${l.h}, par: ${l.par}, diff: "${l.diff}", arrows: [`
    + l.arrows.map(a => `{cells:${JSON.stringify(a.cells)},dir:"${a.dir}"}`).join(',') + '] }').join(',\n')
  + '\n];\n';
const oi = process.argv.indexOf('--out');
const target = oi > 0 ? path.resolve(process.argv[oi + 1]) : path.join(__dirname, '..', 'game', 'js', 'levels.js');
fs.writeFileSync(target, out);
console.log(`${levels.length} seviye yazıldı -> ${target} (${((Date.now() - t0) / 1000).toFixed(0)} sn, ${(out.length / 1024).toFixed(0)} KB)`);
console.log('kısıtı sağlamayan seviye:', levels.filter(l => l.ok === false).map(l => l.id).join(',') || 'yok');
for (const [t, a] of Object.entries(times)) console.log(`üretim süresi ${t}: ort ${(a.reduce((s, x) => s + x, 0) / a.length).toFixed(0)} ms, en çok ${Math.max(...a)} ms`);
