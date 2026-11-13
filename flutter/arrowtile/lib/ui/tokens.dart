// Arrowtile — tokens.dart: theme.js görsel token'ları (renkler, ok temaları, şekil oranları, animasyon süreleri).
// Renkler 0xRRGGBB int olarak tutulur (alfa ayrı); böylece Color API sürüm farklarından bağımsızdır.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 1.2.0 (docs/24 §7.4): uygulama yazı tipi ailesi (pubspec.yaml fonts). Sistem yazı tipleri yalnızca yedek.
const String kAppFont = 'ReadexPro';

/// 0xRRGGBB + alfa (0..1) → Color.
Color rgba(int rgb, [double alpha = 1]) {
  final int a = (alpha.clamp(0.0, 1.0) * 255).round();
  return Color((a << 24) | (rgb & 0xFFFFFF));
}

/// 1.2.2: temadan bağımsız sabitler (theme.js THEME.fixed, style.css :root ile aynı; tools/contrast.js denetler).
const Color kOnGold = Color(0xFF22252B); // altın/hardal dolgu (star, coin) üstündeki koyu yazı
const Color kExtreme = Color(0xFFB3263A); // "Aşırı zor" kademe noktası ve düğüm halkası
const Color kExtremeDeep = Color(0xFF7A1420); // "Aşırı zor" etiket dolgusu ve düğüm alt gölgesi
const int kScrim = 0x14171C; // modal perdesi (eski lacivert 0x0A131C yerine kömür)
const double kScrimAlpha = 0.55;

class Palette {
  final int bg, board, boardEdge, cell, cellDot, ink, inkSoft, accent, accentInk, onFill, star, starEmpty, coin, danger, success,
      highlight, highlightRing;
  /// 1.2.1 (docs/27 §B1): yıldız / jeton SİMGESİ renkleri (kart ve zemin üstünde ≥ 3:1). [star]/[coin] rozet dolgusu olarak kalır.
  final int starInk, coinInk;
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
    required this.onFill,
    required this.star,
    required this.starInk,
    required this.starEmpty,
    required this.coin,
    required this.coinInk,
    required this.danger,
    required this.success,
    required this.highlight,
    required this.highlightRing,
    required this.shadow,
    required this.shadowAlpha,
    required this.dark,
  });

  // 1.2.0 (docs/24 §7): araştırmaya dayalı palet "Kum ve Mürekkep" (sıcak nötr zemin, kahraman oklar; kırmızı yalnızca çarpma/can,
  // altın yalnızca ipucu/yıldız). theme.js colors ile aynı.
  static const Palette light = Palette(
    bg: 0xEFEAE2, // kum zemin
    board: 0xFBF9F5, // tahta yüzü ("kâğıt levha")
    boardEdge: 0xD8D0C3, // tahta kenarı / alt kalınlık
    cell: 0xEEE8DE,
    cellDot: 0xCFC6B8,
    ink: 0x22252B, // mürekkep (metin + tek renk oklar)
    inkSoft: 0x6A6760,
    accent: 0x1E7A78, // derin çam yeşili-turkuaz
    accentInk: 0xFFFFFF,
    onFill: 0xFFFFFF, // 1.2.2: success/accent/danger dolgusu üstündeki yazı (theme.js onFill)
    star: 0xE3A008,
    starInk: 0xAD7800,
    starEmpty: 0xD8D0C3,
    coin: 0xD4951A,
    coinInk: 0xA86F0C,
    danger: 0xD2453B,
    success: 0x267A4D, // 1.2.2: #2F8F5B → #267A4D (kontrast, theme.js ile aynı)
    highlight: 0xFFFFFF,
    highlightRing: 0xAD7800, // 1.2.1: tahtada ≥ 3:1 (eski 0xE3A008: 2,15)
    shadow: 0x22252B,
    shadowAlpha: 0.16,
    dark: false,
  );

  static const Palette darkP = Palette(
    bg: 0x14171C, // kömür
    board: 0x1E2229,
    boardEdge: 0x0C0E12,
    cell: 0x272C35,
    cellDot: 0x3A414D,
    ink: 0xF2EEE6,
    inkSoft: 0xA19D94,
    accent: 0x4DB6AC,
    accentInk: 0x14171C,
    onFill: 0x14171C, // koyu temada açık dolgu üstünde koyu yazı (≥ 4,5:1)
    star: 0xF2B632,
    starInk: 0xF2B632,
    starEmpty: 0x3A414D,
    coin: 0xF0B23A,
    coinInk: 0xF0B23A,
    danger: 0xF0685E,
    success: 0x55C08A,
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
  Color get onFillC => rgba(onFill);
  Color get starC => rgba(star);
  Color get starEmptyC => rgba(starEmpty);
  Color get starInkC => rgba(starInk);
  Color get coinInkC => rgba(coinInk);
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
  // 1.2.0 (docs/24 §7): varsayılan ok paleti — turkuaz, kiremit, hardal, çivit, erik (kırmızı/altın anlam renklerinden ayrık)
  // 1.2.1 (docs/27 §B1): hardal 0xD9A21B → 0xB8850E, çivit 0x4B5FC1 → 0x5468CC (tahtada ≥ 3:1, açık ve koyu)
  ArrowTheme('emaye', 0, <int>[0x1F8A8A, 0xE0703C, 0xB8850E, 0x5468CC, 0xA0508F], 0xFFFFFF, 0.78),
  ArrowTheme('lokum', 300, <int>[0xE2668E, 0xD97511, 0x579C84, 0xA081D0, 0xAE8B19], 0xFFFFFF, 0.85),
  ArrowTheme('cini', 500, <int>[0x246EC2, 0x1C8C8C, 0xC7382C, 0x2F7A3D, 0x5B8DE4], 0xFFFFFF, 0.80),
  ArrowTheme('bakir', 750, <int>[0xB5652E, 0xC76833, 0xB7722E, 0xA5592F, 0xC9773A], 0xFFF0DC, 0.80),
  ArrowTheme('gece', 1000, <int>[0x1B9EAB, 0xF155A0, 0x649F0D, 0xBB8600, 0x9B78FF], 0x0F1B27, 0.70),
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
  static const double bodyWidth = 0.15; // gövde kalınlığı (1.2.0: %18 → %15, daha ince oklar)
  static const double headWidth = 0.40; // ok başı genişliği (1.2.0: %42 → %40; en az headMinPx)
  static const double monoBody = 0.085; // 1.2.0 tek renk kipi: ince çizgi gövde (en az monoMinPx)
  static const double monoHead = 0.34; // tek renk kipi: küçük ok başı (en az 5 px)
  static const double monoMinPx = 1.6;
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
  static const double exitFade = 120; // (eski) 1.2.0'da kullanılmaz: ok tahta kenarında kırpılarak kaybolur
  // 1.2.0 (docs/24 §1.4): çıkış sabit hızla, okun kendi yolunu izleyerek tahta kenarına dek
  static const double exitPerCell = 26; // hücre başına ms
  static const double exitMin = 260;
  static const double exitMax = 1100;
  static const double tapGap = 110; // çıkış başladıktan sonra sıradaki dokunuşa kadar en kısa ara (sahip onayı)
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
