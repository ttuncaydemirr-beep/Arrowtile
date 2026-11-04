// Arrowtile — levelgen.dart: game/js/levelgen.js'in satır satır Dart karşılığı. Saf Dart (Flutter'a bağımlı değil).
//
// KURAL: rand() çağrı SIRASI ve sayısı JS ile birebir aynı olmalı; aksi halde aynı tohum başka seviye üretir.
// Bu dosyada hiçbir "iyileştirme/sadeleştirme" yapılmamıştır. Kısa devre (&&, ||) davranışları da korunmuştur
// (ör. `k > 1 && curvy && rand() < turnP` ifadesinde rand yalnız koşullar doğruysa çağrılır).
// Doğrulama: test/levelgen_golden_test.dart (JS'ten üretilmiş altın seviyeler) — kullanıcı tarafında `flutter test`.
import 'dart:math' as math;
import 'dart:typed_data';

import 'models.dart';
import 'rng.dart';

typedef Rand = double Function();

const Map<String, int> _dx = <String, int>{'U': 0, 'D': 0, 'L': -1, 'R': 1};
const Map<String, int> _dy = <String, int>{'U': -1, 'D': 1, 'L': 0, 'R': 0};
const List<String> _dirs = <String>['U', 'D', 'L', 'R'];

/// Math.pow(m + 0.5, 1.6), m = 0..40 — JS (V8) çıktısı. Dart'ın pow'u son basamakta farklı olabileceğinden
/// pickDir'de pow çağrılmaz; ağırlıklar bu tablodan alınır (v = m + 0.5 her zaman bu biçimdedir).
const List<double> _pow16 = <double>[
  0.32987697769322355,
  1.9131367509386863,
  4.3321552697196655,
  7.421793574444622,
  11.095324849241276,
  15.296085524342262,
  19.983031392186508,
  25.124534349835727,
  30.695186832272437,
  36.673956748302274,
  43.04303423791882,
  49.7870672530613,
  56.89263134456502,
  64.34784834371536,
  72.14210389329124,
  80.26583298236777,
  88.71035368019733,
  97.46773590912011,
  106.53069625164699,
  115.89251247204818,
  125.54695321811779,
  135.48821958576755,
  145.71089607712125,
  156.20990908537908,
  166.98049147550137,
  178.01815214992484,
  189.3186497271384,
  200.87796964111465,
  212.69230410726607,
  224.75803450694713,
  237.07171582552166,
  249.63006284438336,
  262.42993783925596,
  275.468339578696,
  288.7423934502848,
  302.24934256927156,
  315.9865397467369,
  329.9514402127054,
  344.1415950048303,
  358.5546449459248,
  373.18831514418787
];

/// JS'teki `L = { w, h, arrows }` nesnesi (build sırasında arrows sürekli değişir).
class LgBoard {
  final int w;
  final int h;
  List<Arrow> arrows;
  LgBoard(this.w, this.h, this.arrows);
}

// ---- ölçüler (motorla aynı kurallar) ----
List<List<int>> _cellsOf(Arrow a) => a.cells;
int _lenOf(Arrow a) => a.cells.length;
List<int> _headOf(Arrow a) => a.cells[a.cells.length - 1];

bool isCurved(Arrow a) {
  final List<List<int>> c = a.cells;
  if (c.length < 3) return false;
  final int dx = c[1][0] - c[0][0];
  final int dy = c[1][1] - c[0][1];
  for (int i = 2; i < c.length; i++) {
    if (c[i][0] - c[i - 1][0] != dx || c[i][1] - c[i - 1][1] != dy) return true;
  }
  return false;
}

int totalCells(LgBoard L) {
  int t = 0;
  for (int i = 0; i < L.arrows.length; i++) {
    t += _lenOf(L.arrows[i]);
  }
  return t;
}

/// JS grid(L, alive): hücre → ok indeksi (-1 boş). (Int16Array yerine Int32List: değerler aynı.)
Int32List _grid(LgBoard L) {
  final Int32List g = Int32List(L.w * L.h)..fillRange(0, L.w * L.h, -1);
  for (int k = 0; k < L.arrows.length; k++) {
    for (final List<int> c in L.arrows[k].cells) {
      g[c[1] * L.w + c[0]] = k;
    }
  }
  return g;
}

bool canExit(LgBoard L, int i, Int32List g) {
  final Arrow a = L.arrows[i];
  final int dx = _dx[a.dir]!;
  final int dy = _dy[a.dir]!;
  final List<int> hd = _headOf(a);
  int x = hd[0] + dx;
  int y = hd[1] + dy;
  while (x >= 0 && y >= 0 && x < L.w && y < L.h) {
    final int k = g[y * L.w + x];
    if (k != -1 && k != i) return false;
    x += dx;
    y += dy;
  }
  return true;
}

/// Başın önündeki doğru okun kendi gövdesinden geçmemeli (docs/09).
bool ownLineOk(List<List<int>> cells, String dir, int w, int h) {
  final int dx = _dx[dir]!;
  final int dy = _dy[dir]!;
  final List<int> hd = cells[cells.length - 1];
  int x = hd[0] + dx;
  int y = hd[1] + dy;
  while (x >= 0 && y >= 0 && x < w && y < h) {
    for (int i = 0; i < cells.length - 1; i++) {
      if (cells[i][0] == x && cells[i][1] == y) return false;
    }
    x += dx;
    y += dy;
  }
  return true;
}

class Analysis {
  final List<int> free;
  final List<int> stuck;
  final int depth;
  const Analysis(this.free, this.stuck, this.depth);
}

/// Hızlı çözüm analizi (JS analyze): her okun yolundaki farklı okların sayısı; sayısı 0 olan ok çıkar.
/// JS'teki paylaşımlı ara dizi (BUF/EPOCH) optimizasyonu Dart'ta her çağrıda yeni diziyle yapılır; sonuç aynıdır
/// (damga dizisi her ok için benzersiz i+1 değeriyle, JS'teki artan EPOCH ile eşdeğerdir).
Analysis analyze(LgBoard L) {
  final int w = L.w;
  final int h = L.h;
  final int n = L.arrows.length;
  final int N = w * h;
  final Int32List g = Int32List(N)..fillRange(0, N, -1);
  for (int i = 0; i < n; i++) {
    final List<List<int>> cs = _cellsOf(L.arrows[i]);
    for (int k = 0; k < cs.length; k++) {
      g[cs[k][1] * w + cs[k][0]] = i;
    }
  }
  final Int32List cnt = Int32List(n);
  final Int32List stamp = Int32List(n);
  final int maxE = n * (w > h ? w : h);
  final Int32List ef = Int32List(maxE);
  final Int32List et = Int32List(maxE);
  int ne = 0;
  for (int i = 0; i < n; i++) {
    final Arrow a = L.arrows[i];
    final int dx = _dx[a.dir]!;
    final int dy = _dy[a.dir]!;
    final List<int> hd = _headOf(a);
    int x = hd[0] + dx;
    int y = hd[1] + dy;
    final int ep = i + 1;
    while (x >= 0 && y >= 0 && x < w && y < h) {
      final int k = g[y * w + x];
      if (k != -1 && k != i && stamp[k] != ep) {
        stamp[k] = ep;
        cnt[i]++;
        ef[ne] = k;
        et[ne] = i;
        ne++;
      }
      x += dx;
      y += dy;
    }
  }
  final Int32List off = Int32List(n + 1);
  for (int i = 0; i < ne; i++) {
    off[ef[i] + 1]++;
  }
  for (int i = 0; i < n; i++) {
    off[i + 1] += off[i];
  }
  final Int32List adj = Int32List(ne + 1);
  final Int32List pos = Int32List(n + 1);
  for (int i = 0; i <= n; i++) {
    pos[i] = off[i];
  }
  for (int i = 0; i < ne; i++) {
    adj[pos[ef[i]]++] = et[i];
  }
  final Int32List q = Int32List(n);
  int head = 0;
  int tail = 0;
  final List<int> free0 = <int>[];
  int depth = 0;
  for (int i = 0; i < n; i++) {
    if (cnt[i] == 0) {
      q[tail++] = i;
      free0.add(i);
    }
  }
  while (head < tail) {
    depth++;
    final int end = tail;
    for (; head < end; head++) {
      final int u = q[head];
      for (int r = off[u]; r < off[u + 1]; r++) {
        if (--cnt[adj[r]] == 0) q[tail++] = adj[r];
      }
    }
  }
  final List<int> stuck = <int>[];
  if (tail < n) {
    for (int i = 0; i < n; i++) {
      if (cnt[i] > 0) stuck.add(i);
    }
  }
  return Analysis(free0, stuck, depth);
}

List<int> stuckOf(LgBoard L) => analyze(L).stuck;
List<int> freeNow(LgBoard L) => analyze(L).free;

class Measure {
  final bool solvable;
  final int depth;
  final int initialFree;
  final double freeRatio;
  final double fill;
  final int arrows;
  final int curved;
  final double curvedRatio;
  final double score;
  const Measure({
    required this.solvable,
    required this.depth,
    required this.initialFree,
    this.freeRatio = 0,
    this.fill = 0,
    this.arrows = 0,
    this.curved = 0,
    this.curvedRatio = 0,
    this.score = 0,
  });
}

Measure measure(LgBoard L) {
  final int n = L.arrows.length;
  final Analysis an = analyze(L);
  final int depth = an.depth;
  final int initialFree = an.free.length;
  if (an.stuck.isNotEmpty) return Measure(solvable: false, depth: depth, initialFree: initialFree);
  final int cells = totalCells(L);
  int curved = 0;
  for (final Arrow a in L.arrows) {
    if (isCurved(a)) curved++;
  }
  final double fill = cells / (L.w * L.h);
  final double freeRatio = initialFree / n;
  // Birleşik zorluk puanı (docs/08): derinlik + ok sayısı + doluluk; serbest oran yüksekse düşer
  final double score = depth + n / 6 + fill * 12 - freeRatio * 20;
  return Measure(
      solvable: true,
      depth: depth,
      initialFree: initialFree,
      freeRatio: freeRatio,
      fill: fill,
      arrows: n,
      curved: curved,
      curvedRatio: curved / n,
      score: score);
}

const List<List<Object>> kBands = <List<Object>>[
  <Object>['easy', 12],
  <Object>['medium', 26],
  <Object>['hard', 40],
];
String label(double score) {
  if (score <= 12) return 'easy';
  if (score <= 26) return 'medium';
  if (score <= 40) return 'hard';
  return 'extreme';
}

const List<double> _lenP = <double>[0, 0.02, 0.08, 0.18, 0.26, 0.24, 0.22]; // düz okların uzunluk olasılıkları
const List<double> _lenC = <double>[0, 0, 0, 0.16, 0.22, 0.22, 0.18, 0.12, 0.10]; // kıvrımlı okların (3..8)

int _pickLen(Rand rand, int maxLen, bool curvy) {
  final List<double> P = curvy ? _lenC : _lenP;
  final int top = math.min(maxLen, P.length - 1);
  // JS: r = rand() * (toplam)  — önce rand() çağrılır, toplam sırayla (l = 1..top) toplanır.
  final double r0 = rand();
  double t = 0;
  for (int l = 1; l <= top; l++) {
    t += P[l];
  }
  final double r = r0 * t;
  double acc = 0;
  for (int l = 1; l <= top; l++) {
    acc += P[l];
    if (r <= acc) return l;
  }
  return math.min(maxLen, 3);
}

const Map<String, List<String>> _perp = <String, List<String>>{
  'U': <String>['L', 'R'],
  'D': <String>['L', 'R'],
  'L': <String>['U', 'D'],
  'R': <String>['U', 'D'],
};

/// Baştan geriye yılan gövdesi: baş (hx,hy) dir'e bakar; ilk gövde adımı dir yönünde hizalı, sonra curvy ise dönüşler.
/// isFree(x,y) boş hücre denetimi. Dönen: kuyruk→baş hücreler (uzunluk ≤ len) ya da null.
List<List<int>>? _snake(int hx, int hy, String dir, int len, bool Function(int, int) isFree, Rand rand, bool curvy,
    int w, int h) {
  final List<List<int>> cells = <List<int>>[
    <int>[hx, hy]
  ];
  final Set<int> own = <int>{hy * w + hx};
  String s = dir;
  int x = hx;
  int y = hy;
  int turns = 0;
  final double turnP = curvy ? 0.45 : 0;
  for (int k = 1; k < len; k++) {
    List<String> opts;
    if (k > 1 && curvy && rand() < turnP) {
      final List<String> pp = _perp[s]!;
      opts = rand() < 0.5 ? <String>[pp[0], pp[1], s] : <String>[pp[1], pp[0], s];
    } else {
      opts = <String>[s];
      if (curvy && k > 1) {
        final List<String> p2 = _perp[s]!;
        opts = rand() < 0.5 ? <String>[s, p2[0], p2[1]] : <String>[s, p2[1], p2[0]];
      }
    }
    bool moved = false;
    for (int oi = 0; oi < opts.length; oi++) {
      final String ns = opts[oi];
      final int nx = x - _dx[ns]!;
      final int ny = y - _dy[ns]!;
      if (nx < 0 || ny < 0 || nx >= w || ny >= h || own.contains(ny * w + nx) || !isFree(nx, ny)) continue;
      if (ns != s) turns++;
      s = ns;
      x = nx;
      y = ny;
      own.add(ny * w + nx);
      cells.add(<int>[nx, ny]);
      moved = true;
      break;
    }
    if (!moved) break;
  }
  final List<List<int>> rev = cells.reversed.toList(); // JS: cells.reverse()
  if (!ownLineOk(rev, dir, w, h)) return null;
  if (curvy && turns == 0) return null;
  return rev;
}

Arrow _flip(Arrow a) {
  final List<List<int>> c = a.cells.reversed.toList();
  const Map<String, String> rev = <String, String>{'U': 'D', 'D': 'U', 'L': 'R', 'R': 'L'};
  String d;
  if (c.length == 1) {
    d = rev[a.dir]!;
  } else {
    final int dx = c[c.length - 1][0] - c[c.length - 2][0];
    final int dy = c[c.length - 1][1] - c[c.length - 2][1];
    d = dx == 1 ? 'R' : (dx == -1 ? 'L' : (dy == 1 ? 'D' : 'U'));
  }
  return Arrow(c, d);
}

String _pickDir(int x, int y, int w, int h, Rand rand) {
  // JS: [y + 0.5, h - y - 0.5, x + 0.5, w - x - 0.5].map(v => Math.pow(v, 1.6))  — sırayla U D L R.
  // Her v = m + 0.5 (m tamsayı): tablo indeksi m.
  final List<double> wts = <double>[_pow16[y], _pow16[h - y - 1], _pow16[x], _pow16[w - x - 1]];
  final double tot = wts[0] + wts[1] + wts[2] + wts[3];
  double rr = rand() * tot;
  for (int wi = 0; wi < 4; wi++) {
    rr -= wts[wi];
    if (rr <= 0) return _dirs[wi];
  }
  return 'R';
}

/// Fisher-Yates (JS shuffle): for i = n-1 .. 1: j = floor(rand() * (i + 1)).
List<T> _shuffle<T>(List<T> arr, Rand rand) {
  for (int i = arr.length - 1; i > 0; i--) {
    final int j = (rand() * (i + 1)).floor();
    final T t = arr[i];
    arr[i] = arr[j];
    arr[j] = t;
  }
  return arr;
}

/// build() seçenekleri (JS `o`). null = JS'te `undefined`; `||` varsayılanları build içinde uygulanır.
class BuildOpts {
  final int w;
  final int h;
  final double? fill;
  final int? maxLen;
  final double? maxFree;
  final double? curve;
  final Rand rand;
  final int? effort;
  final int? passes;
  final double? flipP;
  final int? cycles;
  final double? fillMax;
  const BuildOpts({
    required this.w,
    required this.h,
    required this.rand,
    this.fill,
    this.maxLen,
    this.maxFree,
    this.curve,
    this.effort,
    this.passes,
    this.flipP,
    this.cycles,
    this.fillMax,
  });
}

// JS `a || b` (sayı için): a null ya da 0 ise b.
int _orI(int? a, int b) => (a == null || a == 0) ? b : a;
double _orD(double? a, double b) => (a == null || a == 0) ? b : a;

/// Yoğun yerleşim + onarım ile ok listesi üretir (JS build). Çözülemezse null.
List<Arrow>? build(BuildOpts o) {
  final int w = o.w;
  final int h = o.h;
  final int N = w * h;
  final Rand rand = o.rand;
  final int maxLen = _orI(o.maxLen, 6);
  final double target = _orD(o.fill, 0.7) * N;
  final double curveP = math.min(0.95, _orD(o.curve, 0) * 1.6); // yerleşimde fazla: boşluk doldurma düz kısa oklar ekler
  final Uint8List occ = Uint8List(N);
  final List<Arrow> arrows0 = <Arrow>[];
  int filled = 0;
  int fails = 0;
  bool freeOcc(int x, int y) => occ[y * w + x] == 0;
  // 1) yoğun yerleşim
  while (filled < target && fails < N * 40) {
    final int x = (rand() * w).floor();
    final int y = (rand() * h).floor();
    if (occ[y * w + x] != 0) {
      fails++;
      continue;
    }
    final String dir = _pickDir(x, y, w, h, rand);
    bool curvy = rand() < curveP;
    int len = _pickLen(rand, maxLen, curvy);
    if (filled > target * 0.92 && fails > N * 25) {
      len = 1 + (rand() * 2).floor();
      curvy = false;
    }
    final List<List<int>>? cells = _snake(x, y, dir, len, freeOcc, rand, curvy, w, h);
    if (cells == null || (!curvy && cells.length < len)) {
      fails++;
      continue;
    }
    for (int k = 0; k < cells.length; k++) {
      occ[cells[k][1] * w + cells[k][0]] = 1;
    }
    arrows0.add(Arrow(cells, dir));
    filled += cells.length;
  }
  final LgBoard L = LgBoard(w, h, arrows0);
  // 2) onarım
  for (int it = 0; it < 4000; it++) {
    final List<int> st = stuckOf(L);
    if (st.isEmpty) break;
    final int pick = st[(rand() * st.length).floor()];
    final Arrow? fl = rand() < (o.flipP ?? 0.05) ? _flip(L.arrows[pick]) : null;
    if (fl != null && ownLineOk(fl.cells, fl.dir, w, h)) {
      L.arrows[pick] = fl; // v1.3: çoğunlukla sil
    } else {
      L.arrows.removeAt(pick);
    }
  }
  if (stuckOf(L).isNotEmpty) return null;
  Int32List occGrid() => _grid(L);
  int limitFree() => math.max(1, ((o.maxFree ?? 0.1) * L.arrows.length).floor());
  // 3) boşluk doldurma: serbest ok sayısını artırmayan ve çözülebilirliği bozmayan adaylar kabul edilir
  void gapFill() {
    final int maxFree0 =
        math.max(1, ((o.maxFree ?? 0.1) * math.max(L.arrows.length.toDouble(), target / 3.5)).floor());
    for (int pass2 = 0; pass2 < 6; pass2++) {
      int cells0 = totalCells(L);
      if (cells0 >= target) break;
      final Int32List g1 = occGrid();
      final List<int> empties = <int>[];
      for (int e = 0; e < N; e++) {
        if (g1[e] == -1) empties.add(e);
      }
      _shuffle<int>(empties, rand);
      int added = 0;
      int curFree = freeNow(L).length;
      bool isF(int xx, int yy) => g1[yy * w + xx] == -1;
      for (int ei = 0; ei < empties.length && cells0 < target; ei++) {
        final int ec = empties[ei];
        final int ex = ec % w;
        final int ey = (ec - ex) ~/ w;
        if (g1[ec] != -1) continue;
        final List<String> dirs = _shuffle<String>(List<String>.of(_dirs), rand);
        bool placed = false;
        for (int di = 0; di < 4 && !placed; di++) {
          final String dd = dirs[di];
          for (int ln = maxLen; ln >= 1 && !placed; ln--) {
            final bool curvy2 = ln >= 3 && rand() < curveP;
            final List<List<int>>? cc = _snake(ex, ey, dd, ln, isF, rand, curvy2, w, h);
            if (cc == null || cc.length != ln) continue;
            L.arrows.add(Arrow(cc, dd));
            final Analysis an3 = analyze(L);
            final int nf = an3.free.length;
            final bool selfFree = an3.free.contains(L.arrows.length - 1);
            final bool good = nf <= math.max(curFree, maxFree0) && (!selfFree || nf <= curFree);
            if (good && an3.stuck.isEmpty) {
              placed = true;
              added++;
              cells0 += ln;
              curFree = nf;
              for (int zz = 0; zz < cc.length; zz++) {
                g1[cc[zz][1] * w + cc[zz][0]] = L.arrows.length - 1;
              }
            } else {
              L.arrows.removeLast();
            }
          }
        }
      }
      if (added == 0) break;
    }
  }

  // 4) başta çıkabilen oranını düşür (en az 1 serbest kalır)
  void reduce() {
    final int maxFree = limitFree();
    for (int pass = 0; pass < _orI(o.passes, 8); pass++) {
      final List<int> fr = freeNow(L);
      if (fr.length <= maxFree) break;
      for (int q = 0; q < fr.length; q++) {
        int i2 = fr[q];
        if (i2 >= L.arrows.length) continue; // JS: `if (!old) continue;` (undefined)
        final Arrow old = L.arrows[i2];
        final int before = freeNow(L).length;
        final Arrow nf2 = _flip(old);
        if (!ownLineOk(nf2.cells, nf2.dir, w, h)) continue;
        L.arrows[i2] = nf2;
        final Int32List g2 = _grid(L);
        if (canExit(L, i2, g2)) {
          L.arrows[i2] = old;
          continue;
        }
        List<int> st2 = stuckOf(L);
        bool okFlip = st2.isEmpty && freeNow(L).length < before;
        List<Arrow>? snapshot;
        if (!okFlip && st2.isNotEmpty) {
          snapshot = List<Arrow>.of(L.arrows);
          snapshot[i2] = old;
          for (int tr = 0; tr < _orI(o.effort, 12) && st2.isNotEmpty; tr++) {
            final int i2c = i2;
            final List<int> cand = st2.where((int k) => k != i2c).toList();
            if (cand.isEmpty) break;
            final int j3 = cand[(rand() * cand.length).floor()];
            L.arrows.removeAt(j3);
            if (j3 < i2) i2--;
            st2 = stuckOf(L);
          }
          okFlip = st2.isEmpty && freeNow(L).length < before;
        }
        if (!okFlip) {
          if (snapshot != null) {
            L.arrows = snapshot;
          } else {
            L.arrows[i2] = old;
          }
        }
        if (okFlip) break;
      }
    }
  }

  for (int cyc = 0; cyc < _orI(o.cycles, 3); cyc++) {
    gapFill();
    reduce();
    if (totalCells(L) >= target - 0.005 * N && freeNow(L).length <= limitFree()) break;
  }
  gapFill();
  // 4b) kalan serbest oklar: tek hücrelik kapalı oklara böl
  final int lim4 = limitFree();
  for (int guard4 = 0; guard4 < 400; guard4++) {
    final List<int> fr4 = freeNow(L);
    if (fr4.length <= lim4) break;
    bool any4 = false;
    for (int q4 = 0; q4 < fr4.length; q4++) {
      if (fr4[q4] >= L.arrows.length) continue; // JS: `if (!A4) continue;`
      final Arrow A4 = L.arrows[fr4[q4]];
      final int before4 = fr4.length;
      final List<List<int>> cells4 = A4.cells;
      final List<Arrow> saved = List<Arrow>.of(L.arrows);
      L.arrows.removeAt(fr4[q4]);
      final int base4 = L.arrows.length;
      for (int c4 = 0; c4 < cells4.length; c4++) {
        L.arrows.add(Arrow(<List<int>>[cells4[c4]], A4.dir));
      }
      for (int c5 = 0; c5 < cells4.length; c5++) {
        final List<String> opts4 = _shuffle<String>(List<String>.of(_dirs), rand);
        for (int d4 = 0; d4 < 4; d4++) {
          L.arrows[base4 + c5] = Arrow(<List<int>>[cells4[c5]], opts4[d4]);
          if (!canExit(L, base4 + c5, _grid(L))) break;
        }
      }
      if (freeNow(L).length < before4 && stuckOf(L).isEmpty) {
        any4 = true;
        break;
      }
      L.arrows = saved;
    }
    if (!any4) break;
  }
  // 5) hâlâ fazla serbest ok varsa: serbest okun yolundaki boş hücreye kendisi kapalı kalan kısa bir ok koy
  final double cap = math.min(N.toDouble(), (o.fillMax != null && o.fillMax != 0) ? (o.fillMax! * N).floorToDouble() : target + 0.06 * N);
  for (int guard5 = 0; guard5 < 200; guard5++) {
    final List<int> fr5 = freeNow(L);
    if (fr5.length <= limitFree()) break;
    bool changed = false;
    for (int q5 = 0; q5 < fr5.length && !changed; q5++) {
      if (totalCells(L) >= cap) break;
      final Arrow fa = L.arrows[fr5[q5]];
      final Int32List gg = occGrid();
      final List<int> hd5 = _headOf(fa);
      int px5 = hd5[0] + _dx[fa.dir]!;
      int py5 = hd5[1] + _dy[fa.dir]!;
      bool isF5(int xx, int yy) => gg[yy * w + xx] == -1;
      while (!changed && px5 >= 0 && py5 >= 0 && px5 < w && py5 < h) {
        if (gg[py5 * w + px5] == -1) {
          final List<String> dirs5 = _shuffle<String>(List<String>.of(_dirs), rand);
          for (int d5 = 0; d5 < 4 && !changed; d5++) {
            for (int l5 = 2; l5 >= 1 && !changed; l5--) {
              final List<List<int>>? cb = _snake(px5, py5, dirs5[d5], l5, isF5, rand, false, w, h);
              if (cb == null || cb.length != l5) continue;
              L.arrows.add(Arrow(cb, dirs5[d5]));
              if (!canExit(L, L.arrows.length - 1, _grid(L)) &&
                  freeNow(L).length < fr5.length &&
                  stuckOf(L).isEmpty) {
                changed = true;
              } else {
                L.arrows.removeLast();
              }
            }
          }
        }
        px5 += _dx[fa.dir]!;
        py5 += _dy[fa.dir]!;
      }
    }
    if (!changed) break;
  }
  // 6) birleştirme (v1.3): kıvrımlı oran hedefin altındaysa, ucu ucuna değen iki oku tek yılana birleştir
  final double want = o.curve ?? 0;
  bool adjacent(List<int> p, List<int> q) => (p[0] - q[0]).abs() + (p[1] - q[1]).abs() == 1;
  double curvedRatio() {
    int c = 0;
    for (int i = 0; i < L.arrows.length; i++) {
      if (isCurved(L.arrows[i])) c++;
    }
    return c / L.arrows.length; // 0 ok ise NaN (JS ile aynı: 0/0)
  }

  final int depth6 = want > 0 ? analyze(L).depth : 0;
  final int floor6 = (depth6 * 0.9).ceil(); // birleştirme derinliği en çok %10 düşürebilir
  for (int guard6 = 0; guard6 < 4 && want > 0 && curvedRatio() < want; guard6++) {
    int merged = 0;
    Int32List g6 = _grid(L);
    List<int> order6 = _shuffle<int>(<int>[for (int i = 0; i < L.arrows.length; i++) i], rand);
    for (int oi6 = 0; oi6 < order6.length && curvedRatio() < want; oi6++) {
      final int qi = order6[oi6];
      if (qi >= L.arrows.length) continue; // JS: `if (!Q) continue;`
      final Arrow Q = L.arrows[qi];
      final List<List<int>> qc = Q.cells;
      if (qc.length >= maxLen) continue;
      final List<int> t = qc[0];
      final List<List<int>> nb = <List<int>>[
        <int>[t[0] + 1, t[1]],
        <int>[t[0] - 1, t[1]],
        <int>[t[0], t[1] + 1],
        <int>[t[0], t[1] - 1],
      ];
      bool done6 = false;
      for (int nb6 = 0; nb6 < 4 && !done6; nb6++) {
        final int nx6 = nb[nb6][0];
        final int ny6 = nb[nb6][1];
        if (nx6 < 0 || ny6 < 0 || nx6 >= w || ny6 >= h) continue;
        final int pi = g6[ny6 * w + nx6];
        if (pi == -1 || pi == qi) continue;
        final Arrow P = L.arrows[pi];
        final List<List<int>> pc = P.cells;
        if (pc.length + qc.length > maxLen) continue;
        List<List<int>>? body;
        if (adjacent(pc[pc.length - 1], t)) {
          body = <List<int>>[...pc, ...qc];
        } else if (adjacent(pc[0], t)) {
          body = <List<int>>[...pc.reversed, ...qc];
        }
        if (body == null) continue;
        final Arrow NA = Arrow(body, Q.dir);
        if (!isCurved(NA) || !ownLineOk(body, Q.dir, w, h)) continue;
        final Analysis an0 = analyze(L);
        final List<Arrow> saved6 = List<Arrow>.of(L.arrows);
        L.arrows[qi] = NA;
        L.arrows.removeAt(pi);
        final Analysis an6 = analyze(L);
        // derinlik düşmemeli (kademe sırası korunur), serbest sayı ne artar ne sınırı aşar
        if (an6.stuck.isEmpty &&
            an6.depth >= math.max(floor6, an0.depth - 1) &&
            an6.free.length <= an0.free.length &&
            (an6.free.length <= limitFree() ||
                an6.free.length < an0.free.length ||
                (an0.free.length > limitFree() && an6.free.length <= an0.free.length - 0))) {
          done6 = true;
          merged++;
        } else {
          L.arrows = saved6;
        }
      }
      if (done6) {
        g6 = _grid(L);
        order6 = _shuffle<int>(<int>[for (int i = 0; i < L.arrows.length; i++) i], rand);
        oi6 = -1;
      }
    }
    if (merged == 0) break;
  }
  // 7) son düzeltme (v1.3): hâlâ sınırdan fazla serbest ok varsa, kısa serbest okları sil
  final double floorCells = target - 0.015 * N;
  for (int guard7 = 0; guard7 < 40; guard7++) {
    final Analysis an7 = analyze(L);
    if (an7.free.length <= limitFree()) break;
    // JS: an7.free.slice().sort((p, q) => len(p) - len(q)) — V8 sıralaması kararlıdır; Dart'ınki değil.
    // an7.free indeks sırasında olduğundan eşitlikte indeksle kıyaslamak kararlı sıralamayla aynıdır.
    final List<int> fr7 = List<int>.of(an7.free)
      ..sort((int p, int q) {
        final int c = _lenOf(L.arrows[p]) - _lenOf(L.arrows[q]);
        return c != 0 ? c : p.compareTo(q);
      });
    bool did7 = false;
    for (int q7 = 0; q7 < fr7.length && !did7; q7++) {
      final Arrow A7 = L.arrows[fr7[q7]];
      if (totalCells(L) - _lenOf(A7) < floorCells) continue;
      L.arrows.removeAt(fr7[q7]);
      final Analysis b7 = analyze(L);
      if (b7.stuck.isEmpty && b7.free.length < an7.free.length) {
        did7 = true;
      } else {
        L.arrows.insert(fr7[q7], A7);
      }
    }
    if (!did7) break;
  }
  return L.arrows;
}

/// generate/genJob için özellikler (JS `spec`).
class GenSpec {
  final int w;
  final int h;
  final double fill;
  final double? fillMax;
  final double maxFree;
  final double? curve;
  final int maxLen;
  final int tries;
  final int? effort;
  final int? passes;
  final int? cycles;
  final int minDepth;
  final double? flipP;
  // specFor() ek alanları
  final int id;
  final int chapter;
  final String tier;
  const GenSpec({
    required this.w,
    required this.h,
    required this.fill,
    required this.maxFree,
    required this.maxLen,
    this.fillMax,
    this.curve,
    this.tries = 6,
    this.effort,
    this.passes,
    this.cycles,
    this.minDepth = 0,
    this.flipP,
    this.id = 0,
    this.chapter = 0,
    this.tier = '',
  });
}

/// generate() sonucu.
class GenResult {
  final int w;
  final int h;
  final List<Arrow> arrows;
  final Measure m;
  final bool ok;
  const GenResult(this.w, this.h, this.arrows, this.m, this.ok);
}

/// Üretim işi: her step() tek bir build denemesi yapar.
class GenJob {
  final GenSpec spec;
  final Rand rand;
  GenResult? _best;
  double _bestKey = double.negativeInfinity;
  int _t = 0;
  bool _done = false;

  GenJob(this.spec, int seed) : rand = Rng(seed & 0xFFFFFFFF).next; // JS: rng(seed >>> 0)

  bool step() {
    if (_done) return true;
    final List<Arrow>? arr = build(BuildOpts(
        w: spec.w,
        h: spec.h,
        fill: spec.fill,
        maxLen: spec.maxLen,
        maxFree: spec.maxFree,
        curve: spec.curve,
        rand: rand,
        effort: spec.effort,
        passes: spec.passes,
        flipP: spec.flipP ?? 0.05,
        cycles: spec.cycles,
        fillMax: spec.fillMax));
    if (arr != null) {
      final LgBoard L = LgBoard(
          spec.w,
          spec.h,
          _shuffle<Arrow>(
              <Arrow>[for (final Arrow a in arr) Arrow(<List<int>>[for (final List<int> c in a.cells) <int>[c[0], c[1]]], a.dir)],
              rand));
      final Measure m = measure(L);
      if (m.solvable) {
        final int freeLim = math.max(1, (spec.maxFree * m.arrows + 1e-9).floor()); // docs/09: ≤ oran (en az 1)
        // kıvrımlı oran "~": seviye başına en çok 0,15 altında (bölüm ortalaması doğrulayıcıda 0,12)
        final bool ok = m.fill >= spec.fill - 0.02 &&
            (spec.fillMax == null || spec.fillMax == 0 || m.fill <= spec.fillMax! + 1e-9) &&
            m.initialFree <= freeLim &&
            m.depth >= spec.minDepth &&
            (spec.curve == null || m.curvedRatio >= spec.curve! - 0.15);
        final double key = (ok ? 1000 : 0) +
            m.score -
            math.max(0, m.initialFree - freeLim) * 3 -
            math.max(0, (spec.curve ?? 0) - 0.1 - m.curvedRatio) * 100 -
            math.max(0, spec.fill - m.fill) * 200;
        if (key > _bestKey) {
          _bestKey = key;
          _best = GenResult(spec.w, spec.h, L.arrows, m, ok);
        }
        if (ok && _t >= 1) _done = true;
      }
    }
    _t++;
    if (_t >= spec.tries) _done = true;
    return _done;
  }

  GenResult? result() => _best;
}

GenResult? generate(GenSpec spec, int seed) {
  final GenJob j = GenJob(spec, seed);
  while (!j.step()) {}
  return j.result();
}

// ---- v1.3 bölüm döngüsü (docs/09) ----
const List<String> kCycle = <String>['easy', 'easy', 'easy', 'medium', 'medium', 'medium', 'hard', 'hard', 'extreme'];

class Tier {
  final double fill;
  final List<double> band;
  final double maxFree;
  final double curve;
  final double mult;
  final int bonus;
  const Tier(this.fill, this.band, this.maxFree, this.curve, this.mult, this.bonus);
}

const Map<String, Tier> kTiers = <String, Tier>{
  'easy': Tier(0.675, <double>[0.65, 0.70], 0.12, 0.30, 1, 50),
  'medium': Tier(0.775, <double>[0.75, 0.80], 0.07, 0.45, 1.5, 75),
  'hard': Tier(0.840, <double>[0.82, 0.86], 0.04, 0.55, 2, 100),
  'extreme': Tier(0.905, <double>[0.88, 0.93], 0.02, 0.65, 3, 200),
};

const int kPerChapter = 12;
const int kPrebuilt = 216;
const int kMaxW = 22;
const int kMaxH = 31;

int chapterOf(int id) => (id - 1) ~/ kPerChapter + 1;
String tierOf(int ch) => kCycle[(ch - 1) % kCycle.length];

/// Seviye numarasından üretim özellikleri. Tahta bölüm bölüm büyür (zorluktan bağımsız), bölüm içinde hafifçe.
GenSpec specFor(int id) {
  final int ch = chapterOf(id);
  final int k = (id - 1) % kPerChapter;
  final String tier = tierOf(ch);
  final Tier T = kTiers[tier]!;
  final double t = (ch - 1) + k / kPerChapter; // bölüm 1 başı 7x9 → bölüm 18 sonu 20x28
  // JS Math.round: .5 yukarı yuvarlanır; değerler pozitif olduğundan Dart round() ile aynıdır.
  final int w = math.min(kMaxW, 7 + (t * 13 / 17.92).round());
  final int h = math.min(kMaxH, 9 + (t * 19 / 17.92).round());
  final int maxLen = math.min(8, 4 + w ~/ 4);
  final bool extreme = tier == 'extreme';
  return GenSpec(
      id: id,
      chapter: ch,
      tier: tier,
      w: w,
      h: h,
      fill: T.fill,
      fillMax: T.band[1],
      maxFree: T.maxFree,
      curve: T.curve,
      maxLen: maxLen,
      tries: 3,
      effort: extreme ? 40 : 24,
      passes: extreme ? 20 : 12,
      cycles: extreme ? 6 : 4);
}

/// Seviye no → sabit tohum (herkes için aynı seviye). round: aynı seviyenin yedek denemeleri.
int seedFor(int id, [int round = 0]) => fnv32('arrowtile-v13-$id-$round');

const int kEndlessRounds = 8;
const String kGenVersion = 'v13.1'; // üretici değişirse artır

class LevelResult {
  final int id;
  final int w;
  final int h;
  final int par;
  final String diff;
  final int chapter;
  final List<Arrow> arrows;
  final bool ok;
  final int rounds;
  const LevelResult(this.id, this.w, this.h, this.par, this.diff, this.chapter, this.arrows, this.ok, this.rounds);

  Level toLevel() => Level(id: id, w: w, h: h, par: par, diff: diff, arrows: arrows, ok: ok);
}

/// Sonsuz seviye işi: tohum = seviye numarası; kısıtları sağlayan ilk tur seçilir (en çok 8 tur).
class LevelJob {
  final int id;
  final GenSpec _sp;
  int _r = 0;
  late GenJob _job;
  double? _bestKey;
  GenResult? _best;
  LevelResult? _out;

  LevelJob(this.id) : _sp = specFor(id) {
    _job = GenJob(_sp, seedFor(id, 0));
  }

  bool step() {
    if (_out != null) return true;
    if (!_job.step()) return false;
    final GenResult? g = _job.result();
    if (g != null) {
      final double key = (g.ok ? 1e6 : 0) + g.m.score;
      if (_best == null || key > _bestKey!) {
        _bestKey = key;
        _best = g;
      }
    }
    if ((g != null && g.ok) || _r + 1 >= kEndlessRounds) {
      if (_best != null) {
        _out = LevelResult(id, _sp.w, _sp.h, _best!.arrows.length, _sp.tier, _sp.chapter, _best!.arrows, _best!.ok, _r + 1);
        return true;
      }
    }
    _r++;
    _job = GenJob(_sp, seedFor(id, _r));
    if (_r >= kEndlessRounds * 2) throw StateError('seviye üretilemedi: $id');
    return false;
  }

  LevelResult? result() => _out;
}

LevelResult makeLevel(int id) {
  final LevelJob j = LevelJob(id);
  while (!j.step()) {}
  return j.result()!;
}
