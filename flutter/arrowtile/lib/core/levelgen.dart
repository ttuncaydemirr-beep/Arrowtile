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
  // JS: [y + 0.5, h - y - 0.5, x + 0.5, w - x - 0.5].map(v => v * Math.sqrt(v)) — sırayla U D L R.
  // Ağırlık v^1,5 = v·√v: yalnızca IEEE-kesin işlemler (çarpma, karekök) kullanılır; JS ve Dart bit-bit aynı sonucu verir
  // (Math.pow / dart:math pow son basamakta farklı olabilirdi).
  double wt(double v) => v * math.sqrt(v);
  final List<double> wts = <double>[wt(y + 0.5), wt(h - y - 0.5), wt(x + 0.5), wt(w - x - 0.5)];
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
  final int? maxDepth; // null = üst sınır yok (JS: spec.maxDepth == null)
  final double? flipP;
  // specFor() ek alanları
  final int id;
  final int chapter;
  final int index;
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
    this.maxDepth,
    this.flipP,
    this.id = 0,
    this.chapter = 0,
    this.index = 0,
    this.tier = '',
  });
}

/// generate() sonucu. [band]: kademe bandı (doluluk + başta çıkabilen) sağlandı mı (derinlik/kıvrımlı oran hariç).
class GenResult {
  final int w;
  final int h;
  final List<Arrow> arrows;
  final Measure m;
  final bool ok;
  final bool band;
  const GenResult(this.w, this.h, this.arrows, this.m, this.ok, this.band);
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
        final int dMin = spec.minDepth; // v1.5: kademe derinlik penceresi
        final int? dMax = spec.maxDepth;
        final bool fillOk = m.fill >= spec.fill - 0.02 && (spec.fillMax == null || spec.fillMax == 0 || m.fill <= spec.fillMax! + 1e-9);
        final bool ok = fillOk &&
            m.initialFree <= freeLim &&
            m.depth >= dMin &&
            (dMax == null || m.depth <= dMax) &&
            (spec.curve == null || m.curvedRatio >= spec.curve! - 0.15);
        final bool hardOk = fillOk && m.initialFree <= freeLim; // kademe bandı (zorunlu)
        // JS ile AYNI işlem sırası (kayan nokta toplamı soldan sağa): (ok?1000:0) + (hardOk?500:0) + score - …
        final double depthOut = math.max(
            0.0, math.max((dMin - m.depth).toDouble(), dMax == null ? double.negativeInfinity : (m.depth - dMax).toDouble()));
        final double key = (ok ? 1000 : 0) +
            (hardOk ? 500 : 0) +
            m.score -
            math.max(0, m.initialFree - freeLim) * 3 -
            math.max(0, (spec.curve ?? 0) - 0.1 - m.curvedRatio) * 100 -
            math.max(0, spec.fill - m.fill) * 200 -
            depthOut * 5;
        if (key > _bestKey) {
          _bestKey = key;
          _best = GenResult(spec.w, spec.h, L.arrows, m, ok, hardOk);
        }
        if (ok) _done = true;
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

// ---- eski kademe tablosu (v1.5): YALNIZCA günlük bulmaca (daily.dart, eski build/generate) kullanır ----
// Değiştirmeyin: günlük bulmaca değişir (web: game/js/levelgen.js TIERS).
class Tier {
  final double fill;
  final List<double> band;
  final double maxFree;
  final double curve;
  final double mult;
  const Tier(this.fill, this.band, this.maxFree, this.curve, this.mult);
}

const Map<String, Tier> kTiers = <String, Tier>{
  'easy': Tier(0.675, <double>[0.65, 0.70], 0.12, 0.30, 1),
  'medium': Tier(0.775, <double>[0.75, 0.80], 0.07, 0.45, 1.5),
  'hard': Tier(0.840, <double>[0.82, 0.86], 0.04, 0.55, 2),
  'extreme': Tier(0.905, <double>[0.88, 0.93], 0.02, 0.65, 3),
};

// =====================================================================================================================
// v2 — sürüm 1.2.0 (docs/24, docs/26): game/js/levelgen.js build2/makeMask/measure2/specFor/levelJob'un satır satır karşılığı.
// Bölüm = 20 seviye (5 Kolay → 5 Orta → 5 Zor → 5 Aşırı zor). Bölüm tahtası GROW_CHAPTERS bölümde 9x13'ten 28x45'e büyür, sonra
// en küçüğe döner. 1.2.0 sahip kararı #2: Kolay/Orta seviyeler bölüm tahtasından KÜÇÜK tahtada oynanır (TIER_SIZE_PCT).
// KURAL: rand() çağrı sırası/sayısı, tamsayı bölmeler ve kayan nokta işlem sırası JS ile birebir aynıdır (altın test:
// tools/level-hashes.json). Yalnızca + − × ÷ ve √ (IEEE-kesin) kullanılır.
// =====================================================================================================================

const int kPerChapter = 20;
const int kPrebuilt = 100; // pakette hazır seviyeler; sonrası oyunda (arka plan izolatında) üretilir
const int kDesigned = 5000; // tasarlanmış (CI'da doğrulanmış) seviye sayısı; sonrası sonsuz devam (aynı kural)
const int kChapters = 250;
const int kChapterBonus = 150;

/// AYAR: en küçük tahtadan en büyüğe kaç bölümde varılır (sonraki bölüm yine en küçüğe döner). Sahip onayı: 9.
const int kGrowChapters = 9;
const int kMinW = 9;
const int kMinH = 13;
const int kMaxW = 28;
const int kMaxH = 45;
const List<String> kTierOrder = <String>['easy', 'medium', 'hard', 'extreme'];
const int kTierSpan = 5;
final List<String> kCycle = List<String>.unmodifiable(<String>[for (int i = 0; i < kPerChapter; i++) kTierOrder[i ~/ kTierSpan]]);

/// AYAR (sahip kararı #2): kademe tahtası = bölüm tahtasının kenar yüzdesi (en-boy korunur). Kolay %71 (alanın ≈ %50'si),
/// Orta %85 (≈ %72), Zor %95 (≈ %90), Aşırı zor %100. Hiçbir kenar en küçük tahtanın altına inmez.
const Map<String, int> kTierSizePct = <String, int>{'easy': 71, 'medium': 85, 'hard': 95, 'extreme': 100};

/// Kademe ayarları (JS TIER2). Alan anlamları game/js/levelgen.js TIER2 açıklamasında.
class Tier2 {
  final double fill;
  final double band0, band1;
  final double free;
  final double maxFree;
  final int minFree;
  final int len0, len1;
  final int turns0, turns1;
  final double turn, same, hug, deep;
  final int ext;
  final int filler;
  final int tries;
  final double minTurns;
  final double mult;
  const Tier2({
    required this.fill,
    required this.band0,
    required this.band1,
    required this.free,
    required this.maxFree,
    required this.minFree,
    required this.len0,
    required this.len1,
    required this.turns0,
    required this.turns1,
    required this.turn,
    required this.same,
    required this.hug,
    required this.deep,
    required this.ext,
    required this.filler,
    required this.tries,
    required this.minTurns,
    required this.mult,
  });
}

const Map<String, Tier2> kTier2 = <String, Tier2>{
  'easy': Tier2(fill: 0.60, band0: 0.50, band1: 0.70, free: 0.15, maxFree: 0.24, minFree: 3, len0: 2, len1: 5, turns0: 0, turns1: 1,
      turn: 0.25, same: 0.5, hug: 0.15, deep: 0.0, ext: 0, filler: 2, tries: 1, minTurns: 0.10, mult: 1),
  'medium': Tier2(fill: 0.72, band0: 0.64, band1: 0.80, free: 0.09, maxFree: 0.14, minFree: 3, len0: 3, len1: 9, turns0: 1, turns1: 3,
      turn: 0.45, same: 0.5, hug: 0.35, deep: 0.3, ext: 1, filler: 2, tries: 2, minTurns: 0.6, mult: 1.5),
  'hard': Tier2(fill: 0.82, band0: 0.75, band1: 0.89, free: 0.05, maxFree: 0.08, minFree: 2, len0: 5, len1: 16, turns0: 2, turns1: 6,
      turn: 0.6, same: 0.6, hug: 0.6, deep: 0.6, ext: 1, filler: 2, tries: 4, minTurns: 1.5, mult: 2),
  'extreme': Tier2(fill: 0.90, band0: 0.83, band1: 0.96, free: 0.03, maxFree: 0.05, minFree: 2, len0: 8, len1: 28, turns0: 4, turns1: 9,
      turn: 0.75, same: 0.65, hug: 0.9, deep: 0.85, ext: 1, filler: 2, tries: 8, minTurns: 2.6, mult: 3),
};

const int kMaxArrowLen = 48; // yapı denetimi üst sınırı (kuyruk uzatma dahil)

/// Seviye 1-3: elle tasarlanmış öğretici (değişmez, düz oklar). Biçim: (x, y, dir, len).
const List<({int w, int h, List<(int, int, String, int)> arrows})> kTutorial = <({int w, int h, List<(int, int, String, int)> arrows})>[
  (w: 3, h: 3, arrows: <(int, int, String, int)>[(2, 0, 'D', 2), (2, 2, 'L', 2)]),
  (w: 3, h: 3, arrows: <(int, int, String, int)>[(0, 2, 'R', 2), (2, 2, 'U', 1), (2, 0, 'L', 2)]),
  (w: 4, h: 4, arrows: <(int, int, String, int)>[(3, 1, 'D', 2), (2, 3, 'R', 2), (0, 2, 'R', 2), (1, 0, 'D', 2)]),
];

int chapterOf(int id) => (id - 1) ~/ kPerChapter + 1;
int indexOf(int id) => (id - 1) % kPerChapter; // bölüm içi sıra, 0..19
String tierOf(int id) => kCycle[(id - 1) % kPerChapter]; // SEVİYE kademesi

/// Bölüm tahtası (yalnızca bölüme bağlı; tamsayı işlemleri): büyüme döngüsünün g. adımı, doğrusal + yuvarlama.
({int w, int h}) sizeOfChapter(int ch) {
  const int d = kGrowChapters - 1;
  final int g = (ch - 1) % kGrowChapters;
  // ignore: dead_code
  if (d <= 0) return (w: kMaxW, h: kMaxH);
  return (
    w: kMinW + ((kMaxW - kMinW) * g * 2 + d) ~/ (2 * d),
    h: kMinH + ((kMaxH - kMinH) * g * 2 + d) ~/ (2 * d),
  );
}

int _scaleDim(int v, int pct, int min) {
  final int r = (v * pct * 2 + 100) ~/ 200;
  return r < min ? min : r;
}

/// Seviyenin tahtası: bölüm tahtası × kademe ölçeği ([kTierSizePct]).
({int w, int h}) sizeOf(int id) {
  final ({int w, int h}) cs = sizeOfChapter(chapterOf(id));
  final int pct = kTierSizePct[tierOf(id)]!;
  if (pct >= 100) return cs;
  return (w: _scaleDim(cs.w, pct, kMinW), h: _scaleDim(cs.h, pct, kMinH));
}

/// Aşırı zor seviyelerin tahta biçimi (bölüm içi sıra 15..19): yeterince büyük tahtada şekilli.
const List<String> kShapes = <String>['organic', 'ring', 'full', 'ringOrganic', 'ring'];
const int kShapeMinW = 14;

String shapeOf(int id) {
  final ({int w, int h}) sz = sizeOf(id);
  if (tierOf(id) != 'extreme' || sz.w < kShapeMinW) return 'full';
  return kShapes[(indexOf(id) - 15 + chapterOf(id)) % kShapes.length];
}

/// specFor(id) sonucu (saf; yalnızca seviye numarasına bağlı).
class LevelSpec {
  final int id;
  final int chapter;
  final int index;
  final String tier;
  final int w;
  final int h;
  final String shape;
  final Tier2 p;
  final int seed;
  const LevelSpec(this.id, this.chapter, this.index, this.tier, this.w, this.h, this.shape, this.p, this.seed);
}

LevelSpec specFor(int id) {
  final int ch = chapterOf(id);
  final String tier = tierOf(id);
  final ({int w, int h}) sz = sizeOf(id);
  return LevelSpec(id, ch, indexOf(id), tier, sz.w, sz.h, shapeOf(id), kTier2[tier]!, seedFor(id, 0));
}

/// Seviye no → sabit tohum (herkes için aynı seviye). round: aynı seviyenin yedek denemeleri.
int seedFor(int id, [int round = 0]) => fnv32('arrowtile-v20-$id-$round');

int turnsOf(Arrow a) {
  final List<List<int>> c = a.cells;
  int t = 0;
  for (int i = 2; i < c.length; i++) {
    if (c[i][0] - c[i - 1][0] != c[i - 1][0] - c[i - 2][0] || c[i][1] - c[i - 1][1] != c[i - 1][1] - c[i - 2][1]) t++;
  }
  return t;
}

// ---- maske (şekilli tahta): Uint8List(w*h), 1 = oynanabilir hücre. Yalnızca rand(), tamsayı ve √.
List<int> _profile(int n, int amp, Rand rand) {
  final List<int> out = <int>[];
  const int step = 4;
  int a = (rand() * (amp + 1)).floor();
  int b = a;
  for (int i = 0; i < n; i++) {
    final int k = i % step;
    if (k == 0) {
      a = b;
      b = (rand() * (amp + 1)).floor();
    }
    out.add((a * (step - k) + b * k + (step >> 1)) ~/ step);
  }
  return out;
}

Uint8List makeMask(int w, int h, String kind, Rand rand) {
  final int N = w * h;
  final Uint8List m = Uint8List(N)..fillRange(0, N, 1);
  if (kind == 'full') return m;
  final bool organic = kind == 'organic' || kind == 'ringOrganic';
  final bool ring = kind == 'ring' || kind == 'ringOrganic';
  if (organic) {
    final int amp = math.max(1, w ~/ 9);
    final List<int> L = _profile(h, amp, rand);
    final List<int> R = _profile(h, amp, rand);
    final List<int> T = _profile(w, amp, rand);
    final List<int> B = _profile(w, amp, rand);
    final int cc = math.max(2, w ~/ 6); // köşe kesiği
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int dx = math.min(x, w - 1 - x);
        final int dy = math.min(y, h - 1 - y);
        if (x < L[y] || x >= w - R[y] || y < T[x] || y >= h - B[x] || dx + dy < cc) m[y * w + x] = 0;
      }
    }
  }
  if (ring) {
    final double cx = (w - 1) / 2 + (rand() - 0.5) * 2;
    final double cy = (h - 1) / 2 + (rand() - 0.5) * 3;
    final double rx = w * (0.24 + rand() * 0.05);
    final double ry = h * (0.19 + rand() * 0.05);
    final List<int> jit = _profile(h, 2, rand);
    final double ix = math.max(1.6, rx * 0.42);
    final double iy = math.max(2.1, ry * 0.36);
    for (int y = 0; y < h; y++) {
      final double ty = (y - cy) / ry;
      if (ty < -1 || ty > 1) continue;
      final double half = rx * math.sqrt(1 - ty * ty) + (jit[y] - 1) * 0.6;
      for (int x = 0; x < w; x++) {
        if ((x - cx).abs() > half) continue;
        final double ex = (x - cx) / ix;
        final double ey = (y - cy) / iy;
        if (ex * ex + ey * ey <= 1) continue; // ortadaki ada
        m[y * w + x] = 0;
      }
    }
  }
  return m;
}

List<String> maskRows(Uint8List m, int w, int h) => <String>[
      for (int y = 0; y < h; y++) String.fromCharCodes(<int>[for (int x = 0; x < w; x++) m[y * w + x] != 0 ? 49 : 48])
    ];

/// Maskedeki oynanabilir hücre sayısı (maske yoksa w·h).
int maskCount(int w, int h, List<String>? mask) {
  if (mask == null) return w * h;
  int c = 0;
  for (final String r in mask) {
    for (int i = 0; i < r.length; i++) {
      if (r.codeUnitAt(i) == 49) c++;
    }
  }
  return c;
}

class _A2 {
  final List<int> cells; // hücre indeksleri, kuyruk→baş
  final int d;
  int blk;
  final int lvl;
  _A2(this.cells, this.d, this.blk, this.lvl);
}

const List<int> _dxc = <int>[0, 0, -1, 1];
const List<int> _dyc = <int>[-1, 1, 0, 0];
const List<String> _dname = <String>['U', 'D', 'L', 'R'];
const List<int> _tl = <int>[2, 3, 1, 0];
const List<int> _tr = <int>[3, 2, 0, 1];

class Build2Result {
  final int maskCells;
  final int cells;
  final List<Arrow> arrows;
  const Build2Result(this.maskCells, this.cells, this.arrows);
}

/// build2 (JS): bağımlılık çizgesi artımlı olarak döngüsüz tutulur → her çıktı kurgu gereği çözülebilir.
Build2Result build2(int w, int h, Uint8List? mask, Rand rand, Tier2 P) {
  final int N = w * h;
  final Int32List g = Int32List(N);
  final Int8List hd = Int8List(N);
  int M = 0;
  for (int i = 0; i < N; i++) {
    hd[i] = -1;
    if (mask == null || mask[i] != 0) {
      g[i] = -1;
      M++;
    } else {
      g[i] = -2;
    }
  }
  final List<_A2> A = <_A2>[];
  final Int32List forb = Int32List(N);
  final Int32List own = Int32List(N);
  final Int32List seenA = Int32List(N + 1);
  final Int32List queue = Int32List(N + 1);
  int ep = 0, oep = 0;
  int nFree = 0, filled = 0;
  double target = P.fill * M;
  final double avgLen = (P.len0 + P.len1) / 2 * 0.7 + 1;
  final int budget = math.max(P.minFree, (P.free * target / avgLen + 0.5).floor());

  // ışın taraması: (c'den d yönünde kenara dek) dolu hücre sayısı + en büyük kat → riCnt, riLv
  int riCnt = 0, riLv = 0;
  void rayInfo(int c, int d) {
    int x = c % w + _dxc[d], y = c ~/ w + _dyc[d], cnt = 0, lv = 0;
    while (x >= 0 && y >= 0 && x < w && y < h) {
      final int k = g[y * w + x];
      if (k >= 0) {
        cnt++;
        if (A[k].lvl > lv) lv = A[k].lvl;
      }
      x += _dxc[d];
      y += _dyc[d];
    }
    riCnt = cnt;
    riLv = lv;
  }

  // X'in (baş c, yön d) bağımlı olduğu tüm okların ışınlarını (ve kendi ışınını) yasakla (forb = ep)
  void markDesc(int c, int d) {
    ep++;
    int qh = 0, qt = 0, x = c % w + _dxc[d], y = c ~/ w + _dyc[d];
    while (x >= 0 && y >= 0 && x < w && y < h) {
      final int q = y * w + x;
      forb[q] = ep;
      final int k = g[q];
      if (k >= 0 && seenA[k] != ep) {
        seenA[k] = ep;
        queue[qt++] = k;
      }
      x += _dxc[d];
      y += _dyc[d];
    }
    while (qh < qt) {
      final _A2 a = A[queue[qh++]];
      final int hc = a.cells[a.cells.length - 1], ad = a.d;
      x = hc % w + _dxc[ad];
      y = hc ~/ w + _dyc[ad];
      while (x >= 0 && y >= 0 && x < w && y < h) {
        final int q = y * w + x;
        forb[q] = ep;
        final int k = g[q];
        if (k >= 0 && seenA[k] != ep) {
          seenA[k] = ep;
          queue[qt++] = k;
        }
        x += _dxc[ad];
        y += _dyc[ad];
      }
    }
  }

  bool okCell(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return false;
    final int q = y * w + x;
    return g[q] == -1 && forb[q] != ep && own[q] != oep;
  }

  int solid(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return 1;
    final int q = y * w + x;
    return (g[q] != -1 || own[q] == oep) ? 1 : 0;
  }

  final Int32List candK = Int32List(3);
  final Float64List candW = Float64List(3);
  int bodyTurns = 0;
  // gövde: baştan geriye büyür. Dönen: hücre indeksleri kuyruk→baş (dönüş sayısı bodyTurns'te)
  List<int> body(int c, int d, int L, int maxTurns) {
    final List<int> cells = <int>[c];
    int x = c % w, y = c ~/ w, s = d, run = 1, turns = 0, last = 0;
    oep++;
    own[c] = oep;
    while (cells.length < L) {
      int nc = 0;
      double tot = 0;
      for (int k = 0; k < 3; k++) {
        final int ns = k == 0 ? s : (k == 1 ? _tl[s] : _tr[s]);
        if (k > 0 && (cells.length == 1 || turns >= maxTurns)) continue;
        final int nx = x - _dxc[ns], ny = y - _dyc[ns];
        if (!okCell(nx, ny)) continue;
        final int occ = solid(nx + 1, ny) + solid(nx - 1, ny) + solid(nx, ny + 1) + solid(nx, ny - 1) - 1; // geldiğimiz hücre hariç
        double wt;
        if (k == 0) {
          wt = run < 2 ? 6.0 : 1.0;
        } else {
          wt = P.turn * (run < 2 ? 0.08 : 1.0) * (last == 0 ? 1.0 : (last == k ? 2 * P.same : 2 * (1 - P.same)));
        }
        wt *= 1 + P.hug * occ;
        if (occ >= 3 && cells.length + 1 < L) wt *= 0.3; // çıkmaz sokak
        candK[nc] = k;
        candW[nc] = wt;
        nc++;
        tot += wt;
      }
      if (nc == 0) break;
      double r = rand() * tot;
      int pick = candK[nc - 1];
      for (int k = 0; k < nc; k++) {
        r -= candW[k];
        if (r <= 0) {
          pick = candK[k];
          break;
        }
      }
      if (pick != 0) {
        s = pick == 1 ? _tl[s] : _tr[s];
        turns++;
        last = pick;
        run = 1;
      } else {
        run++;
      }
      x -= _dxc[s];
      y -= _dyc[s];
      final int q = y * w + x;
      own[q] = oep;
      cells.add(q);
    }
    bodyTurns = turns;
    return cells.reversed.toList();
  }

  // hücre c dolunca: ışını c'den geçen okların engel sayacını artır (list verilirse yalnızca şu an serbest olanları toplar)
  void hit(int k, List<int>? list) {
    if (list != null) {
      if (A[k].blk == 0 && !list.contains(k)) list.add(k);
    } else if (A[k].blk++ == 0) {
      nFree--;
    }
  }

  void crossers(int c, List<int>? list) {
    final int cx = c % w, cy = c ~/ w;
    for (int x = cx - 1; x >= 0; x--) {
      final int q = cy * w + x;
      if (hd[q] == 3) hit(g[q], list);
    }
    for (int x = cx + 1; x < w; x++) {
      final int q = cy * w + x;
      if (hd[q] == 2) hit(g[q], list);
    }
    for (int y = cy - 1; y >= 0; y--) {
      final int q = y * w + cx;
      if (hd[q] == 1) hit(g[q], list);
    }
    for (int y = cy + 1; y < h; y++) {
      final int q = y * w + cx;
      if (hd[q] == 0) hit(g[q], list);
    }
  }

  int wouldBlock(List<int> cells) {
    final List<int> list = <int>[];
    for (int k = 0; k < cells.length; k++) {
      crossers(cells[k], list);
    }
    return list.length; // kaç serbest ok kapanır
  }

  void commit(List<int> cells, int d, int blk, int lvl) {
    final int id = A.length;
    A.add(_A2(cells, d, blk, lvl));
    for (int k = 0; k < cells.length; k++) {
      g[cells[k]] = id;
    }
    hd[cells[cells.length - 1]] = d;
    for (int k = 0; k < cells.length; k++) {
      crossers(cells[k], null);
    }
    if (blk == 0) nFree++;
    filled += cells.length;
  }

  final Int32List infoCnt = Int32List(4);
  final Int32List infoLv = Int32List(4);
  bool tryPlace(int c, int lenMin, int lenLo, int lenHi, int turnLo, int turnHi) {
    final List<int> order = _shuffle<int>(<int>[0, 1, 2, 3], rand);
    final int cx = c % w, cy = c ~/ w;
    final List<int> cands = <int>[];
    final bool allowFree = nFree < budget;
    for (int k = 0; k < 4; k++) {
      final int d = order[k], bx = cx - _dxc[d], by = cy - _dyc[d];
      if (lenMin >= 2 && !(bx >= 0 && by >= 0 && bx < w && by < h && g[by * w + bx] == -1)) continue;
      rayInfo(c, d);
      if (riCnt == 0 && !allowFree) continue;
      cands.add(d);
      infoCnt[d] = riCnt;
      infoLv[d] = riLv;
    }
    if (cands.isEmpty) return false;
    if (cands.length > 1 && rand() < P.deep) {
      // JS: (info[b][1] - info[a][1]) || (a - b) — kesin sıra (eşit öğe yok), sıralama algoritmasından bağımsız
      cands.sort((int a, int b) {
        final int t = infoLv[b] - infoLv[a];
        return t != 0 ? t : a - b;
      });
    }
    for (int k = 0; k < cands.length; k++) {
      final int dd = cands[k];
      markDesc(c, dd);
      if (forb[c] == ep) continue; // baş hücresi bağımlı olunan bir okun ışınında: döngü
      final int L = lenLo + (rand() * (lenHi - lenLo + 1)).floor();
      final int mt = turnLo + (rand() * (turnHi - turnLo + 1)).floor();
      List<int> b = body(c, dd, L, mt);
      int bTurns = bodyTurns;
      for (int tr = 1; tr < P.tries && lenMin > 1 && (b.length < L || bTurns < mt); tr++) {
        // en uzun + en kıvrımlı deneme
        final List<int> b2 = body(c, dd, L, mt);
        final int b2Turns = bodyTurns;
        if (b2.length + 2 * b2Turns > b.length + 2 * bTurns) {
          b = b2;
          bTurns = b2Turns;
        }
      }
      if (b.length < lenMin) continue;
      if (lenMin > 1 && turnLo >= 1 && b.length >= 4 && bTurns == 0) continue; // kıvrım isteyen kademede uzun düz ok yok
      final bool free = infoCnt[dd] == 0;
      if (P.minFree != 0) {
        final int nb = wouldBlock(b);
        if (nb != 0 && nFree - nb + (free ? 1 : 0) < P.minFree) continue;
      }
      commit(b, dd, infoCnt[dd], infoLv[dd] + 1);
      return true;
    }
    return false;
  }

  List<int> empties() {
    final List<int> e = <int>[];
    for (int q = 0; q < N; q++) {
      if (g[q] == -1) e.add(q);
    }
    return _shuffle<int>(e, rand);
  }

  int sweep(int lenMin, int lenLo, int lenHi, int tLo, int tHi) {
    final List<int> e = empties();
    int added = 0;
    for (int k = 0; k < e.length && filled < target; k++) {
      if (g[e[k]] != -1) continue;
      if (tryPlace(e[k], lenMin, lenLo, lenHi, tLo, tHi)) added++;
    }
    return added;
  }

  // kuyruk uzatma: boş hücre bir okun kuyruğuna komşuysa ve döngü kurmuyorsa oka eklenir (tek hücrelik dolgu yerine kıvrım)
  int extend(int maxLen) {
    final List<int> e = empties();
    int added = 0;
    for (int k = 0; k < e.length && filled < target; k++) {
      final int c = e[k];
      if (g[c] != -1) continue;
      final int cx = c % w, cy = c ~/ w;
      for (int j = 0; j < 4; j++) {
        final int nx = cx + _dxc[j], ny = cy + _dyc[j];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final int a = g[ny * w + nx];
        if (a < 0) continue;
        final _A2 ar = A[a];
        if (ar.cells[0] != ny * w + nx || ar.cells.length >= maxLen) continue;
        if (ar.cells.length == 1 && !(_dxc[ar.d] == nx - cx && _dyc[ar.d] == ny - cy)) continue; // tek hücrelik ok: gövde başın tam arkasına
        markDesc(ar.cells[ar.cells.length - 1], ar.d); // a'nın bağımlı olduklarının ışınları + kendi ışını
        if (forb[c] == ep) continue;
        if (P.minFree != 0) {
          final int nb = wouldBlock(<int>[c]);
          if (nb != 0 && nFree - nb < P.minFree) continue;
        }
        ar.cells.insert(0, c);
        g[c] = a;
        crossers(c, null);
        filled++;
        added++;
        break;
      }
    }
    return added;
  }

  final int lo = P.len0, hi = P.len1;
  // 1) uzun kıvrımlı oklar, 2) orta boy, 3) kuyruk uzatma, 4) kısa dolgu okları YALNIZCA doluluk bandın alt sınırına (+0,03) ulaşmadıysa
  for (int guard = 0; guard < 4 && filled < target; guard++) {
    if (sweep(lo, lo, hi, P.turns0, P.turns1) == 0) break;
  }
  final int mid = math.max(2, lo >> 1), mid2 = math.max(mid, 3);
  for (int guard = 0; guard < 3 && filled < target; guard++) {
    if (sweep(mid2, mid2, math.max(mid2, hi >> 1), math.min(1, P.turns0), P.turns1) == 0) break;
  }
  if (P.ext != 0) {
    for (int guard = 0; guard < 6 && filled < target; guard++) {
      if (extend(hi + 8) == 0) break;
    }
  }
  final double full = target;
  target = math.min(full, (P.band0 + 0.03) * M);
  for (int guard = 0; guard < 3 && filled < target; guard++) {
    if (sweep(mid, mid, math.max(mid, 3), 0, 1) == 0) break;
  }
  for (int guard = 0; guard < 3 && filled < target; guard++) {
    if (sweep(1, 1, P.filler, 0, 1) == 0) break;
  }
  target = full;
  if (P.ext != 0) {
    for (int guard = 0; guard < 3 && filled < target; guard++) {
      if (extend(hi + 12) == 0) break;
    }
  }
  return Build2Result(M, filled, <Arrow>[
    for (final _A2 a in A) Arrow(<List<int>>[for (final int q in a.cells) <int>[q % w, q ~/ w]], _dname[a.d])
  ]);
}

/// Kampanya ölçüsü (v2): doluluk maske hücrelerine oranla.
class Measure2 {
  final bool solvable;
  final int depth;
  final int initialFree;
  final double freeRatio;
  final double fill;
  final int arrows;
  final int curved;
  final double curvedRatio;
  final double meanTurns;
  final double meanLen;
  final int maxLen;
  final double score;
  const Measure2({
    required this.solvable,
    required this.depth,
    required this.initialFree,
    this.freeRatio = 0,
    this.fill = 0,
    this.arrows = 0,
    this.curved = 0,
    this.curvedRatio = 0,
    this.meanTurns = 0,
    this.meanLen = 0,
    this.maxLen = 0,
    this.score = 0,
  });
}

/// puan = 40·doluluk + 8·ort. dönüş + 2·ort. uzunluk + 30·(1 − 5·serbest oran) + 0,1·derinlik (JS ile aynı işlem sırası).
Measure2 measure2(int w, int h, List<Arrow> arrows, List<String>? mask) {
  final int n = arrows.length;
  final Analysis an = analyze(LgBoard(w, h, arrows));
  if (an.stuck.isNotEmpty || n == 0) return Measure2(solvable: false, depth: an.depth, initialFree: an.free.length);
  int cells = 0, turns = 0, curved = 0, maxLen = 0;
  for (final Arrow a in arrows) {
    cells += a.cells.length;
    final int t = turnsOf(a);
    turns += t;
    if (t != 0) curved++;
    if (a.cells.length > maxLen) maxLen = a.cells.length;
  }
  final int M = maskCount(w, h, mask);
  final double fill = cells / M, freeRatio = an.free.length / n, meanTurns = turns / n, meanLen = cells / n;
  final double fr5 = freeRatio * 5 > 1 ? 1.0 : freeRatio * 5;
  final double score = 40 * fill + 8 * meanTurns + 2 * meanLen + 30 * (1 - fr5) + 0.1 * an.depth;
  return Measure2(
      solvable: true,
      depth: an.depth,
      initialFree: an.free.length,
      freeRatio: freeRatio,
      fill: fill,
      arrows: n,
      curved: curved,
      curvedRatio: curved / n,
      meanTurns: meanTurns,
      meanLen: meanLen,
      maxLen: maxLen,
      score: score);
}

int freeLimit(String tier, int n) {
  final Tier2 t = kTier2[tier]!;
  return math.max(math.max(t.minFree, 1), (t.maxFree * n + 1e-9).floor());
}

const int kRounds = 8;
const String kGenVersion = 'v20.1'; // üretici/özellik kuralı değişirse artır (oyundaki sonsuz seviye önbelleği geçersizleşir)

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
  final Measure2? m;
  final List<String>? mask;
  const LevelResult(this.id, this.w, this.h, this.par, this.diff, this.chapter, this.arrows, this.ok, this.rounds, [this.m, this.mask]);

  Level toLevel() => Level(id: id, w: w, h: h, par: par, diff: diff, arrows: arrows, ok: ok, mask: mask);
}

LevelResult _tutorialLevel(int id) {
  final t = kTutorial[id - 1];
  final List<Arrow> arrows = <Arrow>[
    for (final (int x, int y, String dir, int len) in t.arrows)
      Arrow(<List<int>>[
        for (int i = 0; i < len; i++) <int>[x + _dx[dir]! * i, y + _dy[dir]! * i]
      ], dir)
  ];
  return LevelResult(id, t.w, t.h, arrows.length, 'easy', 1, arrows, true, 0);
}

class _Best {
  final double key;
  final List<Arrow> arrows;
  final List<String>? mask;
  final Measure2 m;
  final bool ok;
  const _Best(this.key, this.arrows, this.mask, this.m, this.ok);
}

/// Seviye işi (JS levelJob): tohum = seedFor(id, tur); kademe koşullarını sağlayan ilk tur seçilir (en çok [kRounds] tur,
/// sağlanamazsa en iyi aday). step() tek build2 yapar. Zaman sınırı yok, yalnızca adım sayısı → aynı seviye her cihazda aynıdır.
class LevelJob {
  final int id;
  final LevelSpec? _sp;
  int _r = 0;
  _Best? _best;
  LevelResult? _out;

  LevelJob(this.id) : _sp = id <= kTutorial.length ? null : specFor(id) {
    if (id <= kTutorial.length) _out = _tutorialLevel(id);
  }

  bool step() {
    if (_out != null) return true;
    final LevelSpec sp = _sp!;
    final Tier2 P = sp.p;
    final Rand rand = Rng(seedFor(id, _r)).next;
    final Uint8List? mask = sp.shape == 'full' ? null : makeMask(sp.w, sp.h, sp.shape, rand);
    final Build2Result b = build2(sp.w, sp.h, mask, rand, P);
    final List<Arrow> arrows = _shuffle<Arrow>(b.arrows, rand);
    final List<String>? rows = mask == null ? null : maskRows(mask, sp.w, sp.h);
    final Measure2 m = measure2(sp.w, sp.h, arrows, rows);
    if (m.solvable) {
      final bool ok = m.fill >= P.band0 - 1e-9 &&
          m.fill <= P.band1 + 1e-9 &&
          m.initialFree <= freeLimit(sp.tier, m.arrows) &&
          m.meanTurns >= P.minTurns;
      final double key = (ok ? 1e6 : 0.0) + m.score;
      final _Best? bb = _best;
      if (bb == null || key > bb.key) _best = _Best(key, arrows, rows, m, ok);
    }
    _r++;
    final _Best? best = _best;
    if (best == null && _r >= kRounds * 4) throw StateError('levelgen: çözülebilir aday yok (seviye $id)');
    if (best != null && (best.ok || _r >= kRounds)) {
      _out = LevelResult(id, sp.w, sp.h, best.arrows.length, sp.tier, sp.chapter, best.arrows, best.ok, _r, best.m, best.mask);
      return true;
    }
    return false;
  }

  LevelResult? result() => _out;
}

LevelResult makeLevel(int id) {
  final LevelJob j = LevelJob(id);
  while (!j.step()) {}
  return j.result()!;
}

// ---- seviye özeti (altın test): kanonik serileştirme + FNV-1a 32 ----
// canon = "id:wxh:tier:" + oklar "x,y;x,y;...>D" ("|" ayracı) + (maske varsa) ":m" + satırlar "/" ile; oklar üretici sırasında.
String canon(int id, int w, int h, String? diff, List<Arrow> arrows, [List<String>? mask]) {
  final StringBuffer sb = StringBuffer('$id:${w}x$h:${diff ?? tierOf(id)}:');
  for (int i = 0; i < arrows.length; i++) {
    if (i > 0) sb.write('|');
    final Arrow a = arrows[i];
    for (int k = 0; k < a.cells.length; k++) {
      if (k > 0) sb.write(';');
      sb.write('${a.cells[k][0]},${a.cells[k][1]}');
    }
    sb.write('>${a.dir}');
  }
  if (mask != null) sb.write(':m${mask.join('/')}');
  return sb.toString();
}

/// Seviye özeti: 8 hane onaltılık FNV-1a 32 (tools/level-hashes.json ile aynı).
String levelHash(Level lv) => fnv32(canon(lv.id, lv.w, lv.h, lv.diff, lv.arrows, lv.mask)).toRadixString(16).padLeft(8, '0');
String levelResultHash(LevelResult r) => fnv32(canon(r.id, r.w, r.h, r.diff, r.arrows, r.mask)).toRadixString(16).padLeft(8, '0');
