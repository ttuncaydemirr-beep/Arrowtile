/* Arrowtile — levelgen.js: ortak seviye üretici + ölçüler (v1.2 docs/08 §3; v1.3 kıvrımlı oklar docs/09)
 * Hem tools/generate-levels.js (120 seviye) hem game/js/daily.js (günlük bulmaca) bunu kullanır.
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
    var wts = [y + 0.5, h - y - 0.5, x + 0.5, w - x - 0.5].map(function (v) { return Math.pow(v, 1.6); }); // U D L R
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
      var fr7 = an7.free.slice().sort(function (p, q) { return lenOf(L.arrows[p]) - lenOf(L.arrows[q]); }), did7 = false;
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
          var ok = m.fill >= spec.fill - 0.02 && (!spec.fillMax || m.fill <= spec.fillMax + 1e-9) && m.initialFree <= freeLim && m.depth >= (spec.minDepth || 0) && (spec.curve == null || m.curvedRatio >= spec.curve - 0.15);
          var key = (ok ? 1000 : 0) + m.score - Math.max(0, m.initialFree - freeLim) * 3 - Math.max(0, (spec.curve || 0) - 0.1 - m.curvedRatio) * 100 - Math.max(0, spec.fill - m.fill) * 200;
          if (key > bestKey) { bestKey = key; best = { w: spec.w, h: spec.h, arrows: L.arrows, m: m, ok: ok }; }
          if (ok && t >= 1) done = true;
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

  // ---- v1.3 bölüm döngüsü (docs/09) — hazır 216 seviye ve sonsuz devam aynı kuralları kullanır ----
  var CYCLE = ['easy', 'easy', 'easy', 'medium', 'medium', 'medium', 'hard', 'hard', 'extreme'];
  // fill = hedef doluluk (bant ortası), band = [en az, en çok], maxFree = başta çıkabilen oranı üst sınırı, curve = kıvrımlı oran
  var TIERS = {
    easy:    { fill: 0.675, band: [0.65, 0.70], maxFree: 0.12, curve: 0.30, mult: 1,   bonus: 50 },
    medium:  { fill: 0.775, band: [0.75, 0.80], maxFree: 0.07, curve: 0.45, mult: 1.5, bonus: 75 },
    hard:    { fill: 0.840, band: [0.82, 0.86], maxFree: 0.04, curve: 0.55, mult: 2,   bonus: 100 },
    extreme: { fill: 0.905, band: [0.88, 0.93], maxFree: 0.02, curve: 0.65, mult: 3,   bonus: 200 }
  };
  var PER_CHAPTER = 12, PREBUILT = 216, MAX_W = 22, MAX_H = 31;
  function chapterOf(id) { return Math.floor((id - 1) / PER_CHAPTER) + 1; }
  function tierOf(ch) { return CYCLE[(ch - 1) % CYCLE.length]; }
  /** Seviye numarasından üretim özellikleri. Tahta bölüm bölüm büyür (zorluktan bağımsız), bölüm içinde hafifçe. */
  function specFor(id) {
    var ch = chapterOf(id), k = (id - 1) % PER_CHAPTER, tier = tierOf(ch), T = TIERS[tier];
    var t = (ch - 1) + k / PER_CHAPTER; // bölüm 1 başı 7x9 → bölüm 18 sonu 20x28
    var w = Math.min(MAX_W, 7 + Math.round(t * 13 / 17.92)), h = Math.min(MAX_H, 9 + Math.round(t * 19 / 17.92));
    var maxLen = Math.min(8, 4 + Math.floor(w / 4));
    var sp = { id: id, chapter: ch, tier: tier, w: w, h: h, fill: T.fill, fillMax: T.band[1], maxFree: T.maxFree, curve: T.curve, maxLen: maxLen,
      tries: 3, effort: 24, passes: 12, cycles: 4 };
    if (tier === 'extreme') { sp.effort = 40; sp.passes = 20; sp.cycles = 6; }
    return sp;
  }
  /** Seviye no → sabit tohum (herkes için aynı seviye). round: aynı seviyenin yedek denemeleri. */
  function seedFor(id, round) { return hash('arrowtile-v13-' + id + '-' + (round || 0)); }
  /** Bir seviyeyi üretir: { id, w, h, par, diff, arrows, m, ok } (kısıtlar sağlanamazsa en iyi aday). */
  /**
   * Sonsuz seviye işi (oyun içi, docs/09): tohum = seviye numarası (seedFor(id, tur)); kısıtları sağlayan ilk tur
   * seçilir (en çok ENDLESS_ROUNDS tur, sağlanamazsa en iyi aday). step() tek build yapar → arka planda dilimlenebilir.
   * Aynı seviye her cihazda aynıdır (zaman sınırı yok, yalnızca adım sayısı).
   */
  var ENDLESS_ROUNDS = 8;
  function levelJob(id) {
    var sp = specFor(id), r = 0, job = genJob(sp, seedFor(id, 0)), best = null, out = null;
    function finish() {
      out = { id: id, w: sp.w, h: sp.h, par: best.g.arrows.length, diff: sp.tier, chapter: sp.chapter, arrows: best.g.arrows, ok: best.g.ok, rounds: r + 1 };
      return true;
    }
    function step() {
      if (out) return true;
      if (!job.step()) return false;
      var g = job.result();
      if (g) { var key = (g.ok ? 1e6 : 0) + g.m.score; if (!best || key > best.key) best = { key: key, g: g }; }
      if ((g && g.ok) || r + 1 >= ENDLESS_ROUNDS) { if (best) return finish(); }
      r++; job = genJob(sp, seedFor(id, r));
      if (r >= ENDLESS_ROUNDS * 2) throw new Error('seviye üretilemedi: ' + id);
      return false;
    }
    return { id: id, step: step, result: function () { return out; } };
  }
  function makeLevel(id) { var j = levelJob(id); while (!j.step()); return j.result(); }

  var VERSION = 'v13.1'; // üretici değişirse artır (oyundaki sonsuz seviye önbelleği geçersizleşir)
  var LevelGen = { VERSION: VERSION, rng: rng, hash: hash, build: build, generate: generate, measure: measure, analyze: analyze, label: label, BANDS: BANDS, cellsOf: cellsOf, headOf: headOf, lenOf: lenOf, norm: norm, isCurved: isCurved, ownLineOk: ownLineOk,
    CYCLE: CYCLE, TIERS: TIERS, PER_CHAPTER: PER_CHAPTER, PREBUILT: PREBUILT, MAX_W: MAX_W, MAX_H: MAX_H,
    chapterOf: chapterOf, tierOf: tierOf, specFor: specFor, seedFor: seedFor, makeLevel: makeLevel, levelJob: levelJob, genJob: genJob, ENDLESS_ROUNDS: ENDLESS_ROUNDS };
  root.LevelGen = LevelGen;
  if (typeof module !== 'undefined' && module.exports) module.exports = LevelGen;
})(typeof window !== 'undefined' ? window : globalThis);
