// Arrowtile -> Flutter: game/js/levels.js  =>  flutter/arrowtile/lib/data/levels.json
// Kullanım (proje kökünden): node tools/flutter/export-levels.js
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm');
const ROOT = path.join(__dirname, '..', '..');
const ctx = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(ROOT, 'game', 'js', 'levels.js'), 'utf8'), ctx);
const L = ctx.window.LEVELS;
if (!Array.isArray(L) || L.length !== 216) throw new Error('beklenen 216 seviye, bulunan ' + (L && L.length));
const out = L.map((lv, i) => {
  if (lv.id !== i + 1) throw new Error('id sırası bozuk: ' + lv.id);
  lv.arrows.forEach(a => { if (!a.cells || !a.dir) throw new Error('eski biçim ok: seviye ' + lv.id); });
  return { id: lv.id, w: lv.w, h: lv.h, par: lv.par, diff: lv.diff, arrows: lv.arrows.map(a => ({ cells: a.cells, dir: a.dir })) };
});
const dst = path.join(ROOT, 'flutter', 'arrowtile', 'lib', 'data', 'levels.json');
fs.mkdirSync(path.dirname(dst), { recursive: true });
fs.writeFileSync(dst, JSON.stringify(out));
console.log(`levels.json: ${out.length} seviye, ${out.reduce((s, l) => s + l.arrows.length, 0)} ok, ${fs.statSync(dst).size} bayt -> ${path.relative(ROOT, dst)}`);
