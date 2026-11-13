// Arrowtile — map_screen.dart: seviye haritası (index.html #scr-map, main.js renderers.map).
// Aşağıdan yukarıya ilerilir; en üstte son bölüm. 1.2.0 (docs/24): 250 bölüm × 20 seviye (5 Kolay → 5 Orta → 5 Zor → 5 Aşırı zor;
// sonrası oyuncuyla birlikte uzar). Her kademe diliminin başında küçük kademe etiketi; bölüm başlığı (bölümün sonu, en üstte) bonus durumunu
// gösterir.
// TEMBEL LİSTE: ListView.builder + sabit itemExtent → yalnızca görünen bölümler (± önbellek) oluşturulur, bölüm sayısı ne olursa olsun
// çizim maliyeti sabittir. Açılışta oyuncunun bölümüne kaydırılır. Zorluk seviye bazında döner: düğümün köşe noktası kademesini gösterir
// (Aşırı zor: koyu kırmızı halka). Altta banner (docs/15 §3).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ads_rules.dart' show AdScreen;
import '../../core/economy.dart' as eco;
import '../../core/levelgen.dart' show chapterOf, kChapters, kPerChapter, tierOf;
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_lookup.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../ad_banner.dart';
import '../flow.dart';
import '../tokens.dart';
import '../widgets.dart';

const double _step = 96, _padB = 48, _padT = 40; // yıldızlar için düğümler arası boşluk
const double _pathH = _padB + _padT + (kPerChapter - 1) * _step;
const double _headH = 76;
const double _chapterExtent = 12 + _headH + 6 + _pathH + 18;


Color _dotColor(Palette pal, String tier) {
  switch (tier) {
    case 'easy':
      return pal.successC;
    case 'medium':
      return pal.accentC;
    case 'hard':
      return pal.coinC;
    default:
      return kExtreme;
  }
}

/// Haritadaki bölüm sayısı: en az [kChapters] (250); 5.000 sonrası oyuncunun bölümü + bir sonraki (kilitli).
int mapChapterCount(int unlocked) => math.max(kChapters, (unlocked / kPerChapter).ceil() + 1);

Color tierColor(Palette pal, String tier) {
  switch (tier) {
    case 'easy':
      return pal.successC;
    case 'medium':
      return pal.accentC;
    case 'hard':
      return pal.coinC;
    default:
      return kExtremeDeep;
  }
}

class TierBadge extends StatelessWidget {
  final String tier;
  const TierBadge(this.tier, {super.key});
  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    final AppLocalizations loc = locOf(context);
    // 1.2.2: Kolay/Orta yazısı pal.onFill (koyu temada koyu), Zor #22252B, Aşırı zor beyaz
    final Color fg = tier == 'hard'
        ? kOnGold
        : (tier == 'easy' || tier == 'medium')
            ? pal.onFillC
            : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: tierColor(pal, tier), borderRadius: BorderRadius.circular(999)),
      child: Text(diffName(loc, tier),
          style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  ScrollController? _sc;

  @override
  void dispose() {
    _sc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    final bool rtl = app.isRtl;
    final int chapters = mapChapterCount(app.save.unlocked);
    final int total = eco.totalStars(app.save);
    final int max = chapters * kPerChapter * 3;
    final int curChapter = chapterOf(app.save.unlocked);
    final bool narrow = MediaQuery.sizeOf(context).width <= 400;

    return ScreenScaffold(
      child: Column(children: <Widget>[
        ScreenBar(
          title: loc.mapTitle,
          onBack: () => Navigator.of(context).maybePop(),
          trailing: <Widget>[
            Semantics(label: loc.mapStarsTotal(total, max), child: Pill(icon: Icons.star, iconColor: pal.starInkC, text: '$total/$max')),
            if (!narrow) const CoinPill(), // dar ekranda harita başlığı tek satırda kalsın: haritada jeton gerekmez
          ],
        ),
        Expanded(
          child: LayoutBuilder(builder: (BuildContext ctx, BoxConstraints bc) {
            // sıradaki seviyeye kaydır: dizin 0 = en üst (son bölüm)
            if (_sc == null) {
              final int idxFromTop = chapters - curChapter;
              final int k = (app.save.unlocked - 1) % kPerChapter;
              final double nodeY = idxFromTop * _chapterExtent + 12 + _headH + 6 + (_pathH - _padB - k * _step);
              final double off = math.max(0.0, nodeY - bc.maxHeight / 2);
              _sc = ScrollController(initialScrollOffset: off);
            }
            return ListView.builder(
              controller: _sc,
              itemExtent: _chapterExtent,
              itemCount: chapters,
              itemBuilder: (BuildContext c, int index) => _ChapterView(chapter: chapters - index, rtl: rtl),
            );
          }),
        ),
        // banner (docs/15 §3): yalnızca ana menü ve harita; reklamsızda / yüklenmediyse yer kaplamaz
        const AdBannerSlot(screen: AdScreen.map),
      ]),
    );
  }
}

class _ChapterView extends StatelessWidget {
  final int chapter;
  final bool rtl;
  const _ChapterView({required this.chapter, required this.rtl});

  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    final int first = (chapter - 1) * kPerChapter + 1;
    int cs = 0;
    for (int k = first; k < first + kPerChapter; k++) {
      cs += app.save.stars[k] ?? 0;
    }
    final bool bonusDone = app.save.chapterBonus.contains(chapter);
    final List<Offset> pts = <Offset>[];
    for (int i = 0; i < kPerChapter; i++) {
      double x = 50 + 30 * math.sin(i * math.pi / 3);
      if (rtl) x = 100 - x; // harita yönü aynalanır
      pts.add(Offset(x / 100, _pathH - _padB - i * _step));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 18),
      child: Column(children: <Widget>[
        Container(
          height: _headH,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: pal.boardC,
            borderRadius: BorderRadius.circular(14),
            boxShadow: <BoxShadow>[BoxShadow(color: pal.edgeC, offset: const Offset(0, 3))],
          ),
          child: Row(children: <Widget>[
            Expanded(
              child: FitText(chapterName(loc, chapter),
                  style: TextStyle(color: pal.inkC, fontSize: 20, fontWeight: FontWeight.w700), minFont: 14, align: TextAlign.start),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Icon(Icons.star, size: 18, color: pal.starInkC),
                    const SizedBox(width: 2),
                    Text('$cs/${kPerChapter * 3}', style: TextStyle(color: pal.inkSoftC, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
                FitText(bonusDone ? loc.endChapterDone : loc.mapChapterBonus(eco.chapterBonusFor(chapter)),
                    style: TextStyle(color: pal.inkSoftC, fontSize: 13, fontWeight: FontWeight.w600), minFont: 11, maxLines: 3, align: TextAlign.end),
              ]),
            ),
          ]),
        ),
        SizedBox(
          height: _pathH,
          child: LayoutBuilder(builder: (BuildContext ctx, BoxConstraints bc) {
            final double w = bc.maxWidth;
            return Stack(clipBehavior: Clip.none, children: <Widget>[
              Positioned.fill(child: CustomPaint(painter: _TrailPainter(pts, pal))),
              for (int i = 0; i < kPerChapter; i++)
                Positioned(
                  left: pts[i].dx * w - 32,
                  top: pts[i].dy - 32,
                  child: _LevelNode(id: first + i, tier: tierOf(first + i)),
                ),
              // 1.2.0: her kademe diliminin (5 seviye) başında küçük etiket (Kolay / Orta / Zor / Aşırı zor)
              for (int i = 0; i < kPerChapter; i += 5)
                Positioned(
                  left: (pts[i].dx + (pts[i].dx > 0.5 ? -0.30 : 0.30)) * w - 60,
                  width: 120,
                  top: pts[i].dy - 11,
                  child: IgnorePointer(child: Center(child: TierBadge(tierOf(first + i), key: ValueKey<String>('tier-label-${first + i}')))),
                ),
            ]);
          }),
        ),
      ]),
    );
  }
}

class _TierDot extends StatelessWidget {
  final String tier;
  final Color color, edge;
  const _TierDot({required this.tier, required this.color, required this.edge});
  @override
  Widget build(BuildContext context) {
    final Widget dot = Container(
      key: ValueKey<String>('tier-dot-$tier'),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: tier == 'easy' || tier == 'extreme' ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: tier == 'medium' ? BorderRadius.circular(4) : (tier == 'hard' ? BorderRadius.circular(2) : null),
        color: color,
        border: Border.all(color: edge, width: 2),
      ),
    );
    return tier == 'hard' ? Transform.rotate(angle: math.pi / 4, child: Transform.scale(scale: 0.86, child: dot)) : dot;
  }
}

class _TrailPainter extends CustomPainter {
  final List<Offset> pts; // x: 0..1 oran, y: piksel
  final Palette pal;
  _TrailPainter(this.pts, this.pal);

  @override
  void paint(Canvas canvas, Size size) {
    final Path p = Path();
    for (int i = 0; i < pts.length; i++) {
      final Offset o = Offset(pts[i].dx * size.width, pts[i].dy);
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
        p, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = pal.edgeC);
    // noktalı iç çizgi (stroke-dasharray 2 12, yuvarlak uç)
    final Paint dot = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = pal.boardC;
    for (final m in p.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        final double e = math.min(d + 2, m.length);
        canvas.drawPath(m.extractPath(d, e), dot);
        d += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) => old.pal != pal || old.pts != pts;
}

class _LevelNode extends StatelessWidget {
  final int id;
  final String tier;
  const _LevelNode({required this.id, required this.tier});

  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    final int stars = app.save.stars[id] ?? 0;
    final bool locked = id > app.save.unlocked;
    final bool current = id == app.save.unlocked;
    final bool done = !locked && stars > 0;
    final Color face = locked ? pal.cellC : (done ? pal.successC : pal.accentC);
    final Color edge = locked ? pal.edgeC : rgba(shadeRgb(done ? pal.success : pal.accent, -0.4));
    final Color fg = locked ? pal.inkSoftC : pal.accentInkC;
    return Semantics(
      button: true,
      label: '${loc.mapLevel(id)} · ${diffName(loc, tier)}${locked ? ' — ${loc.mapLocked}' : ''}',
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(clipBehavior: Clip.none, children: <Widget>[
          Positioned.fill(
            child: Pressable(
              onTap: () {
                if (locked) {
                  app.sfx.error();
                  app.toast(loc.mapLockedHint);
                  return;
                }
                app.sfx.button();
                unawaited(startLevel(context, id));
              },
              child: Container(
                decoration: BoxDecoration(
                  color: face,
                  shape: BoxShape.circle,
                  border: locked ? Border.all(color: pal.edgeC, width: 3) : null,
                  boxShadow: tier == 'extreme'
                      ? <BoxShadow>[
                          const BoxShadow(color: kExtreme, spreadRadius: 3), // 0 0 0 3px var(--extreme)
                          BoxShadow(color: locked ? pal.edgeC : kExtremeDeep, offset: const Offset(0, 4)),
                        ]
                      : <BoxShadow>[BoxShadow(color: edge, offset: const Offset(0, 4))],
                ),
                foregroundDecoration: current
                    ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: pal.starC, width: 4))
                    : null,
                alignment: Alignment.center,
                child: locked
                    ? Icon(Icons.lock, size: 22, color: fg)
                    : Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text('$id', style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w700)),
                      ),
              ),
            ),
          ),
          // kademe noktası (köşede, içeri yalıtımlı): Kolay yeşil, Orta mavi, Zor sarı, Aşırı zor koyu kırmızı.
          // 1.2.1 (docs/27 §B3): renk tek başına anlam taşımasın → şekil de farklı: Kolay daire, Orta yuvarlak kare, Zor baklava,
          // Aşırı zor daire + düğüm çevresinde kırmızı halka.
          PositionedDirectional(
            top: -2,
            end: -2,
            child: IgnorePointer(child: _TierDot(tier: tier, color: _dotColor(pal, tier), edge: pal.boardC)),
          ),
          if (!locked && stars > 0)
            Positioned(
              top: 68,
              left: 0,
              right: 0,
              child: Center(child: StarsRow(filled: stars, size: 16)),
            ),
        ]),
      ),
    );
  }
}
