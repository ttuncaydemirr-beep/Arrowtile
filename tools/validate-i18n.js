// Arrowtile — dil sözlüğü doğrulayıcı. Kullanım: node tools/validate-i18n.js
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm');
const file = process.argv[2] || path.join(__dirname, '..', 'game', 'js', 'i18n.js');
const ctx = { window: {} };
vm.runInNewContext(fs.readFileSync(file, 'utf8'), ctx);
const D = ctx.window.I18N, LANGS = ['tr', 'en', 'de', 'ar'];
const errs = [];
for (const l of LANGS) if (!D[l]) errs.push(`dil eksik: ${l}`);
const extra = Object.keys(D).filter(l => !LANGS.includes(l)); if (extra.length) errs.push(`beklenmeyen dil: ${extra}`);
const ref = Object.keys(D.tr).sort();
const ph = s => (s.match(/\{\w+\}/g) || []).sort().join(',');
for (const l of LANGS) {
  const keys = Object.keys(D[l]).sort();
  const miss = ref.filter(k => !(k in D[l])), more = keys.filter(k => !(k in D.tr));
  if (miss.length) errs.push(`${l}: eksik anahtarlar ${miss.join(', ')}`);
  if (more.length) errs.push(`${l}: fazla anahtarlar ${more.join(', ')}`);
  for (const k of keys) {
    const v = D[l][k];
    if (typeof v !== 'string' || !v.trim()) errs.push(`${l}.${k}: boş`);
    else if (k in D.tr && ph(v) !== ph(D.tr[k])) errs.push(`${l}.${k}: yer tutucu uyuşmuyor (${ph(v)} vs ${ph(D.tr[k])})`);
  }
  const t = [...D[l]['store.title']].length, s = [...D[l]['store.short']].length;
  if (t > 30) errs.push(`${l}: store.title ${t} > 30 karakter`);
  if (s > 80) errs.push(`${l}: store.short ${s} > 80 karakter`);
  if (D[l]['store.long'] !== undefined) { const lg = [...D[l]['store.long']].length; if (lg > 4000) errs.push(`${l}: store.long ${lg} > 4000 karakter`); }
  console.log(`${l}: ${keys.length} anahtar, dir=${D[l]['meta.dir']}, mağaza başlığı ${t}/30, kısa açıklama ${s}/80`);
}
if (D.ar && D.ar['meta.dir'] !== 'rtl') errs.push('ar: meta.dir rtl olmalı');
for (const l of ['tr', 'en', 'de']) if (D[l] && D[l]['meta.dir'] !== 'ltr') errs.push(`${l}: meta.dir ltr olmalı`);
const names = { tr: 'Türkçe', en: 'English', de: 'Deutsch', ar: 'العربية' };
for (const l of LANGS) for (const n of LANGS) if (D[l] && D[l]['lang.' + n] !== names[n]) errs.push(`${l}.lang.${n} endonim olmalı: ${names[n]}`);
if (errs.length) { console.log('\nHATALAR:\n- ' + errs.join('\n- ')); process.exit(1); }
console.log(`\nGEÇTİ: 4 dilde ${ref.length} anahtar birebir eşleşiyor, boş değer yok, yer tutucular tutarlı, mağaza metinleri sınır içinde.`);
