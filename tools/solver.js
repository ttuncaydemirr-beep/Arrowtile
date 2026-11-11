// Arrowtile — ortak çözücü/doğrulayıcı çekirdeği (Node.js ve tarayıcı uyumlu)
'use strict';
const DIRS = { U: [0, -1], D: [0, 1], L: [-1, 0], R: [1, 0] };

// Okun kapladığı hücreler: kuyruk (x,y)'den dir yönünde len hücre. Son hücre = baş.
// v1.3: kıvrımlı ok biçimi { cells, dir } ya da eski düz biçim { x, y, dir, len }
function cellsOf(a) {
  if (a.cells) return a.cells;
  const [dx, dy] = DIRS[a.dir];
  const out = [];
  for (let i = 0; i < a.len; i++) out.push([a.x + dx * i, a.y + dy * i]);
  return out;
}
function headOf(a) { const c = cellsOf(a); return c[c.length - 1]; }

// Baştan kenara kadar olan yol hücreleri
function pathOf(a, w, h) {
  const [dx, dy] = DIRS[a.dir];
  let [x, y] = headOf(a);
  const out = [];
  x += dx; y += dy;
  while (x >= 0 && y >= 0 && x < w && y < h) { out.push([x, y]); x += dx; y += dy; }
  return out;
}

// Doluluk ızgarası: hücre -> ok indeksi (-1 boş)
function buildGrid(level, alive) {
  const g = new Int16Array(level.w * level.h).fill(-1);
  level.arrows.forEach((a, i) => {
    if (alive && !alive[i]) return;
    for (const [x, y] of cellsOf(a)) g[y * level.w + x] = i;
  });
  return g;
}

function canExit(level, i, grid) {
  for (const [x, y] of pathOf(level.arrows[i], level.w, level.h)) if (grid[y * level.w + x] !== -1) return false;
  return true;
}

// Yapısal kontroller: sınırlar, len, yön, çakışma
function checkStructure(level) {
  const errs = [];
  const seen = new Map();
  if (!(level.w >= 3 && level.h >= 3 && level.w <= 28 && level.h <= 45)) errs.push(`ızgara ${level.w}x${level.h} sınır dışı`); // 1.2.0: en fazla 28x45
  const mask = level.mask; // 1.2.0: şekilli tahta — satır dizgileri, '1' = oynanabilir hücre
  if (mask && (!Array.isArray(mask) || mask.length !== level.h || mask.some(r => typeof r !== 'string' || r.length !== level.w || /[^01]/.test(r)))) errs.push('maske biçimi bozuk');
  level.arrows.forEach((a, i) => {
    if (!DIRS[a.dir]) { errs.push(`ok ${i}: geçersiz yön ${a.dir}`); return; }
    const cs = cellsOf(a), L = cs.length;
    if (!(L >= 1 && L <= 48)) errs.push(`ok ${i}: uzunluk ${L}`); // 1.2.0: 1-48 (uzun kıvrımlı oklar)
    if (!a.cells && !(Number.isInteger(a.len) && a.len >= 1)) errs.push(`ok ${i}: len ${a.len}`);
    for (let k = 1; k < L; k++) if (Math.abs(cs[k][0] - cs[k - 1][0]) + Math.abs(cs[k][1] - cs[k - 1][1]) !== 1) errs.push(`ok ${i}: hücre ${k} komşu değil`);
    { const own = new Set(cs.map(c => c[0] + ',' + c[1])); if (own.size !== L) errs.push(`ok ${i}: kendi üstünden geçiyor`);
      const [dx, dy] = DIRS[a.dir], hd = cs[L - 1]; let x = hd[0] + dx, y = hd[1] + dy;
      while (x >= 0 && y >= 0 && x < level.w && y < level.h) { if (own.has(x + ',' + y)) { errs.push(`ok ${i}: başı kendi gövdesine bakıyor`); break; } x += dx; y += dy; } }
    for (const [x, y] of cs) {
      if (x < 0 || y < 0 || x >= level.w || y >= level.h) errs.push(`ok ${i}: (${x},${y}) tahta dışında`);
      else if (mask && Array.isArray(mask) && mask[y] && mask[y][x] !== '1') errs.push(`ok ${i}: (${x},${y}) maske dışında`);
      const k = x + ',' + y;
      if (seen.has(k)) errs.push(`ok ${i} ile ok ${seen.get(k)} (${k}) hücresinde çakışıyor`);
      seen.set(k, i);
    }
  });
  return errs;
}

// Açgözlü çözüm: her turda çıkabilen tüm okları çıkar (kural monoton: bir ok çıkınca başka okun yolu sadece açılır)
function solve(level) {
  const n = level.arrows.length;
  const alive = new Array(n).fill(true);
  const order = [];
  let layers = 0, initialFree = -1;
  while (order.length < n) {
    const grid = buildGrid(level, alive);
    const free = [];
    for (let i = 0; i < n; i++) if (alive[i] && canExit(level, i, grid)) free.push(i);
    if (initialFree < 0) initialFree = free.length;
    if (!free.length) return { solvable: false, order, layers, initialFree, stuck: alive.map((v, i) => v ? i : -1).filter(i => i >= 0) };
    for (const i of free) { alive[i] = false; order.push(i); }
    layers++;
  }
  return { solvable: true, order, layers, initialFree };
}

// Zorluk (v1.2, docs/08): birleşik puan = derinlik + ok sayısı/6 + doluluk×12 − başta serbest oran×20.
// Hesap oyunla ortak modülde (game/js/levelgen.js); etiket bantları LevelGen.BANDS.
const LG = require('../game/js/levelgen.js');
const DIFF_BANDS = LG.BANDS;
function difficulty(level) {
  const m = LG.measure(level);
  return { depth: m.depth, initialFree: m.initialFree, freeRatio: m.freeRatio, fill: m.fill, score: m.score, label: m.solvable ? LG.label(m.score) : 'unsolvable' };
}

module.exports = { DIRS, cellsOf, headOf, pathOf, buildGrid, canExit, checkStructure, solve, difficulty, DIFF_BANDS };
