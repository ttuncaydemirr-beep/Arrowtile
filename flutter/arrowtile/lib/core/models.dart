// Arrowtile — models.dart: ok ve seviye veri tipleri (levels.js / levelgen.js biçimiyle aynı).

/// Yön harfleri: 'U' yukarı, 'D' aşağı, 'L' sol, 'R' sağ. (Arapçada da aynalanmaz: R = ekranın sağı.)
const Map<String, List<int>> kDirs = {
  'U': [0, -1],
  'D': [0, 1],
  'L': [-1, 0],
  'R': [1, 0],
};

/// Yılan biçimli ok: [cells] kuyruktan başa, her hücre bir öncekine komşu; [dir] başın baktığı yön.
class Arrow {
  final List<List<int>> cells; // [[x, y], ...]
  final String dir;
  const Arrow(this.cells, this.dir);

  int get len => cells.length;
  List<int> get head => cells[cells.length - 1];

  factory Arrow.fromJson(Map<String, dynamic> j) {
    final List<dynamic> raw = j['cells'] as List<dynamic>;
    final List<List<int>> cs = <List<int>>[
      for (final dynamic c in raw) <int>[(c as List<dynamic>)[0] as int, c[1] as int]
    ];
    return Arrow(cs, j['dir'] as String);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cells': <List<int>>[for (final List<int> c in cells) <int>[c[0], c[1]]],
        'dir': dir,
      };
}

/// Bir seviye. Hazır seviyeler (1..216), sonsuz seviyeler ve günlük bulmaca aynı tiptir.
/// [daily] doluysa 'YYYY-MM-DD' (id = 0).
class Level {
  final int id;
  final int w;
  final int h;
  final int par;
  final String? diff; // easy | medium | hard | extreme
  final List<Arrow> arrows;
  final String? daily;
  final bool ok;
  const Level({
    required this.id,
    required this.w,
    required this.h,
    required this.par,
    required this.arrows,
    this.diff,
    this.daily,
    this.ok = true,
  });

  bool get isDaily => daily != null;

  factory Level.fromJson(Map<String, dynamic> j) => Level(
        id: j['id'] as int,
        w: j['w'] as int,
        h: j['h'] as int,
        par: j['par'] as int,
        diff: j['diff'] as String?,
        daily: j['daily'] as String?,
        ok: (j['ok'] as bool?) ?? true,
        arrows: <Arrow>[
          for (final dynamic a in (j['arrows'] as List<dynamic>)) Arrow.fromJson(a as Map<String, dynamic>)
        ],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'w': w,
        'h': h,
        'par': par,
        if (diff != null) 'diff': diff,
        if (daily != null) 'daily': daily,
        'arrows': <Map<String, dynamic>>[for (final Arrow a in arrows) a.toJson()],
      };
}
