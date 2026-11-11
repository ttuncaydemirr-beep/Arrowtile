// Arrowtile — widgets.dart: ortak arayüz parçaları (style.css karşılıkları): düğme, hap, üst çubuk, sığan metin, pencere.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import 'tokens.dart';

AppLocalizations locOf(BuildContext c) => AppLocalizations.of(c);

// ---------------------------------------------------------------- metin sığdırma (docs/02 §4 "buton kuralı")
/// Önce satır kaydır (kelime arasından, en çok [maxLines]), sonra yazıyı 1 px adımlarla [minFont]'a dek küçült.
/// Kelime asla ortadan bölünmez; "…" ile kırpma yoktur. En küçük boyutta hâlâ sığmıyorsa metin yine de tam gösterilir.
class FitText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double minFont;
  final int maxLines;
  final TextAlign align;
  const FitText(this.text,
      {super.key, required this.style, this.minFont = 14, this.maxLines = 2, this.align = TextAlign.center});

  static bool _fits(BuildContext ctx, String text, TextStyle st, double maxW, int maxLines, TextDirection dir) {
    final TextScaler ts = MediaQuery.textScalerOf(ctx);
    final TextPainter tp = TextPainter(text: TextSpan(text: text, style: st), textDirection: dir, textScaler: ts)
      ..layout(maxWidth: maxW);
    final int lines = tp.computeLineMetrics().length;
    tp.dispose(); // yerel paragraf belleğini hemen bırak (her kurulumda ~20 deneme yapılabilir)
    if (lines > maxLines) return false;
    for (final String w in text.split(RegExp(r'\s+'))) {
      if (w.length < 2) continue;
      final TextPainter wp = TextPainter(text: TextSpan(text: w, style: st), textDirection: dir, textScaler: ts)
        ..layout();
      final double ww = wp.width;
      wp.dispose();
      if (ww > maxW + 0.5) return false; // tek kelime sığmıyor → küçült
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext ctx, BoxConstraints c) {
      final TextDirection dir = Directionality.of(ctx);
      double size = style.fontSize ?? 18;
      if (c.maxWidth.isFinite) {
        while (size > minFont && !_fits(ctx, text, style.copyWith(fontSize: size), c.maxWidth, maxLines, dir)) {
          size -= 1;
        }
      }
      return Text(text, style: style.copyWith(fontSize: size), textAlign: align, softWrap: true, overflow: TextOverflow.visible);
    });
  }
}

// ---------------------------------------------------------------- basılabilir yüzey
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, this.onTap});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    return Listener(
      onPointerDown: enabled ? (_) => setState(() => _down = true) : null,
      onPointerUp: (_) {
        if (_down && mounted) setState(() => _down = false);
      },
      onPointerCancel: (_) {
        if (_down && mounted) setState(() => _down = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: const Cubic(0.2, 0.8, 0.2, 1),
          child: Transform.translate(offset: Offset(0, _down ? 2 : 0), child: widget.child),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- düğme
enum BtnKind { primary, secondary, ghost, danger, equipped, tiny }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final bool big;
  final bool block;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String? sub; // ikinci satır küçük metin
  final Color? subColor;
  final bool alignStart;
  final double fontSize;
  final bool plainSound; // true: dokunuşta ses/titreşim yok
  const AppButton(
    this.label, {
    super.key,
    this.onTap,
    this.kind = BtnKind.secondary,
    this.big = false,
    this.block = true,
    this.icon,
    this.iconColor,
    this.leading,
    this.sub,
    this.subColor,
    this.alignStart = false,
    this.fontSize = 18,
    this.plainSound = false,
  });

  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    final AppController app = AppScope.read(context);
    final bool tiny = kind == BtnKind.tiny;
    Color bg, fg, shadow;
    switch (kind) {
      case BtnKind.primary:
        bg = pal.accentC;
        fg = pal.accentInkC;
        shadow = rgba(shadeRgb(pal.accent, -0.4));
      case BtnKind.danger:
        bg = pal.dangerC;
        fg = Colors.white;
        shadow = rgba(shadeRgb(pal.danger, -0.4));
      case BtnKind.equipped:
        bg = pal.successC;
        fg = Colors.white;
        shadow = rgba(shadeRgb(pal.success, -0.4));
      case BtnKind.ghost:
        bg = Colors.transparent;
        fg = pal.inkSoftC;
        shadow = Colors.transparent;
      case BtnKind.tiny:
        bg = pal.boardC;
        fg = pal.inkC;
        shadow = pal.edgeC;
      case BtnKind.secondary:
        bg = pal.boardC;
        fg = pal.inkC;
        shadow = pal.edgeC;
    }
    final double fs = big ? 22 : (tiny ? 14 : fontSize);
    final TextStyle ts = TextStyle(color: fg, fontSize: fs, fontWeight: FontWeight.w800, height: 1.15);
    final Widget textCol = sub == null
        ? FitText(label, style: ts, minFont: tiny ? 12 : 14, align: alignStart ? TextAlign.start : TextAlign.center)
        : Column(
            crossAxisAlignment: alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FitText(label, style: ts, minFont: 14, align: alignStart ? TextAlign.start : TextAlign.center),
              Text(sub!, style: TextStyle(color: subColor ?? pal.successC, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          );
    // block değilse genişlik sınırsızdır: Flexible kullanılamaz (Row'da sınırsız genişlikte esnek çocuk hata verir)
    final Widget content = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: alignStart ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: <Widget>[
        if (leading != null) ...<Widget>[leading!, const SizedBox(width: 10)],
        if (icon != null) ...<Widget>[Icon(icon, size: 24, color: iconColor ?? fg), const SizedBox(width: 10)],
        if (block) Flexible(child: textCol) else textCol,
      ],
    );
    final Widget body = Container(
      constraints: BoxConstraints(minHeight: big ? 64 : (tiny ? 36 : Shape.buttonMinHeight)),
      padding: EdgeInsets.symmetric(horizontal: tiny ? 12 : 18, vertical: tiny ? 4 : 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Shape.buttonRadius),
        boxShadow: kind == BtnKind.ghost
            ? null
            : <BoxShadow>[BoxShadow(color: shadow, offset: Offset(0, tiny ? 2 : 4))],
      ),
      alignment: alignStart ? AlignmentDirectional.centerStart : Alignment.center,
      child: content,
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Pressable(
          onTap: onTap == null
              ? null
              : () {
                  if (!plainSound) {
                    app.sfx.button();
                    app.buzz('button');
                  }
                  onTap!();
                },
          child: block ? SizedBox(width: double.infinity, child: body) : body,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- kare simge düğmesi (geri, duraklat …)
class IconSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  const IconSquareButton({super.key, required this.icon, required this.onTap, required this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    final AppController app = AppScope.read(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Pressable(
        onTap: () {
          app.sfx.button();
          onTap();
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: pal.boardC,
            borderRadius: BorderRadius.circular(14),
            boxShadow: <BoxShadow>[BoxShadow(color: pal.edgeC, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, size: 24, color: pal.inkC),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- hap (jeton, yıldız)
class Pill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  const Pill({super.key, required this.icon, required this.iconColor, required this.text});

  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: pal.boardC,
          borderRadius: BorderRadius.circular(999),
          boxShadow: <BoxShadow>[BoxShadow(color: pal.edgeC, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: pal.inkC, fontSize: 17, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class CoinPill extends StatelessWidget {
  const CoinPill({super.key});
  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final Palette pal = Palette.of(context);
    return Pill(icon: Icons.monetization_on, iconColor: pal.coinC, text: '${app.save.coins}');
  }
}

// ---------------------------------------------------------------- üst çubuk
class ScreenBar extends StatelessWidget {
  final String? title;
  final VoidCallback? onBack;
  final List<Widget> trailing;
  final Widget? titleWidget;
  const ScreenBar({super.key, this.title, this.onBack, this.trailing = const <Widget>[], this.titleWidget});

  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    final AppLocalizations loc = locOf(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: <Widget>[
          if (onBack != null) ...<Widget>[
            IconSquareButton(icon: Icons.arrow_back, onTap: onBack!, semanticLabel: loc.commonBack),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: titleWidget ??
                (title == null
                    ? const SizedBox.shrink()
                    : FitText(title!,
                        style: TextStyle(color: pal.inkC, fontSize: 22, fontWeight: FontWeight.w800),
                        minFont: 15,
                        align: TextAlign.start)),
          ),
          for (final Widget w in trailing) ...<Widget>[const SizedBox(width: 8), w],
        ]),
      ),
    );
  }
}

/// Ekran iskeleti: arka plan + güvenli alan + (en çok 480 px) ortalanmış içerik.
class ScreenScaffold extends StatelessWidget {
  final Widget child;
  const ScreenScaffold({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    // 1.1.6 (docs/23): hiçbir tam ekran sayfada metin girişi yok (TextField yalnızca showSheet iletişim penceresinde; Dialog klavyeyi kendi
    // payıyla karşılar). Scaffold'un varsayılanı resizeToAvoidBottomInset:true idi: viewInsets.bottom (klavye / reklam sonrası takılı IME payı)
    // gövdeyi küçültüyor, oyun arayüzü ekranın üst %55'ine sıkışıyordu. Kapalı + gövdede de alt pay silinir.
    final Brightness icons = pal.dark ? Brightness.light : Brightness.dark;
    // web'deki setSystemBarsDark karşılığı: durum/gezinme çubuğu simgeleri tema rengine göre
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: icons,
        systemNavigationBarIconBrightness: icons,
      ),
      child: Scaffold(
        backgroundColor: pal.bgC,
        resizeToAvoidBottomInset: false,
        body: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: SafeArea(
            child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: child)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- pencere (modal sheet)
Future<T?> showSheet<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: rgba(0x0A131C, 0.55),
    builder: (BuildContext ctx) {
      final Palette pal = Palette.of(ctx);
      return PopScope(
        canPop: dismissible,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                decoration: BoxDecoration(
                  color: pal.boardC,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: pal.edgeC, offset: const Offset(0, 8)),
                    const BoxShadow(color: Color(0x40000000), blurRadius: 40, offset: Offset(0, 20)),
                  ],
                ),
                child: SingleChildScrollView(child: builder(ctx)),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Pencere içi başlık / metin yardımcıları.
Widget sheetTitle(BuildContext c, String t) {
  final Palette pal = Palette.of(c);
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, textAlign: TextAlign.center, style: TextStyle(color: pal.inkC, fontSize: 24, fontWeight: FontWeight.w800)),
  );
}

Widget sheetText(BuildContext c, String t, {Color? color, FontWeight? weight}) {
  final Palette pal = Palette.of(c);
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
    child: Text(t, textAlign: TextAlign.center, style: TextStyle(color: color ?? pal.inkSoftC, fontSize: 17, fontWeight: weight)),
  );
}

/// Pencere içinde dikey düğme sütunu (.actions).
Widget actionsColumn(List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[if (i > 0) const SizedBox(height: 10), children[i]],
      ]),
    );

/// Yan yana eşit genişlikte düğmeler (.actions.row).
Widget actionsRow(List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[if (i > 0) const SizedBox(width: 10), Expanded(child: children[i])],
      ]),
    );

/// Onay penceresi (confirmBox).
Future<void> confirmBox(BuildContext context, String text, VoidCallback onYes, {String? yesLabel, bool danger = false}) {
  final AppLocalizations loc = locOf(context);
  return showSheet<void>(context, builder: (BuildContext ctx) {
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      sheetText(ctx, text),
      actionsRow(<Widget>[
        AppButton(loc.commonCancel, onTap: () => Navigator.of(ctx).pop()),
        AppButton(yesLabel ?? loc.commonYes,
            kind: danger ? BtnKind.danger : BtnKind.primary,
            onTap: () {
              Navigator.of(ctx).pop();
              onYes();
            }),
      ]),
    ]);
  });
}

// ---------------------------------------------------------------- yıldızlar
class StarsRow extends StatelessWidget {
  final int total;
  final int filled;
  final double size;
  const StarsRow({super.key, this.total = 3, required this.filled, this.size = 16});
  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        for (int i = 1; i <= total; i++) Icon(Icons.star, size: size, color: i <= filled ? pal.starC : pal.starEmptyC),
      ]),
    );
  }
}

/// Seviye sonu büyük yıldızlar: sırayla belirir (380 ms, 180 ms aralık; azaltılmış harekette sade solma).
class StarsBig extends StatefulWidget {
  final int stars;
  final bool reduced;
  const StarsBig({super.key, required this.stars, this.reduced = false});
  @override
  State<StarsBig> createState() => _StarsBigState();
}

class _StarsBigState extends State<StarsBig> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  // main.js zamanlaması: k. yıldız 200 + k·(starPop/2 + starStagger) ms'de başlar, 380 ms sürer
  static double _startMs(int k, bool reduced) => reduced ? 50.0 + k * 80 : 200.0 + k * (Anim.starPop * 0.5 + Anim.starStagger);

  @override
  void initState() {
    super.initState();
    final double total = _startMs(2, widget.reduced) + Anim.starPop;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: total.round()))..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // 0 → 1,15 → 1 (starpop)
  static double _pop(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return t < 0.6 ? 1.15 * (t / 0.6) : 1.15 - 0.15 * ((t - 0.6) / 0.4);
  }

  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    final double total = _startMs(2, widget.reduced) + Anim.starPop;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext ctx, Widget? _) {
          final double ms = _c.value * total;
          return Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: <Widget>[
            for (int k = 0; k < 3; k++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Transform.translate(
                  offset: Offset(0, k == 1 ? -10 : 0),
                  child: Builder(builder: (BuildContext _) {
                    final double t = ((ms - _startMs(k, widget.reduced)) / Anim.starPop).clamp(0.0, 1.0);
                    final double sc = widget.reduced ? 1 : _pop(t);
                    return Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: sc,
                        child: Icon(Icons.star, size: 64, color: k < widget.stars ? pal.starC : pal.starEmptyC),
                      ),
                    );
                  }),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

double clampD(double v, double lo, double hi) => math.max(lo, math.min(hi, v));
