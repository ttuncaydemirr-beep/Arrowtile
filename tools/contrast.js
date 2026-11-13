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
const DP = { light: dartPalette('light'), dark: dartPalette('darkP'), lightHc: dartPalette('lightHc'), darkHc: dartPalette('darkHc') };
for (const mode of Object.keys(DP)) {
  if (!T.colors[mode]) { errs.push('theme.js: THEME.colors.' + mode + ' yok'); continue; }
  for (const [k, v] of Object.entries(DP[mode])) {
    const w = T.colors[mode][k];
    if (typeof w === 'string' && w.startsWith('#') && w.toUpperCase() !== v) errs.push(`renk farkı ${mode}.${k}: web ${w} ≠ Flutter ${v}`);
  }
}
// 1.2.2: temadan bağımsız sabitler — web THEME.fixed, Flutter kOnGold/kExtreme/kExtremeDeep/kScrim, style.css :root aynı olmalı
const F = T.fixed;
if (!F) errs.push('theme.js: THEME.fixed yok');
else {
  const dc = (n) => { const m = new RegExp(`const Color ${n} = Color\\(0xFF([0-9A-Fa-f]{6})\\)`).exec(dart); return m ? '#' + m[1].toUpperCase() : null; };
  const di = (n) => { const m = new RegExp(`const int ${n} = 0x([0-9A-Fa-f]{6})`).exec(dart); return m ? '#' + m[1].toUpperCase() : null; };
  const css = fs.readFileSync(path.join(ROOT, 'game', 'css', 'style.css'), 'utf8');
  const cv = (n) => { const m = new RegExp(`--${n}:\\s*([^;]+);`).exec(css); return m ? m[1].trim().toUpperCase() : null; };
  const hexRgba = (h, a) => { const n = parseInt(h.slice(1), 16); return `RGBA(${n >> 16},${(n >> 8) & 255},${n & 255},${a})`; };
  const chk = [['onGold', dc('kOnGold'), cv('on-gold')], ['extreme', dc('kExtreme'), cv('extreme')], ['extremeDeep', dc('kExtremeDeep'), cv('extreme-deep')], ['scrim', di('kScrim'), null]];
  for (const [k, d, c] of chk) {
    if (F[k].toUpperCase() !== d) errs.push(`sabit farkı ${k}: web ${F[k]} ≠ Flutter ${d}`);
    if (c !== null && F[k].toUpperCase() !== c) errs.push(`sabit farkı ${k}: theme.js ${F[k]} ≠ style.css ${c}`);
  }
  const da = /const double kScrimAlpha = ([0-9.]+);/.exec(dart);
  if (!da || +da[1] !== F.scrimAlpha) errs.push(`sabit farkı scrimAlpha: web ${F.scrimAlpha} ≠ Flutter ${da && da[1]}`);
  if (cv('scrim') !== hexRgba(F.scrim, F.scrimAlpha)) errs.push(`sabit farkı scrim: style.css ${cv('scrim')} ≠ ${hexRgba(F.scrim, F.scrimAlpha)}`);
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
  add('metin', 'kuşanıldı düğmesi yazısı / success', C.onFill, C.success, 4.5, mode);
  add('metin', 'Orta etiketi yazısı / accent', C.onFill, C.accent, 4.5, mode);
  add('metin', 'Kolay etiketi yazısı / success', C.onFill, C.success, 4.5, mode);
  // 1.2.2: altın dolgu üstündeki koyu yazı (onGold) — ödül etiketi, bugünkü günlük ödül (star), Zor etiketi (coin); Aşırı zor etiketi
  add('metin', 'ödül etiketi yazısı (onGold) / star', T.fixed.onGold, C.star, 4.5, mode);
  add('metin', 'Zor etiketi yazısı (onGold) / coin', T.fixed.onGold, C.coin, 4.5, mode);
  add('metin', 'Aşırı zor etiketi yazısı / extremeDeep', '#FFFFFF', T.fixed.extremeDeep, 4.5, mode);
  // 1.2.2: klavye odak halkası (starInk) — kontrol çevresindeki yüzeylerde ≥ 3:1
  add('simge', 'odak halkası (starInk) / kart', C.starInk, C.board, 3, mode);
  add('simge', 'odak halkası (starInk) / zemin', C.starInk, C.bg, 3, mode);
  add('simge', 'odak halkası (starInk) / hücre', C.starInk, C.cell, 3, mode);
  // 1.2.2: success küçük metin olarak ("Ödülün hazır!", "2 ücretsiz", rahat mod) — hep kart/modal üstünde; açık temada #267A4D ile zorunlu
  add('metin', 'başarı yazısı (success) / kart', C.success, C.board, 4.5, mode);
}

// 1.2.2 (Madde 9): yüksek kontrast paletleri — WCAG AAA: metin ≥ 7:1 (büyük metin ≥ 4,5:1), kenarlık / simge / ok / odak ≥ 3:1
for (const mode of ['lightHc', 'darkHc']) {
  const C = T.colors[mode];
  if (!C) continue;
  T.arrowThemes.forEach(th => th.colors.forEach((c, i) => add(`YK ok (tema ${th.id})`, `${th.id}[${i}] ${c}`, c, C.board, 3, mode)));
  add('YK ok (Tek renk)', 'ink', C.ink, C.board, 3, mode);
  add('YK ok konturu', 'ink / tahta', C.ink, C.board, 3, mode);
  for (const [bn, bg] of [['zemin', C.bg], ['kart', C.board], ['hücre', C.cell]]) {
    add('YK metin', `ana metin / ${bn}`, C.ink, bg, 7, mode);
    add('YK metin', `ikincil metin / ${bn}`, C.inkSoft, bg, 7, mode);
    add('YK kenarlık', `kenarlık (boardEdge) / ${bn}`, C.boardEdge, bg, 3, mode);
    add('YK simge', `odak halkası (starInk) / ${bn}`, C.starInk, bg, 3, mode);
  }
  add('YK metin', 'birincil düğme yazısı / vurgu', C.accentInk, C.accent, 7, mode);
  add('YK metin', 'dolgu yazısı (onFill) / success', C.onFill, C.success, 7, mode);
  add('YK metin', 'dolgu yazısı (onFill) / danger', C.onFill, C.danger, 7, mode);
  add('YK metin', 'dolgu yazısı (onFill) / accent', C.onFill, C.accent, 7, mode);
  add('YK metin', 'başarı yazısı (success) / kart', C.success, C.board, 7, mode);
  add('YK metin (büyük)', 'ödül yazısı (coinInk) / kart', C.coinInk, C.board, 4.5, mode);
  add('YK metin', 'ödül etiketi yazısı (onGold) / star', T.fixed.onGold, C.star, 7, mode);
  add('YK metin', 'Zor etiketi yazısı (onGold) / coin', T.fixed.onGold, C.coin, 7, mode);
  add('YK simge', 'yıldız (starInk) / kart', C.starInk, C.board, 3, mode);
  add('YK simge', 'can (danger) / kart', C.danger, C.board, 3, mode);
  add('YK simge', 'ipucu halkası / tahta', C.highlightRing, C.board, 3, mode);
  add('YK simge', 'ızgara noktası (cellDot) / tahta', C.cellDot, C.board, 3, mode);
  add('YK simge', 'anahtar topuzu beyaz / kapalı iz (starEmpty)', '#FFFFFF', C.starEmpty, 3, mode);
}

// 1.2.1 (docs/27 §B1): satın alınan temalar (lokum, cini, bakir, gece) da ZORUNLU — sahip onayıyla açık/koyu tahtada ok ≥ 3:1.
const fails = rows.filter(r => r.r < r.min && !r.warn);
const warns = rows.filter(r => r.r < r.min && r.warn);
const fmt = r => r.r.toFixed(2);
if (process.argv.includes('--markdown')) {
  console.log('| Grup | Öğe | Ön plan | Arka plan | Kip | Oran | Eşik | Sonuç |');
  console.log('|---|---|---|---|---|---|---|---|');
  for (const r of rows) console.log(`| ${r.group} | ${r.what} | ${r.fg} | ${r.bg} | ${({ light: 'açık', dark: 'koyu', lightHc: 'açık YK', darkHc: 'koyu YK' })[r.mode]} | ${fmt(r)} | ${r.min}:1 | ${r.r >= r.min ? 'GEÇTİ' : (r.warn ? 'UYARI' : 'KALDI')} |`);
} else {
  for (const r of rows) console.log(`${r.r >= r.min ? 'ok  ' : (r.warn ? 'UYARI' : 'KALDI')} ${r.mode.padEnd(7)} ${r.group.padEnd(26)} ${r.what.padEnd(28)} ${r.fg} / ${r.bg}  ${fmt(r)}:1 (≥ ${r.min})`);
}
if (errs.length) { console.error('\nHATA (web ≠ Flutter):\n' + errs.join('\n')); process.exit(1); }
if (fails.length) { console.error(`\nKALDI: ${fails.length} çift eşik altında: ` + fails.map(r => `${r.mode}:${r.what}=${fmt(r)}`).join(', ')); process.exit(1); }
if (warns.length) console.warn(`\nUYARI (bilinen açık, CI'ı durdurmaz): ` + warns.map(r => `${r.mode}:${r.what}=${fmt(r)}`).join(', '));
console.log(`\nGEÇTİ: ${rows.length} çift; web ve Flutter renkleri özdeş; tüm ok temaları (satın alınanlar dahil) ve Kum ve Mürekkep eşikleri sağlıyor.`);
