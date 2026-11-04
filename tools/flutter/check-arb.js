// ARB doğrulayıcı: 4 dilde anahtar eşitliği + yer tutucu eşitliği + i18n.js ile değer eşitliği + Dart kaynağında kullanılan
// `loc.xxx` anahtarlarının ARB'de var olması (yazım hatası denetimi). Kullanım: node tools/flutter/check-arb.js
'use strict';
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..', '..'), P = path.join(ROOT, 'flutter', 'arrowtile');
const LANGS = ['tr', 'en', 'de', 'ar'], errs = [];
const arb = {}; LANGS.forEach(l => arb[l] = JSON.parse(fs.readFileSync(path.join(P, 'lib', 'l10n', `app_${l}.arb`), 'utf8')));
const msgKeys = o => Object.keys(o).filter(k => !k.startsWith('@'));
const ref = msgKeys(arb.tr).sort();
const ph = s => (String(s).match(/\{\w+\}/g) || []).sort().join(',');
for (const l of LANGS) {
  const ks = msgKeys(arb[l]).sort();
  if (arb[l]['@@locale'] !== l) errs.push(`${l}: @@locale yanlış`);
  ref.filter(k => !(k in arb[l])).forEach(k => errs.push(`${l}: eksik ${k}`));
  ks.filter(k => !(k in arb.tr)).forEach(k => errs.push(`${l}: fazla ${k}`));
  for (const k of ks) { if (!String(arb[l][k]).trim()) errs.push(`${l}.${k}: boş`); if (k in arb.tr && ph(arb[l][k]) !== ph(arb.tr[k])) errs.push(`${l}.${k}: yer tutucu uyuşmuyor`); }
}
// tr şablonundaki her yer tutucu için @meta bildirimi var mı
for (const k of ref) { const p = (arb.tr[k].match(/\{(\w+)\}/g) || []).map(x => x.slice(1, -1)); const m = arb.tr['@' + k]; for (const x of p) if (!m || !m.placeholders || !m.placeholders[x]) errs.push(`tr.${k}: @${k}.placeholders.${x} yok`); }
// i18n.js ile değer eşitliği (' -> ’ dönüşümü hariç)
const vm = require('vm'), c = { window: {} }; vm.runInNewContext(fs.readFileSync(path.join(ROOT, 'game', 'js', 'i18n.js'), 'utf8'), c);
const map = JSON.parse(fs.readFileSync(path.join(P, 'tool', 'arb_keymap.json'), 'utf8'));
for (const l of LANGS) for (const cam of ref) { const orig = String(c.window.I18N[l][map[cam]]).replace(/'/g, '’'); if (arb[l][cam] !== orig) errs.push(`${l}.${cam}: i18n.js ile uyuşmuyor`); }
// Dart kaynağı
const used = new Set(), files = [];
(function walk(d) { for (const f of fs.readdirSync(d)) { const p = path.join(d, f); if (fs.statSync(p).isDirectory()) { if (!/gen$/.test(f)) walk(p); } else if (p.endsWith('.dart')) files.push(p); } })(path.join(P, 'lib'));
for (const f of files) { const s = fs.readFileSync(f, 'utf8'); for (const m of s.matchAll(/\bloc\.([A-Za-z0-9_]+)/g)) used.add(m[1] + ' @ ' + path.relative(P, f)); }
const SPECIAL = new Set(['localeName']);
for (const u of used) { const [k, where] = u.split(' @ '); if (!SPECIAL.has(k) && !(k in arb.tr)) errs.push(`Dart kullanımı ARB'de yok: loc.${k} (${where})`); }
const usedKeys = new Set([...used].map(u => u.split(' @ ')[0]));
const unused = ref.filter(k => !usedKeys.has(k));
console.log(`ARB: ${ref.length} anahtar x 4 dil; Dart'ta doğrudan kullanılan ${usedKeys.size}; doğrudan kullanılmayan ${unused.length} (dinamik arama: bölüm/kademe/tema adları vb.)`);
if (process.argv.includes('--unused')) console.log(unused.join(' '));
if (errs.length) { console.log('HATALAR:\n- ' + errs.join('\n- ')); process.exit(1); }
console.log('GEÇTİ: anahtar/yer tutucu eşitliği, i18n.js ile değer eşitliği, Dart kullanımı');
