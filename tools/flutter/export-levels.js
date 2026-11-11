// Arrowtile -> Flutter: game/js/levels.js  =>  flutter/arrowtile/lib/data/levels.json
// Kullanım (proje kökünden): node tools/flutter/export-levels.js
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm');
const ROOT = path.join(__dirname, '..', '..');
const LG = require(path.join(ROOT, 'game', 'js', 'levelgen.js'));
const HASHES = JSON.parse(fs.readFileSync(path.join(ROOT, 'tools', 'level-hashes.json'), 'utf8')).hashes;
const ctx = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(ROOT, 'game', 'js', 'levels.js'), 'utf8'), ctx);
const L = ctx.window.LEVELS;
if (!Array.isArray(L) || L.length !== LG.PREBUILT) throw new Error('beklenen ' + LG.PREBUILT + ' seviye, bulunan ' + (L && L.length));
const out = L.map((lv, i) => {
  if (lv.id !== i + 1) throw new Error('id sırası bozuk: ' + lv.id);
  lv.arrows.forEach(a => { if (!a.cells || !a.dir) throw new Error('eski biçim ok: seviye ' + lv.id); });
  if (LG.levelHash(lv) !== HASHES[i]) throw new Error('seviye ' + lv.id + ' tools/level-hashes.json özetiyle uyuşmuyor (verify-5000 çalıştırın)');
  const o = { id: lv.id, w: lv.w, h: lv.h, par: lv.par, diff: lv.diff };
  if (lv.mask) o.mask = lv.mask; // 1.2.0: şekilli tahta (satırlar, '1' = oynanabilir)
  o.arrows = lv.arrows.map(a => ({ cells: a.cells, dir: a.dir }));
  return o;
});
const dst = path.join(ROOT, 'flutter', 'arrowtile', 'lib', 'data', 'levels.json');
fs.mkdirSync(path.dirname(dst), { recursive: true });
fs.writeFileSync(dst, JSON.stringify(out));
console.log(`levels.json: ${out.length} seviye, ${out.reduce((s, l) => s + l.arrows.length, 0)} ok, ${fs.statSync(dst).size} bayt -> ${path.relative(ROOT, dst)}`);
