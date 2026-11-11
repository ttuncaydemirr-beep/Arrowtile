// Arrowtile — board_painter.dart: theme.js drawArrow() ve main.js draw()/drawTray() için CustomPainter karşılığı.
// Oranlar birebir: gövde %15, baş %40 (en az 7 px), şevron yalnız hücre ≥ 22 px, ok başında nokta, alt kalınlık gölgesi.
// 1.2.0: tek renk kipi (ince çizgi, gölge/şevron/nokta yok), şekilli (maskeli) tahta tepsisi, ekran dışı ok çizilmez,
// çıkış sabit hızla tahta kenarına dek (kenarda kırpılır, solma yok), küçük harita yalnızca tahta kaydırılabilirken.
// Yılan oklar: iz = gövde hücre merkezleri + baştan dir yönünde düz doğru; gövde başı tren gibi izler (off = iz kayması).
import 'dart:math' as math;

import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../core/engine.dart';
import '../core/models.dart';
import 'tokens.dart';

const Map<String, double> _angle = <String, double>{'R': 0, 'D': math.pi / 2, 'L': math.pi, 'U': -math.pi / 2};
const Map<String, List<int>> _step = <String, List<int>>{
  'R': <int>[1, 0],
  'D': <int>[0, 1],
  'L': <int>[-1, 0],
  'U': <int>[0, -1],
};

/// HTML canvas arcTo(x1, y1, x2, y2, r) anlamıyla köşe yuvarlama: geçerli nokta [p0] → [p1] köşesi → [p2].
/// Dönen: yeni geçerli nokta.
Offset _arcTo(Path path, Offset p0, Offset p1, Offset p2, double r) {
  final Offset v0 = p0 - p1;
  final Offset v1 = p2 - p1;
  final double l0 = v0.distance;
  final double l1 = v1.distance;
  if (l0 == 0 || l1 == 0 || r <= 0) {
    path.lineTo(p1.dx, p1.dy);
    return p1;
  }
  final Offset u0 = v0 / l0;
  final Offset u1 = v1 / l1;
  final double cross = u0.dx * u1.dy - u0.dy * u1.dx;
  final double dot = u0.dx * u1.dx + u0.dy * u1.dy;
  final double sinA = cross.abs();
  if (sinA < 1e-9) {
    path.lineTo(p1.dx, p1.dy);
    return p1;
  }
  final double angle = math.atan2(sinA, dot); // u0 ile u1 arasındaki açı (0..π)
  final double d = r / math.tan(angle / 2); // köşeden teğet noktalarına uzaklık
  final Offset t0 = p1 + u0 * d;
  final Offset t1 = p1 + u1 * d;
  path.lineTo(t0.dx, t0.dy);
  // Dönüş yönü: (p1 - p0) × (p2 - p1) > 0 ise ekranda (y aşağı) saat yönü.
  final double turn = (p1 - p0).dx * (p2 - p1).dy - (p1 - p0).dy * (p2 - p1).dx;
  path.arcToPoint(t1, radius: Radius.circular(r), clockwise: turn > 0);
  return t1;
}

/// theme.js roundedPoly(): köşeleri ayrı yarıçaplı kapalı çokgen.
Path _roundedPoly(List<Offset> pts, List<double> radii) {
  final Path path = Path();
  final int n = pts.length;
  Offset cur = Offset((pts[n - 1].dx + pts[0].dx) / 2, (pts[n - 1].dy + pts[0].dy) / 2);
  path.moveTo(cur.dx, cur.dy);
  for (int i = 0; i < n; i++) {
    cur = _arcTo(path, cur, pts[i], pts[(i + 1) % n], radii[i]);
  }
  path.close();
  return path;
}

/// drawArrow() girdileri. [cells] kuyruk→baş (hücre koordinatı), [off] iz üzerindeki kayma (hücre).
class ArrowDrawOpts {
  final double ox, oy; // tahtanın sol üst köşesi (piksel)
  final List<List<int>> cells;
  final String dir;
  final double cell;
  final double off;
  final int color; // 0xRRGGBB
  final double alpha;
  final bool highlight;
  final int chevron; // 0xRRGGBB
  final double chevronAlpha;
  final bool mono; // 1.2.0 tek renk kipi
  const ArrowDrawOpts({
    required this.ox,
    required this.oy,
    required this.cells,
    required this.dir,
    required this.cell,
    required this.color,
    required this.chevron,
    required this.chevronAlpha,
    this.off = 0,
    this.alpha = 1,
    this.highlight = false,
    this.mono = false,
  });
}

void drawArrow(Canvas canvas, ArrowDrawOpts o, Palette pal) {
  final double cell = o.cell;
  final String dir = _angle.containsKey(o.dir) ? o.dir : 'R';
  final List<int> D = _step[dir]!;
  final List<List<int>> cells = o.cells;
  final int n = cells.length;
  final double off = o.off;
  const double mg = Shape.margin;
  final bool mono = o.mono;
  final double bw = mono ? math.max(Shape.monoMinPx, Shape.monoBody * cell) : math.max(2.0, Shape.bodyWidth * cell);
  final double hw = mono ? math.max(5.0, Shape.monoHead * cell) : math.max(Shape.headMinPx, Shape.headWidth * cell);
  final double hl = math.max(hw * 0.72, Shape.headLength * cell);
  final double ga = o.alpha.clamp(0.0, 1.0); // globalAlpha

  // iz noktası (hücre merkezleri, hücre biriminde): -1 = kuyruğun arkasındaki sanal nokta
  final List<int> back = n > 1
      ? <int>[cells[0][0] - cells[1][0], cells[0][1] - cells[1][1]]
      : <int>[-D[0], -D[1]];
  List<double> P(int i) {
    if (i < 0) return <double>[(cells[0][0] + back[0]).toDouble(), (cells[0][1] + back[1]).toDouble()];
    if (i <= n - 1) return <double>[cells[i][0].toDouble(), cells[i][1].toDouble()];
    return <double>[(cells[n - 1][0] + D[0] * (i - n + 1)).toDouble(), (cells[n - 1][1] + D[1] * (i - n + 1)).toDouble()];
  }

  List<double> T(double sv) {
    int i = sv.floor();
    if (i > n - 2 && sv >= n - 1) {
      final List<int> hd = cells[n - 1];
      final double q = sv - (n - 1);
      return <double>[hd[0] + D[0] * q, hd[1] + D[1] * q];
    }
    if (i < -1) i = -1;
    final List<double> a = P(i);
    final List<double> b = P(i + 1);
    final double t = sv - i;
    return <double>[a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
  }

  Offset px(List<double> pt) => Offset(o.ox + (pt[0] + 0.5) * cell, o.oy + (pt[1] + 0.5) * cell);

  final double s0 = off - (0.5 - mg); // kuyruk ucu
  final double s1 = off + n - 1 + (0.5 - mg); // uç
  final double sb = s1 - hl / cell; // ok başı tabanı
  final Offset tip = px(T(s1));
  final Offset basePt = px(T(sb));
  final double ang = _angle[dir]!;

  Path bodyPath(double dy) {
    final Path p = Path();
    final Offset p0 = px(T(s0));
    p.moveTo(p0.dx, p0.dy + dy);
    for (int i = (s0 + 1e-6).ceil(); i < sb; i++) {
      final Offset pi = px(T(i.toDouble()));
      p.lineTo(pi.dx, pi.dy + dy);
    }
    p.lineTo(basePt.dx + math.cos(ang) * bw * 0.3, basePt.dy + math.sin(ang) * bw * 0.3 + dy);
    return p;
  }

  Path headPath(double dy) {
    // yerel çerçeve: uç noktası orijin, dönüş ang; üçgen (-hl, -hw/2) (0,0) (-hl, hw/2)
    final double c = math.cos(ang);
    final double s = math.sin(ang);
    Offset rot(double x, double y) => Offset(tip.dx + x * c - y * s, tip.dy + dy + x * s + y * c);
    return _roundedPoly(
      <Offset>[rot(-hl, -hw / 2), rot(0, 0), rot(-hl, hw / 2)],
      <double>[Shape.headRadius * cell, Shape.tipRadius * cell, Shape.headRadius * cell],
    );
  }

  Paint stroke(double width, int rgb, [double a = 1]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = rgba(rgb, a * ga)
    ..isAntiAlias = true;
  Paint fill(int rgb, [double a = 1]) => Paint()
    ..style = PaintingStyle.fill
    ..color = rgba(rgb, a * ga)
    ..isAntiAlias = true;

  void whole(double dy, double width, int rgb, bool doFill) {
    canvas.drawPath(bodyPath(dy), stroke(width, rgb));
    final Path head = headPath(dy);
    if (doFill) canvas.drawPath(head, fill(rgb));
    if (width > bw) canvas.drawPath(head, stroke(width - bw, rgb));
  }

  if (o.highlight) {
    whole(0, bw + cell * 0.20, pal.highlightRing, true);
    whole(0, bw + cell * 0.08, pal.highlight, true);
  }
  if (!mono) whole(Shape.depth * cell, bw, _shadeOf(o.color), true); // alt kalınlık (ekran aşağısı)
  whole(0, bw, o.color, true); // yüz
  if (mono) return; // tek renk: ince çizgi, şevron/nokta yok

  // şevronlar: her gövde hücresinde akış yönünde ">" (köşe ve baş hücresi hariç)
  if (cell >= Shape.chevronMinCell) {
    final double cs = Shape.chevronSize * cell;
    final Paint cp = stroke(math.max(0.9, Shape.chevronLine * cell), o.chevron, o.chevronAlpha);
    for (int c = 0; c < n - 1; c++) {
      final double sv = off + c;
      if (sv > sb - 0.35) break;
      final int fi = sv.floor();
      final double fr = sv - fi;
      final List<double> a1 = T(fi.toDouble());
      final List<double> a2 = T(fi + 1.0);
      final double ddx = a2[0] - a1[0];
      final double ddy = a2[1] - a1[1];
      if (fr < 0.01 && fi >= 0 && fi <= n - 2) {
        // tam hücre merkezinde: gelen ve giden yön aynı olmalı (köşe değil)
        final List<double> pv = T(fi - 1.0);
        if (fi > 0 && (a1[0] - pv[0] != ddx || a1[1] - pv[1] != ddy)) continue;
      } else if (fr > 0.65 ||
          (fr < 0.35 &&
              fi > 0 &&
              (() {
                final List<double> pv2 = T(fi - 1.0);
                return a1[0] - pv2[0] != ddx || a1[1] - pv2[1] != ddy;
              })())) {
        continue;
      }
      final Offset c0 = px(T(sv));
      final double ca = math.atan2(ddy, ddx);
      final double cc = math.cos(ca);
      final double ss = math.sin(ca);
      Offset rot(double x, double y) => Offset(c0.dx + x * cc - y * ss, c0.dy + x * ss + y * cc);
      final Path ch = Path();
      final Offset q0 = rot(-cs * 0.6, -cs);
      final Offset q1 = rot(cs * 0.4, 0);
      final Offset q2 = rot(-cs * 0.6, cs);
      ch.moveTo(q0.dx, q0.dy);
      ch.lineTo(q1.dx, q1.dy);
      ch.lineTo(q2.dx, q2.dy);
      canvas.drawPath(ch, cp);
    }
  }
  // ok başında küçük nokta: yönü renk dışı bir işaretle pekiştirir
  canvas.drawCircle(
    Offset(tip.dx - math.cos(ang) * hl * 0.70, tip.dy - math.sin(ang) * hl * 0.70),
    math.max(0.9, cell * Shape.dotRadius),
    fill(o.chevron, o.chevronAlpha),
  );
}

final Map<int, int> _shadeCache = <int, int>{};
int _shadeOf(int c) => _shadeCache.putIfAbsent(c, () => shadeRgb(c, -0.35));

/// theme.js drawBoard(): tepsi + hücre köşelerinde çok hafif nokta ızgara (dikdörtgen tahta; 1.2.0 oyun ekranı [TrayCache] kullanır).
void drawBoardBg(Canvas canvas, double ox, double oy, int w, int h, double cell, Palette pal) {
  final double pad = boardPadFor(w) * cell;
  final double r = math.min(Shape.boardRadius * cell, 10);
  final double bx = ox - pad;
  final double by = oy - pad;
  final double bwid = w * cell + pad * 2;
  final double bh = h * cell + pad * 2;
  RRect rr(double x, double y, double ww, double hh, double rad) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, ww, hh), Radius.circular(rad));
  canvas.drawRRect(rr(bx, by + cell * 0.1, bwid, bh, r), Paint()..color = rgba(pal.boardEdge));
  canvas.drawRRect(rr(bx, by, bwid, bh, r), Paint()..color = rgba(pal.board));
  // Noktalar hücre merkezinde değil köşelerde: boş hücrenin ortası tahta renginde kalır
  final double dr = math.max(0.7, Shape.gridDot * cell);
  final Paint dp = Paint()
    ..color = rgba(pal.cellDot, pal.dark ? 0.55 : 0.75)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = dr * 2;
  final List<Offset> pts = <Offset>[
    for (int j = 0; j <= h; j++)
      for (int i = 0; i <= w; i++) Offset(ox + i * cell, oy + j * cell)
  ];
  canvas.drawPoints(PointMode.points, pts, dp);
}

// ------------------------------------------------------------------ oyun tahtası durumu + boyayıcı

/// Çıkış / çarpma / belirme animasyonu kaydı (main.js anims[i]). Süreler ms (BoardModel.nowMs ile aynı saat).
class BoardAnim {
  final String kind; // exit | bump | appear
  final double t0;
  final double dur;
  final double dist;
  final double fwd;
  VoidCallback? done;
  BoardAnim({required this.kind, required this.t0, required this.dur, this.dist = 0, this.fwd = 0, this.done});
}

class ShakeAnim {
  final double t0;
  final double dur;
  final double ax;
  final double ay;
  const ShakeAnim(this.t0, this.dur, this.ax, this.ay);
}

/// 1.2.0 (main.js buildTray/drawTray): tahta tepsisi. Maske varsa (şekilli tahta) oynanabilir hücrelerin birleşimi, yuvarlak
/// köşeli (yol, tepsi payı kalınlığında yuvarlak birleşimle çizilir); yoksa dikdörtgen. Hücre biriminde önbellek + ok sınır kutuları.
class TrayCache {
  final Level level;
  final Path path; // hücre biriminde
  final List<Offset> dots; // ızgara noktaları (hücre köşeleri, hücre biriminde)
  final List<List<int>> boxes; // ok başına [x0, y0, x1, y1] (hücre)
  TrayCache._(this.level, this.path, this.dots, this.boxes);

  factory TrayCache.of(Level lv) {
    final int w = lv.w, h = lv.h;
    final Path p = Path();
    if (lv.mask == null) {
      p.addRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    } else {
      for (int y = 0; y < h; y++) {
        int x = 0;
        while (x < w) {
          if (!lv.inMask(x, y)) {
            x++;
            continue;
          }
          final int x0 = x;
          while (x < w && lv.inMask(x, y)) {
            x++;
          }
          p.addRect(Rect.fromLTWH(x0.toDouble(), y.toDouble(), (x - x0).toDouble(), 1));
        }
      }
    }
    final List<Offset> dots = <Offset>[
      for (int y = 0; y <= h; y++)
        for (int x = 0; x <= w; x++)
          if (lv.inMask(x, y) || lv.inMask(x - 1, y) || lv.inMask(x, y - 1) || lv.inMask(x - 1, y - 1)) Offset(x.toDouble(), y.toDouble())
    ];
    final List<List<int>> boxes = <List<int>>[for (final Arrow a in lv.arrows) _boxOf(a)];
    return TrayCache._(lv, p, dots, boxes);
  }

  static List<int> _boxOf(Arrow a) {
    final List<int> b = <int>[1 << 30, 1 << 30, -(1 << 30), -(1 << 30)];
    for (final List<int> q in a.cells) {
      if (q[0] < b[0]) b[0] = q[0];
      if (q[1] < b[1]) b[1] = q[1];
      if (q[0] > b[2]) b[2] = q[0];
      if (q[1] > b[3]) b[3] = q[1];
    }
    return b;
  }
}

/// Boyayıcının okuduğu değişken oyun görüntüsü. State nesnesi bunu günceller, boyayıcı [repaint] ile yeniden çizer.
class BoardModel {
  Level level;
  Game game;
  ArrowTheme theme;
  Palette pal;
  bool rtl;
  bool mono = false; // 1.2.0: Ayarlar → Ok rengi: Tek renk
  List<int> colors; // E.colorize sonucu (okun tema renk indeksi)
  final Map<int, BoardAnim> anims = <int, BoardAnim>{};
  ShakeAnim? shake;
  int hintIdx = -1;
  int aimSel = -1;
  List<int> flashIds = <int>[];
  bool minimap = false; // tahta kaydırılabilir (ve seviye bitmedi): köşede küçük harita
  // yerleşim (1.2.0: varsayılan yakınlıkta hücre ≥ 20 px; sMin = tüm tahta görünür, sMax = en yakın)
  double cell = 40, ox = 0, oy = 0, width = 0, height = 0, fit = 40, sMin = 1, sMax = 2.5;
  // yakınlaştırma / kaydırma (tahta koordinatı → ekran = p·vs + (vx, vy))
  double vs = 1, vx = 0, vy = 0;
  TrayCache tray;
  final Stopwatch _clock = Stopwatch()..start();

  BoardModel(this.level, this.game, this.theme, this.pal, this.rtl)
      : colors = colorize(level, theme.colors.length),
        tray = TrayCache.of(level);

  /// Testler için: sahte saat (widget testlerinde gerçek Stopwatch ilerlemez, animasyonlar bitmez). Üretimde null.
  static double Function()? testClock;

  double get nowMs {
    final double Function()? tc = testClock;
    return tc != null ? tc() : _clock.elapsedMicroseconds / 1000.0;
  }

  void recolor() {
    colors = colorize(level, theme.colors.length);
  }

  /// Tepsi kutusu (piksel, görünüm dönüşümü öncesi): [x0, y0, x1, y1].
  List<double> trayBox() {
    final double p = boardPadFor(level.w) * cell;
    return <double>[ox - p, oy - p, ox + level.w * cell + p, oy + level.h * cell + p];
  }
}

class BoardPainter extends CustomPainter {
  final BoardModel m;
  BoardPainter(this.m, Listenable repaint) : super(repaint: repaint);

  void _drawTray(Canvas canvas, double c) {
    final Level lv = m.level;
    final Palette pal = m.pal;
    final double pad = boardPadFor(lv.w);
    final Path p = m.tray.path;
    canvas.save();
    canvas.translate(m.ox, m.oy);
    canvas.scale(c, c);
    Paint fillP(int rgb) => Paint()
      ..color = rgba(rgb)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    Paint edgeP(int rgb) => Paint()
      ..color = rgba(rgb)
      ..style = PaintingStyle.stroke
      ..strokeWidth = pad * 2
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.save();
    canvas.translate(0, 0.1);
    canvas.drawPath(p, fillP(pal.boardEdge));
    canvas.drawPath(p, edgeP(pal.boardEdge));
    canvas.restore();
    canvas.drawPath(p, fillP(pal.board));
    canvas.drawPath(p, edgeP(pal.board));
    if (c * m.vs >= 9) {
      final Paint dp = Paint()
        ..color = rgba(pal.cellDot, pal.dark ? 0.55 : 0.75)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = Shape.gridDot * 2;
      canvas.drawPoints(PointMode.points, m.tray.dots, dp);
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Level lv = m.level;
    final double c = m.cell;
    final double now = m.nowMs;
    if (!identical(m.tray.level, lv)) m.tray = TrayCache.of(lv);
    canvas.save();
    canvas.translate(m.vx, m.vy);
    canvas.scale(m.vs);
    double sx = 0, sy = 0;
    final ShakeAnim? sh = m.shake;
    if (sh != null) {
      final double p = (now - sh.t0) / sh.dur;
      final double amp = Anim.shakeAmp * c * math.sin(p * math.pi * 2 * Anim.shakeCycles) * (1 - p);
      sx = sh.ax * amp;
      sy = sh.ay * amp;
    }
    canvas.translate(sx, sy);
    _drawTray(canvas, c);
    final ArrowTheme th = m.theme;
    final bool mono = m.mono;
    // görünür hücre penceresi (ekran dışındaki oklar çizilmez)
    final double bx0 = (0 - m.vx) / m.vs, by0 = (0 - m.vy) / m.vs;
    final double bx1 = (m.width - m.vx) / m.vs, by1 = (m.height - m.vy) / m.vs;
    final double vx0 = (bx0 - m.ox) / c - 1.5, vy0 = (by0 - m.oy) / c - 1.5, vx1 = (bx1 - m.ox) / c + 0.5, vy1 = (by1 - m.oy) / c + 0.5;
    void one(int i, BoardAnim? an) {
      final Arrow a = lv.arrows[i];
      double off = 0, alpha = 1;
      if (an != null) {
        final double q = math.min(1.0, (now - an.t0) / an.dur);
        if (an.kind == 'exit') {
          off = an.dist * q; // sabit hız: ok kendi yolunu izleyerek tahta kenarına dek gider (kenarda kırpılır)
        } else if (an.kind == 'bump') {
          final double tf = an.fwd / an.dur;
          if (q < tf) {
            off = an.dist * easeIn(q / tf);
          } else {
            off = an.dist * (1 - easeBack((q - tf) / (1 - tf)));
          }
        } else if (an.kind == 'appear') {
          alpha = q;
        }
      }
      final int col = mono ? m.pal.ink : th.colors[m.colors[i] % th.colors.length];
      if (i == m.hintIdx) {
        // ipucu halkası (web: globalAlpha nabzı drawArrow içinde yeniden kurulduğundan etkisiz; davranış birebir)
        drawArrow(
            canvas,
            ArrowDrawOpts(
                ox: m.ox, oy: m.oy, cells: a.cells, dir: a.dir, cell: c, off: off, color: col,
                highlight: true, chevron: th.chevron, chevronAlpha: th.chevronAlpha, mono: mono),
            m.pal);
      }
      final bool sel = i == m.aimSel || m.flashIds.contains(i);
      drawArrow(
          canvas,
          ArrowDrawOpts(
              ox: m.ox, oy: m.oy, cells: a.cells, dir: a.dir, cell: c, off: off, color: col, alpha: alpha,
              chevron: th.chevron, chevronAlpha: th.chevronAlpha, highlight: sel, mono: mono),
          m.pal);
    }

    List<int>? exits;
    final List<List<int>> boxes = m.tray.boxes;
    for (int i = 0; i < lv.arrows.length; i++) {
      final BoardAnim? an = m.anims[i];
      if (an != null && an.kind == 'exit') {
        (exits ??= <int>[]).add(i);
        continue;
      }
      if (!m.game.alive[i]) continue;
      final List<int> bb = boxes[i];
      if (an == null && (bb[2] < vx0 || bb[0] > vx1 || bb[3] < vy0 || bb[1] > vy1)) continue;
      one(i, an);
    }
    if (exits != null) {
      // çıkan oklar tahta kenarında kaybolur
      final List<double> tb = m.trayBox();
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(tb[0], tb[1], tb[2], tb[3] + c * 0.12));
      for (final int e in exits) {
        one(e, m.anims[e]);
      }
      canvas.restore();
    }
    if (m.aimSel >= 0 && m.aimSel < lv.arrows.length && m.game.alive[m.aimSel] && !m.anims.containsKey(m.aimSel)) {
      _drawAimPath(canvas, m.aimSel, c);
    }
    canvas.restore();
    if (m.minimap) _drawMinimap(canvas, th);
  }

  // G1: seçili okun yolu (engel ya da tahta kenarına kadar) noktalarla gösterilir
  void _drawAimPath(Canvas canvas, int i, double c) {
    final Level lv = m.level;
    final Arrow a = lv.arrows[i];
    final List<List<int>> p = pathOf(a, lv.w, lv.h);
    final List<int> g = m.game.grid();
    for (int k = 0; k < p.length; k++) {
      final bool occ = g[p[k][1] * lv.w + p[k][0]] != -1;
      final Offset ctr = Offset(m.ox + (p[k][0] + 0.5) * c, m.oy + (p[k][1] + 0.5) * c);
      if (occ) {
        canvas.drawCircle(
            ctr, c * 0.36, Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = c * 0.08
              ..color = rgba(m.pal.danger));
        break;
      }
      canvas.drawCircle(ctr, c * 0.09, Paint()..color = rgba(m.pal.highlightRing));
    }
  }

  // küçük harita (ekran koordinatında, üst köşe; RTL'de karşı köşe) — yalnızca tahta kaydırılabilirken
  void _drawMinimap(Canvas canvas, ArrowTheme th) {
    final Level lv = m.level;
    const double mw = 64;
    final double cs = mw / (lv.w + 0.6);
    final double mh = cs * (lv.h + 0.6);
    const double mm = 8;
    final double mx = m.rtl ? m.width - mw - mm : mm;
    const double my = 6;
    final Rect box = Rect.fromLTWH(mx, my, mw, mh);
    canvas.drawRect(box, Paint()..color = rgba(m.pal.board, 0.92));
    canvas.drawRect(
        box, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = rgba(m.pal.boardEdge, 0.92));
    final double ox = mx + cs * 0.3;
    final double oy = my + cs * 0.3;
    for (int i = 0; i < lv.arrows.length; i++) {
      if (!m.game.alive[i]) continue;
      final Paint fp = Paint()..color = rgba(m.mono ? m.pal.inkSoft : th.colors[m.colors[i] % th.colors.length], 0.92);
      for (final List<int> q in lv.arrows[i].cells) {
        canvas.drawRect(Rect.fromLTWH(ox + q[0] * cs + 0.3, oy + q[1] * cs + 0.3, cs - 0.6, cs - 0.6), fp);
      }
    }
    // görünen alan
    final double b0x = (0 - m.vx) / m.vs, b0y = (0 - m.vy) / m.vs;
    final double b1x = (m.width - m.vx) / m.vs, b1y = (m.height - m.vy) / m.vs;
    final double rx = ox + (b0x - m.ox) / m.cell * cs;
    final double ry = oy + (b0y - m.oy) / m.cell * cs;
    final double rw = (b1x - b0x) / m.cell * cs;
    final double rh = (b1y - b0y) / m.cell * cs;
    canvas.save();
    canvas.clipRect(box);
    canvas.drawRect(
        Rect.fromLTWH(rx, ry, rw, rh), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = rgba(m.pal.accent));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}
