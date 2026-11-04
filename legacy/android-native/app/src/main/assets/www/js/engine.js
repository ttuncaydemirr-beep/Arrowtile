/* Arrowtile — engine.js
 * Saf oyun mantığı (DOM yok). Tarayıcıda window.OkEngine, Node'da module.exports.
 * Kurallar: docs/01-oyun-tasarim-belgesi.md §2-5. Çözüm/ipucu mantığı tools/solver.js ile aynıdır.
 */
(function (root) {
  'use strict';

  var DIRS = { U: [0, -1], D: [0, 1], L: [-1, 0], R: [1, 0] };
  var MAX_LIVES = 3;

  // v1.3 (docs/09): kıvrımlı oklar. Yeni biçim { cells: [[x,y]...] (kuyruktan başa, komşu hücreler), dir } ;
  // eski düz biçim { x, y, dir, len } de okunur. Baş = son hücre; ok başı dir yönünde düz ilerler, gövde onu izler.
  function cellsOf(a) {
    if (a.cells) return a.cells;
    var d = DIRS[a.dir], out = [];
    for (var i = 0; i < a.len; i++) out.push([a.x + d[0] * i, a.y + d[1] * i]);
    return out;
  }
  function lenOf(a) { return a.cells ? a.cells.length : a.len; }
  function headOf(a) { var c = cellsOf(a); return c[c.length - 1]; }
  function pathOf(a, w, h) {
    var d = DIRS[a.dir], hd = headOf(a), x = hd[0] + d[0], y = hd[1] + d[1], out = [];
    while (x >= 0 && y >= 0 && x < w && y < h) { out.push([x, y]); x += d[0]; y += d[1]; }
    return out;
  }
  function buildGrid(level, alive) {
    var g = [], n = level.w * level.h, i;
    for (i = 0; i < n; i++) g.push(-1);
    level.arrows.forEach(function (a, k) {
      if (alive && !alive[k]) return;
      cellsOf(a).forEach(function (c) { g[c[1] * level.w + c[0]] = k; });
    });
    return g;
  }
  // Yoldaki ilk engel: { blocker, free } (free = engelden önceki boş hücre sayısı) ya da null
  function firstObstacle(level, i, grid) {
    var p = pathOf(level.arrows[i], level.w, level.h);
    for (var k = 0; k < p.length; k++) {
      var v = grid[p[k][1] * level.w + p[k][0]];
      if (v !== -1) return { blocker: v, free: k };
    }
    return null;
  }
  function freeList(level, alive) {
    var g = buildGrid(level, alive), out = [];
    for (var i = 0; i < level.arrows.length; i++) if (alive[i] && !firstObstacle(level, i, g)) out.push(i);
    return out;
  }
  // tools/solver.js ile aynı açgözlü çözüm
  function solve(level) {
    var n = level.arrows.length, alive = [], order = [], layers = 0, i;
    for (i = 0; i < n; i++) alive.push(true);
    while (order.length < n) {
      var free = freeList(level, alive);
      if (!free.length) return { solvable: false, order: order, layers: layers };
      free.forEach(function (k) { alive[k] = false; order.push(k); });
      layers++;
    }
    return { solvable: true, order: order, layers: layers };
  }
  // İpucu: çıkabilen oklardan en çok oku serbest bırakanı seç (eşitlikte küçük indeks)
  function bestHint(level, alive) {
    var free = freeList(level, alive);
    if (!free.length) return -1;
    var base = free.length, best = free[0], bestGain = -1;
    free.forEach(function (i) {
      var a2 = alive.slice(); a2[i] = false;
      var gain = freeList(level, a2).length - (base - 1);
      if (gain > bestGain) { bestGain = gain; best = i; }
    });
    return best;
  }

  /** Bir seviye oturumu. opts.noLifeLoss: öğretici muafiyeti (seviye 2) */
  function Game(level, opts) {
    this.level = level;
    this.opts = opts || {};
    this.reset();
  }
  Game.prototype.reset = function () {
    this.alive = this.level.arrows.map(function () { return true; });
    this.lives = MAX_LIVES;
    this.collisions = 0;
    this.taps = 0;
    this.revived = 0;
  };
  Game.prototype.remaining = function () { return this.alive.filter(Boolean).length; };
  Game.prototype.isWon = function () { return this.remaining() === 0; };
  Game.prototype.isDead = function () { return this.lives <= 0; };
  Game.prototype.grid = function () { return buildGrid(this.level, this.alive); };
  Game.prototype.arrowAt = function (cx, cy) {
    if (cx < 0 || cy < 0 || cx >= this.level.w || cy >= this.level.h) return -1;
    return this.grid()[cy * this.level.w + cx];
  };
  Game.prototype.canExit = function (i) { return !!this.alive[i] && !firstObstacle(this.level, i, this.grid()); };
  Game.prototype.freeArrows = function () { return freeList(this.level, this.alive); };
  Game.prototype.hint = function () { return bestHint(this.level, this.alive); };
  Game.prototype.stars = function () {
    var s = this.collisions === 0 ? 3 : this.collisions === 1 ? 2 : 1;
    return this.opts.relaxed ? Math.min(2, s) : s; // rahat modda en fazla 2 yıldız
  };

  /** Oka dokun. Döner: null | {type:'exit', i, steps} | {type:'bump', i, free, blocker, lifeLost, dead} */
  Game.prototype.tap = function (i) {
    if (this.isWon() || this.isDead() || i < 0 || !this.alive[i]) return null;
    this.taps++;
    var a = this.level.arrows[i];
    var obs = firstObstacle(this.level, i, this.grid());
    if (!obs) {
      this.alive[i] = false;
      return { type: 'exit', i: i, steps: pathOf(a, this.level.w, this.level.h).length, won: this.isWon() };
    }
    // Rahat mod (G3): can gitmez ama çarpışma sayılır (yıldız için); öğretici muafiyeti: hiçbiri
    var relaxed = !!this.opts.relaxed;
    var lifeLost = !this.opts.noLifeLoss && !relaxed;
    if (lifeLost) this.lives--;
    if (lifeLost || (relaxed && !this.opts.noLifeLoss)) this.collisions++;
    return { type: 'bump', i: i, free: obs.free, blocker: obs.blocker, lifeLost: lifeLost, dead: this.isDead() };
  };
  /** Ödüllü reklamla +1 can (can bittiğinde, isteğe bağlı). Çarpışma sayacı korunur. */
  Game.prototype.revive = function () {
    if (!this.isDead() || this.isWon()) return false;
    this.lives = 1; this.revived = (this.revived | 0) + 1;
    return true;
  };
  /** v1.3: komşu (kenar paylaşan) oklar aynı renk olmasın — açgözlü boyama; renk sayısı k. */
  function colorize(level, k) {
    var n = level.arrows.length, w = level.w, g = buildGrid(level), out = [], i, j;
    for (i = 0; i < n; i++) out.push(-1);
    for (i = 0; i < n; i++) {
      var used = {}, cs = cellsOf(level.arrows[i]);
      for (j = 0; j < cs.length; j++) {
        var x = cs[j][0], y = cs[j][1], nb = [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]];
        for (var q = 0; q < 4; q++) {
          var nx = nb[q][0], ny = nb[q][1]; if (nx < 0 || ny < 0 || nx >= w || ny >= level.h) continue;
          var o = g[ny * w + nx]; if (o !== -1 && o !== i && out[o] >= 0) used[out[o]] = (used[out[o]] || 0) + 1;
        }
      }
      var pick = -1;
      for (var c = 0; c < k; c++) { var cc = (i + c) % k; if (!used[cc]) { pick = cc; break; } }
      if (pick < 0) { var best = 1e9; for (var c2 = 0; c2 < k; c2++) if (used[c2] < best) { best = used[c2]; pick = c2; } }
      out[i] = pick;
    }
    return out;
  }
  var OkEngine = {
    DIRS: DIRS, MAX_LIVES: MAX_LIVES,
    cellsOf: cellsOf, lenOf: lenOf, headOf: headOf, pathOf: pathOf, buildGrid: buildGrid,
    solve: solve, bestHint: bestHint, Game: Game, colorize: colorize,
    rewardFor: function (stars) { return [0, 10, 15, 20][stars] || 0; }
  };
  root.OkEngine = OkEngine;
  if (typeof module !== 'undefined' && module.exports) module.exports = OkEngine;
})(typeof window !== 'undefined' ? window : globalThis);
