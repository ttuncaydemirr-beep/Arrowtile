// Arrowtile -> Flutter: game/js/i18n.js  =>  lib/l10n/app_{tr,en,de,ar}.arb  (+ anahtar eşlemesi)
// Anahtar dönüşümü: "game.out_of_lives_title" -> gameOutOfLivesTitle. Mağaza listesi metinleri (store.*), meta.dir ve
// yalnız web'de kullanılan app.rotate ARB'ye alınmaz (uygulama içinde kullanılmaz).
// Düz kesme işareti (') ICU/gen-l10n ayrıştırıcısını karıştırmasın diye tipografik ’ ile değiştirilir (yalnız en'de 6 yer).
// Kullanım: node tools/flutter/export-arb.js
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm');
const ROOT = path.join(__dirname, '..', '..');
const ctx = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(ROOT, 'game', 'js', 'i18n.js'), 'utf8'), ctx);
const D = ctx.window.I18N, LANGS = ['tr', 'en', 'de', 'ar'];
const SKIP = k => /^store\./.test(k) || k === 'meta.dir' || k === 'app.rotate';
const camel = k => k.split(/[._]/).map((p, i) => i === 0 ? p : p[0].toUpperCase() + p.slice(1)).join('');
const PH = { n: 'int', max: 'int', v: 'String' };
const keys = Object.keys(D.tr).filter(k => !SKIP(k));
const names = {};
for (const k of keys) { const c = camel(k); if (names[c]) throw new Error('ARB anahtar çakışması: ' + c); names[c] = k; }
const outDir = path.join(ROOT, 'flutter', 'arrowtile', 'lib', 'l10n');
fs.mkdirSync(outDir, { recursive: true });
for (const l of LANGS) {
  const o = { '@@locale': l };
  for (const k of keys) {
    const v = String(D[l][k]).replace(/'/g, '’');
    o[camel(k)] = v;
    if (l === 'tr') {
      const ph = [...new Set((v.match(/\{(\w+)\}/g) || []).map(x => x.slice(1, -1)))];
      const meta = { description: k };
      if (ph.length) { meta.placeholders = {}; ph.forEach(p => { if (!PH[p]) throw new Error('bilinmeyen yer tutucu ' + p); meta.placeholders[p] = { type: PH[p] }; }); }
      o['@' + camel(k)] = meta;
    }
  }
  fs.writeFileSync(path.join(outDir, `app_${l}.arb`), JSON.stringify(o, null, 2) + '\n');
}
fs.writeFileSync(path.join(ROOT, 'flutter', 'arrowtile', 'tool', 'arb_keymap.json'), JSON.stringify(names, null, 1));
console.log(`ARB: ${keys.length} anahtar x ${LANGS.length} dil -> ${path.relative(ROOT, outDir)}`);
