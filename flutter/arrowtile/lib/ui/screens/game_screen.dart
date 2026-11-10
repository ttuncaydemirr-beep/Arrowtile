// Arrowtile — game_screen.dart: oyun ekranı (main.js "OYUN" bölümü): tahta, girdi, animasyon, öğretici, ipucu, bitiş pencereleri.
//
// Web ile aynı kurallar: isabet okun çizgisine (polyline) en yakın mesafe, eşik 0,5 hücre, belirsizlik 0,18; çıkış animasyonu
// sürerken yeni dokunuşlar yok sayılır (ok tahtayı terk edince kilit açılır); yakınlaştırma ≤ 5×; azaltılmış hareket
// (MediaQuery.disableAnimations) süreleri kısaltır, tahta sarsıntısını kapatır.
// Not: InteractiveViewer yerine ham işaretçi olayları (Listener) kullanılır; böylece web'deki pinch/pan/kenetleme
// kuralları ve isabet hesabı birebir korunur.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../config/ads_config.dart';
import '../../core/daily.dart' as dl;
import '../../core/diag.dart';
import '../../core/economy.dart' as eco;
import '../../core/engine.dart';
import '../../core/ads_rules.dart' show Unsubscribe, kLoadingOverlayDelay;
import '../../core/levelgen.dart' show chapterOf, isCurved, kDesigned;
import '../../core/models.dart';
import '../../core/save_data.dart' show kMaxLevel;
import '../../l10n/app_localizations.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../board_painter.dart';
import '../flow.dart';
import '../rewarded_flow.dart';
import '../tokens.dart';
import '../widgets.dart';
import 'daily_dialogs.dart';
import 'map_screen.dart' show TierBadge;

class _Repaint extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _Tut {
  final int id;
  int step = 0;
  _Tut(this.id);
}

class _Gest {
  String type; // tap | pan | pinch | none
  final double x0, y0, vx, vy, d0, s0, mx, my;
  _Gest(this.type, {this.x0 = 0, this.y0 = 0, this.vx = 0, this.vy = 0, this.d0 = 1, this.s0 = 1, this.mx = 0, this.my = 0});
}

const double _hitMax = 0.5; // hücre birimi — isabet eşiği
const double _ambig = 0.18; // iki ok neredeyse eşit yakınsa hiçbiri oynamaz
const double _zMax = 5; // yakınlaştırma üst sınırı

class GameScreen extends StatefulWidget {
  final Level level;
  const GameScreen({super.key, required this.level});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AppController app;
  late Level lv;
  late Game g;
  late BoardModel model;
  final _Repaint _repaint = _Repaint();
  late final Ticker _ticker;
  late final AnimationController _heartCtl;

  bool busy = false;
  int exitStreak = 0;
  double lockUntil = 0;
  int session = 0;
  bool winDone = false;
  double hintUntil = 0;
  double flashT0 = 0;
  _Tut? tut;
  bool curveTip = false;
  bool _reduced = false;
  bool _tipsDone = false;
  final Map<String, bool> tipShown = <String, bool>{};
  final Map<int, Offset> ptrs = <int, Offset>{};
  _Gest? gest;
  Size _lastSize = Size.zero;
  final List<Timer> _timers = <Timer>[];

  /// Tam ekran reklam gösteriliyor (docs/15 §4): animasyon döngüsü (ticker) ve ses duraklar, reklam kapanınca devam eder.
  bool _adPause = false;
  Unsubscribe? _unsubAd;

  // ---- analiz (docs/19): bu denemenin süresi ve kullanılan ipucu sayısı (yeniden başlatınca sıfırlanır)
  final Stopwatch _attemptClock = Stopwatch();
  int _hintsUsed = 0;

  /// Yeni bir deneme başladı: sayaçlar sıfırlanır ve level_start gönderilir (günlük bulmaca için level_start yok).
  void _beginAttempt() {
    _hintsUsed = 0;
    _attemptClock
      ..reset()
      ..start();
    diag('level', 'start', <String, Object?>{'lvl': lv.isDaily ? 'daily' : lv.id});
    if (!lv.isDaily) app.telemetry.levelStart(level: lv.id, tier: lv.diff, chapter: chapterOf(lv.id));
  }

  int get _attemptSeconds => _attemptClock.elapsed.inSeconds;

  bool get daily => lv.isDaily;
  String get levelKey => lv.daily ?? '${lv.id}';

  @override
  void initState() {
    super.initState();
    app = AppScope.read(context);
    app.gameEntered();
    app.mon.closeLevelEnd(); // 1.1.3: yeni seviye başladı: önceki seviye sonu yerleştirmesi geçersiz (seviye sırasında reklam yok)
    WidgetsBinding.instance.addObserver(this);
    _adPause = app.mon.isAdShowing;
    _unsubAd = app.mon.addAdListener(_onAdState);
    _ticker = createTicker(_onTick);
    _heartCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    lv = widget.level;
    if (app.revivedFor != levelKey) app.revivedFor = null;
    final bool tutorial = !lv.isDaily && lv.id <= 3 && !app.save.tutorialDone.contains(lv.id);
    g = Game(lv, noLifeLoss: tutorial && lv.id == 2, relaxed: app.save.relaxed);
    model = BoardModel(lv, g, arrowThemeById(app.save.theme), Palette.light, app.isRtl);
    tut = tutorial ? _Tut(lv.id) : null;
    if (!lv.isDaily) app.prefetchNext(lv.id);
    // v1.3: ilk kıvrımlı ok (seviye 4) tek cümlelik baloncukla tanıtılır; bir kez
    if (tut == null && !lv.isDaily && !app.hasTip('curve_tip') && lv.arrows.any(isCurved)) curveTip = true;
    _beginAttempt();
    if (AdsConfig.autoPlayOn && !lv.isDaily) _startAutoPlay();
    // oyun ekranı açılınca ödüllü reklam önceden yüklenir (docs/15 §4); hazırsa/yükleniyorsa yenisi başlatılmaz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) app.mon.preloadRewarded();
    });
  }

  // ---------------------------------------------------------------- otomatik oynatma (yalnızca debug; docs/18)
  Timer? _autoTimer;

  /// `AUTOPLAY_FROM` / test: seviyeyi kendiliğinden çözer; seviye sonunda "Sonraki"ne basılır ([_EndSheetState]).
  void _startAutoPlay() {
    app.markTip('aim_suggest'); // "önce seç" önerisi penceresi otomatik oyunu engellemesin
    debugPrint('AUTOPLAY: level ${lv.id} opened');
    _autoTimer = Timer.periodic(const Duration(milliseconds: 160), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_lastSize == Size.zero || _locked || _modalOpen || g.isWon || g.isDead) return;
      final int i = g.hint();
      if (i >= 0) _tapArrow(i);
    });
  }

  /// Test: animasyon döngüsü şu an çalışıyor mu / reklam bayrağı takılı mı.
  @visibleForTesting
  bool get debugTickerActive => _ticker.isActive;
  @visibleForTesting
  bool get debugAdPaused => _adPause;
  @visibleForTesting
  int get debugRemaining => g.remaining();

  /// Reklam açılınca ticker durur (ses AppController'da tutulur); kapanınca tahta yeniden çizilir ve döngü sürer.
  void _onAdState(bool active) {
    _adPause = active;
    _resetPointers();
    if (!mounted) return;
    if (active) {
      if (_ticker.isActive) _ticker.stop();
    } else {
      _repaint.ping();
      if (model.anims.isNotEmpty || model.shake != null || model.hintIdx >= 0 || model.flashIds.isNotEmpty) _kick();
    }
  }

  /// 1.1.4: seviye sonunda show() çağrıldı ve SDK sonucu bekleniyor: 0 yok, 1 "Reklam açılıyor…", 2 "reklam gecikiyor".
  final ValueNotifier<int> _adWait = ValueNotifier<int>(0);

  @override
  void dispose() {
    _autoTimer?.cancel();
    _adWait.dispose();
    _unsubAd?.call();
    _unsubAd = null;
    app.mon.closeLevelEnd(_levelEndToken == 0 ? null : _levelEndToken);
    WidgetsBinding.instance.removeObserver(this);
    for (final Timer t in _timers) {
      t.cancel();
    }
    _ticker.dispose();
    _heartCtl.dispose();
    _repaint.dispose();
    app.gameLeft();
    super.dispose();
  }

  /// Arka plana giderken duraklatma istendi (web: visibilitychange → document.hidden). Pencere ARKA PLANDA açılmaz:
  /// çerçeveler durdurulmuşken (hidden/paused) rota eklemek, yüzey yeniden oluşunca boş/yanıtsız pencereye yol açabiliyordu
  /// (docs/16). İstek bu bayrakta bekler, uygulama öne gelince (resumed) tek bir pencere açılır.
  bool _pausePending = false;

  /// Duraklatma penceresi şu an açık (aynı anda en fazla bir tane; her yolda sıfırlanır).
  bool _pauseOpen = false;

  /// Test için: bekleyen ya da açık duraklatma var mı.
  @visibleForTesting
  bool get pauseRequested => _pausePending || _pauseOpen;

  /// Seviye sonu yerleştirme belirteci (0: seviye sürüyor / seviye sonu kapalı). [Monetization.openLevelEnd].
  int _levelEndToken = 0;

  /// 1.1.3: bu ekran şu an "seviye SIRASINDA" mı (seviye sonu penceresi açık değil)?
  bool get _levelInProgress => _levelEndToken == 0 && !winDone;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    // 1.1.3 kalkan: seviye sürerken, bırakılmış bir reklamın penceresi açıksa ve uygulama arka plana düştüyse (inactive/hidden/paused)
    // bu büyük olasılıkla geç gelen tam ekran reklamdır → telemetri late_blocked, oyun (ticker + ses) duraklar, kayıp yok.
    if (state == AppLifecycleState.resumed) {
      app.mon.lateAdGone();
    } else if (_levelInProgress && app.mon.lateWindowOpen && state != AppLifecycleState.detached) {
      app.mon.lateAdSurfaced();
    }
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // açık pencere / meşgul durum yoksa duraklatma iste (web ile aynı koşul)
        if (!busy && !_modalOpen && !_pauseOpen) _pausePending = true;
      case AppLifecycleState.resumed:
        _onForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break; // inactive: bildirim çubuğu, reklam/izin penceresi vb. — duraklatma tetiklenmez
    }
  }

  /// Uygulama öne geldi: yüzey yeniden oluşmuş olabilir → tahtayı yeniden çiz, animasyon döngüsünü canlandır,
  /// bekleyen duraklatmayı (varsa) şimdi aç.
  void _onForeground() {
    _resetPointers();
    if (_adPause && !app.mon.isAdShowing) _adPause = false; // bayat "reklam gösteriliyor" bayrağı
    _repaint.ping();
    if (model.anims.isNotEmpty || model.shake != null || model.hintIdx >= 0 || model.flashIds.isNotEmpty) _kick();
    setState(() {});
    if (!_pausePending) return;
    _pausePending = false;
    if (!busy && !_modalOpen && !_pauseOpen) unawaited(_openPause());
  }

  bool get _modalOpen => ModalRoute.of(context)?.isCurrent != true;

  void _later(double ms, VoidCallback f) {
    final int my = session;
    late Timer t;
    t = Timer(Duration(milliseconds: ms.round()), () {
      _timers.remove(t);
      if (!mounted || my != session) return;
      f();
    });
    _timers.add(t);
  }

  void _laterAlways(double ms, VoidCallback f) {
    late Timer t;
    t = Timer(Duration(milliseconds: ms.round()), () {
      _timers.remove(t);
      if (!mounted) return;
      f();
    });
    _timers.add(t);
  }

  void _hud() {
    if (mounted) setState(() {});
  }

  void _kick() {
    // reklam gösteriliyor: döngü duraklar, reklam kapanınca _onAdState sürdürür. 1.1.1: bayrak takılı kalmış olabilir
    // (reklam bitti ama olay bu ekrana ulaşmadı) — gerçek durum Monetization'dan okunur; çıkış animasyonu bitişi
    // (kazanma) ticker'a bağlı olduğundan ticker asla bayat bir bayrakla kapalı kalmamalı.
    if (_adPause) {
      if (app.mon.isAdShowing) return;
      _adPause = false;
    }
    if (!_ticker.isActive) _ticker.start();
  }

  /// Basılı işaretçi kayıtlarını sıfırlar: arka plana gitme / reklam / pencere sırasında 'up' olayı kaçarsa bayat işaretçi kalır,
  /// sonraki tek parmak dokunuşu "iki parmak" (pinch) sanılıp yutulurdu (1.1.1, dokunma bulgusu).
  void _resetPointers() {
    ptrs.clear();
    gest = null;
  }

  bool get _locked => busy || model.nowMs < lockUntil;

  // ---------------------------------------------------------------- yerleşim / görünüm
  void _layout(double W, double H) {
    final double padF = boardPadFor(lv.w) * 2;
    final double c = math.min(math.min((W - 4) / (lv.w + padF), (H - 16) / (lv.h + padF + 0.1)), 72.0).floorToDouble();
    model.cell = c;
    model.width = W;
    model.height = H;
    model.ox = ((W - lv.w * c) / 2).roundToDouble();
    model.oy = ((H - lv.h * c) / 2).roundToDouble();
    _clampView();
  }

  List<double> _trayBox() {
    final double p = boardPadFor(lv.w) * model.cell;
    return <double>[model.ox - p, model.oy - p, model.ox + lv.w * model.cell + p, model.oy + lv.h * model.cell + p];
  }

  void _clampView() {
    model.vs = math.max(1.0, math.min(_zMax, model.vs));
    if (model.vs <= 1.001) {
      model.vs = 1;
      model.vx = 0;
      model.vy = 0;
      return;
    }
    final List<double> b = _trayBox();
    const double m = 12;
    for (int ax = 0; ax < 2; ax++) {
      final double lo = b[ax] * model.vs;
      final double hi = b[ax + 2] * model.vs;
      final double size = ax == 0 ? model.width : model.height;
      final double v = ax == 0 ? model.vx : model.vy;
      double nv;
      if (hi - lo + 2 * m <= size) {
        nv = (size - (lo + hi)) / 2;
      } else {
        nv = math.min(m - lo, math.max(size - m - hi, v));
      }
      if (ax == 0) {
        model.vx = nv;
      } else {
        model.vy = nv;
      }
    }
  }

  Offset _toBoard(double px, double py) => Offset((px - model.vx) / model.vs, (py - model.vy) / model.vs);

  void _fitView() {
    model.vs = 1;
    model.vx = 0;
    model.vy = 0;
    _hud();
    _repaint.ping();
  }

  void _afterViewChange() {
    _clampView();
    _repaint.ping();
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- animasyon döngüsü
  void _onTick(Duration _) {
    final double now = model.nowMs;
    bool active = false;
    for (final int k in model.anims.keys.toList()) {
      final BoardAnim? an = model.anims[k];
      if (an == null) continue;
      if (now - an.t0 >= an.dur) {
        model.anims.remove(k);
        an.done?.call();
      } else {
        active = true;
      }
    }
    final ShakeAnim? sh = model.shake;
    if (sh != null && now - sh.t0 >= sh.dur) model.shake = null;
    if (model.shake != null) active = true;
    if (model.hintIdx >= 0) {
      if (now > hintUntil || !g.alive[model.hintIdx]) {
        model.hintIdx = -1;
      } else {
        active = true;
      }
    }
    if (model.flashIds.isNotEmpty) {
      if (now - flashT0 > 320) {
        model.flashIds = <int>[];
      } else {
        active = true;
      }
    }
    _repaint.ping();
    if (!active) _ticker.stop();
  }

  double _offscreenCells(Arrow a) {
    // gövde başı izler; kuyruk önce (uzunluk−1) adımda başın yerine gelir, sonra baş doğrusundan çıkar
    final List<int> hd = headOf(a);
    final int extra = a.cells.length - 1;
    final double c = model.cell;
    final List<int> d = kDirs[a.dir]!;
    final double tx = model.ox + hd[0] * c;
    final double ty = model.oy + hd[1] * c;
    return extra + _offscreenFrom(tx, ty, c, d);
  }

  double _offscreenFrom(double tx, double ty, double c, List<int> d) {
    final double L = -model.vx / model.vs;
    final double R = (model.width - model.vx) / model.vs;
    final double Tp = -model.vy / model.vs;
    final double B = (model.height - model.vy) / model.vs;
    if (d[0] > 0) return (R - tx) / c + 0.2;
    if (d[0] < 0) return (tx + c - L) / c + 0.2;
    if (d[1] > 0) return (B - ty) / c + 0.3;
    return (ty + c - Tp) / c + 0.3;
  }

  double _boardLeaveCells(Arrow a) {
    final double pad = boardPadFor(lv.w);
    final List<int> hd = headOf(a);
    final int extra = a.cells.length - 1;
    if (a.dir == 'R') return extra + lv.w - hd[0] + pad;
    if (a.dir == 'L') return extra + hd[0] + 1 + pad;
    if (a.dir == 'D') return extra + lv.h - hd[1] + pad;
    return extra + hd[1] + 1 + pad;
  }

  // ---------------------------------------------------------------- girdi
  double _segDist(double u, double v, Arrow a) {
    final List<List<int>> cl = a.cells;
    double best = 1e9;
    for (int k = 0; k < cl.length; k++) {
      final double x1 = cl[k][0] + 0.5, y1 = cl[k][1] + 0.5;
      final List<int> b = k + 1 < cl.length ? cl[k + 1] : cl[k];
      final double x2 = b[0] + 0.5, y2 = b[1] + 0.5;
      final double dx = x2 - x1, dy = y2 - y1;
      final double L2 = dx * dx + dy * dy;
      final double q = L2 > 0 ? math.max(0.0, math.min(1.0, ((u - x1) * dx + (v - y1) * dy) / L2)) : 0;
      final double px = x1 + q * dx - u, py = y1 + q * dy - v;
      final double dd = math.sqrt(px * px + py * py);
      if (dd < best) best = dd;
      if (cl.length > 1 && k == cl.length - 2) break;
    }
    return best;
  }

  /// İsabet: {i} ya da belirsizse {amb}. i = -1 → isabet yok.
  (int, List<int>?) _hitTest(double px, double py) {
    final Offset b = _toBoard(px, py);
    final double u = (b.dx - model.ox) / model.cell, v = (b.dy - model.oy) / model.cell;
    int best = -1, second = -1;
    double bd = 1e9, sd = 1e9;
    for (int i = 0; i < lv.arrows.length; i++) {
      if (!g.alive[i]) continue;
      final double d = _segDist(u, v, lv.arrows[i]);
      if (d < bd) {
        second = best;
        sd = bd;
        best = i;
        bd = d;
      } else if (d < sd) {
        second = i;
        sd = d;
      }
    }
    if (best < 0 || bd > _hitMax) return (-1, null);
    if (second >= 0 && sd <= _hitMax && sd - bd < _ambig) return (-1, <int>[best, second]);
    return (best, null);
  }

  void _onBoardTap(double px, double py) {
    if (_locked || _modalOpen) return;
    final AppLocalizations loc = AppLocalizations.of(context);
    final (int hit, List<int>? amb) = _hitTest(px, py);
    if (amb != null) {
      app.buzz('error');
      model.flashIds = amb;
      flashT0 = model.nowMs;
      _kick();
      if (tipShown['amb'] != true) {
        tipShown['amb'] = true;
        app.toast(loc.gameAmbiguous);
      }
      return;
    }
    if (hit < 0) {
      if (model.aimSel >= 0) {
        model.aimSel = -1;
        _repaint.ping();
      }
      return;
    }
    if (app.save.aim && model.aimSel != hit) {
      // G1: önce seç
      model.aimSel = hit;
      app.sfx.tap();
      app.buzz('tap');
      _repaint.ping();
      if (tipShown['aim'] != true) {
        tipShown['aim'] = true;
        app.toast(loc.gameTapAgain);
      }
      return;
    }
    _tapArrow(hit);
  }

  void _down(PointerDownEvent e) {
    ptrs[e.pointer] = e.localPosition;
    if (ptrs.length == 1) {
      gest = _Gest('tap', x0: e.localPosition.dx, y0: e.localPosition.dy, vx: model.vx, vy: model.vy);
    } else if (ptrs.length == 2) {
      final List<Offset> l = ptrs.values.toList();
      final double d = (l[0] - l[1]).distance;
      gest = _Gest('pinch',
          d0: d == 0 ? 1 : d, s0: model.vs, mx: (l[0].dx + l[1].dx) / 2, my: (l[0].dy + l[1].dy) / 2, vx: model.vx, vy: model.vy);
    } else {
      gest = _Gest('none');
    }
  }

  void _move(PointerMoveEvent e) {
    final _Gest? gs = gest;
    if (!ptrs.containsKey(e.pointer) || gs == null) return;
    ptrs[e.pointer] = e.localPosition;
    if (gs.type == 'pinch') {
      if (ptrs.length < 2) return;
      final List<Offset> l = ptrs.values.toList();
      final double d = (l[0] - l[1]).distance;
      final double mx = (l[0].dx + l[1].dx) / 2, my = (l[0].dy + l[1].dy) / 2;
      final double bx = (gs.mx - gs.vx) / gs.s0, by = (gs.my - gs.vy) / gs.s0;
      model.vs = math.max(1.0, math.min(_zMax, gs.s0 * d / gs.d0));
      model.vx = mx - bx * model.vs;
      model.vy = my - by * model.vs;
      _afterViewChange();
    } else if (gs.type == 'tap' || gs.type == 'pan') {
      final double dx = e.localPosition.dx - gs.x0, dy = e.localPosition.dy - gs.y0;
      if (gs.type == 'tap' && math.sqrt(dx * dx + dy * dy) > 10) gs.type = model.vs > 1.01 ? 'pan' : 'none';
      if (gs.type == 'pan') {
        model.vx = gs.vx + dx;
        model.vy = gs.vy + dy;
        _afterViewChange();
      }
    }
  }

  void _end(PointerEvent e, bool cancel) {
    if (!ptrs.containsKey(e.pointer)) return;
    ptrs.remove(e.pointer);
    final _Gest? gs = gest;
    if (!cancel && gs != null && gs.type == 'tap' && ptrs.isEmpty) _onBoardTap(gs.x0, gs.y0);
    if (ptrs.isEmpty) {
      gest = null;
    } else if (gs != null && gs.type == 'pinch') {
      gest = _Gest('none');
    }
  }

  // ---------------------------------------------------------------- dokunma → ok
  TapResult? _tapArrow(int i) {
    if (_locked || _modalOpen || !mounted) return null;
    final AppLocalizations loc = AppLocalizations.of(context);
    final TapResult? r = g.tap(i);
    if (r == null) return null;
    model.aimSel = -1;
    // v1.1 (docs/15 §1): ok hareketi başına YALNIZCA tek ses (çıkışta slideOut, çarpmada bump) — ayrıca "tık" (tap) çalmaz.
    // "tap" yalnızca "önce seç" kipinde ok seçilirken çalar (_onBoardTap; hareket yok).
    // 1.1.5 (docs/22): ok hareketi başına TEK kısa titreşim (çıkışta slideOut, çarpmada bump). Eskiden önce buzz('tap') sonra slideOut/bump
    // çalıyordu; telefon yüzeyde dururken iki titreşim, ok sesinden önce fazladan "tık" gibi duyuluyordu.
    model.hintIdx = -1;
    final Arrow a = lv.arrows[i];
    final double now = model.nowMs;
    final double per = _reduced ? 30 : Anim.slidePerCell;
    if (r.isExit) {
      final double dist = _offscreenCells(a);
      double dur = math.max(Anim.slideMin, dist * per);
      if (_reduced) dur = math.max(120.0, dist * per);
      model.anims[i] = BoardAnim(kind: 'exit', t0: now, dur: dur, dist: dist, done: () {
        if (g.isWon) _onWin();
      });
      // easeSlide(q)·dist = tahtadan çıkış mesafesi olan q'yu ikiye bölerek bul
      final double need = math.min(dist, _boardLeaveCells(a));
      double lo = 0, hi = 1;
      for (int it = 0; it < 18; it++) {
        final double mid = (lo + hi) / 2;
        if (easeSlide(mid) * dist < need) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      lockUntil = now + hi * dur;
      app.sfx.slideOut(math.min(1.0, exitStreak / 6));
      exitStreak++;
      app.buzz('slideOut');
      if (!daily && g.remaining() <= 2) app.mon.preloadInterstitial(lv.id); // geçiş reklamı seviye bitmeden hazır olsun (docs/15 §4)
      busy = g.isWon; // son ok: kazanma ekranına kadar girdi kapalı
    } else {
      exitStreak = 0;
      if (r.lifeLost && g.lives <= 1) app.mon.preloadRewarded(); // can 1'e düştü: "+1 can" reklamı önceden yüklensin (docs/15 §4)
      final double fwd = _reduced ? 60 : Anim.bumpForward;
      final double back = _reduced ? 120 : Anim.bumpBack;
      busy = true;
      model.anims[i] = BoardAnim(kind: 'bump', t0: now, dur: fwd + back, fwd: fwd, dist: r.free + 0.2, done: () {
        busy = false;
        if (r.dead) _onDead();
      });
      _later(fwd, () {
        app.sfx.bump();
        app.buzz('bump');
        if (!_reduced) {
          final List<int> d = kDirs[a.dir]!;
          model.shake = ShakeAnim(model.nowMs, Anim.shake, d[0].toDouble(), d[1].toDouble());
        }
        if (r.lifeLost) {
          app.toast(loc.gameCrash);
          _heartCtl.forward(from: 0);
        }
        _hud();
        _kick();
      });
    }
    _hud();
    _onTutorialTap(r);
    _kick();
    return r;
  }

  // ---------------------------------------------------------------- kazanma / kaybetme
  void _onWin() {
    if (winDone) return;
    winDone = true;
    diag('level', 'end', <String, Object?>{'lvl': lv.isDaily ? 'daily' : lv.id});
    busy = true;
    final int my = session;
    final int stars = g.stars();
    final int id = lv.id;
    if (daily) {
      app.telemetry.dailyPuzzleComplete(stars: stars, mistakes: g.collisions, durationS: _attemptSeconds);
      final r = app.finishDaily(lv.daily!, stars);
      _hideTutorial();
      tut = null;
      app.sfx.levelWin();
      app.buzz('levelWin');
      _laterAlways(_reduced ? 50 : 250, () {
        if (my == session) _showDailyEnd(stars, r.first);
      });
      return;
    }
    app.telemetry.levelComplete(
        level: id,
        tier: lv.diff,
        stars: stars,
        mistakes: g.collisions,
        hintsUsed: _hintsUsed,
        durationS: _attemptSeconds);
    final eco.CompleteResult res = app.finishLevel(id, stars, g.relaxed);
    _hideTutorial();
    tut = null;
    app.sfx.levelWin();
    app.buzz('levelWin');
    _laterAlways(_reduced ? 50 : 250, () {
      if (my == session) _showEnd(stars, res);
    });
  }

  Future<void> _showEnd(int stars, eco.CompleteResult res) async {
    final int id = lv.id;
    final int collisions = g.collisions;
    final bool relaxed = g.relaxed;
    final int my = session;
    final int token = app.mon.openLevelEnd(id); // 1.1.3: geçiş reklamı yalnızca bu yerleştirme etkinken
    _levelEndToken = token;
    // yıldız sesleri: k. yıldız 200 + k·(190 + 180) ms'de; jeton sesi bunlardan sonra
    for (int k = 0; k < stars; k++) {
      _laterAlways(_reduced ? 50.0 + k * 80 : 200.0 + k * (Anim.starPop * 0.5 + Anim.starStagger), () {
        if (my == session) app.sfx.star(k);
      });
    }
    if (res.coins > 0) {
      _laterAlways(200.0 + 3 * (Anim.starPop * 0.5 + Anim.starStagger), () {
        if (my == session) app.sfx.coin();
      });
    }
    await showSheet<void>(context, dismissible: false, builder: (BuildContext ctx) {
      return _EndSheet(
        stars: stars,
        res: res,
        collisions: collisions,
        relaxed: relaxed,
        reduced: _reduced,
        levelId: id,
        allDone: id == kDesigned, // 5.000 seviye bitti: sonsuz bölümler başlıyor
        adWait: _adWait,
        onNext: () async {
          await _adThenContinue(id, token);
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (mounted) unawaited(startLevel(context, id + 1, replace: true));
        },
        onReplay: () async {
          await _adThenContinue(id, token);
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (mounted) unawaited(startLevel(context, id, replace: true));
        },
        onMap: () async {
          await _adThenContinue(id, token);
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (mounted) goToMap(context);
        },
      );
    });
  }

  /// Seviye sonu "devam" adımında geçiş reklamı denemesi. HİÇBİR yolda istisna fırlatmaz.
  /// 1.1.4 (docs/21): reklam yüklü değilse anında döner. Yüklüyse show() çağrılır ve SDK "kapandı/gösterilemedi" bildirene ya da
  /// uygulama reklamdan dönene dek BEKLENİR — sonraki seviye bu bekleme bitmeden başlamaz (seviye ortasında reklam olamaz).
  /// Bekleme 300 ms'yi aşarsa pencerede "Reklam açılıyor…", 20 sn'yi aşarsa "reklam gecikiyor" ipucu görünür. Üst süre sınırı YOKTUR.
  Future<void> _adThenContinue(int id, int token) async {
    final Timer t = Timer(kLoadingOverlayDelay, () {
      if (mounted && app.mon.adHoldActive && _adWait.value == 0) _adWait.value = 1;
    });
    try {
      await app.mon.continueAfterLevel(id, placement: token, onSlow: () {
        if (mounted) _adWait.value = 2;
      });
    } catch (_) {
      // yut: oyun devam eder
    } finally {
      t.cancel();
      if (mounted) _adWait.value = 0;
      app.mon.closeLevelEnd(token); // yerleştirme biter: bundan sonra hiçbir yol show() çağıramaz
    }
  }

  Future<void> _showDailyEnd(int stars, bool first) async {
    final AppLocalizations loc = AppLocalizations.of(context);
    final dl.StreakInfo info = dl.streakInfo(app.save.dp, lv.daily!);
    await showSheet<void>(context, dismissible: false, builder: (BuildContext ctx) {
      final Palette pal = Palette.of(ctx);
      return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        sheetTitle(ctx, loc.dpDone),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Icon(Icons.emoji_events, size: 72, color: pal.starC)),
        if (first)
          Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: pal.starC, borderRadius: BorderRadius.circular(999)),
              child: Text(loc.dpTrophyWon, style: const TextStyle(color: Color(0xFF1D2C3B), fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
        DpStats(info),
        sheetText(ctx, loc.dpComeBack),
        actionsRow(<Widget>[
          AppButton(loc.commonBack, onTap: () {
            Navigator.of(ctx).pop();
            if (mounted) goToMenu(context);
          }),
          AppButton(loc.dpTitle, kind: BtnKind.primary, onTap: () {
            Navigator.of(ctx).pop();
            if (mounted) {
              goToMenu(context);
              // oyun ekranı kapandı: takvimi gezgin katmanının bağlamından aç
              final BuildContext? root = app.navKey.currentState?.overlay?.context;
              if (root != null && root.mounted) unawaited(openCalendar(root));
            }
          }),
        ]),
      ]);
    });
  }

  Future<void> _onDead() async {
    busy = true;
    if (!daily) app.telemetry.levelFail(level: lv.id, tier: lv.diff);
    app.sfx.error();
    app.buzz('error');
    final int my = session;
    if (!mounted) return;
    final AppLocalizations loc = AppLocalizations.of(context);
    await showSheet<void>(context, dismissible: false, builder: (BuildContext ctx) {
      final bool canRevive = app.mon.rewardedOffered() && app.revivedFor != levelKey; // ödüllü +1 can: seviye başına en fazla 1 kez
      return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        sheetTitle(ctx, loc.gameOutOfLivesTitle),
        sheetText(ctx, loc.gameOutOfLivesText),
        actionsColumn(<Widget>[
          AppButton(loc.gameRetry, kind: BtnKind.primary, onTap: () {
            Navigator.of(ctx).pop();
            _restartLevel();
          }),
          if (canRevive)
            AppButton('${loc.adsWatchLife} · ${loc.adsOptional}', onTap: () async {
              final bool rewarded = await playRewarded(context, 'life', onReward: () {
                if (my == session && g.revive()) app.revivedFor = levelKey;
              });
              if (my != session || !mounted) return;
              if (rewarded && !g.isDead) {
                if (ctx.mounted) Navigator.of(ctx).pop();
                busy = false;
                _hud();
                app.toast(loc.adsRewardLife);
                _kick();
              } else if (rewarded) {
                app.toast(loc.adsNoReward);
              }
            }),
          AppButton(daily ? loc.commonBack : loc.gameToMap, onTap: () {
            Navigator.of(ctx).pop();
            if (mounted) daily ? goToMenu(context) : goToMap(context);
          }),
        ]),
      ]);
    });
  }

  void _restartLevel() {
    g.reset();
    model.anims.clear();
    model.shake = null;
    model.hintIdx = -1;
    busy = false;
    lockUntil = 0;
    exitStreak = 0;
    session++;
    winDone = false;
    _levelEndToken = 0;
    model.aimSel = -1;
    _beginAttempt();
    _hud();
    _repaint.ping();
  }

  // ---------------------------------------------------------------- araç çubuğu
  Future<void> _openPause() async {
    if (busy || !mounted || _modalOpen || _pauseOpen) return;
    _pausePending = false;
    _pauseOpen = true;
    final AppLocalizations loc = AppLocalizations.of(context);
    try {
      await showSheet<void>(context, builder: (BuildContext ctx) {
        return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          sheetTitle(ctx, loc.gamePaused),
          actionsColumn(<Widget>[
            AppButton(loc.gameResume, kind: BtnKind.primary, onTap: () => Navigator.of(ctx).pop()),
            AppButton(loc.gameRestart, onTap: () {
              Navigator.of(ctx).pop();
              _restartLevel();
            }),
            AppButton(daily ? loc.commonBack : loc.gameToMap, onTap: () {
              Navigator.of(ctx).pop();
              if (mounted) daily ? goToMenu(context) : goToMap(context);
            }),
          ]),
        ]);
      });
    } finally {
      _pauseOpen = false;
    }
  }

  void _useHint() {
    if (busy || g.isWon || _modalOpen) return;
    final AppLocalizations loc = AppLocalizations.of(context);
    final int i = g.hint();
    if (i < 0) return;
    if (app.save.freeHints <= 0 && app.save.coins < eco.kHintPrice) {
      // ücretsiz hak da jeton da yok: "Jetonun yetmiyor" (reklam izle +50 jeton / Mağaza / Kapat)
      app.sfx.error();
      app.buzz('error');
      unawaited(openLowCoinsSheet(context, onCoins: _hud));
      return;
    }
    if (!eco.spendHint(app.save)) {
      app.sfx.error();
      app.buzz('error');
      app.toast(loc.gameNotEnoughCoins);
      return;
    }
    app.persist();
    _hintsUsed++;
    if (!daily) app.telemetry.hintUsed(level: lv.id);
    app.sfx.hint();
    app.buzz('button');
    model.hintIdx = i;
    hintUntil = model.nowMs + 2000;
    app.commit();
    _kick();
    final _Tut? t = tut;
    if (t != null && t.id == 3) {
      t.step = 1;
    }
    _hud();
  }

  // ---------------------------------------------------------------- öğretici
  void _hideTutorial() {
    curveTip = false;
    if (mounted) setState(() {});
  }

  int _tutorialTarget() {
    final _Tut? t = tut;
    if (t == null) return -1;
    if (t.id == 1) return g.hint();
    if (t.id == 2) {
      if (t.step == 0) {
        for (int i = 0; i < lv.arrows.length; i++) {
          if (g.alive[i] && !g.canExit(i)) return i;
        }
      }
      return g.hint();
    }
    return -1;
  }

  void _onTutorialTap(TapResult r) {
    if (curveTip) _closeCurveTip(); // ilk hamlede baloncuk kapanır (görüldü sayılır)
    final _Tut? t = tut;
    if (t == null) return;
    if (t.id == 2 && t.step == 0 && r.isBump) {
      t.step = 1;
      _laterAlways(350, () {
        if (tut != null) {
          model.hintIdx = g.hint();
          hintUntil = model.nowMs + 2000;
          _kick();
        }
        _hud();
      });
      return;
    }
    if (t.id == 3 && r.isExit) t.step = 1;
    _laterAlways(30, _hud);
  }

  void _closeCurveTip() {
    if (curveTip) {
      curveTip = false;
      app.markTip('curve_tip');
      _hud();
    }
  }

  void _skipTutorial() {
    app.sfx.button();
    if (curveTip) {
      _closeCurveTip();
      return;
    }
    final _Tut? t = tut;
    if (t != null) {
      if (!app.save.tutorialDone.contains(t.id)) {
        app.save.tutorialDone.add(t.id);
        app.persist();
      }
      g.noLifeLoss = false;
    }
    tut = null;
    _hud();
  }

  String? _bubbleText(AppLocalizations loc) {
    if (curveTip) return loc.tutCurve;
    final _Tut? t = tut;
    if (t == null) return null;
    if (t.id == 1) return loc.tutTap;
    if (t.id == 2) return t.step == 0 ? loc.tutCrash : loc.tutOrder;
    return t.step == 0 ? loc.tutHint : loc.tutOrder;
  }

  // ---------------------------------------------------------------- bir kez gösterilen ipuçları
  void _oneTimeTips() {
    if (_tipsDone || !mounted) return;
    _tipsDone = true;
    final AppLocalizations loc = AppLocalizations.of(context);
    // v1.2/v1.3: sığdırılmış hücre 26 px'ten küçükse ilk büyük seviyede bir kez "önce seç, sonra fırlat" önerisi
    if (model.cell < 26 && !app.save.aim && !app.hasTip('aim_suggest')) {
      app.markTip('aim_suggest');
      confirmBox(context, loc.gameAimSuggest, () => app.setAim(true), yesLabel: loc.commonYes);
      return;
    }
    // G2: büyük tahtada bir kez yakınlaştırma ipucu
    if (model.cell < 36 && !app.hasTip('zoom_tip') && tut == null) {
      app.markTip('zoom_tip');
      app.toast(loc.gameZoomTip);
    }
  }

  // ---------------------------------------------------------------- arayüz
  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    AppScope.of(context); // dil / tema / jeton değişince yeniden kur
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    model.pal = pal;
    model.rtl = app.isRtl;
    final ArrowTheme th = arrowThemeById(app.save.theme);
    if (!identical(th, model.theme)) {
      model.theme = th;
      model.recolor();
    }
    final String? bubble = _bubbleText(loc);
    final int target = _tutorialTarget();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (!busy) unawaited(_openPause());
      },
      child: ScreenScaffold(
        child: Column(children: <Widget>[
          _topBar(loc, pal),
          Expanded(
            child: LayoutBuilder(builder: (BuildContext ctx, BoxConstraints bc) {
              final Size sz = Size(bc.maxWidth, bc.maxHeight);
              if (sz != _lastSize) {
                _lastSize = sz;
                _layout(sz.width, sz.height);
                WidgetsBinding.instance.addPostFrameCallback((_) => _oneTimeTips());
              }
              return Stack(children: <Widget>[
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _down,
                    onPointerMove: _move,
                    onPointerUp: (PointerUpEvent e) => _end(e, false),
                    onPointerCancel: (PointerCancelEvent e) => _end(e, true),
                    child: CustomPaint(painter: BoardPainter(model, _repaint), size: Size.infinite),
                  ),
                ),
                if (lv.diff != null)
                  Positioned(top: 10, left: 0, right: 0, child: IgnorePointer(child: Center(child: TierBadge(lv.diff!)))),
                if (model.vs > 1.01)
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: AppButton(loc.gameFit, icon: Icons.fit_screen, block: false, fontSize: 16, onTap: _fitView),
                  ),
                if (tut != null && target >= 0) _hand(target),
                if (bubble != null) _bubble(bubble, loc, pal),
              ]);
            }),
          ),
          _toolbar(loc, pal),
        ]),
      ),
    );
  }

  Widget _hand(int target) {
    final List<List<int>> cl = lv.arrows[target].cells;
    final double c = model.cell;
    final List<int> t0 = cl[0], hd = cl[cl.length - 1];
    double mx = (t0[0] + hd[0]) / 2, my = (t0[1] + hd[1]) / 2;
    if (cl.length > 2 && !(t0[0] == hd[0] || t0[1] == hd[1])) {
      final List<int> mid = cl[cl.length >> 1];
      mx = mid[0].toDouble();
      my = mid[1].toDouble();
    }
    final double left = (model.ox + (mx + 0.5) * c) * model.vs + model.vx;
    final double top = (model.oy + (my + 0.5) * c) * model.vs + model.vy;
    return Positioned(
      left: left - 14,
      top: top - 6,
      child: const IgnorePointer(child: _BouncingHand()),
    );
  }

  Widget _bubble(String text, AppLocalizations loc, Palette pal) {
    final bool pass = curveTip; // büyük tahtada baloncuk dokunuşları yutmasın: yalnızca "Atla" tıklanır
    final Widget skip = AppButton(loc.tutSkip, kind: BtnKind.tiny, block: false, onTap: _skipTutorial);
    final Widget textBox = Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: pal.inkC,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[BoxShadow(color: pal.shadowC, blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: pass
          ? Text(text, style: TextStyle(color: pal.bgC, fontSize: 17, fontWeight: FontWeight.w700))
          : Row(children: <Widget>[
              Expanded(child: Text(text, style: TextStyle(color: pal.bgC, fontSize: 17, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              skip,
            ]),
    );
    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: pass
          ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
              IgnorePointer(child: textBox),
              const SizedBox(height: 6),
              skip,
            ])
          : textBox,
    );
  }

  Widget _topBar(AppLocalizations loc, Palette pal) {
    final String title = daily ? loc.dpLevel(dayLabel(loc, lv.daily!)) : loc.gameLevel(lv.id);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: <Widget>[
          IconSquareButton(
            icon: Icons.pause,
            semanticLabel: loc.gamePause,
            onTap: () {
              if (!busy) unawaited(_openPause());
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
              FitText(title, style: TextStyle(color: pal.inkC, fontSize: 18, fontWeight: FontWeight.w800), minFont: 13, maxLines: 1, align: TextAlign.start),
              Text(loc.gameArrowsLeft(g.remaining()),
                  maxLines: 1, style: TextStyle(color: pal.inkSoftC, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 8),
          _hearts(loc, pal),
          const SizedBox(width: 8),
          const CoinPill(),
        ]),
      ),
    );
  }

  Widget _hearts(AppLocalizations loc, Palette pal) {
    if (g.relaxed) {
      // G3: rahat modda can yok
      return Semantics(
        label: loc.settingsRelaxed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: pal.boardC,
            borderRadius: BorderRadius.circular(999),
            boxShadow: <BoxShadow>[BoxShadow(color: pal.edgeC, offset: const Offset(0, 2))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Icon(Icons.eco, size: 20, color: pal.successC),
            const SizedBox(width: 4),
            Text(loc.gameRelaxedBadge, style: TextStyle(color: pal.successC, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
    }
    return Semantics(
      label: '${loc.gameLives}: ${g.lives}',
      child: AnimatedBuilder(
        animation: _heartCtl,
        builder: (BuildContext c, Widget? _) {
          final double t = _heartCtl.value;
          final double dx = t == 0 ? 0 : math.sin(t * math.pi * 4) * 4 * (1 - t);
          return Transform.translate(
            offset: Offset(dx, 0),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                for (int i = 0; i < kMaxLives; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Icon(Icons.favorite, size: 26, color: i < g.lives ? pal.dangerC : rgba(0x888888, 0.28)),
                  ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _toolbar(AppLocalizations loc, Palette pal) {
    final bool free = app.save.freeHints > 0;
    final bool pulse = tut != null && tut!.id == 3 && tut!.step == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(children: <Widget>[
        Expanded(
          child: _ToolButton(
            icon: Icons.lightbulb,
            iconColor: pal.starC,
            label: loc.gameHint,
            sub: free ? loc.gameFreeLeft(app.save.freeHints) : loc.shopPrice(eco.kHintPrice),
            subColor: free ? pal.successC : pal.inkSoftC,
            pulse: pulse,
            onTap: _useHint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ToolButton(
            icon: Icons.refresh,
            iconColor: pal.inkC,
            label: loc.gameRestart,
            sub: ' ',
            subColor: pal.inkSoftC,
            onTap: () {
              app.sfx.button();
              if (_locked) return;
              _restartLevel();
            },
          ),
        ),
      ]),
    );
  }
}

class _ToolButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sub;
  final Color subColor;
  final bool pulse;
  final VoidCallback onTap;
  const _ToolButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.subColor,
    required this.onTap,
    this.pulse = false,
  });
  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(covariant _ToolButton old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.pulse && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      child: Pressable(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _c,
          builder: (BuildContext ctx, Widget? _) {
            return Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: pal.boardC,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: pal.edgeC, offset: const Offset(0, 4)),
                  if (widget.pulse) BoxShadow(color: rgba(pal.star, 0.7 * (1 - _c.value)), spreadRadius: 8 * _c.value),
                ],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: <Widget>[
                Icon(widget.icon, size: 24, color: widget.iconColor),
                FitText(widget.label, style: TextStyle(color: pal.inkC, fontSize: 15, fontWeight: FontWeight.w800, height: 1.15), minFont: 12, maxLines: 3),
                Text(widget.sub, maxLines: 1, style: TextStyle(color: widget.subColor, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// Öğretici eli: aşağı yukarı dokunma animasyonu (CSS tapme).
class _BouncingHand extends StatefulWidget {
  const _BouncingHand();
  @override
  State<_BouncingHand> createState() => _BouncingHandState();
}

class _BouncingHandState extends State<_BouncingHand> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext ctx, Widget? _) {
        // 0% ve 100%: (0, 10) ölçek 1 → 45%: (0, 0) ölçek .9
        final double t = _c.value;
        final double k = t < 0.45 ? t / 0.45 : 1 - (t - 0.45) / 0.55;
        return Transform.translate(
          offset: Offset(0, 10 * (1 - k)),
          child: Transform.scale(
            scale: 1 - 0.1 * k,
            child: const Icon(Icons.touch_app, size: 44, color: Colors.white, shadows: <Shadow>[Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 3))]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- seviye sonu penceresi
class _EndSheet extends StatefulWidget {
  final int stars, collisions, levelId;
  final eco.CompleteResult res;
  final bool relaxed, reduced, allDone;
  final Future<void> Function() onNext, onReplay, onMap;
  final ValueListenable<int> adWait;
  const _EndSheet({
    required this.adWait,
    required this.stars,
    required this.res,
    required this.collisions,
    required this.relaxed,
    required this.reduced,
    required this.levelId,
    required this.allDone,
    required this.onNext,
    required this.onReplay,
    required this.onMap,
  });
  @override
  State<_EndSheet> createState() => _EndSheetState();
}

class _EndSheetState extends State<_EndSheet> {
  bool _going = false;
  Timer? _autoNext;

  @override
  void initState() {
    super.initState();
    // docs/18 otomatik oynatma (yalnızca debug): kısa süre sonra "Sonraki"ne bas
    if (AdsConfig.autoPlayOn && widget.levelId < kMaxLevel) {
      _autoNext = Timer(const Duration(milliseconds: 900), () {
        if (mounted) _go(widget.onNext);
      });
    }
  }

  @override
  void dispose() {
    _autoNext?.cancel();
    super.dispose();
  }

  /// Oyuncu devam edince (ve yalnızca o zaman) geçiş reklamı kuralları değerlendirilir (core/ads_rules.dart).
  void _go(Future<void> Function() f) {
    if (_going) return;
    setState(() => _going = true);
    // 1.1.1: f herhangi bir nedenle istisna fırlatırsa düğmeler kilitli kalmasın (pencere kapanmadıysa yeniden etkinleşir)
    unawaited(f().catchError((Object _) {
      if (mounted) setState(() => _going = false); // yalnızca hata: normal bitişte pencere zaten kapanır (çift dokunuş yok)
    }));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    final eco.CompleteResult res = widget.res;
    Widget tag(String t) => Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: pal.starC, borderRadius: BorderRadius.circular(999)),
            child: Text(t, style: const TextStyle(color: Color(0xFF1D2C3B), fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      sheetTitle(context, loc.endTitle),
      StarsBig(stars: widget.stars, reduced: widget.reduced),
      sheetText(context, widget.collisions == 0 ? loc.endPerfect : loc.endCollisions(widget.collisions)),
      if (widget.relaxed) sheetText(context, loc.endRelaxedNote, color: pal.successC, weight: FontWeight.w700),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(Icons.monetization_on, size: 28, color: pal.coinC),
          const SizedBox(width: 6),
          Flexible(child: Text(loc.endReward(res.coins), style: TextStyle(color: pal.coinC, fontSize: 26, fontWeight: FontWeight.w800))),
        ]),
      ),
      Wrap(alignment: WrapAlignment.center, children: <Widget>[
        if (res.newBest) tag(loc.endNewBest),
        if (res.chapterDone) tag(loc.endChapterDone),
        if (res.chapterDone) tag(loc.mapChapterBonus(res.bonus)),
      ]),
      if (widget.allDone) sheetText(context, loc.endAllDone),
      // 1.1.4: show() sonrası bekleme göstergesi (yalnızca 300 ms'den uzun sürerse)
      ValueListenableBuilder<int>(
        valueListenable: widget.adWait,
        builder: (BuildContext c, int w, Widget? _) {
          if (w == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: pal.inkSoftC)),
                const SizedBox(width: 10),
                Flexible(child: Text(loc.adsOpening, style: TextStyle(color: pal.inkSoftC, fontSize: 15, fontWeight: FontWeight.w700))),
              ]),
              if (w == 2) sheetText(c, loc.adsSlow),
            ]),
          );
        },
      ),
      actionsColumn(<Widget>[
        if (widget.levelId < kMaxLevel) AppButton(loc.endNext, kind: BtnKind.primary, onTap: _going ? null : () => _go(widget.onNext)),
        Row(children: <Widget>[
          Expanded(child: AppButton(loc.endReplay, onTap: _going ? null : () => _go(widget.onReplay))),
          const SizedBox(width: 10),
          Expanded(child: AppButton(loc.endMap, onTap: _going ? null : () => _go(widget.onMap))),
        ]),
      ]),
    ]);
  }
}
