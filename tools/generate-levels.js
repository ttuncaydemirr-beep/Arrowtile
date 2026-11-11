// Arrowtile — hazır seviye paketi üretici (v1.5, docs/15 §5). Kullanım: node tools/generate-levels.js [--out dosya] [--count N]
// Paketteki ilk PREBUILT (200) seviye, oyun içi üreticiyle AYNI saf fonksiyonla üretilir: LevelGen.makeLevel(id)
// (özellikler specFor(id), tohum seedFor(id, tur)); yani hazır seviye N == oyunun seviye N'i üretmesiyle elde edeceği seviye.
// 201–5.000 (ve sonrası) oyunda aynı fonksiyonla üretilir; tools/verify-5000.js hepsini üretip doğrular.
// Bölüm = 10 seviye; sıra: 1-2-3 Kolay, 4-5-6 Orta, 7-8 Zor, 9-10 Aşırı zor. Seviye 1–3 öğretici (levelgen.js TUTORIAL).
'use strict';
const fs = require('fs');
const path = require('path');
const G = require('../game/js/levelgen.js');

const ci = process.argv.indexOf('--count');
const COUNT = ci > 0 ? Number(process.argv[ci + 1]) : G.PREBUILT;
const t0 = Date.now(), times = {};
const levels = [];
for (let id = 1; id <= COUNT; id++) {
  const ts = Date.now();
  const lv = G.makeLevel(id);
  levels.push({ id, w: lv.w, h: lv.h, diff: lv.diff, mask: lv.mask, arrows: lv.arrows.map(a => ({ cells: G.cellsOf(a).map(c => [c[0], c[1]]), dir: a.dir })), ok: lv.ok });
  (times[lv.diff] = times[lv.diff] || []).push(Date.now() - ts);
  if (process.env.VERBOSE) process.stderr.write(`\r${id}/${COUNT} ${lv.w}x${lv.h} ${lv.diff} ok=${lv.ok}   `);
}
levels.forEach(l => { l.par = l.arrows.length; });

const out = '// Arrowtile — seviye verisi 1.2.0 (v20) (tools/generate-levels.js ile üretildi, tools/validate-levels.js ile doğrulandı)\n'
  + '// İlk ' + COUNT + ' seviye pakette hazır; sonrası oyunda aynı üreticiyle (game/js/levelgen.js makeLevel) üretilir.\n'
  + '// cells = kuyruktan başa komşu hücreler [x,y] (0 tabanlı, sol üst 0,0); dir = baş yönü; par = optimal dokunma = ok sayısı\n'
  + '// diff = SEVİYE kademesi (easy|medium|hard|extreme); bölüm = 20 seviye: 5 Kolay, 5 Orta, 5 Zor, 5 Aşırı zor; mask (varsa) = şekilli tahta satırları, 1 = oynanabilir hücre\n'
  + 'window.LEVELS = [\n'
  + levels.map(l => `  { id: ${l.id}, w: ${l.w}, h: ${l.h}, par: ${l.par}, diff: "${l.diff}", ${l.mask ? "mask: " + JSON.stringify(l.mask) + ", " : ""}arrows: [`
    + l.arrows.map(a => `{cells:${JSON.stringify(a.cells)},dir:"${a.dir}"}`).join(',') + '] }').join(',\n')
  + '\n];\n';
const oi = process.argv.indexOf('--out');
const target = oi > 0 ? path.resolve(process.argv[oi + 1]) : path.join(__dirname, '..', 'game', 'js', 'levels.js');
fs.writeFileSync(target, out);
console.log(`${levels.length} seviye yazıldı -> ${target} (${((Date.now() - t0) / 1000).toFixed(0)} sn, ${(out.length / 1024).toFixed(0)} KB)`);
console.log('kısıtı (derinlik penceresi/kıvrımlı oran dahil) tam sağlamayan seviye:', levels.filter(l => l.ok === false).map(l => l.id).join(',') || 'yok');
for (const [t, a] of Object.entries(times)) console.log(`üretim süresi ${t}: ort ${(a.reduce((s, x) => s + x, 0) / a.length).toFixed(0)} ms, en çok ${Math.max(...a)} ms`);
