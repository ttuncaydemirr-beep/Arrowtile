/* Arrowtile — levelgen.js: ortak seviye üretici + ölçüler (v1.2 docs/08 §3; v1.3 kıvrımlı oklar docs/09; v1.5 docs/15 §5)
 * tools/generate-levels.js (ilk 200 seviye), tools/verify-5000.js (5.000 seviye), oyun içi üretim ve
 * game/js/daily.js (günlük bulmaca) bunu kullanır.
 * Tarayıcıda window.LevelGen, Node'da module.exports. Bağımlılık yok.
 *
 * YÖNTEM — yoğun yerleşim + onarım (build içindeki açıklamaya bakın). Her çıktı açgözlü çözücüyle
 * (measure) doğrulanır: çözülemeyen seviye üretilmez. Ters inşa yoğun tahtada düşük "başta çıkabilen"
 * oranını sağlayamadığı için v1.2'de bu yöntem seçildi.
 */
(function (root) {
  'use strict';
  var DX = { U: 0, D: 0, L: -1, R: 1 }, DY = { U: -1, D: 1, L: 0, R: 0 }, DIRS = ['U', 'D', 'L', 'R'];

  function rng(seed) {
    return function () {
      seed |= 0; seed = seed + 0x6D2B79F5 | 0;
      var t = Math.imul(seed ^ seed >>> 15, 1 | seed);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }
  function hash(str) { var h = 0x811c9dc5; for (var i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 0x01000193); } return h >>> 0; }

  // ---- ölçüler (motorla aynı kurallar) ----
  // v1.3: ok biçimi { cells: [[x,y]...] (kuyruk→baş, komşu), dir }; eski { x, y, dir, len } de okunur.
  function cellsOf(a) {
    if (a.cells) return a.cells;
    var o = []; for (var i = 0; i < a.len; i++) o.push([a.x + DX[a.dir] * i, a.y + DY[a.dir] * i]); return o;
  }
  function norm(a) { return a.cells ? a : { cells: cellsOf(a), dir: a.dir }; }
  function lenOf(a) { return a.cells ? a.cells.length : a.len; }
  function headOf(a) { var c = cellsOf(a); return c[c.length - 1]; }
  function isCurved(a) {
    var c = cellsOf(a); if (c.length < 3) return false;
    var dx = c[1][0] - c[0][0], dy = c[1][1] - c[0][1];
    for (var i = 2; i < c.length; i++) if (c[i][0] - c[i - 1][0] !== dx || c[i][1] - c[i - 1][1] !== dy) return true;
    return false;
  }
  function totalCells(L) { var t = 0; for (var i = 0; i < L.arrows.length; i++) t += lenOf(L.arrows[i]); return t; }
  function grid(L, alive) {
    var g = new Int16Array(L.w * L.h).fill(-1);
    L.arrows.forEach(function (a, k) { if (alive && !alive[k]) return; cellsOf(a).forEach(function (c) { g[c[1] * L.w + c[0]] = k; }); });
    return g;
  }
  function canExit(L, i, g) {
    var a = L.arrows[i], dx = DX[a.dir], dy = DY[a.dir], hd = headOf(a), x = hd[0] + dx, y = hd[1] + dy;
    while (x >= 0 && y >= 0 && x < L.w && y < L.h) { var k = g[y * L.w + x]; if (k !== -1 && k !== i) return false; x += dx; y += dy; }
    return true;
  }
  // başın önündeki doğru okun kendi gövdesinden geçmemeli (docs/09)
  function ownLineOk(cells, dir, w, h) {
    var dx = DX[dir], dy = DY[dir], hd = cells[cells.length - 1], x = hd[0] + dx, y = hd[1] + dy;
    while (x >= 0 && y >= 0 && x < w && y < h) {
      for (var i = 0; i < cells.length - 1; i++) if (cells[i][0] === x && cells[i][1] === y) return false;
      x += dx; y += dy;
    }
    return true;
  }
  /** Açgözlü çözüm: her turda çıkabilen tüm okları çıkarır. depth = tur sayısı (bağımlılık derinliği). */
  function measure(L) {
    var n = L.arrows.length, an = analyze(L), depth = an.depth, initialFree = an.free.length, order = [];
    if (an.stuck.length) return { solvable: false, depth: depth, initialFree: initialFree, order: order };
    var cells = totalCells(L), curved = 0; L.arrows.forEach(function (a) { if (isCurved(a)) curved++; });
    var fill = cells / (L.w * L.h), freeRatio = initialFree / n;
    // Birleşik zorluk puanı (docs/08): derinlik + ok sayısı + doluluk; serbest oran yüksekse düşer
    var score = depth + n / 6 + fill * 12 - freeRatio * 20;
    return { solvable: true, depth: depth, initialFree: initialFree, freeRatio: freeRatio, fill: fill, arrows: n, curved: curved, curvedRatio: curved / n, score: score, order: order };
  }
  // Etiket bantları birleşik puana göre (v1.2 sürekli bantlar; v1.3'te etiket bölüm kademesidir)
  var BANDS = [['easy', 12], ['medium', 26], ['hard', 40], ['extreme', Infinity]];
  function label(score) { for (var i = 0; i < BANDS.length; i++) if (score <= BANDS[i][1]) return BANDS[i][0]; return 'extreme'; }

  var LENP = [0, 0.02, 0.08, 0.18, 0.26, 0.24, 0.22]; // düz okların uzunluk olasılıkları
  var LENC = [0, 0, 0, 0.16, 0.22, 0.22, 0.18, 0.12, 0.10]; // kıvrımlı okların (3..8)
  function pickLen(rand, maxLen, curvy) {
    var P = curvy ? LENC : LENP, r = rand() * (function () { var t = 0; for (var l = 1; l <= Math.min(maxLen, P.length - 1); l++) t += P[l]; return t; })(), acc = 0;
    for (var l = 1; l <= Math.min(maxLen, P.length - 1); l++) { acc += P[l]; if (r <= acc) return l; }
    return Math.min(maxLen, 3);
  }
  var PERP = { U: ['L', 'R'], D: ['L', 'R'], L: ['U', 'D'], R: ['U', 'D'] };
  /**
   * Baştan geriye yılan gövdesi: baş (hx,hy) dir'e bakar; ilk gövde adımı dir yönünde hizalı, sonra
   * curvy ise dönüşler. isFree(x,y) boş hücre denetimi. Dönen: kuyruk→baş hücreler (uzunluk ≤ len) ya da null.
   */
  function snake(hx, hy, dir, len, isFree, rand, curvy, w, h) {
    var cells = [[hx, hy]], own = {}, s = dir, x = hx, y = hy, turns = 0;
    own[hx + ',' + hy] = 1;
    var turnP = curvy ? 0.45 : 0;
    for (var k = 1; k < len; k++) {
      var opts = [];
      if (k > 1 && curvy && rand() < turnP) { var pp = PERP[s]; opts = rand() < 0.5 ? [pp[0], pp[1], s] : [pp[1], pp[0], s]; }
      else { opts = [s]; if (curvy && k > 1) { var p2 = PERP[s]; opts = rand() < 0.5 ? [s, p2[0], p2[1]] : [s, p2[1], p2[0]]; } }
      var moved = false;
      for (var oi = 0; oi < opts.length; oi++) {
        var ns = opts[oi], nx = x - DX[ns], ny = y - DY[ns];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h || own[nx + ',' + ny] || !isFree(nx, ny)) continue;
        if (ns !== s) turns++;
        s = ns; x = nx; y = ny; own[nx + ',' + ny] = 1; cells.push([nx, ny]); moved = true; break;
      }
      if (!moved) break;
    }
    cells.reverse();
    if (!ownLineOk(cells, dir, w, h)) return null;
    if (curvy && !turns) return null;
    return cells;
  }
  function flip(a) {
    var c = cellsOf(a).slice().reverse(), rev = { U: 'D', D: 'U', L: 'R', R: 'L' }, d;
    if (c.length === 1) d = rev[a.dir];
    else { var dx = c[c.length - 1][0] - c[c.length - 2][0], dy = c[c.length - 1][1] - c[c.length - 2][1]; d = dx === 1 ? 'R' : dx === -1 ? 'L' : dy === 1 ? 'D' : 'U'; }
    return { cells: c, dir: d };
  }
  // Hızlı çözüm analizi: her okun yolundaki farklı okların sayısı tutulur; sayısı 0 olan ok çıkar ve yolunda
  // olduğu okların sayısını azaltır (kuyruk). Sonuç açgözlü tur sayımıyla aynıdır, ama O(toplam yol uzunluğu).
  // Hız (v1.3): ara diziler yeniden kullanılır (her çağrıda ayırma yok), ayrık engel denetimi damga dizisiyle,
  // bağımlılıklar düz (CSR) dizide. Sonuç önceki sürümle aynıdır (free/stuck indeks sırasında).
  var BUF = { stamp2: new Int32Array(0), g: new Int16Array(0), cnt: new Int32Array(0), stamp: new Int32Array(0), ef: new Int32Array(0), et: new Int32Array(0), off: new Int32Array(0), adj: new Int32Array(0), q: new Int32Array(0) };
  var EPOCH = 0;
  function ensure(name, size, Ctor) { if (BUF[name].length < size) BUF[name] = new (Ctor || Int32Array)(Math.max(size, BUF[name].length * 2)); return BUF[name]; }
  function analyze(L) {
    var w = L.w, h = L.h, n = L.arrows.length, N = w * h, i, k;
    var g = ensure('g', N, Int16Array); g.fill(-1, 0, N);
    for (i = 0; i < n; i++) { var cs = cellsOf(L.arrows[i]); for (k = 0; k < cs.length; k++) g[cs[k][1] * w + cs[k][0]] = i; }
    var cnt = ensure('cnt', n); cnt.fill(0, 0, n);
    var stamp = ensure('stamp', n), maxE = n * (w > h ? w : h), ef = ensure('ef', maxE), et = ensure('et', maxE), ne = 0;
    if (EPOCH > 2000000000) { EPOCH = 0; stamp.fill(0); }
    for (i = 0; i < n; i++) {
      var a = L.arrows[i], dx = DX[a.dir], dy = DY[a.dir], hd = headOf(a), x = hd[0] + dx, y = hd[1] + dy, ep = ++EPOCH;
      while (x >= 0 && y >= 0 && x < w && y < h) {
        k = g[y * w + x];
        if (k !== -1 && k !== i && stamp[k] !== ep) { stamp[k] = ep; cnt[i]++; ef[ne] = k; et[ne] = i; ne++; }
        x += dx; y += dy;
      }
    }
    var off = ensure('off', n + 1); off.fill(0, 0, n + 1);
    for (i = 0; i < ne; i++) off[ef[i] + 1]++;
    for (i = 0; i < n; i++) off[i + 1] += off[i];
    var adj = ensure('adj', ne + 1), pos = ensure('stamp2', n + 1); // pos: yazma imleci
    for (i = 0; i <= n; i++) pos[i] = off[i];
    for (i = 0; i < ne; i++) adj[pos[ef[i]]++] = et[i];
    var q = ensure('q', n), head = 0, tail = 0, free0 = [], depth = 0;
    for (i = 0; i < n; i++) if (!cnt[i]) { q[tail++] = i; free0.push(i); }
    while (head < tail) {
      depth++; var end = tail;
      for (; head < end; head++) { var u = q[head]; for (var r = off[u]; r < off[u + 1]; r++) if (--cnt[adj[r]] === 0) q[tail++] = adj[r]; }
    }
    var stuck = []; if (tail < n) for (i = 0; i < n; i++) if (cnt[i] > 0) stuck.push(i);
    return { free: free0, stuck: stuck, depth: depth };
  }
  function stuckOf(L) { return analyze(L).stuck; }
  function freeNow(L) { return analyze(L).free; }
  function pickDir(x, y, w, h, rand) {
    // ağırlık = v^1.5 (v·√v): Math.pow yerine yalnızca IEEE-kesin işlemler (çarpma, karekök) → Dart'ta bit-bit aynı sonuç
    var wts = [y + 0.5, h - y - 0.5, x + 0.5, w - x - 0.5].map(function (v) { return v * Math.sqrt(v); }); // U D L R
    var tot = wts[0] + wts[1] + wts[2] + wts[3], rr = rand() * tot;
    for (var wi = 0; wi < 4; wi++) { rr -= wts[wi]; if (rr <= 0) return DIRS[wi]; }
    return 'R';
  }
  /**
   * build({ w, h, fill, maxLen, maxFree, curve, rand, ... }) → arrows[] ya da null
   * 1) Yoğun yerleşim: rastgele baş hücresi + içeri bakan yön; gövde baştan geriye büyür (curve olasılıkla kıvrımlı).
   * 2) Onarım: kilitlenen oklar çoğunlukla silinir (az olasılıkla ters çevrilir).
   * 3) Boşluk doldurma + serbest oranı düşürme döngüleri, 4b) serbest okları kapalı tek hücrelere bölme,
   * 5) serbest okların yolunu kısa kapalı oklarla kapatma. Her adım çözülebilirliği korur.
   */
  function build(o) {
    var w = o.w, h = o.h, N = w * h, rand = o.rand, maxLen = o.maxLen || 6, target = (o.fill || 0.7) * N, curveP = Math.min(0.95, (o.curve || 0) * 1.6); // yerleşimde fazla: boşluk doldurma düz kısa oklar ekler
    var occ = new Uint8Array(N), arrows = [], filled = 0, fails = 0;
    var freeOcc = function (x, y) { return !occ[y * w + x]; };
    // 1) yoğun yerleşim
    while (filled < target && fails < N * 40) {
      var x = Math.floor(rand() * w), y = Math.floor(rand() * h);
      if (occ[y * w + x]) { fails++; continue; }
      var dir = pickDir(x, y, w, h, rand), curvy = rand() < curveP;
      var len = pickLen(rand, maxLen, curvy);
      if (filled > target * 0.92 && fails > N * 25) { len = 1 + Math.floor(rand() * 2); curvy = false; }
      var cells = snake(x, y, dir, len, freeOcc, rand, curvy, w, h);
      if (!cells || (!curvy && cells.length < len)) { fails++; continue; }
      for (var k = 0; k < cells.length; k++) occ[cells[k][1] * w + cells[k][0]] = 1;
      arrows.push({ cells: cells, dir: dir }); filled += cells.length;
    }
    var L = { w: w, h: h, arrows: arrows };
    // 2) onarım
    for (var it = 0; it < 4000; it++) {
      var st = stuckOf(L); if (!st.length) break;
      var pick = st[Math.floor(rand() * st.length)];
      var fl = rand() < (o.flipP == null ? 0.05 : o.flipP) ? flip(L.arrows[pick]) : null;
      if (fl && ownLineOk(fl.cells, fl.dir, w, h)) L.arrows[pick] = fl; // v1.3: çoğunlukla sil
      else L.arrows.splice(pick, 1);
    }
    if (stuckOf(L).length) return null;
    function occGrid() { return grid(L); }
    function limitFree() { return Math.max(1, Math.floor((o.maxFree == null ? 0.1 : o.maxFree) * L.arrows.length)); }
    // 3) boşluk doldurma: serbest ok sayısını artırmayan ve çözülebilirliği bozmayan adaylar kabul edilir
    function gapFill() {
      var maxFree0 = Math.max(1, Math.floor((o.maxFree == null ? 0.1 : o.maxFree) * Math.max(L.arrows.length, target / 3.5)));
      for (var pass2 = 0; pass2 < 6; pass2++) {
        var cells0 = totalCells(L);
        if (cells0 >= target) break;
        var g1 = occGrid(), empties = []; for (var e = 0; e < N; e++) if (g1[e] === -1) empties.push(e);
        shuffle(empties, rand);
        var added = 0, curFree = freeNow(L).length;
        var isF = function (xx, yy) { return g1[yy * w + xx] === -1; };
        for (var ei = 0; ei < empties.length && cells0 < target; ei++) {
          var ec = empties[ei], ex = ec % w, ey = (ec - ex) / w;
          if (g1[ec] !== -1) continue;
          var dirs = shuffle(DIRS.slice(), rand), placed = false;
          for (var di = 0; di < 4 && !placed; di++) {
            var dd = dirs[di];
            for (var ln = maxLen; ln >= 1 && !placed; ln--) {
              var curvy2 = ln >= 3 && rand() < curveP;
              var cc = snake(ex, ey, dd, ln, isF, rand, curvy2, w, h);
              if (!cc || cc.length !== ln) continue;
              L.arrows.push({ cells: cc, dir: dd });
              var an3 = analyze(L), nf = an3.free.length, selfFree = an3.free.indexOf(L.arrows.length - 1) >= 0;
              var good = nf <= Math.max(curFree, maxFree0) && (!selfFree || nf <= curFree);
              if (good && !an3.stuck.length) {
                placed = true; added++; cells0 += ln; curFree = nf;
                for (var zz = 0; zz < cc.length; zz++) g1[cc[zz][1] * w + cc[zz][0]] = L.arrows.length - 1;
              } else L.arrows.pop();
            }
          }
        }
        if (!added) break;
      }
    }
    // 4) başta çıkabilen oranını düşür (en az 1 serbest kalır)
    function reduce() {
      var maxFree = limitFree();
      for (var pass = 0; pass < (o.passes || 8); pass++) {
        var fr = freeNow(L); if (fr.length <= maxFree) break;
        for (var q = 0; q < fr.length; q++) {
          var i2 = fr[q], old = L.arrows[i2], before = freeNow(L).length;
          if (!old) continue;
          var nf2 = flip(old);
          if (!ownLineOk(nf2.cells, nf2.dir, w, h)) continue;
          L.arrows[i2] = nf2;
          var g2 = grid(L);
          if (canExit(L, i2, g2)) { L.arrows[i2] = old; continue; }
          var st2 = stuckOf(L), okFlip = !st2.length && freeNow(L).length < before;
          var snapshot = null;
          if (!okFlip && st2.length) {
            snapshot = L.arrows.slice(); snapshot[i2] = old;
            for (var tr = 0; tr < (o.effort || 12) && st2.length; tr++) {
              var cand = st2.filter(function (k) { return k !== i2; });
              if (!cand.length) break;
              var j3 = cand[Math.floor(rand() * cand.length)];
              L.arrows.splice(j3, 1); if (j3 < i2) i2--;
              st2 = stuckOf(L);
            }
            okFlip = !st2.length && freeNow(L).length < before;
          }
          if (!okFlip) { if (snapshot) L.arrows = snapshot; else L.arrows[i2] = old; }
          if (okFlip) break;
        }
      }
    }
    for (var cyc = 0; cyc < (o.cycles || 3); cyc++) {
      gapFill(); reduce();
      if (totalCells(L) >= target - 0.005 * N && freeNow(L).length <= limitFree()) break;
    }
    gapFill();
    // 4b) kalan serbest oklar: tek hücrelik kapalı oklara böl
    var lim4 = limitFree();
    for (var guard4 = 0; guard4 < 400; guard4++) {
      var fr4 = freeNow(L); if (fr4.length <= lim4) break;
      var any4 = false;
      for (var q4 = 0; q4 < fr4.length; q4++) {
        var A4 = L.arrows[fr4[q4]], before4 = fr4.length;
        if (!A4) continue;
        var cells4 = cellsOf(A4), saved = L.arrows.slice();
        L.arrows.splice(fr4[q4], 1);
        var base4 = L.arrows.length;
        for (var c4 = 0; c4 < cells4.length; c4++) L.arrows.push({ cells: [cells4[c4]], dir: A4.dir });
        for (var c5 = 0; c5 < cells4.length; c5++) {
          var opts4 = shuffle(DIRS.slice(), rand);
          for (var d4 = 0; d4 < 4; d4++) {
            L.arrows[base4 + c5] = { cells: [cells4[c5]], dir: opts4[d4] };
            if (!canExit(L, base4 + c5, grid(L))) break;
          }
        }
        if (freeNow(L).length < before4 && !stuckOf(L).length) { any4 = true; break; }
        L.arrows = saved;
      }
      if (!any4) break;
    }
    // 5) hâlâ fazla serbest ok varsa: serbest okun yolundaki boş hücreye kendisi kapalı kalan kısa bir ok koy
    var cap = Math.min(N, o.fillMax ? Math.floor(o.fillMax * N) : target + 0.06 * N); // v1.3: kademe bandının üstüne çıkma
    for (var guard5 = 0; guard5 < 200; guard5++) {
      var fr5 = freeNow(L);
      if (fr5.length <= limitFree()) break;
      var changed = false;
      for (var q5 = 0; q5 < fr5.length && !changed; q5++) {
        if (totalCells(L) >= cap) break;
        var fa = L.arrows[fr5[q5]], gg = occGrid(), hd5 = headOf(fa), px5 = hd5[0] + DX[fa.dir], py5 = hd5[1] + DY[fa.dir];
        var isF5 = function (xx, yy) { return gg[yy * w + xx] === -1; };
        while (!changed && px5 >= 0 && py5 >= 0 && px5 < w && py5 < h) {
          if (gg[py5 * w + px5] === -1) {
            var dirs5 = shuffle(DIRS.slice(), rand);
            for (var d5 = 0; d5 < 4 && !changed; d5++) for (var l5 = 2; l5 >= 1 && !changed; l5--) {
              var cb = snake(px5, py5, dirs5[d5], l5, isF5, rand, false, w, h);
              if (!cb || cb.length !== l5) continue;
              L.arrows.push({ cells: cb, dir: dirs5[d5] });
              if (!canExit(L, L.arrows.length - 1, grid(L)) && freeNow(L).length < fr5.length && !stuckOf(L).length) changed = true;
              else L.arrows.pop();
            }
          }
          px5 += DX[fa.dir]; py5 += DY[fa.dir];
        }
      }
      if (!changed) break;
    }
    // 6) birleştirme (v1.3): kıvrımlı oran hedefin altındaysa, ucu ucuna değen iki oku tek yılana birleştir
    //    (P'nin bir ucu Q'nun kuyruğuna komşu → P(+ters) + Q, yön = Q'nun yönü). Çözülebilirlik korunur,
    //    serbest ok sayısı artmaz.
    var want = o.curve || 0;
    function adj(p, q) { return Math.abs(p[0] - q[0]) + Math.abs(p[1] - q[1]) === 1; }
    function curvedRatio() { var c = 0; for (var i = 0; i < L.arrows.length; i++) if (isCurved(L.arrows[i])) c++; return c / L.arrows.length; }
    var depth6 = want > 0 ? analyze(L).depth : 0, floor6 = Math.ceil(depth6 * 0.9); // birleştirme derinliği en çok %10 düşürebilir
    for (var guard6 = 0; guard6 < 4 && want > 0 && curvedRatio() < want; guard6++) {
      var merged = 0, g6 = grid(L);
      var order6 = shuffle(L.arrows.map(function (_, i) { return i; }), rand);
      for (var oi6 = 0; oi6 < order6.length && curvedRatio() < want; oi6++) {
        var qi = order6[oi6], Q = L.arrows[qi]; if (!Q) continue;
        var qc = cellsOf(Q); if (qc.length >= maxLen) continue;
        var t = qc[0], nb = [[t[0] + 1, t[1]], [t[0] - 1, t[1]], [t[0], t[1] + 1], [t[0], t[1] - 1]], done6 = false;
        for (var nb6 = 0; nb6 < 4 && !done6; nb6++) {
          var nx6 = nb[nb6][0], ny6 = nb[nb6][1]; if (nx6 < 0 || ny6 < 0 || nx6 >= w || ny6 >= h) continue;
          var pi = g6[ny6 * w + nx6]; if (pi === -1 || pi === qi) continue;
          var P = L.arrows[pi], pc = cellsOf(P); if (pc.length + qc.length > maxLen) continue;
          var body = null;
          if (adj(pc[pc.length - 1], t)) body = pc.concat(qc); else if (adj(pc[0], t)) body = pc.slice().reverse().concat(qc);
          if (!body) continue;
          var NA = { cells: body, dir: Q.dir };
          if (!isCurved(NA) || !ownLineOk(body, Q.dir, w, h)) continue;
          var an0 = analyze(L), saved6 = L.arrows.slice();
          L.arrows[qi] = NA; L.arrows.splice(pi, 1);
          var an6 = analyze(L);
          // derinlik düşmemeli (kademe sırası korunur), serbest sayı ne artar ne sınırı aşar
          if (!an6.stuck.length && an6.depth >= Math.max(floor6, an0.depth - 1) && an6.free.length <= an0.free.length && (an6.free.length <= limitFree() || an6.free.length < an0.free.length || an0.free.length > limitFree() && an6.free.length <= an0.free.length - 0)) { done6 = true; merged++; }
          else L.arrows = saved6;
        }
        if (done6) { g6 = grid(L); order6 = shuffle(L.arrows.map(function (_, i) { return i; }), rand); oi6 = -1; }
      }
      if (!merged) break;
    }
    // 7) son düzeltme (v1.3): hâlâ sınırdan fazla serbest ok varsa, kısa serbest okları sil (doluluk hedefin en çok
    //    %1,5 altına inebilir); yalnızca serbest sayısını gerçekten düşüren silmeler kalır.
    var floorCells = target - 0.015 * N;
    for (var guard7 = 0; guard7 < 40; guard7++) {
      var an7 = analyze(L); if (an7.free.length <= limitFree()) break;
      var fr7 = an7.free.slice().sort(function (p, q) { return (lenOf(L.arrows[p]) - lenOf(L.arrows[q])) || (p - q); }), did7 = false; // kararlı sıralama: eşitlikte indeks (Dart List.sort kararsızdır)
      for (var q7 = 0; q7 < fr7.length && !did7; q7++) {
        var A7 = L.arrows[fr7[q7]];
        if (totalCells(L) - lenOf(A7) < floorCells) continue;
        L.arrows.splice(fr7[q7], 1);
        var b7 = analyze(L);
        if (!b7.stuck.length && b7.free.length < an7.free.length) did7 = true;
        else L.arrows.splice(fr7[q7], 0, A7);
      }
      if (!did7) break;
    }
    return L.arrows;
  }
  function shuffle(arr, rand) { for (var i = arr.length - 1; i > 0; i--) { var j = Math.floor(rand() * (i + 1)); var t = arr[i]; arr[i] = arr[j]; arr[j] = t; } return arr; }

  /**
   * generate(spec, seed) → { w, h, arrows, m } — spec: { w, h, fill, maxLen, maxFree, minDepth, tries }
   * Koşulları (doluluk, serbest oran, derinlik) sağlayan en iyi denemeyi döndürür; sağlanamazsa en iyiyi.
   */
  // Üretim işi: her step() tek bir build denemesi yapar (oyunda arka planda dilimlerle çalıştırmak için).
  function genJob(spec, seed) {
    var rand = rng(seed >>> 0), best = null, bestKey = -Infinity, tries = spec.tries || 6, t = 0, done = false;
    function step() {
      if (done) return true;
      var arr = build({ w: spec.w, h: spec.h, fill: spec.fill, maxLen: spec.maxLen, maxFree: spec.maxFree, curve: spec.curve, rand: rand, effort: spec.effort, passes: spec.passes, flipP: spec.flipP == null ? 0.05 : spec.flipP, cycles: spec.cycles, fillMax: spec.fillMax });
      if (arr) {
        var L = { w: spec.w, h: spec.h, arrows: shuffle(arr.map(function (a) { return { cells: a.cells.map(function (c) { return [c[0], c[1]]; }), dir: a.dir }; }), rand) };
        var m = measure(L);
        if (m.solvable) {
          var freeLim = Math.max(1, Math.floor(spec.maxFree * m.arrows + 1e-9)); // docs/09: ≤ oran (en az 1)
          // kıvrımlı oran "~": seviye başına en çok 0,15 altında (bölüm ortalaması doğrulayıcıda 0,12)
          var dMin = spec.minDepth || 0, dMax = spec.maxDepth == null ? Infinity : spec.maxDepth; // v1.5: kademe derinlik penceresi
          var ok = m.fill >= spec.fill - 0.02 && (!spec.fillMax || m.fill <= spec.fillMax + 1e-9) && m.initialFree <= freeLim && m.depth >= dMin && m.depth <= dMax && (spec.curve == null || m.curvedRatio >= spec.curve - (spec.curveSlack == null ? 0.15 : spec.curveSlack));
          var hardOk = m.fill >= spec.fill - 0.02 && (!spec.fillMax || m.fill <= spec.fillMax + 1e-9) && m.initialFree <= freeLim; // kademe bandı (zorunlu)
          var key = (ok ? 1000 : 0) + (hardOk ? 500 : 0) + m.score - Math.max(0, m.initialFree - freeLim) * 3 - Math.max(0, (spec.curve || 0) - 0.1 - m.curvedRatio) * 100 - Math.max(0, spec.fill - m.fill) * 200
            - Math.max(0, dMin - m.depth, m.depth - dMax) * 5;
          if (key > bestKey) { bestKey = key; best = { w: spec.w, h: spec.h, arrows: L.arrows, m: m, ok: ok, band: hardOk }; }
          if (ok) done = true;
        }
      }
      t++; if (t >= tries) done = true;
      return done;
    }
    return { step: step, result: function () { return best; } };
  }
  /**
   * generate(spec, seed) → { w, h, arrows, m, ok } — spec: { w, h, fill, fillMax, maxLen, maxFree, curve, minDepth, tries, ... }
   * Koşulları (doluluk bandı, başta çıkabilen, kıvrımlı oran) sağlayan en iyi denemeyi döndürür; sağlanamazsa en iyiyi.
   */
  function generate(spec, seed) { var j = genJob(spec, seed); while (!j.step()); return j.result(); }

  // =====================================================================================================
  // v2 — sürüm 1.2.0 "Aşama A" (docs/17, docs/24): bölüm = 20 seviye (5 Kolay → 5 Orta → 5 Zor → 5 Aşırı zor),
  // tahta bölümden bölüme büyür (GROW_CHAPTERS bölümde en küçükten en büyüğe ≈ 28x45), sonra en küçüğe döner.
  // Yeni üretici (build2): uzun, çok kıvrımlı, iç içe oklar + şekilli (maskeli) tahtalar.
  // Günlük bulmaca eski üreticiyi (build/generate + TIERS) kullanmaya devam eder → değişmez.
  //
  // YÖNTEM (build2) — bağımlılık çizgesi artımlı olarak DÖNGÜSÜZ tutulur, bu yüzden her çıktı kurgu gereği çözülebilir:
  //   X oku, başının baktığı doğru (ışın) üzerindeki tüm oklara bağımlıdır (onlar çıkmadan çıkamaz).
  //   Yeni ok için önce baş hücresi + yön seçilir; ışındaki oklardan başlayarak X'in bağımlı olduğu tüm oklar (Desc) bulunur.
  //   Desc içindeki okların ışınlarının geçtiği hücreler X'in gövdesine YASAKTIR (yoksa Desc→X kenarı döngü kurardı).
  //   Gövde, yasak olmayan boş hücrelerde baştan geriye serbestçe büyür (uzunluk/dönüş/sarmal eğilimi kademeye göre).
  //   Işını boş ok (başta çıkabilen) yalnızca kademe bütçesi kadar yerleştirilir → başta çıkabilen sayısı kurgu gereği sınırlı.
  // Yalnızca tamsayı işlemleri, rand() karşılaştırmaları, IEEE-kesin + − × ÷ ve √ kullanılır (Dart portu bit-bit aynı olmalı).
  var PER_CHAPTER = 20, PREBUILT = 100, DESIGNED = 5000, CHAPTERS = 250, CHAPTER_BONUS = 150;
  /** AYAR: en küçük tahtadan en büyüğe kaç bölümde varılır (sonraki bölüm yine en küçüğe döner). Sahip onayıyla değişir. */
  var GROW_CHAPTERS = 9;
  var MIN_W = 9, MIN_H = 13, MAX_W = 28, MAX_H = 45;
  var TIER_ORDER = ['easy', 'medium', 'hard', 'extreme'], TIER_SPAN = 5;
  var CYCLE = []; (function () { for (var i = 0; i < PER_CHAPTER; i++) CYCLE.push(TIER_ORDER[Math.floor(i / TIER_SPAN)]); })();
  /**
   * Kademe ayarları (AYAR tablosu). band = doluluk bandı (maske hücrelerine oranla), fill = hedef;
   * free = başta çıkabilen oranı bütçesi, maxFree = doğrulayıcı üst sınırı (en az 1 ok), minFree = en az bu kadar ok başta çıkabilir kalır;
   * len = [en kısa, en uzun] gövde, turns = [en az, en çok] dönüş, turn = dönme eğilimi, same = aynı yöne dönme (sarmal) olasılığı,
   * hug = dolu hücrelere yaslanma (sıkı kıvrım), deep = derin zincire bağlanma olasılığı, ext = kuyruk uzatma, filler = dolgu oku en çok uzunluk, tries = gövde denemesi (en uzun/en kıvrımlı seçilir),
   * minTurns = ok başına ortalama dönüş alt sınırı (seviye kabulü), mult = jeton çarpanı.
   */
  var TIER2 = {
    easy:    { fill: 0.60, band: [0.50, 0.70], free: 0.15, maxFree: 0.24, minFree: 3, len: [2, 5],  turns: [0, 1], turn: 0.25, same: 0.5,  hug: 0.15, deep: 0.0,  ext: 0, filler: 2, tries: 1, minTurns: 0.10, mult: 1 },
    medium:  { fill: 0.72, band: [0.64, 0.80], free: 0.09, maxFree: 0.14, minFree: 3, len: [3, 9],  turns: [1, 3], turn: 0.45, same: 0.5,  hug: 0.35, deep: 0.3,  ext: 1, filler: 2, tries: 2, minTurns: 0.6,  mult: 1.5 },
    hard:    { fill: 0.82, band: [0.75, 0.89], free: 0.05, maxFree: 0.08, minFree: 2, len: [5, 16], turns: [2, 6], turn: 0.6,  same: 0.6,  hug: 0.6,  deep: 0.6,  ext: 1, filler: 2, tries: 4, minTurns: 1.5,  mult: 2 },
    extreme: { fill: 0.90, band: [0.83, 0.96], free: 0.03, maxFree: 0.05, minFree: 2, len: [8, 28], turns: [4, 9], turn: 0.75, same: 0.65, hug: 0.9,  deep: 0.85, ext: 1, filler: 2, tries: 8, minTurns: 2.6,  mult: 3 }
  };
  // Eski kademe tablosu (v1.5): YALNIZCA günlük bulmaca (daily.js, eski build/generate) kullanır — değiştirmeyin, günlük bulmaca değişir.
  var TIERS = {
    easy:    { fill: 0.675, band: [0.65, 0.70], maxFree: 0.12, curve: 0.30, mult: 1 },
    medium:  { fill: 0.775, band: [0.75, 0.80], maxFree: 0.07, curve: 0.45, mult: 1.5 },
    hard:    { fill: 0.840, band: [0.82, 0.86], maxFree: 0.04, curve: 0.55, mult: 2 },
    extreme: { fill: 0.905, band: [0.88, 0.93], maxFree: 0.02, curve: 0.65, mult: 3 }
  };
  var MAX_ARROW_LEN = 48; // yapı denetimi üst sınırı (kuyruk uzatma dahil)
  var TUTORIAL = [ // seviye 1-3 (elle tasarlanmış, değişmez; düz oklar). Biçim: eski {x,y,dir,len} → toCells ile {cells,dir}
    { w: 3, h: 3, arrows: [{ x: 2, y: 0, dir: 'D', len: 2 }, { x: 2, y: 2, dir: 'L', len: 2 }] },
    { w: 3, h: 3, arrows: [{ x: 0, y: 2, dir: 'R', len: 2 }, { x: 2, y: 2, dir: 'U', len: 1 }, { x: 2, y: 0, dir: 'L', len: 2 }] },
    { w: 4, h: 4, arrows: [{ x: 3, y: 1, dir: 'D', len: 2 }, { x: 2, y: 3, dir: 'R', len: 2 }, { x: 0, y: 2, dir: 'R', len: 2 }, { x: 1, y: 0, dir: 'D', len: 2 }] }
  ];
  function chapterOf(id) { return Math.floor((id - 1) / PER_CHAPTER) + 1; }
  function indexOf(id) { return (id - 1) % PER_CHAPTER; }              // bölüm içi sıra, 0..19
  function tierOf(id) { return CYCLE[(id - 1) % PER_CHAPTER]; }        // SEVİYE kademesi
  /** Tahta boyu yalnızca bölüme bağlıdır (tamsayı işlemleri): büyüme döngüsünün g. adımı, doğrusal + yuvarlama. */
  function sizeOfChapter(ch) {
    var d = GROW_CHAPTERS - 1, g = (ch - 1) % GROW_CHAPTERS;
    if (d <= 0) return { w: MAX_W, h: MAX_H };
    return { w: MIN_W + Math.floor(((MAX_W - MIN_W) * g * 2 + d) / (2 * d)), h: MIN_H + Math.floor(((MAX_H - MIN_H) * g * 2 + d) / (2 * d)) };
  }
  /**
   * AYAR (1.2.0 sahip kararı #2, docs/26): bölüm içinde Kolay/Orta seviyeler bölüm tahtasından KÜÇÜK tahtada oynanır
   * ("bölüm nefes alır"; büyük tahta Zor ve Aşırı zor içindir). Değer = kenar uzunluğu yüzdesi (en-boy oranı korunur):
   * Kolay %71 (alanın ≈ %50'si), Orta %85 (≈ %72), Zor %95 (≈ %90), Aşırı zor %100. Hiçbir kenar en küçük tahtanın altına inmez.
   * Yalnızca tamsayı işlemleri (yarım yukarı yuvarlama) → Dart'ta aynı sonuç.
   */
  var TIER_SIZE_PCT = { easy: 71, medium: 85, hard: 95, extreme: 100 };
  function scaleDim(v, pct, min) { var r = Math.floor((v * pct * 2 + 100) / 200); return r < min ? min : r; }
  /** Seviyenin tahta boyu: bölüm tahtası × kademe ölçeği (TIER_SIZE_PCT). */
  function sizeOf(id) {
    var cs = sizeOfChapter(chapterOf(id)), pct = TIER_SIZE_PCT[tierOf(id)];
    if (pct >= 100) return { w: cs.w, h: cs.h };
    return { w: scaleDim(cs.w, pct, MIN_W), h: scaleDim(cs.h, pct, MIN_H) };
  }
  /** Aşırı zor seviyelerin tahta biçimi (bölüm içi sıra 15..19): yeterince büyük tahtada şekilli. */
  var SHAPES = ['organic', 'ring', 'full', 'ringOrganic', 'ring'], SHAPE_MIN_W = 14;
  function shapeOf(id) {
    var sz = sizeOf(id);
    if (tierOf(id) !== 'extreme' || sz.w < SHAPE_MIN_W) return 'full';
    return SHAPES[(indexOf(id) - 15 + chapterOf(id)) % SHAPES.length];
  }
  function specFor(id) {
    var ch = chapterOf(id), tier = tierOf(id), sz = sizeOf(id);
    return { id: id, chapter: ch, index: indexOf(id), tier: tier, w: sz.w, h: sz.h, shape: shapeOf(id), p: TIER2[tier], seed: seedFor(id, 0) };
  }
  /** Seviye no → sabit tohum (herkes için aynı seviye). round: aynı seviyenin yedek denemeleri. */
  function seedFor(id, round) { return hash('arrowtile-v20-' + id + '-' + (round || 0)); }
  function toCells(a) { return { cells: cellsOf(a).map(function (c) { return [c[0], c[1]]; }), dir: a.dir }; }
  function tutorialLevel(id) {
    var t = TUTORIAL[id - 1], arrows = t.arrows.map(toCells);
    return { id: id, w: t.w, h: t.h, par: arrows.length, diff: 'easy', chapter: 1, arrows: arrows, ok: true, rounds: 0 };
  }
  function turnsOf(a) {
    var c = cellsOf(a), t = 0;
    for (var i = 2; i < c.length; i++) if (c[i][0] - c[i - 1][0] !== c[i - 1][0] - c[i - 2][0] || c[i][1] - c[i - 1][1] !== c[i - 1][1] - c[i - 2][1]) t++;
    return t;
  }

  // ---- maske (şekilli tahta): Uint8Array(w*h), 1 = oynanabilir hücre. Yalnızca rand(), tamsayı ve √.
  function profile(n, amp, rand) { // 0..amp arası yumuşak tamsayı profil (parçalı doğrusal)
    var out = [], step = 4, a = Math.floor(rand() * (amp + 1)), b = a, k;
    for (var i = 0; i < n; i++) {
      k = i % step;
      if (k === 0) { a = b; b = Math.floor(rand() * (amp + 1)); }
      out.push(Math.floor((a * (step - k) + b * k + (step >> 1)) / step));
    }
    return out;
  }
  function makeMask(w, h, kind, rand) {
    var N = w * h, m = new Uint8Array(N), x, y, i;
    for (i = 0; i < N; i++) m[i] = 1;
    if (kind === 'full') return m;
    var organic = kind === 'organic' || kind === 'ringOrganic', ring = kind === 'ring' || kind === 'ringOrganic';
    if (organic) {
      var amp = Math.max(1, Math.floor(w / 9)), L = profile(h, amp, rand), R = profile(h, amp, rand), T = profile(w, amp, rand), B = profile(w, amp, rand);
      var cc = Math.max(2, Math.floor(w / 6)); // köşe kesiği
      for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
        var dx = Math.min(x, w - 1 - x), dy = Math.min(y, h - 1 - y);
        if (x < L[y] || x >= w - R[y] || y < T[x] || y >= h - B[x] || dx + dy < cc) m[y * w + x] = 0;
      }
    }
    if (ring) {
      var cx = (w - 1) / 2 + (rand() - 0.5) * 2, cy = (h - 1) / 2 + (rand() - 0.5) * 3;
      var rx = w * (0.24 + rand() * 0.05), ry = h * (0.19 + rand() * 0.05), jit = profile(h, 2, rand);
      var ix = Math.max(1.6, rx * 0.42), iy = Math.max(2.1, ry * 0.36);
      for (y = 0; y < h; y++) {
        var ty = (y - cy) / ry; if (ty < -1 || ty > 1) continue;
        var half = rx * Math.sqrt(1 - ty * ty) + (jit[y] - 1) * 0.6;
        for (x = 0; x < w; x++) {
          if (Math.abs(x - cx) > half) continue;
          var ex = (x - cx) / ix, ey = (y - cy) / iy;
          if (ex * ex + ey * ey <= 1) continue; // ortadaki ada
          m[y * w + x] = 0;
        }
      }
    }
    return m;
  }
  function maskRows(m, w, h) { var rows = []; for (var y = 0; y < h; y++) { var s = ''; for (var x = 0; x < w; x++) s += m[y * w + x] ? '1' : '0'; rows.push(s); } return rows; }
  function maskCount(lv) { if (!lv.mask) return lv.w * lv.h; var c = 0; lv.mask.forEach(function (r) { for (var i = 0; i < r.length; i++) if (r.charCodeAt(i) === 49) c++; }); return c; }

  var DXC = [0, 0, -1, 1], DYC = [-1, 1, 0, 0], DNAME = ['U', 'D', 'L', 'R'], TL = [2, 3, 1, 0], TR = [3, 2, 0, 1];
  /**
   * build2({ w, h, mask, rand, p }) → { arrows: [{cells, dir}], cells, maskCells } — her zaman çözülebilir (döngüsüz kurgu).
   */
  function build2(o) {
    var w = o.w, h = o.h, N = w * h, rand = o.rand, P = o.p, mask = o.mask, i;
    var g = new Int16Array(N), hd = new Int8Array(N), M = 0;
    for (i = 0; i < N; i++) { hd[i] = -1; if (!mask || mask[i]) { g[i] = -1; M++; } else g[i] = -2; }
    var A = [], forb = new Int32Array(N), own = new Int32Array(N), ep = 0, oep = 0, seenA = new Int32Array(N + 1), queue = new Int32Array(N + 1);
    var nFree = 0, filled = 0, target = P.fill * M;
    var avgLen = (P.len[0] + P.len[1]) / 2 * 0.7 + 1;
    var budget = Math.max(P.minFree, Math.floor(P.free * target / avgLen + 0.5));
    // ışın taraması: (c'den d yönünde kenara dek) dolu hücre sayısı + en büyük kat
    function rayInfo(c, d) {
      var x = c % w + DXC[d], y = Math.floor(c / w) + DYC[d], cnt = 0, lv = 0;
      while (x >= 0 && y >= 0 && x < w && y < h) { var k = g[y * w + x]; if (k >= 0) { cnt++; if (A[k].lvl > lv) lv = A[k].lvl; } x += DXC[d]; y += DYC[d]; }
      return [cnt, lv];
    }
    // X'in (baş c, yön d) bağımlı olduğu tüm okların ışınlarını (ve kendi ışınını) yasakla (forb = ep)
    function markDesc(c, d) {
      ep++;
      var qh = 0, qt = 0, x = c % w + DXC[d], y = Math.floor(c / w) + DYC[d], k, q;
      while (x >= 0 && y >= 0 && x < w && y < h) { q = y * w + x; forb[q] = ep; k = g[q]; if (k >= 0 && seenA[k] !== ep) { seenA[k] = ep; queue[qt++] = k; } x += DXC[d]; y += DYC[d]; }
      while (qh < qt) {
        var a = A[queue[qh++]], hc = a.cells[a.cells.length - 1], ad = a.d;
        x = hc % w + DXC[ad]; y = Math.floor(hc / w) + DYC[ad];
        while (x >= 0 && y >= 0 && x < w && y < h) { q = y * w + x; forb[q] = ep; k = g[q]; if (k >= 0 && seenA[k] !== ep) { seenA[k] = ep; queue[qt++] = k; } x += DXC[ad]; y += DYC[ad]; }
      }
    }
    function okCell(x, y) { if (x < 0 || y < 0 || x >= w || y >= h) return false; var q = y * w + x; return g[q] === -1 && forb[q] !== ep && own[q] !== oep; }
    function solid(x, y) { if (x < 0 || y < 0 || x >= w || y >= h) return 1; var q = y * w + x; return (g[q] !== -1 || own[q] === oep) ? 1 : 0; }
    // gövde: baştan geriye büyür. Dönen: hücre indeksleri kuyruk→baş
    function body(c, d, L, maxTurns) {
      var cells = [c], x = c % w, y = Math.floor(c / w), s = d, run = 1, turns = 0, last = 0;
      oep++; own[c] = oep;
      while (cells.length < L) {
        var cand = [], wts = [], tot = 0, k;
        for (k = 0; k < 3; k++) {
          var ns = k === 0 ? s : k === 1 ? TL[s] : TR[s];
          if (k > 0 && (cells.length === 1 || turns >= maxTurns)) continue;
          var nx = x - DXC[ns], ny = y - DYC[ns];
          if (!okCell(nx, ny)) continue;
          var occ = solid(nx + 1, ny) + solid(nx - 1, ny) + solid(nx, ny + 1) + solid(nx, ny - 1) - 1; // geldiğimiz hücre hariç
          var wt;
          if (k === 0) wt = run < 2 ? 6 : 1;
          else wt = P.turn * (run < 2 ? 0.08 : 1) * (last === 0 ? 1 : (last === k ? 2 * P.same : 2 * (1 - P.same)));
          wt *= 1 + P.hug * occ;
          if (occ >= 3 && cells.length + 1 < L) wt *= 0.3; // çıkmaz sokak
          cand.push(k); wts.push(wt); tot += wt;
        }
        if (!cand.length) break;
        var r = rand() * tot, pick = cand[cand.length - 1];
        for (k = 0; k < cand.length; k++) { r -= wts[k]; if (r <= 0) { pick = cand[k]; break; } }
        if (pick !== 0) { s = pick === 1 ? TL[s] : TR[s]; turns++; last = pick; run = 1; } else run++;
        x -= DXC[s]; y -= DYC[s];
        var q = y * w + x; own[q] = oep; cells.push(q);
      }
      cells.reverse();
      return { cells: cells, turns: turns };
    }
    // hücre c dolunca: ışını c'den geçen okların engel sayacını artır (list verilirse yalnızca şu an serbest olanları toplar)
    function crossers(c, list) {
      var cx = c % w, cy = Math.floor(c / w), x, y, q;
      for (x = cx - 1; x >= 0; x--) { q = cy * w + x; if (hd[q] === 3) hit(g[q], list); }
      for (x = cx + 1; x < w; x++) { q = cy * w + x; if (hd[q] === 2) hit(g[q], list); }
      for (y = cy - 1; y >= 0; y--) { q = y * w + cx; if (hd[q] === 1) hit(g[q], list); }
      for (y = cy + 1; y < h; y++) { q = y * w + cx; if (hd[q] === 0) hit(g[q], list); }
    }
    function hit(k, list) { if (list) { if (!A[k].blk && list.indexOf(k) < 0) list.push(k); } else if (A[k].blk++ === 0) nFree--; }
    function wouldBlock(cells) { var list = []; for (var k = 0; k < cells.length; k++) crossers(cells[k], list); return list.length; } // kaç serbest ok kapanır
    function commit(cells, d, blk, lvl) {
      var id = A.length, k;
      A.push({ cells: cells, d: d, blk: blk, lvl: lvl });
      for (k = 0; k < cells.length; k++) g[cells[k]] = id;
      hd[cells[cells.length - 1]] = d;
      for (k = 0; k < cells.length; k++) crossers(cells[k], null);
      if (!blk) nFree++;
      filled += cells.length;
    }
    function tryPlace(c, lenMin, lenLo, lenHi, turnLo, turnHi) {
      var order = shuffle([0, 1, 2, 3], rand), k, cx = c % w, cy = Math.floor(c / w), info = [], cands = [];
      var allowFree = nFree < budget;
      for (k = 0; k < 4; k++) {
        var d = order[k], bx = cx - DXC[d], by = cy - DYC[d];
        if (lenMin >= 2 && !(bx >= 0 && by >= 0 && bx < w && by < h && g[by * w + bx] === -1)) continue;
        var ri = rayInfo(c, d);
        if (!ri[0] && !allowFree) continue;
        cands.push(d); info[d] = ri;
      }
      if (!cands.length) return false;
      if (cands.length > 1 && rand() < P.deep) cands.sort(function (a, b) { return (info[b][1] - info[a][1]) || (a - b); });
      for (k = 0; k < cands.length; k++) {
        var dd = cands[k];
        markDesc(c, dd);
        if (forb[c] === ep) continue; // baş hücresi bağımlı olunan bir okun ışınında: döngü
        var L = lenLo + Math.floor(rand() * (lenHi - lenLo + 1)), mt = turnLo + Math.floor(rand() * (turnHi - turnLo + 1));
        var b = body(c, dd, L, mt), tr = 1;
        for (; tr < P.tries && lenMin > 1 && (b.cells.length < L || b.turns < mt); tr++) { // en uzun + en kıvrımlı deneme
          var b2 = body(c, dd, L, mt);
          if (b2.cells.length + 2 * b2.turns > b.cells.length + 2 * b.turns) b = b2;
        }
        if (b.cells.length < lenMin) continue;
        if (lenMin > 1 && turnLo >= 1 && b.cells.length >= 4 && !b.turns) continue; // kıvrım isteyen kademede uzun düz ok yok
        var free = !info[dd][0];
        if (P.minFree) { var nb = wouldBlock(b.cells); if (nb && nFree - nb + (free ? 1 : 0) < P.minFree) continue; }
        commit(b.cells, dd, info[dd][0], info[dd][1] + 1);
        return true;
      }
      return false;
    }
    function empties() { var e = []; for (var q = 0; q < N; q++) if (g[q] === -1) e.push(q); return shuffle(e, rand); }
    function sweep(lenMin, lenLo, lenHi, tLo, tHi) {
      var e = empties(), added = 0;
      for (var k = 0; k < e.length && filled < target; k++) { if (g[e[k]] !== -1) continue; if (tryPlace(e[k], lenMin, lenLo, lenHi, tLo, tHi)) added++; }
      return added;
    }
    // kuyruk uzatma: boş hücre bir okun kuyruğuna komşuysa ve döngü kurmuyorsa oka eklenir (tek hücrelik dolgu yerine kıvrım)
    function extend(maxLen) {
      var e = empties(), added = 0, k, j;
      for (k = 0; k < e.length && filled < target; k++) {
        var c = e[k]; if (g[c] !== -1) continue;
        var cx = c % w, cy = Math.floor(c / w);
        for (j = 0; j < 4; j++) {
          var nx = cx + DXC[j], ny = cy + DYC[j]; if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          var a = g[ny * w + nx]; if (a < 0) continue;
          var ar = A[a]; if (ar.cells[0] !== ny * w + nx || ar.cells.length >= maxLen) continue;
          if (ar.cells.length === 1 && !(DXC[ar.d] === nx - cx && DYC[ar.d] === ny - cy)) continue; // tek hücrelik ok: gövde başın tam arkasına
          markDesc(ar.cells[ar.cells.length - 1], ar.d); // a'nın bağımlı olduklarının ışınları + kendi ışını
          if (forb[c] === ep) continue;
          if (P.minFree) { var nb = wouldBlock([c]); if (nb && nFree - nb < P.minFree) continue; }
          ar.cells.unshift(c); g[c] = a; crossers(c, null); filled++; added++;
          break;
        }
      }
      return added;
    }
    var lo = P.len[0], hi = P.len[1], guard;
    // 1) uzun kıvrımlı oklar, 2) orta boy, 3) kuyruk uzatma (tek hücrelik boşlukları kıvrıma katar),
    // 4) kısa dolgu okları YALNIZCA doluluk bandın alt sınırına (+0,03) ulaşmadıysa → kısa düz oklar azınlıkta kalır
    for (guard = 0; guard < 4 && filled < target; guard++) if (!sweep(lo, lo, hi, P.turns[0], P.turns[1])) break;
    var mid = Math.max(2, lo >> 1), mid2 = Math.max(mid, 3);
    for (guard = 0; guard < 3 && filled < target; guard++) if (!sweep(mid2, mid2, Math.max(mid2, hi >> 1), Math.min(1, P.turns[0]), P.turns[1])) break;
    if (P.ext) for (guard = 0; guard < 6 && filled < target; guard++) if (!extend(hi + 8)) break;
    var full = target; target = Math.min(full, (P.band[0] + 0.03) * M);
    for (guard = 0; guard < 3 && filled < target; guard++) if (!sweep(mid, mid, Math.max(mid, 3), 0, 1)) break;
    for (guard = 0; guard < 3 && filled < target; guard++) if (!sweep(1, 1, P.filler, 0, 1)) break;
    target = full;
    if (P.ext) for (guard = 0; guard < 3 && filled < target; guard++) if (!extend(hi + 12)) break;
    return { maskCells: M, cells: filled, arrows: A.map(function (a) { return { cells: a.cells.map(function (q) { return [q % w, Math.floor(q / w)]; }), dir: DNAME[a.d] }; }) };
  }
  /** Kampanya ölçüsü (v2): doluluk maske hücrelerine oranla; puan = 40·doluluk + 8·ort. dönüş + 2·ort. uzunluk + 30·(1 − 5·serbest oran) + 0,1·derinlik. */
  function measure2(L) {
    var n = L.arrows.length, an = analyze(L);
    if (an.stuck.length || !n) return { solvable: false, depth: an.depth, initialFree: an.free.length };
    var cells = totalCells(L), M = maskCount(L), turns = 0, curved = 0, maxLen = 0;
    L.arrows.forEach(function (a) { var t = turnsOf(a); turns += t; if (t) curved++; if (lenOf(a) > maxLen) maxLen = lenOf(a); });
    var fill = cells / M, freeRatio = an.free.length / n, meanTurns = turns / n, meanLen = cells / n;
    var fr5 = freeRatio * 5 > 1 ? 1 : freeRatio * 5;
    var score = 40 * fill + 8 * meanTurns + 2 * meanLen + 30 * (1 - fr5) + 0.1 * an.depth;
    return { solvable: true, depth: an.depth, initialFree: an.free.length, freeRatio: freeRatio, fill: fill, arrows: n, curved: curved, curvedRatio: curved / n,
      meanTurns: meanTurns, meanLen: meanLen, maxLen: maxLen, score: score };
  }
  function freeLimit(tier, n) { return Math.max(TIER2[tier].minFree, 1, Math.floor(TIER2[tier].maxFree * n + 1e-9)); }
  /**
   * Seviye işi: tohum = seviye numarası (seedFor(id, tur)); kademe koşullarını sağlayan ilk tur seçilir (en çok ROUNDS tur,
   * sağlanamazsa en iyi aday). step() tek build2 yapar → arka planda dilimlenebilir. Zaman sınırı yok, yalnızca adım sayısı →
   * aynı seviye her cihazda aynıdır. Hem hazır paket hem oyun içi seviyeler bu işle üretilir.
   */
  var ROUNDS = 8, ENDLESS_ROUNDS = ROUNDS;
  function levelJob(id) {
    if (id <= TUTORIAL.length) { var tl = tutorialLevel(id); return { id: id, step: function () { return true; }, result: function () { return tl; } }; }
    var sp = specFor(id), P = sp.p, r = 0, best = null, out = null;
    function step() {
      if (out) return true;
      var rand = rng(seedFor(id, r));
      var mask = sp.shape === 'full' ? null : makeMask(sp.w, sp.h, sp.shape, rand);
      var b = build2({ w: sp.w, h: sp.h, mask: mask, rand: rand, p: P });
      var L = { id: id, w: sp.w, h: sp.h, arrows: shuffle(b.arrows, rand) };
      if (mask) L.mask = maskRows(mask, sp.w, sp.h);
      var m = measure2(L);
      if (m.solvable) {
        var ok = m.fill >= P.band[0] - 1e-9 && m.fill <= P.band[1] + 1e-9 && m.initialFree <= freeLimit(sp.tier, m.arrows) && m.meanTurns >= P.minTurns;
        var key = (ok ? 1e6 : 0) + m.score;
        if (!best || key > best.key) best = { key: key, L: L, m: m, ok: ok };
      }
      r++;
      if (!best && r >= ROUNDS * 4) throw new Error('levelgen: çözülebilir aday yok (seviye ' + id + ')');
      if (best && (best.ok || r >= ROUNDS)) {
        out = { id: id, w: sp.w, h: sp.h, par: best.L.arrows.length, diff: sp.tier, chapter: sp.chapter, arrows: best.L.arrows, ok: best.ok, rounds: r, m: best.m };
        if (best.L.mask) out.mask = best.L.mask;
        return true;
      }
      return false;
    }
    return { id: id, step: step, result: function () { return out; } };
  }
  function makeLevel(id) { var j = levelJob(id); while (!j.step()); return j.result(); }

  // ---- seviye özeti (Dart altın testi): kanonik serileştirme + FNV-1a 32 ----
  // canon = "id:wxh:tier:" + oklar "x,y;x,y;...>D" birleşimi ("|" ayracı); oklar üretici sırasında (dizideki sıra).
  function canon(lv) {
    return lv.id + ':' + lv.w + 'x' + lv.h + ':' + (lv.diff || tierOf(lv.id)) + ':' + lv.arrows.map(function (a) {
      return cellsOf(a).map(function (c) { return c[0] + ',' + c[1]; }).join(';') + '>' + a.dir;
    }).join('|') + (lv.mask ? ':m' + lv.mask.join('/') : '');
  }
  function levelHash(lv) { return ('0000000' + hash(canon(lv)).toString(16)).slice(-8); }

  var VERSION = 'v20.1'; // üretici/özellik kuralı değişirse artır (oyundaki sonsuz seviye önbelleği geçersizleşir)
  var LevelGen = { VERSION: VERSION, rng: rng, hash: hash, build: build, generate: generate, measure: measure, analyze: analyze, label: label, BANDS: BANDS, cellsOf: cellsOf, headOf: headOf, lenOf: lenOf, norm: norm, isCurved: isCurved, ownLineOk: ownLineOk,
    TIER2: TIER2, TIER_ORDER: TIER_ORDER, GROW_CHAPTERS: GROW_CHAPTERS, MIN_W: MIN_W, MIN_H: MIN_H, MAX_ARROW_LEN: MAX_ARROW_LEN, build2: build2, measure2: measure2,
    makeMask: makeMask, maskCount: maskCount, turnsOf: turnsOf, shapeOf: shapeOf, freeLimit: freeLimit, ROUNDS: ROUNDS,
    CYCLE: CYCLE, TIERS: TIERS, PER_CHAPTER: PER_CHAPTER, PREBUILT: PREBUILT, DESIGNED: DESIGNED, CHAPTERS: CHAPTERS, CHAPTER_BONUS: CHAPTER_BONUS, MAX_W: MAX_W, MAX_H: MAX_H, TUTORIAL: TUTORIAL,
    chapterOf: chapterOf, indexOf: indexOf, tierOf: tierOf, sizeOfChapter: sizeOfChapter, sizeOf: sizeOf, TIER_SIZE_PCT: TIER_SIZE_PCT, specFor: specFor, seedFor: seedFor, makeLevel: makeLevel, levelJob: levelJob, genJob: genJob, ENDLESS_ROUNDS: ENDLESS_ROUNDS,
    canon: canon, levelHash: levelHash };
  root.LevelGen = LevelGen;
  if (typeof module !== 'undefined' && module.exports) module.exports = LevelGen;
})(typeof window !== 'undefined' ? window : globalThis);
