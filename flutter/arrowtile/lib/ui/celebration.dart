// Arrowtile — celebration.dart: 1.2.0 seviye sonu kutlaması (main.js celebrationOf/flameHTML + style.css .flame).
// Meşale/alev büyüklüğü performansa göre: reklamla devam → küçük; can kaybı → orta; kusursuz → büyük + kıvılcım;
// Aşırı zor + kusursuz → altın alev + havai fişek. Mesaj = kademe × performans matrisi (4 dil, ARB `cel*`), hız rozeti (`celFast`):
// ok başına ortalama ≤ 1,5 sn ve ≥ 8 ok; bekleme süresi sayılmaz; yavaşlık hiçbir yerde söylenmez.
// Animasyon SONLUDUR (≈ 3,6 sn, sonra durağan): widget testlerindeki pumpAndSettle takılmaz; azaltılmış harekette hiç oynamaz.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_lookup.dart';
import 'tokens.dart';

/// AYAR: hız rozeti eşiği (main.js FAST_MS_PER_ARROW / FAST_MIN_ARROWS).
const double kFastMsPerArrow = 1500;
const int kFastMinArrows = 8;

class Celebration {
  final String tier; // easy | medium | hard | extreme
  final String perf; // flawless | l1 | l2 | ad
  final String size; // s | m | l
  final bool sparks;
  final bool gold;
  final bool fast;
  final String msg;
  final String? fastMsg;
  const Celebration({
    required this.tier,
    required this.perf,
    required this.size,
    required this.sparks,
    required this.gold,
    required this.fast,
    required this.msg,
    this.fastMsg,
  });
}

/// main.js perfOf(): reklamla devam ettiyse 'ad', 2+ çarpma 'l2', 1 çarpma 'l1', yoksa 'flawless'.
String perfOf({required int revived, required int collisions}) =>
    revived > 0 ? 'ad' : (collisions >= 2 ? 'l2' : (collisions == 1 ? 'l1' : 'flawless'));

Celebration celebrationOf(AppLocalizations loc,
    {required String? tier, required int revived, required int collisions, required int arrows, required double playMs, math.Random? rnd}) {
  final math.Random r = rnd ?? math.Random();
  final String t = (tier == null || tier.isEmpty) ? 'easy' : tier;
  final String perf = perfOf(revived: revived, collisions: collisions);
  final String size = perf == 'ad' ? 's' : (perf == 'flawless' ? 'l' : 'm');
  final bool fast = perf != 'ad' && arrows >= kFastMinArrows && playMs > 0 && playMs / arrows <= kFastMsPerArrow;
  return Celebration(
    tier: t,
    perf: perf,
    size: size,
    sparks: perf == 'flawless',
    gold: perf == 'flawless' && t == 'extreme',
    fast: fast,
    msg: pickVariant(celVariants(loc, t, perf), r.nextDouble()),
    fastMsg: fast ? pickVariant(loc.celFast, r.nextDouble()) : null,
  );
}

/// Meşale + alev (+ kıvılcım, + havai fişek).
class TorchFlame extends StatefulWidget {
  final Celebration cel;
  final bool reduced;
  const TorchFlame({super.key, required this.cel, required this.reduced});
  @override
  State<TorchFlame> createState() => _TorchFlameState();
}

class _TorchFlameState extends State<TorchFlame> with SingleTickerProviderStateMixin {
  static const int _totalMs = 3600;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: _totalMs));

  @override
  void initState() {
    super.initState();
    if (!widget.reduced) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _px => widget.cel.size == 's' ? 52 : (widget.cel.size == 'm' ? 78 : 108);

  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    final double px = _px;
    return ExcludeSemantics(
      child: SizedBox(
        key: const ValueKey<String>('cel-flame'),
        width: px + 96,
        height: px + 26,
        child: AnimatedBuilder(
          animation: _c,
          builder: (BuildContext ctx, Widget? _) => CustomPaint(
            painter: _FlamePainter(
              cel: widget.cel,
              px: px,
              ms: widget.reduced ? -1 : _c.value * _totalMs,
              star: pal.star,
              danger: pal.danger,
              accent: pal.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  final Celebration cel;
  final double px;
  final double ms; // < 0: azaltılmış hareket (durağan)
  final int star, danger, accent;
  _FlamePainter({required this.cel, required this.px, required this.ms, required this.star, required this.danger, required this.accent});

  static Path _outer() => Path()
    ..moveTo(32, 3)
    ..cubicTo(39, 17, 55, 27, 55, 46)
    ..cubicTo(55, 60, 45, 70, 32, 70)
    ..cubicTo(19, 70, 9, 60, 9, 46)
    ..cubicTo(9, 34, 17, 29, 21, 17)
    ..cubicTo(26, 23, 26, 27, 30, 29)
    ..cubicTo(30, 19, 28, 12, 32, 3)
    ..close();
  static Path _inner() => Path()
    ..moveTo(32, 30)
    ..cubicTo(37, 38, 45, 43, 45, 53)
    ..cubicTo(45, 62, 39, 69, 32, 69)
    ..cubicTo(25, 69, 19, 62, 19, 53)
    ..cubicTo(19, 47, 23, 44, 25, 38)
    ..cubicTo(28, 42, 30, 43, 32, 30)
    ..close();
  static Path _core() => Path()
    ..moveTo(32, 49)
    ..cubicTo(35, 53, 39, 55, 39, 61)
    ..cubicTo(39, 66, 36, 69, 32, 69)
    ..cubicTo(28, 69, 25, 66, 25, 61)
    ..cubicTo(25, 56, 30, 54, 32, 49)
    ..close();
  static final Path _outerP = _outer(), _innerP = _inner(), _coreP = _core();

  // CSS flick: 900 ms ease-in-out, alternate. anahtar kareler (sx, sy, eğim°).
  List<double> _flick(double t) {
    final bool small = cel.size == 's';
    final List<List<double>> k = small
        ? <List<double>>[
            <double>[0.72, 0.69, -2],
            <double>[0.70, 0.75, 2],
          ]
        : <List<double>>[
            <double>[1, 0.96, -2],
            <double>[0.97, 1.04, 2],
            <double>[1.02, 0.98, -1],
          ];
    if (t < 0) return k[0];
    final int cyc = (t / 900).floor();
    double u = (t % 900) / 900;
    if (cyc.isOdd) u = 1 - u;
    u = u < 0.5 ? 2 * u * u : 1 - (-2 * u + 2) * (-2 * u + 2) / 2; // ease-in-out
    if (k.length == 2) return <double>[for (int i = 0; i < 3; i++) k[0][i] + (k[1][i] - k[0][i]) * u];
    final double v = u * 2;
    final List<double> a = v < 1 ? k[0] : k[1], b = v < 1 ? k[1] : k[2];
    final double f = v < 1 ? v : v - 1;
    return <double>[for (int i = 0; i < 3; i++) a[i] + (b[i] - a[i]) * f];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double s = px / 100; // viewBox 64x100 → px kutusuna "meet"
    final double boxL = (size.width - px) / 2, boxT = size.height - px;
    final double ox = boxL + (px - 64 * s) / 2;
    final bool gold = cel.gold;
    final Color out = Color(gold ? 0xFFE3A008 : 0xFFEF5B2F), inn = Color(gold ? 0xFFFFD24A : 0xFFF9A825), core = Color(gold ? 0xFFFFF7D6 : 0xFFFFE7A3);
    final Color cup = Color(gold ? 0xFFC9902A : 0xFF8A5A2B), handle = Color(gold ? 0xFF8A5A2B : 0xFF6E4521);
    canvas.save();
    canvas.translate(ox, boxT);
    canvas.scale(s, s);
    if (gold) {
      canvas.drawCircle(const Offset(32, 44), 30, Paint()
        ..color = const Color(0x66F2B632)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    }
    // meşale
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(24, 68, 16, 7), const Radius.circular(2.5)), Paint()..color = cup);
    canvas.drawPath(
        Path()
          ..moveTo(27.5, 75)
          ..lineTo(36.5, 75)
          ..lineTo(34.5, 97)
          ..lineTo(29.5, 97)
          ..close(),
        Paint()..color = handle);
    // alev (dönüşüm merkezi 32, 70)
    final List<double> f = _flick(ms);
    canvas.save();
    canvas.translate(32, 70);
    canvas.transform(Matrix4.skewX(f[2] * math.pi / 180).storage);
    canvas.scale(f[0], f[1]);
    canvas.translate(-32, -70);
    canvas.drawPath(_outerP, Paint()..color = out);
    canvas.drawPath(_innerP, Paint()..color = inn);
    canvas.drawPath(_coreP, Paint()..color = core);
    canvas.restore();
    canvas.restore();

    // kıvılcımlar (kutu koordinatında px): sol %50, üst %34
    if (cel.sparks) {
      const List<double> dxs = <double>[-34, 26, -14, 38, -40, 12, 30];
      final Offset o = Offset(boxL + px / 2, boxT + px * 0.34);
      final int spRgb = gold ? 0xFFE27A : 0xFFC83D;
      final Paint sp = Paint();
      for (int k = 0; k < dxs.length; k++) {
        double op, tx, ty, sc;
        if (ms < 0) {
          op = 0.9;
          tx = dxs[k];
          ty = -40;
          sc = 1;
        } else {
          final double t0 = ms - k * 170;
          if (t0 < 0) continue;
          final double q = (t0 % 1500) / 1500;
          final double e = 1 - (1 - q) * (1 - q); // ease-out
          op = q < 0.15 ? q / 0.15 : 1 - (q - 0.15) / 0.85;
          tx = dxs[k] * e;
          ty = -64 * e;
          sc = 0.6 + (0.2 - 0.6) * e;
        }
        sp.color = rgba(spRgb, op.clamp(0.0, 1.0));
        canvas.drawCircle(o + Offset(tx, ty), 2.5 * sc, sp);
      }
    }
    // havai fişek (yalnızca altın)
    if (gold) {
      final List<Offset> at = <Offset>[
        Offset(boxL - 46, boxT + 6),
        Offset(boxL + px + 46, boxT - 4),
        Offset(boxL + px / 2, boxT - 22),
      ];
      final List<int> cols = <int>[star, danger, accent];
      for (int b = 0; b < 3; b++) {
        final Paint p = Paint();
        for (int r = 0; r < 10; r++) {
          final double a = r * 36 * math.pi / 180;
          double op, dist, sc;
          if (ms < 0) {
            op = 0.9;
            dist = 30;
            sc = 1;
          } else {
            final double t0 = ms - b * 450;
            if (t0 < 0) continue;
            final double q = (t0 % 1700) / 1700;
            final double e = 1 - (1 - q) * (1 - q);
            op = q < 0.12 ? q / 0.12 : (q < 0.7 ? 1 : 1 - (q - 0.7) / 0.3);
            dist = 38 * e;
            sc = 0.4 + 0.5 * e;
          }
          p.color = rgba(cols[b], op.clamp(0.0, 1.0));
          // CSS rotate(a) translateY(-d): yukarı vektör a kadar döndürülür
          canvas.drawCircle(at[b] + Offset(math.sin(a) * dist, -math.cos(a) * dist), 2.5 * sc, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlamePainter old) => old.ms != ms || old.cel != cel || old.star != star;
}
