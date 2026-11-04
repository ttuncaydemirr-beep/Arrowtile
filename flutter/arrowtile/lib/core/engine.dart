// Arrowtile — engine.dart: engine.js'in satır satır Dart karşılığı. Saf Dart (Flutter'a bağımlı değil).
// Kurallar: docs/01-oyun-tasarim-belgesi.md §2-5. Yılan oklar: baş = son hücre; ok başı dir yönünde düz ilerler.
import 'models.dart';

const int kMaxLives = 3;

List<List<int>> cellsOf(Arrow a) => a.cells;
int lenOf(Arrow a) => a.cells.length;
List<int> headOf(Arrow a) => a.cells[a.cells.length - 1];

/// Başın önündeki hücreler (tahta kenarına kadar). JS pathOf(a, w, h).
List<List<int>> pathOf(Arrow a, int w, int h) {
  final List<int> d = kDirs[a.dir]!;
  final List<int> hd = headOf(a);
  int x = hd[0] + d[0];
  int y = hd[1] + d[1];
  final List<List<int>> out = <List<int>>[];
  while (x >= 0 && y >= 0 && x < w && y < h) {
    out.add(<int>[x, y]);
    x += d[0];
    y += d[1];
  }
  return out;
}

/// Izgara: her hücre ya -1 (boş) ya da o hücreyi kaplayan okun indeksi. [alive] verilirse ölü oklar sayılmaz.
List<int> buildGrid(Level level, [List<bool>? alive]) {
  final int n = level.w * level.h;
  final List<int> g = List<int>.filled(n, -1);
  for (int k = 0; k < level.arrows.length; k++) {
    if (alive != null && !alive[k]) continue;
    for (final List<int> c in level.arrows[k].cells) {
      g[c[1] * level.w + c[0]] = k;
    }
  }
  return g;
}

/// Yoldaki ilk engel: blocker = engel olan okun indeksi, free = engelden önceki boş hücre sayısı.
class Obstacle {
  final int blocker;
  final int free;
  const Obstacle(this.blocker, this.free);
}

Obstacle? firstObstacle(Level level, int i, List<int> grid) {
  final List<List<int>> p = pathOf(level.arrows[i], level.w, level.h);
  for (int k = 0; k < p.length; k++) {
    final int v = grid[p[k][1] * level.w + p[k][0]];
    if (v != -1) return Obstacle(v, k);
  }
  return null;
}

/// Şu an çıkabilen oklar (indeks sırasıyla).
List<int> freeList(Level level, List<bool> alive) {
  final List<int> g = buildGrid(level, alive);
  final List<int> out = <int>[];
  for (int i = 0; i < level.arrows.length; i++) {
    if (alive[i] && firstObstacle(level, i, g) == null) out.add(i);
  }
  return out;
}

class SolveResult {
  final bool solvable;
  final List<int> order;
  final int layers;
  const SolveResult(this.solvable, this.order, this.layers);
}

/// Açgözlü çözüm (her turda çıkabilen tüm oklar).
SolveResult solve(Level level) {
  final int n = level.arrows.length;
  final List<bool> alive = List<bool>.filled(n, true);
  final List<int> order = <int>[];
  int layers = 0;
  while (order.length < n) {
    final List<int> free = freeList(level, alive);
    if (free.isEmpty) return SolveResult(false, order, layers);
    for (final int k in free) {
      alive[k] = false;
      order.add(k);
    }
    layers++;
  }
  return SolveResult(true, order, layers);
}

/// İpucu: çıkabilen oklardan en çok oku serbest bırakanı seç (eşitlikte küçük indeks). Yoksa -1.
int bestHint(Level level, List<bool> alive) {
  final List<int> free = freeList(level, alive);
  if (free.isEmpty) return -1;
  final int base = free.length;
  int best = free[0];
  int bestGain = -1;
  for (final int i in free) {
    final List<bool> a2 = List<bool>.of(alive);
    a2[i] = false;
    final int gain = freeList(level, a2).length - (base - 1);
    if (gain > bestGain) {
      bestGain = gain;
      best = i;
    }
  }
  return best;
}

/// Komşu (kenar paylaşan) oklar aynı renk olmasın — açgözlü boyama; renk sayısı [k].
List<int> colorize(Level level, int k) {
  final int n = level.arrows.length;
  final int w = level.w;
  final List<int> g = buildGrid(level);
  final List<int> out = List<int>.filled(n, -1);
  for (int i = 0; i < n; i++) {
    final Map<int, int> used = <int, int>{};
    final List<List<int>> cs = level.arrows[i].cells;
    for (int j = 0; j < cs.length; j++) {
      final int x = cs[j][0];
      final int y = cs[j][1];
      final List<List<int>> nb = <List<int>>[
        <int>[x + 1, y],
        <int>[x - 1, y],
        <int>[x, y + 1],
        <int>[x, y - 1],
      ];
      for (int q = 0; q < 4; q++) {
        final int nx = nb[q][0];
        final int ny = nb[q][1];
        if (nx < 0 || ny < 0 || nx >= w || ny >= level.h) continue;
        final int o = g[ny * w + nx];
        if (o != -1 && o != i && out[o] >= 0) used[out[o]] = (used[out[o]] ?? 0) + 1;
      }
    }
    int pick = -1;
    for (int c = 0; c < k; c++) {
      final int cc = (i + c) % k;
      if ((used[cc] ?? 0) == 0) {
        pick = cc;
        break;
      }
    }
    if (pick < 0) {
      int best = 1000000000;
      for (int c2 = 0; c2 < k; c2++) {
        final int u = used[c2] ?? 0;
        if (u < best) {
          best = u;
          pick = c2;
        }
      }
    }
    out[i] = pick;
  }
  return out;
}

/// Seviye başına jeton tabanı (yıldıza göre): [0, 10, 15, 20][stars].
int rewardFor(int stars) {
  const List<int> t = <int>[0, 10, 15, 20];
  return stars >= 0 && stars < t.length ? t[stars] : 0;
}

/// Dokunuş sonucu. type: 'exit' | 'bump'.
class TapResult {
  final String type;
  final int i;
  // exit
  final int steps;
  final bool won;
  // bump
  final int free;
  final int blocker;
  final bool lifeLost;
  final bool dead;
  const TapResult.exit({required this.i, required this.steps, required this.won})
      : type = 'exit',
        free = 0,
        blocker = -1,
        lifeLost = false,
        dead = false;
  const TapResult.bump(
      {required this.i, required this.free, required this.blocker, required this.lifeLost, required this.dead})
      : type = 'bump',
        steps = 0,
        won = false;
  bool get isExit => type == 'exit';
  bool get isBump => type == 'bump';
}

/// Bir seviye oturumu. [noLifeLoss]: öğretici muafiyeti (seviye 2). [relaxed]: rahat mod (can yok, en çok 2 yıldız).
class Game {
  final Level level;
  bool noLifeLoss;
  final bool relaxed;
  late List<bool> alive;
  int lives = kMaxLives;
  int collisions = 0;
  int taps = 0;
  int revived = 0;

  Game(this.level, {this.noLifeLoss = false, this.relaxed = false}) {
    reset();
  }

  void reset() {
    alive = List<bool>.filled(level.arrows.length, true);
    lives = kMaxLives;
    collisions = 0;
    taps = 0;
    revived = 0;
  }

  int remaining() => alive.where((bool b) => b).length;
  bool get isWon => remaining() == 0;
  bool get isDead => lives <= 0;
  List<int> grid() => buildGrid(level, alive);

  int arrowAt(int cx, int cy) {
    if (cx < 0 || cy < 0 || cx >= level.w || cy >= level.h) return -1;
    return grid()[cy * level.w + cx];
  }

  bool canExit(int i) => alive[i] && firstObstacle(level, i, grid()) == null;
  List<int> freeArrows() => freeList(level, alive);
  int hint() => bestHint(level, alive);

  int stars() {
    final int s = collisions == 0 ? 3 : (collisions == 1 ? 2 : 1);
    return relaxed ? (s < 2 ? s : 2) : s; // rahat modda en fazla 2 yıldız
  }

  /// Oka dokun. Geçersizse (oyun bitti, ölü ok, geçersiz indeks) null.
  TapResult? tap(int i) {
    if (isWon || isDead || i < 0 || i >= alive.length || !alive[i]) return null;
    taps++;
    final Arrow a = level.arrows[i];
    final Obstacle? obs = firstObstacle(level, i, grid());
    if (obs == null) {
      alive[i] = false;
      return TapResult.exit(i: i, steps: pathOf(a, level.w, level.h).length, won: isWon);
    }
    // Rahat mod: can gitmez ama çarpışma sayılır (yıldız için); öğretici muafiyeti: hiçbiri.
    final bool lifeLost = !noLifeLoss && !relaxed;
    if (lifeLost) lives--;
    if (lifeLost || (relaxed && !noLifeLoss)) collisions++;
    return TapResult.bump(i: i, free: obs.free, blocker: obs.blocker, lifeLost: lifeLost, dead: isDead);
  }

  /// Ödüllü reklamla +1 can (can bittiğinde). Çarpışma sayacı korunur.
  bool revive() {
    if (!isDead || isWon) return false;
    lives = 1;
    revived++;
    return true;
  }
}
