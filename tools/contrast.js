// Arrowtile — WCAG 2.x kontrast ölçümü (1.2.1, docs/27 §B1).
// Değerler GERÇEK tema sabitlerinden okunur: web game/js/theme.js (THEME.colors, THEME.arrowThemes) ve Flutter lib/ui/tokens.dart
// (Palette.light/darkP, kArrowThemes). İkisi birebir aynı değilse hata verir (web ve Flutter renkleri özdeş kalmalı).
// Eşikler: metin ≥ 4,5:1, metin dışı grafik (ok, simge) ≥ 3:1 (WCAG 1.4.3 / 1.4.11).
// Kullanım: node tools/contrast.js            → tablo + denetim (başarısızlıkta çıkış kodu 1)
//           node tools/contrast.js --markdown → docs için Markdown tablo
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm');
const ROOT = path.join(__dirname, '..');

// ---- WCAG göreli parlaklık / kontrast oranı
function lum(hex) {
  const n = parseInt(hex.replace('#', ''), 16);
  const ch = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map(v => {
    const c = v / 255;
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2];
}
function ratio(a, b) {
  const la = lum(a), lb = lum(b);
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

// ---- web tema sabitleri
const ctx = { window: {}, document: undefined, navigator: {}, console };
vm.runInNewContext(fs.readFileSync(path.join(ROOT, 'game', 'js', 'theme.js'), 'utf8'), ctx);
const T = ctx.window.THEME;
if (!T) throw new Error('theme.js: window.THEME yok');

// ---- Flutter tema sabitleri (tokens.dart) — ayrıştır ve web ile karşılaştır
const dart = fs.readFileSync(path.join(ROOT, 'flutter', 'arrowtile', 'lib', 'ui', 'tokens.dart'), 'utf8');
function dartPalette(name) {
  const m = new RegExp(`static const Palette ${name} = Palette\\(([\\s\\S]*?)\\);`).exec(dart);
  if (!m) throw new Error('tokens.dart: Palette ' + name + ' yok');
  const o = {};
  for (const x of m[1].matchAll(/(\w+):\s*0x([0-9A-Fa-f]{6})\b/g)) o[x[1]] = '#' + x[2].toUpperCase();
  return o;
}
function dartThemes() {
  const o = {};
  for (const x of dart.matchAll(/ArrowTheme\('(\w+)',\s*\d+,\s*<int>\[([^\]]*)\]/g)) {
    o[x[1]] = x[2].split(',').map(s => '#' + s.trim().replace(/^0x/i, '').toUpperCase());
  }
  return o;
}
const errs = [];
const DP = { light: dartPalette('light'), dark: dartPalette('darkP') };
for (const mode of ['light', 'dark']) {
  for (const [k, v] of Object.entries(DP[mode])) {
    const w = T.colors[mode][k];
    if (typeof w === 'string' && w.startsWith('#') && w.toUpperCase() !== v) errs.push(`renk farkı ${mode}.${k}: web ${w} ≠ Flutter ${v}`);
  }
}
const DT = dartThemes();
for (const th of T.arrowThemes) {
  const d = DT[th.id];
  if (!d) { errs.push('Flutter teması yok: ' + th.id); continue; }
  th.colors.forEach((c, i) => { if (c.toUpperCase() !== d[i]) errs.push(`ok rengi farkı ${th.id}[${i}]: web ${c} ≠ Flutter ${d[i]}`); });
}

// ---- ölçülecek çiftler
// Oklar tahta yüzüne (board) çizilir (theme.js drawBoard: tepsi = board, hücre noktaları cellDot). Tek renk kipi: ok = ink.
const rows = [];
function add(group, what, fg, bg, min, mode, warn) { rows.push({ group, what, fg, bg, min, mode, warn: !!warn, r: ratio(fg, bg) }); }
for (const mode of ['light', 'dark']) {
  const C = T.colors[mode];
  T.arrowThemes.forEach(th => th.colors.forEach((c, i) => add(th.id === 'emaye' ? 'ok (Renkli, varsayılan)' : `ok (tema ${th.id})`, `${th.id}[${i}] ${c}`, c, C.board, 3, mode)));
  add('ok (Tek renk)', 'ink', C.ink, C.board, 3, mode);
  add('simge', 'yıldız (dolu, starInk) / kart', C.starInk, C.board, 3, mode);
  add('simge', 'yıldız (dolu, starInk) / zemin', C.starInk, C.bg, 3, mode);
  add('simge', 'yıldız (boş çerçeve, inkSoft) / kart', C.inkSoft, C.board, 3, mode);
  add('simge', 'yıldız (boş çerçeve, inkSoft) / zemin', C.inkSoft, C.bg, 3, mode);
  add('simge', 'jeton (coinInk) / kart', C.coinInk, C.board, 3, mode);
  add('simge', 'jeton (coinInk) / zemin', C.coinInk, C.bg, 3, mode);
  add('simge', 'ipucu halkası / tahta', C.highlightRing, C.board, 3, mode);
  add('metin (büyük)', 'ödül yazısı 26 px kalın (coinInk) / kart', C.coinInk, C.board, 3, mode);
  add('simge', 'can (kalp) / kart', C.danger, C.board, 3, mode);
  add('metin', 'ana metin / zemin', C.ink, C.bg, 4.5, mode);
  add('metin', 'ikincil metin / kart', C.inkSoft, C.board, 4.5, mode);
  add('metin', 'ikincil metin / zemin', C.inkSoft, C.bg, 4.5, mode);
  add('metin', 'birincil düğme yazısı / vurgu', C.accentInk, C.accent, 4.5, mode);
  // 1.2.2: renkli dolgu üstündeki yazı (onFill) — tehlike / kuşanıldı düğmesi (18 px kalın), Kolay / Orta etiketi (11–12 px kalın)
  add('metin', 'tehlike düğmesi yazısı / danger', C.onFill, C.danger, 4.5, mode);
  add('metin', 'kuşanıldı düğmesi yazısı / success', C.onFill, C.success, 4.5, mode, mode === 'light');
  add('metin', 'Orta etiketi yazısı / accent', C.onFill, C.accent, 4.5, mode);
  add('metin', 'Kolay etiketi yazısı / success', C.onFill, C.success, 4.5, mode, mode === 'light');
  // 1.2.2: klavye odak halkası (starInk) — kontrol çevresindeki yüzeylerde ≥ 3:1
  add('simge', 'odak halkası (starInk) / kart', C.starInk, C.board, 3, mode);
  add('simge', 'odak halkası (starInk) / zemin', C.starInk, C.bg, 3, mode);
  add('simge', 'odak halkası (starInk) / hücre', C.starInk, C.cell, 3, mode);
  // bilinen açık (UYARI, CI'ı durdurmaz): success küçük metin olarak ("Ödülün hazır!", "2 ücretsiz") — renk kararı sahipte
  add('metin', 'başarı yazısı (success) / kart', C.success, C.board, 4.5, mode, mode === 'light');
}

// 1.2.1 (docs/27 §B1): satın alınan temalar (lokum, cini, bakir, gece) da ZORUNLU — sahip onayıyla açık/koyu tahtada ok ≥ 3:1.
const fails = rows.filter(r => r.r < r.min && !r.warn);
const warns = rows.filter(r => r.r < r.min && r.warn);
const fmt = r => r.r.toFixed(2);
if (process.argv.includes('--markdown')) {
  console.log('| Grup | Öğe | Ön plan | Arka plan | Kip | Oran | Eşik | Sonuç |');
  console.log('|---|---|---|---|---|---|---|---|');
  for (const r of rows) console.log(`| ${r.group} | ${r.what} | ${r.fg} | ${r.bg} | ${r.mode === 'light' ? 'açık' : 'koyu'} | ${fmt(r)} | ${r.min}:1 | ${r.r >= r.min ? 'GEÇTİ' : (r.warn ? 'UYARI' : 'KALDI')} |`);
} else {
  for (const r of rows) console.log(`${r.r >= r.min ? 'ok  ' : (r.warn ? 'UYARI' : 'KALDI')} ${r.mode.padEnd(5)} ${r.group.padEnd(26)} ${r.what.padEnd(28)} ${r.fg} / ${r.bg}  ${fmt(r)}:1 (≥ ${r.min})`);
}
if (errs.length) { console.error('\nHATA (web ≠ Flutter):\n' + errs.join('\n')); process.exit(1); }
if (fails.length) { console.error(`\nKALDI: ${fails.length} çift eşik altında: ` + fails.map(r => `${r.mode}:${r.what}=${fmt(r)}`).join(', ')); process.exit(1); }
if (warns.length) console.warn(`\nUYARI (bilinen açık, CI'ı durdurmaz): ` + warns.map(r => `${r.mode}:${r.what}=${fmt(r)}`).join(', '));
console.log(`\nGEÇTİ: ${rows.length} çift; web ve Flutter renkleri özdeş; tüm ok temaları (satın alınanlar dahil) ve Kum ve Mürekkep eşikleri sağlıyor.`);
