// Arrowtile — tokens.dart: theme.js görsel token'ları (renkler, ok temaları, şekil oranları, animasyon süreleri).
// Renkler 0xRRGGBB int olarak tutulur (alfa ayrı); böylece Color API sürüm farklarından bağımsızdır.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 0xRRGGBB + alfa (0..1) → Color.
Color rgba(int rgb, [double alpha = 1]) {
  final int a = (alpha.clamp(0.0, 1.0) * 255).round();
  return Color((a << 24) | (rgb & 0xFFFFFF));
}

class Palette {
  final int bg, board, boardEdge, cell, cellDot, ink, inkSoft, accent, accentInk, star, starEmpty, coin, danger, success,
      highlight, highlightRing;
  final int shadow; // 0xRRGGBB
  final double shadowAlpha;
  final bool dark;
  const Palette({
    required this.bg,
    required this.board,
    required this.boardEdge,
    required this.cell,
    required this.cellDot,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.accentInk,
    required this.star,
    required this.starEmpty,
    required this.coin,
    required this.danger,
    required this.success,
    required this.highlight,
    required this.highlightRing,
    required this.shadow,
    required this.shadowAlpha,
    required this.dark,
  });

  static const Palette light = Palette(
    bg: 0xE3E9EE, // porselen gri-mavi zemin
    board: 0xF6F8FA, // tahta yüzü
    boardEdge: 0xC9D3DC, // tahta kenarı / alt kalınlık
    cell: 0xE6ECF1,
    cellDot: 0xC3CED8,
    ink: 0x1D2C3B, // lacivert mürekkep
    inkSoft: 0x5B6B7B,
    accent: 0x2456A6, // kobalt
    accentInk: 0xFFFFFF,
    star: 0xE8A317, // safran
    starEmpty: 0xC9D3DC,
    coin: 0xD99A1E,
    danger: 0xC9372F,
    success: 0x2E8B57,
    highlight: 0xFFFFFF,
    highlightRing: 0xE8A317,
    shadow: 0x1D2C3B,
    shadowAlpha: 0.18,
    dark: false,
  );

  static const Palette darkP = Palette(
    bg: 0x0F1B27,
    board: 0x172736,
    boardEdge: 0x0A131C,
    cell: 0x1E3245,
    cellDot: 0x2C4560,
    ink: 0xE9EFF4,
    inkSoft: 0x93A5B6,
    accent: 0x5B8DE0,
    accentInk: 0x0F1B27,
    star: 0xF2B632,
    starEmpty: 0x2C4560,
    coin: 0xF0B23A,
    danger: 0xEF5B52,
    success: 0x4DBB7F,
    highlight: 0xFFFFFF,
    highlightRing: 0xF2B632,
    shadow: 0x000000,
    shadowAlpha: 0.45,
    dark: true,
  );

  static Palette of(BuildContext context) {
    // MaterialApp'in ThemeData.brightness değeri uygulama kökündeki Brightness üzerinden okunur.
    final Brightness b = _brightnessOf(context);
    return b == Brightness.dark ? darkP : light;
  }

  static Brightness _brightnessOf(BuildContext context) {
    final _PaletteScope? s = context.dependOnInheritedWidgetOfExactType<_PaletteScope>();
    return s?.brightness ?? Brightness.light;
  }

  Color get bgC => rgba(bg);
  Color get boardC => rgba(board);
  Color get edgeC => rgba(boardEdge);
  Color get cellC => rgba(cell);
  Color get inkC => rgba(ink);
  Color get inkSoftC => rgba(inkSoft);
  Color get accentC => rgba(accent);
  Color get accentInkC => rgba(accentInk);
  Color get starC => rgba(star);
  Color get starEmptyC => rgba(starEmpty);
  Color get coinC => rgba(coin);
  Color get dangerC => rgba(danger);
  Color get successC => rgba(success);
  Color get shadowC => rgba(shadow, shadowAlpha);
}

/// Seçili (açık/koyu) parlaklığı alt ağaca taşır; MaterialApp builder içinde konur.
class PaletteScope extends StatelessWidget {
  final Brightness brightness;
  final Widget child;
  const PaletteScope({super.key, required this.brightness, required this.child});

  @override
  Widget build(BuildContext context) => _PaletteScope(brightness: brightness, child: child);
}

class _PaletteScope extends InheritedWidget {
  final Brightness brightness;
  const _PaletteScope({required this.brightness, required super.child});
  @override
  bool updateShouldNotify(_PaletteScope old) => old.brightness != brightness;
}

/// Açılabilir ok teması. Oklar renkleri sırayla (index % n) kullanır; chevron: gövde üstündeki yön işaretinin rengi.
class ArrowTheme {
  final String id;
  final int price;
  final List<int> colors;
  final int chevron; // 0xRRGGBB
  final double chevronAlpha;
  const ArrowTheme(this.id, this.price, this.colors, this.chevron, this.chevronAlpha);
}

const List<ArrowTheme> kArrowThemes = <ArrowTheme>[
  ArrowTheme('emaye', 0, <int>[0x2456A6, 0xC9372F, 0xE09A12, 0x2E8B57, 0x6B4C9A], 0xFFFFFF, 0.78),
  ArrowTheme('lokum', 300, <int>[0xE77FA0, 0xF2A65A, 0x7FB8A4, 0xA78BD4, 0xE7C65A], 0xFFFFFF, 0.85),
  ArrowTheme('cini', 500, <int>[0x1F5FA8, 0x1C8C8C, 0xC2362B, 0x2F7A3D, 0x14397A], 0xFFFFFF, 0.80),
  ArrowTheme('bakir', 750, <int>[0xB5652E, 0x8E4A24, 0xD08A45, 0x6E3B1F, 0xC9773A], 0xFFF0DC, 0.80),
  ArrowTheme('gece', 1000, <int>[0x38D1E0, 0xF25FA6, 0xB6F25F, 0xFFC83D, 0x9D7BFF], 0x0F1B27, 0.70),
];

ArrowTheme arrowThemeById(String id) {
  for (final ArrowTheme t in kArrowThemes) {
    if (t.id == id) return t;
  }
  return kArrowThemes[0];
}

/// Tüm oranlar hücre boyuna (cell) göredir (theme.js THEME.shape).
class Shape {
  Shape._();
  static const double margin = 0.12; // okun hücre kenarından içeride kalma payı
  static const double bodyWidth = 0.18; // gövde kalınlığı (v1.3: %18)
  static const double headWidth = 0.42; // ok başı genişliği (v1.3: %42; en az headMinPx)
  static const double headLength = 0.30;
  static const double headMinPx = 7;
  static const double chevronMinCell = 22; // hücre bundan küçükse şevron çizilmez
  static const double headRadius = 0.05;
  static const double tipRadius = 0.04;
  static const double depth = 0.045; // alt kalınlık gölgesi
  static const double chevronSize = 0.075;
  static const double chevronLine = 0.045;
  static const double dotRadius = 0.04;
  static const double gridDot = 0.045;
  static const double boardRadius = 0.30;
  static const double boardPad = 0.30;
  static const double buttonRadius = 14;
  static const double buttonMinHeight = 52;
}

/// Tepsi dolgusu (hücre oranı): geniş tahtada (≥ 21 sütun) 0,1, aksi halde 0,3.
double boardPadFor(int w) => w >= 21 ? 0.1 : Shape.boardPad;

/// Süreler ms (theme.js THEME.anim).
class Anim {
  Anim._();
  static const double slidePerCell = 55;
  static const double slideMin = 160;
  static const double exitFade = 120;
  static const double bumpForward = 90;
  static const double bumpBack = 220;
  static const double shake = 260;
  static const double shakeAmp = 0.08;
  static const double shakeCycles = 3;
  static const double starPop = 380;
  static const double starStagger = 180;
  static const double hintPulse = 900;
  static const double screenFade = 200;
}

/// CSS cubic-bezier(x1, y1, x2, y2) — main.js bezier() ile aynı Newton çözümü.
double Function(double) bezier(double x1, double y1, double x2, double y2) {
  double a(double p1, double p2) => 1 - 3 * p2 + 3 * p1;
  double b(double p1, double p2) => 3 * p2 - 6 * p1;
  double c(double p1) => 3 * p1;
  double calc(double t, double p1, double p2) => ((a(p1, p2) * t + b(p1, p2)) * t + c(p1)) * t;
  double slope(double t, double p1, double p2) => 3 * a(p1, p2) * t * t + 2 * b(p1, p2) * t + c(p1);
  return (double x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    double tt = x;
    for (int i = 0; i < 8; i++) {
      final double s = slope(tt, x1, x2);
      if (s.abs() < 1e-6) break;
      tt -= (calc(tt, x1, x2) - x) / s;
    }
    return calc(math.max(0.0, math.min(1.0, tt)), y1, y2);
  };
}

final double Function(double) easeSlide = bezier(0.45, 0, 0.85, 0.35);
final double Function(double) easeBack = bezier(0.34, 1.56, 0.64, 1);
double easeIn(double x) => x * x;

/// theme.js shade(): amt < 0 koyulaştırır, > 0 açar. Dönen: 0xRRGGBB.
int shadeRgb(int rgb, double amt) {
  final double t = amt < 0 ? 0 : 255;
  final double p = amt.abs();
  int ch(int v) => (v + (t - v) * p).round();
  return (ch((rgb >> 16) & 255) << 16) | (ch((rgb >> 8) & 255) << 8) | ch(rgb & 255);
}
