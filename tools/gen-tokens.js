// Arrowtile — renk token üreticisi (1.2.2). Tek kaynak: design/colors.json.
// Üç dosyadaki @tokens bölgelerini yeniden yazar; bölge dışına dokunmaz:
//   game/css/style.css                       colors        (:root, koyu tema media + [data-theme="dark"], yüksek kontrast [data-contrast="more"])
//   game/js/theme.js                         colors, arrowThemes, fixed
//   flutter/arrowtile/lib/ui/tokens.dart     fixed, palettes, arrowThemes
// Kullanım: node tools/gen-tokens.js           → dosyaları günceller
//           node tools/gen-tokens.js --check   → yalnızca denetler; kaynakla farklıysa çıkış kodu 1 (CI)
'use strict';
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..');
const SRC = JSON.parse(fs.readFileSync(path.join(ROOT, 'design', 'colors.json'), 'utf8'));
const HEAD = 'tools/gen-tokens.js üretir; elle düzenlemeyin (kaynak: design/colors.json)';

// ---- yardımcılar
const HEX = /^#[0-9A-F]{6}$/;
function hex(v, where) {
  if (typeof v !== 'string' || !HEX.test(v)) throw new Error(`${where}: #RRGGBB (büyük harf) bekleniyor, gelen ${JSON.stringify(v)}`);
  return v;
}
function alpha(a, where) {
  if (typeof a !== 'number' || a < 0 || a > 1) throw new Error(`${where}: alfa 0..1 bekleniyor`);
  return a;
}
const rgbOf = (h) => { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; };
const rgbaStr = (o) => `rgba(${rgbOf(o.rgb).join(',')},${o.alpha.toFixed(2)})`; // theme.js / CSS biçimi
const dartInt = (h) => '0x' + h.slice(1);
const dartAlpha = (a) => a.toFixed(2);
const jsStr = (s) => "'" + String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'") + "'";
const note = (n) => (n ? ' // ' + n : '');

// ---- kaynağı doğrula
const P = SRC.palette;
const PH = SRC.paletteHc; // 1.2.2 (Madde 9): yüksek kontrast paletleri, anahtarlar palette ile aynı
const MODES = ['light', 'dark'];
for (const [name, pal] of [['palette', P], ['paletteHc', PH]]) {
  for (const [k, e] of Object.entries(pal)) {
    for (const m of MODES) {
      if (k === 'shadow') { hex(e[m].rgb, `${name}.${k}.${m}.rgb`); alpha(e[m].alpha, `${name}.${k}.${m}.alpha`); }
      else hex(e[m], `${name}.${k}.${m}`);
    }
  }
}
if (Object.keys(PH).join() !== Object.keys(P).join()) throw new Error('paletteHc anahtarları palette ile aynı ve aynı sırada olmalı');
// Dört palet: theme.js colors.<js>, tokens.dart Palette.<dart>
const VARIANTS = [
  { js: 'light', dart: 'light', src: P, m: 'light', hc: false },
  { js: 'dark', dart: 'darkP', src: P, m: 'dark', hc: false },
  { js: 'lightHc', dart: 'lightHc', src: PH, m: 'light', hc: true },
  { js: 'darkHc', dart: 'darkHc', src: PH, m: 'dark', hc: true },
];
for (const [k, e] of Object.entries(SRC.fixed)) {
  if ('value' in e) hex(e.value, `fixed.${k}.value`); else { hex(e.rgb, `fixed.${k}.rgb`); alpha(e.alpha, `fixed.${k}.alpha`); }
}
for (const t of SRC.arrowThemes) {
  if (!/^[a-z]+$/.test(t.id)) throw new Error('arrowThemes: geçersiz id ' + t.id);
  if (!Array.isArray(t.colors) || t.colors.length !== 5) throw new Error(`arrowThemes.${t.id}: 5 renk bekleniyor`);
  t.colors.forEach((c, i) => hex(c, `arrowThemes.${t.id}.colors[${i}]`));
  hex(t.chevron.rgb, `arrowThemes.${t.id}.chevron.rgb`); alpha(t.chevron.alpha, `arrowThemes.${t.id}.chevron.alpha`);
}

// ---- CSS
function cssVars(mode, src = P) {
  const items = [];
  for (const [k, e] of Object.entries(P)) if (e.css) items.push(`--${e.css}: ${k === 'shadow' ? rgbaStr(src[k][mode]) : src[k][mode]};`);
  for (const [alias, key] of Object.entries(SRC.cssAliases || {})) items.push(`--${alias}: ${src[key][mode]};`);
  const lines = [];
  for (let i = 0; i < items.length; i += 6) lines.push(items.slice(i, i + 6).join(' '));
  return lines;
}
function genCss() {
  const fixed = Object.values(SRC.fixed).map((e) => `--${e.css}: ${'value' in e ? e.value : rgbaStr(e)};`).join(' ');
  const ind = (arr, s) => arr.map((l) => s + l).join('\n');
  const dark = cssVars('dark');
  const hcLight = cssVars('light', PH), hcDark = cssVars('dark', PH);
  return [
    `/* @tokens:begin colors — ${HEAD} */`,
    ':root {',
    ind(cssVars('light'), '  '),
    '  /* temadan bağımsız sabitler */',
    '  ' + fixed,
    '  color-scheme: light;',
    '}',
    '/* G7: Görünüm = Otomatik (sistem) / Açık / Koyu. data-theme main.js applyAppearance() ile ayarlanır */',
    '@media (prefers-color-scheme: dark) {',
    '  :root:not([data-theme="light"]) {',
    ind(dark, '    '),
    '    color-scheme: dark;',
    '  }',
    '}',
    ':root[data-theme="dark"] {',
    ind(dark, '  '),
    '  color-scheme: dark;',
    '}',
    '/* Yüksek kontrast (Madde 9): data-contrast="more" main.js applyAppearance() ile; açık ve koyu YK paletleri */',
    ':root[data-contrast="more"] {',
    ind(hcLight, '  '),
    '  color-scheme: light;',
    '}',
    '@media (prefers-color-scheme: dark) {',
    '  :root[data-contrast="more"]:not([data-theme="light"]) {',
    ind(hcDark, '    '),
    '    color-scheme: dark;',
    '  }',
    '}',
    ':root[data-contrast="more"][data-theme="dark"] {',
    ind(hcDark, '  '),
    '  color-scheme: dark;',
    '}',
    '/* @tokens:end colors */',
  ].join('\n');
}

// ---- theme.js
function genJsColors() {
  const out = [`    // @tokens:begin colors — ${HEAD}`, '    colors: {'];
  VARIANTS.forEach((V, vi) => {
    if (V.js === 'lightHc') out.push('      // yüksek kontrast (Madde 9): THEME.highContrast açıkken THEME.palette() bunları döndürür');
    out.push(`      ${V.js}: {`);
    const keys = Object.keys(P);
    keys.forEach((k, i) => {
      const e = V.src[k], v = k === 'shadow' ? rgbaStr(e[V.m]) : e[V.m];
      const comma = i < keys.length - 1 ? ',' : '';
      out.push(`        ${(k + ':').padEnd(14)} ${jsStr(v)}${comma}${V.js === 'light' ? note(P[k].note) : ''}`);
    });
    out.push(`      }${vi < VARIANTS.length - 1 ? ',' : ''}`);
  });
  out.push('    },', '    // @tokens:end colors');
  return out.join('\n');
}
function genJsThemes() {
  const out = [`    // @tokens:begin arrowThemes — ${HEAD}`,
    '    // Açılabilir ok temaları. Oklar dizideki renkleri sırayla (index % n) kullanır; chevron: gövde üstündeki yön işaretlerinin rengi.',
    '    arrowThemes: ['];
  SRC.arrowThemes.forEach((t, i) => {
    const names = Object.entries(t.names).map(([l, n]) => `${l}: ${jsStr(n)}`).join(', ');
    if (t.note) out.push(`      // ${t.id}: ${t.note}`);
    out.push(`      { id: ${jsStr(t.id)}, name: ${jsStr(t.name)}, names: { ${names} }, price: ${t.price},`);
    out.push(`        colors: [${t.colors.map(jsStr).join(', ')}],`);
    out.push(`        chevron: ${jsStr(rgbaStr(t.chevron))} }${i < SRC.arrowThemes.length - 1 ? ',' : ''}`);
  });
  out.push('    ],', '    // @tokens:end arrowThemes');
  return out.join('\n');
}
function genJsFixed() {
  const out = [`    // @tokens:begin fixed — ${HEAD}`, '    // Temadan bağımsız sabitler (style.css :root, tokens.dart ile aynı).', '    fixed: {'];
  const rows = [];
  for (const [k, e] of Object.entries(SRC.fixed)) {
    if ('value' in e) rows.push([k, jsStr(e.value), e.note]);
    else { rows.push([k, jsStr(e.rgb), e.note + ' (alfa ' + k + 'Alpha)']); rows.push([k + 'Alpha', String(e.alpha), '']); }
  }
  rows.forEach(([k, v, n], i) => out.push(`      ${(k + ':').padEnd(13)} ${v}${i < rows.length - 1 ? ',' : ''}${note(n)}`));
  out.push('    },', '    // @tokens:end fixed');
  return out.join('\n');
}

// ---- tokens.dart
function genDartFixed() {
  const out = [`// @tokens:begin fixed — ${HEAD}`, '/// Temadan bağımsız sabitler (theme.js THEME.fixed, style.css :root ile aynı).'];
  for (const e of Object.values(SRC.fixed)) {
    if ('value' in e) out.push(`const Color ${e.dart} = Color(0xFF${e.value.slice(1)});${note(e.note)}`);
    else { out.push(`const int ${e.dart} = ${dartInt(e.rgb)};${note(e.note)}`); out.push(`const double ${e.dart}Alpha = ${e.alpha};`); }
  }
  out.push('// @tokens:end fixed');
  return out.join('\n');
}
function genDartPalettes() {
  const out = [`  // @tokens:begin palettes — ${HEAD}`];
  VARIANTS.forEach((V, vi) => {
    if (V.dart === 'lightHc') out.push('  // yüksek kontrast (Madde 9): metin ≥ 7:1, kenarlık / simge ≥ 3:1');
    out.push(`  static const Palette ${V.dart} = Palette(`);
    for (const k of Object.keys(P)) {
      const e = V.src[k];
      if (k === 'shadow') { out.push(`    shadow: ${dartInt(e[V.m].rgb)},`, `    shadowAlpha: ${dartAlpha(e[V.m].alpha)},`); }
      else out.push(`    ${k}: ${dartInt(e[V.m])},${V.dart === 'light' ? note(P[k].note) : ''}`);
    }
    out.push(`    dark: ${V.m === 'dark'},`);
    if (V.hc) out.push('    hc: true,');
    out.push('  );');
    if (vi < VARIANTS.length - 1) out.push('');
  });
  out.push('  // @tokens:end palettes');
  return out.join('\n');
}
function genDartThemes() {
  const out = [`// @tokens:begin arrowThemes — ${HEAD}`, 'const List<ArrowTheme> kArrowThemes = <ArrowTheme>['];
  for (const t of SRC.arrowThemes) {
    if (t.note) out.push(`  // ${t.id}: ${t.note}`);
    out.push(`  ArrowTheme('${t.id}', ${t.price}, <int>[${t.colors.map(dartInt).join(', ')}], ${dartInt(t.chevron.rgb)}, ${dartAlpha(t.chevron.alpha)}),`);
  }
  out.push('];', '// @tokens:end arrowThemes');
  return out.join('\n');
}

// ---- bölge değiştirme
const FILES = [
  { file: 'game/css/style.css', css: true, regions: { colors: genCss } },
  { file: 'game/js/theme.js', regions: { colors: genJsColors, arrowThemes: genJsThemes, fixed: genJsFixed } },
  { file: 'flutter/arrowtile/lib/ui/tokens.dart', regions: { fixed: genDartFixed, palettes: genDartPalettes, arrowThemes: genDartThemes } },
];
function esc(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
const check = process.argv.includes('--check');
let stale = [];
for (const f of FILES) {
  const p = path.join(ROOT, f.file);
  const before = fs.readFileSync(p, 'utf8');
  let text = before;
  for (const [name, gen] of Object.entries(f.regions)) {
    const re = f.css
      ? new RegExp(`/\\* @tokens:begin ${esc(name)}\\b[^]*?/\\* @tokens:end ${esc(name)} \\*/`)
      : new RegExp(`[ \\t]*// @tokens:begin ${esc(name)}\\b[^]*?// @tokens:end ${esc(name)}\\b`);
    const hits = text.match(new RegExp(re.source, 'g'));
    if (!hits || hits.length !== 1) throw new Error(`${f.file}: "${name}" bölgesi ${hits ? hits.length : 0} kez bulundu (tam 1 olmalı)`);
    const body = gen();
    text = text.replace(re, () => body);
  }
  if (text !== before) {
    stale.push(f.file);
    if (!check) fs.writeFileSync(p, text);
  }
}
// ---- design/system/tokens.json (tasarım sistemi kopyası): renk değerleri colors.json ile aynı olmalı (yalnızca denetlenir)
const sysPath = path.join(ROOT, 'design', 'system', 'tokens.json');
const drift = [];
if (fs.existsSync(sysPath)) {
  const sys = JSON.parse(fs.readFileSync(sysPath, 'utf8'));
  const tok = Object.fromEntries(sys.color.tokens.map((t) => [t.name, t.value]));
  const val = (v, m) => (typeof v === 'string' ? v : (v[m] || v.light)).toUpperCase();
  const want = [];
  for (const [k, e] of Object.entries(P)) if (e.css && k !== 'shadow') for (const m of MODES) want.push([e.css, m, e[m]], [e.css, m + '-hc', PH[k][m]]);
  for (const e of Object.values(SRC.fixed)) if ('value' in e) for (const m of MODES) want.push([e.css, m, e.value]);
  for (const t of SRC.arrowThemes) t.colors.forEach((c, i) => want.push([`arrow-${t.id}-${i + 1}`, 'light', c]));
  for (const [name, m, v] of want) {
    if (!(name in tok)) drift.push(`${name} yok`);
    else if (val(tok[name], m) !== v) drift.push(`${name}.${m}: ${val(tok[name], m)} ≠ ${v}`);
  }
  if (drift.length) {
    console.error('design/system/tokens.json colors.json ile farklı:\n  ' + drift.join('\n  '));
    if (check) process.exit(1);
  }
}
if (check) {
  if (stale.length) { console.error('KAYNAKTAN SAPMA: ' + stale.join(', ') + '\nÇözüm: renkleri design/colors.json içinde değiştirin ve `node tools/gen-tokens.js` çalıştırın.'); process.exit(1); }
  console.log('GEÇTİ: style.css, theme.js, tokens.dart ve design/system/tokens.json renkleri design/colors.json ile aynı.');
} else {
  console.log(stale.length ? 'Güncellendi: ' + stale.join(', ') : 'Değişiklik yok: üç dosya zaten kaynakla aynı.');
}
