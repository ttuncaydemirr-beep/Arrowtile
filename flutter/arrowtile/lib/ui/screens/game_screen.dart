// Arrowtile — game_screen.dart: oyun ekranı (main.js "OYUN" bölümü): tahta, girdi, animasyon, öğretici, ipucu, bitiş pencereleri.
//
// 1.2.0 (docs/24 §1.3, docs/26) — web ile aynı kurallar:
//  - Tahta ekrana sığmak zorunda değil: varsayılan yakınlıkta hücre ≥ 20 px (_minCell). Sığan hücre ≥ 18 px ise (_fitOk) tam sığar,
//    kaydırma yok; daha küçükse tahta ekrandan büyük açılır. Tek parmak = kaydırma (ataletli), iki parmak = yakınlaştırma
//    (sMin = tüm tahta … sMax = hücre ≈ 64 px). > 10 px hareket eden parmak ASLA dokunuş sayılmaz. "Sığdır" ↔ "Yakınlaştır".
//  - İsabet HÜCRE bazlı: okun kapladığı hücrenin herhangi bir yerine dokunmak yeter; boş hücrede en yakın ok (0,45 hücre içinde),
//    iki ok neredeyse eşit uzaklıktaysa (0,12) hiçbiri oynamaz.
//  - Çıkış: ok kendi yolunu izleyerek SABİT hızla tahta kenarına dek gider, kenarda kırpılır; 110 ms sonra sıradaki oka dokunulabilir.
//  - Azaltılmış hareket (MediaQuery.disableAnimations) süreleri kısaltır, sarsıntı/atalet/geçişleri kapatır.
// Not: InteractiveViewer yerine ham işaretçi olayları (Listener) kullanılır; böylece web'deki pinch/pan/kenetleme
// kuralları ve isabet hesabı birebir korunur.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;

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
import '../celebration.dart';
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
  double lx = 0, ly = 0, lt = 0, sx = 0, sy = 0; // kaydırma hızı (yumuşatılmış, px/ms)
  _Gest(this.type, {this.x0 = 0, this.y0 = 0, this.vx = 0, this.vy = 0, this.d0 = 1, this.s0 = 1, this.mx = 0, this.my = 0});
}

class _View {
  double s, x, y;
  _View(this.s, this.x, this.y);
}

class _ViewAnim {
  final _View from, to;
  final double t0, dur;
  const _ViewAnim(this.from, this.to, this.t0, this.dur);
}

class _Fling {
  double vx, vy, t;
  _Fling(this.vx, this.vy, this.t);
}

// AYAR (main.js ile aynı): varsayılan en küçük hücre, kaydırmasız kabul edilen en küçük hücre, en büyük hücre, en yakın hücre (px)
const double _minCell = 20;
const double _fitOk = 18;
const double _maxCell = 72;
const double _zoomCell = 64;
const double _topBand = 36; // tahta alanının üstünde zorluk etiketi için ayrılan şerit (px)
const double _hitNear = 0.45; // hücre birimi — boş hücrede en yakın ok eşiği
const double _ambig = 0.12; // iki ok neredeyse eşit yakınsa hiçbiri oynamaz
const double _panSlop = 10; // bu kadar (px) hareket eden parmak artık dokunuş değildir
const int _crashToastMs = 2500; // "Çarptı! −1 can" bildirimi (sahip kararı); diğerleri 1,6 sn

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
  _ViewAnim? _viewAnim; // yumuşak görünüm geçişi (Sığdır / oka odaklan)
  _Fling? _fling; // kaydırma ataleti
  double _playMs = 0, _lastTapAt = 0; // hız rozeti: etkin oyun süresi (dokunuşlar arası en çok 8 sn sayılır)

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
    if (!lv.isDaily) {
      app.telemetry.levelStart(level: lv.id, tier: lv.diff, chapter: chapterOf(lv.id), board: '${lv.w}x${lv.h}', shaped: lv.mask != null);
    }
  }

  int get _attemptSeconds => _attemptClock.elapsed.inSeconds;

  bool get daily => lv.isDaily;
  String get levelKey => lv.daily ?? '${lv.id}';

  @override
  void initState() {
    super.initState();
    app = AppScope.read(context);
    FocusManager.instance.primaryFocus?.unfocus(); // 1.1.6: takılı odak/IME payı oyuna taşınmasın
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
    app.markTip('zoom_tip'); // büyük tahta ipucu otomatik oyunda görünmesin
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
      if (_animating) _kick();
    }
  }

  bool get _animating =>
      model.anims.isNotEmpty || model.shake != null || model.hintIdx >= 0 || model.flashIds.isNotEmpty || _viewAnim != null || _fling != null;

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
    if (_animating) _kick();
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
    _fling = null;
  }

  bool get _locked => busy || model.nowMs < lockUntil;

  // ---------------------------------------------------------------- yerleşim / görünüm (main.js resize/clampV/fitView)
  void _layout(double W, double H) {
    final double padF = boardPadFor(lv.w) * 2;
    final double fit = math.min(math.min((W - 4) / (lv.w + padF), (H - 12 - _topBand) / (lv.h + padF + 0.1)), _maxCell);
    // sığan hücre _fitOk px'ten küçük değilse tahta tam sığar (kaydırma yok); daha küçükse varsayılan hücre _minCell olur ve kaydırılır
    final double c = fit >= _fitOk ? fit.floorToDouble() : _minCell;
    model.cell = c;
    model.fit = fit;
    model.width = W;
    model.height = H;
    model.sMin = math.min(1.0, fit / c);
    model.sMax = math.max(2.5, _zoomCell / c);
    model.ox = ((W - lv.w * c) / 2).roundToDouble();
    model.oy = _topBand + ((H - _topBand - lv.h * c) / 2).roundToDouble();
    _clampView();
  }

  List<double> _trayBox() => model.trayBox();

  /// Görünümü sınırla: tahta kenarda durur (baş/son payı x: 2/2, y: _topBand/8); ekrandan küçükse ortalanır.
  _View _clampV(_View v) {
    v.s = math.max(model.sMin, math.min(model.sMax, v.s));
    final List<double> b = _trayBox();
    for (int ax = 0; ax < 2; ax++) {
      final double lo = b[ax] * v.s, hi = b[ax + 2] * v.s;
      final double size = ax == 0 ? model.width : model.height;
      final double m0 = ax == 0 ? 2 : _topBand, m1 = ax == 0 ? 2 : 8;
      final double cur = ax == 0 ? v.x : v.y;
      double nv;
      if (hi - lo <= size - m0 - m1 + 0.5) {
        nv = m0 + (size - m0 - m1 - (hi - lo)) / 2 - lo;
      } else {
        nv = math.min(m0 - lo, math.max(size - m1 - hi, cur));
      }
      if (ax == 0) {
        v.x = nv;
      } else {
        v.y = nv;
      }
    }
    return v;
  }

  void _clampView() {
    final _View v = _clampV(_View(model.vs, model.vx, model.vy));
    model.vs = v.s;
    model.vx = v.x;
    model.vy = v.y;
    model.minimap = _pannable() && !winDone;
  }

  Offset _toBoard(double px, double py) => Offset((px - model.vx) / model.vs, (py - model.vy) / model.vs);

  /// Tahta (tepsi) şu yakınlıkta ekrandan büyük mü (kaydırılabilir mi).
  bool _pannable() {
    final List<double> b = _trayBox();
    return (b[2] - b[0]) * model.vs > model.width - 3.5 || (b[3] - b[1]) * model.vs > model.height - _topBand - 7.5;
  }

  /// Tüm tahta görünür ve bu, varsayılan yakınlıktan farklı (sMin < 1).
  bool _overview() => model.sMin < 0.999 && model.vs <= model.sMin + 0.005;

  bool get _fitVisible => model.sMin < 0.999 || model.vs > 1.01;

  /// Görünümü yumuşak geçişle (bx, by) tahta noktası ekran ortasına gelecek şekilde ns yakınlığına götürür.
  void _animateView(double ns, double bx, double by) {
    final _View to = _View(ns, 0, 0);
    to.s = math.max(model.sMin, math.min(model.sMax, ns));
    to.x = model.width / 2 - bx * to.s;
    to.y = model.height / 2 - by * to.s;
    _clampV(to);
    _fling = null;
    if (_reduced) {
      _viewAnim = null;
      model.vs = to.s;
      model.vx = to.x;
      model.vy = to.y;
      _afterViewChange();
      return;
    }
    _viewAnim = _ViewAnim(_View(model.vs, model.vx, model.vy), to, model.nowMs, 281);
    _kick();
  }

  /// "Sığdır": tüm tahtayı göster; tahta zaten sığdırılmışsa varsayılan yakınlığa (hücre ≥ _minCell) döner.
  void _fitView() {
    final Offset c = _toBoard(model.width / 2, model.height / 2);
    _animateView(_overview() ? 1 : (model.sMin < 0.999 ? model.sMin : 1), c.dx, c.dy);
    _hud();
  }

  /// Ok görünür alanda değilse görünümü oka kaydırır (ipucu).
  void _focusArrow(int i) {
    final List<int> hd = headOf(lv.arrows[i]);
    final double c = model.cell;
    final double bx = model.ox + (hd[0] + 0.5) * c, by = model.oy + (hd[1] + 0.5) * c;
    final double sx = bx * model.vs + model.vx, sy = by * model.vs + model.vy, m = 2.5 * c * model.vs;
    if (sx > m && sy > m + 30 && sx < model.width - m && sy < model.height - m) return;
    _animateView(math.max(model.vs, math.min(1.0, model.sMax)), bx, by);
  }

  void _zoomAt(double px, double py, double ns) {
    final Offset bp = _toBoard(px, py);
    _viewAnim = null;
    _fling = null;
    model.vs = math.max(model.sMin, math.min(model.sMax, ns));
    model.vx = px - bp.dx * model.vs;
    model.vy = py - bp.dy * model.vs;
    _afterViewChange();
  }

  void _afterViewChange() {
    _clampView();
    _repaint.ping();
    if (mounted) setState(() {});
  }

  /// Test: görünüm durumu (web __ok.view()).
  @visibleForTesting
  ({double s, double x, double y, double cell, double sMin, double sMax, bool pannable, bool overview}) get debugView =>
      (s: model.vs, x: model.vx, y: model.vy, cell: model.cell, sMin: model.sMin, sMax: model.sMax, pannable: _pannable(), overview: _overview());

  /// Test: (u, v) tahta hücre koordinatının (hücre birimi) ekrandaki yeri (oyun alanı yerel koordinatı).
  @visibleForTesting
  Offset debugBoardPoint(double u, double v) =>
      Offset((model.ox + u * model.cell) * model.vs + model.vx, (model.oy + v * model.cell) * model.vs + model.vy);

  @visibleForTesting
  (int, List<int>?) debugHitTest(double px, double py) => _hitTest(px, py);

  @visibleForTesting
  void debugZoomAt(double px, double py, double s) => _zoomAt(px, py, s);

  @visibleForTesting
  void debugFit() => _fitView();

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
    final _ViewAnim? va = _viewAnim;
    if (va != null) {
      // yumuşak görünüm geçişi (ease-out kübik)
      final double qv = math.min(1.0, (now - va.t0) / va.dur);
      final double ev = 1 - (1 - qv) * (1 - qv) * (1 - qv);
      model.vs = va.from.s + (va.to.s - va.from.s) * ev;
      model.vx = va.from.x + (va.to.x - va.from.x) * ev;
      model.vy = va.from.y + (va.to.y - va.from.y) * ev;
      if (qv >= 1) {
        _viewAnim = null;
        _clampView();
        if (mounted) setState(() {});
      } else {
        active = true;
      }
    }
    final _Fling? fl = _fling;
    if (fl != null) {
      // kaydırma ataleti: hız 300 ms zaman sabitiyle söner; kenara dayanan eksende durur
      final double dtf = math.min(40.0, now - fl.t), kf = math.exp(-dtf / 300);
      fl.t = now;
      model.vx += fl.vx * dtf;
      model.vy += fl.vy * dtf;
      fl.vx *= kf;
      fl.vy *= kf;
      final double fx0 = model.vx, fy0 = model.vy;
      _clampView();
      if (model.vx != fx0) fl.vx = 0;
      if (model.vy != fy0) fl.vy = 0;
      if (fl.vx.abs() + fl.vy.abs() < 0.03) {
        _fling = null;
      } else {
        active = true;
      }
    }
    _repaint.ping();
    if (!active) _ticker.stop();
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
  /// 1.2.0 İsabet HÜCRE bazlı (main.js hitTest): okun hücresine dokunmak yeter. Boş hücrede komşu 3x3 hücrelerden en yakın ok
  /// (hücre karesine uzaklık ≤ [_hitNear]); iki farklı ok neredeyse eşit uzaklıktaysa ({amb}) hiçbiri oynamaz.
  (int, List<int>?) _hitTest(double px, double py) {
    final Offset b = _toBoard(px, py);
    final double u = (b.dx - model.ox) / model.cell, v = (b.dy - model.oy) / model.cell;
    final int w = lv.w, h = lv.h, fx = u.floor(), fy = v.floor();
    final List<int> grid = _liveGrid();
    if (fx >= 0 && fy >= 0 && fx < w && fy < h && grid[fy * w + fx] >= 0) return (grid[fy * w + fx], null);
    int best = -1, second = -1;
    double bd = 1e9, sd = 1e9;
    for (int ny = fy - 1; ny <= fy + 1; ny++) {
      for (int nx = fx - 1; nx <= fx + 1; nx++) {
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final int k = grid[ny * w + nx];
        if (k < 0) continue;
        final double dx = u < nx ? nx - u : (u > nx + 1 ? u - nx - 1 : 0);
        final double dy = v < ny ? ny - v : (v > ny + 1 ? v - ny - 1 : 0);
        final double d = math.sqrt(dx * dx + dy * dy);
        if (k == best) {
          if (d < bd) bd = d;
        } else if (d < bd) {
          second = best;
          sd = bd;
          best = k;
          bd = d;
        } else if (k == second) {
          if (d < sd) sd = d;
        } else if (d < sd) {
          second = k;
          sd = d;
        }
      }
    }
    if (best < 0 || bd > _hitNear) return (-1, null);
    if (second >= 0 && sd <= _hitNear && sd - bd < _ambig) return (-1, <int>[best, second]);
    return (best, null);
  }

  /// Canlı okların ızgarası (hücre → ok, -1 boş); dokunuş başına bir kez hesaplanır.
  List<int> _liveGrid() => g.grid();

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
    _fling = null;
    _viewAnim = null;
    if (ptrs.length == 1) {
      gest = _Gest('tap', x0: e.localPosition.dx, y0: e.localPosition.dy, vx: model.vx, vy: model.vy)
        ..lx = e.localPosition.dx
        ..ly = e.localPosition.dy
        ..lt = model.nowMs;
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
      model.vs = math.max(model.sMin, math.min(model.sMax, gs.s0 * d / gs.d0));
      model.vx = mx - bx * model.vs;
      model.vy = my - by * model.vs;
      _afterViewChange();
    } else if (gs.type == 'tap' || gs.type == 'pan') {
      final double dx = e.localPosition.dx - gs.x0, dy = e.localPosition.dy - gs.y0;
      // kaydırma eşiği: bu kadar hareket eden parmak artık dokunuş değildir (kaydırma asla ok oynatmaz)
      if (gs.type == 'tap' && math.sqrt(dx * dx + dy * dy) > _panSlop) gs.type = _pannable() ? 'pan' : 'none';
      if (gs.type == 'pan') {
        final double nowm = model.nowMs, dtm = math.max(1.0, nowm - gs.lt);
        gs.sx = 0.6 * gs.sx + 0.4 * (e.localPosition.dx - gs.lx) / dtm; // yumuşatılmış hız (px/ms)
        gs.sy = 0.6 * gs.sy + 0.4 * (e.localPosition.dy - gs.ly) / dtm;
        gs.lx = e.localPosition.dx;
        gs.ly = e.localPosition.dy;
        gs.lt = nowm;
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
    if (!cancel &&
        gs != null &&
        gs.type == 'pan' &&
        ptrs.isEmpty &&
        !_reduced &&
        model.nowMs - gs.lt < 80 &&
        math.sqrt(gs.sx * gs.sx + gs.sy * gs.sy) > 0.25) {
      _fling = _Fling(gs.sx, gs.sy, model.nowMs);
      _kick();
    }
    if (ptrs.isEmpty) {
      gest = null;
    } else if (gs != null && gs.type == 'pinch') {
      gest = _Gest('none');
    }
  }

  /// Masaüstü / emülatör fare tekerleği: tekerlek = kaydırma; Ctrl + tekerlek ya da kaydırılamayan tahta = yakınlaştırma.
  void _wheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final bool ctrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isAltPressed;
    if (ctrl || !_pannable()) {
      _zoomAt(e.localPosition.dx, e.localPosition.dy, model.vs * (e.scrollDelta.dy < 0 ? 1.15 : 1 / 1.15));
      return;
    }
    model.vx -= e.scrollDelta.dx;
    model.vy -= e.scrollDelta.dy;
    _afterViewChange();
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
    if (_lastTapAt > 0) _playMs += math.min(8000.0, now - _lastTapAt); // hız rozeti: etkin oyun süresi (bekleme sayılmaz)
    _lastTapAt = now;
    if (r.isExit) {
      // 1.2.0 (docs/17 §11): ok kendi yolunu izleyerek SABİT hızla tahta kenarına dek gider ve kenarda kırpılarak kaybolur
      // (gövdenin tamamı, kuyruk dahil, yol boyunca akar; solma yok). Mesafe = kuyruğun tahtayı terk etmesi.
      final double dist = _boardLeaveCells(a) + 0.6;
      double dur = math.min(Anim.exitMax, math.max(Anim.exitMin, dist * Anim.exitPerCell));
      if (_reduced) dur = math.min(dur, 180);
      model.anims[i] = BoardAnim(kind: 'exit', t0: now, dur: dur, dist: dist, done: () {
        if (g.isWon && !model.anims.values.any((BoardAnim x) => x.kind == 'exit')) _onWin();
      });
      // Ok yola çıktıktan kısa süre sonra (tapGap, sahip onayı 110 ms) sıradaki oka dokunulabilir; oyun durumu dokunuş anında güncellendi.
      lockUntil = now + math.min(dur, Anim.tapGap);
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
          app.toast(loc.gameCrash, ms: _crashToastMs);
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
    model.minimap = false;
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
        durationS: _attemptSeconds,
        chapter: chapterOf(id),
        board: '${lv.w}x${lv.h}',
        shaped: lv.mask != null);
    model.minimap = false;
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
    final Celebration cel = celebrationOf(AppLocalizations.of(context),
        tier: lv.diff, revived: g.revived, collisions: collisions, arrows: lv.arrows.length, playMs: _playMs);
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
        cel: cel,
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
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Icon(Icons.emoji_events, size: 72, color: pal.starInkC)),
        if (first)
          Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: pal.starC, borderRadius: BorderRadius.circular(999)),
              child: Text(loc.dpTrophyWon, style: const TextStyle(color: Color(0xFF22252B), fontSize: 14, fontWeight: FontWeight.w800)),
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
    if (!daily) {
      app.telemetry.levelFail(level: lv.id, tier: lv.diff, chapter: chapterOf(lv.id), board: '${lv.w}x${lv.h}', shaped: lv.mask != null);
    }
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
    _playMs = 0;
    _lastTapAt = 0;
    _clampView();
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
    hintUntil = model.nowMs + 2600;
    _focusArrow(i); // büyük tahtada ipucu oku ekranda değilse oraya kaydır
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
    // 1.2.0: tahta ekrana sığmıyorsa bir kez kaydırma/yakınlaştırma ipucu. İsabet hücre bazlı olduğundan otomatik
    // "önce seç, sonra fırlat" önerisi kaldırıldı (sahip onayı); ayar Ayarlar'da duruyor.
    if (_pannable() && !app.hasTip('zoom_tip') && tut == null) {
      app.markTip('zoom_tip');
      app.toast(loc.gamePanTip, ms: 2600);
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
    model.mono = app.save.arrowColor == 'mono';
    final String? bubble = _bubbleText(loc);
    final int target = _tutorialTarget();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (!busy) unawaited(_openPause());
      },
      child: ScreenScaffold(
        // 1.1.6 (docs/23): oyun arayüzünde (üst çubuk/araç çubuğu) yazı ölçeği en çok 1,3 — büyük yazı tahtayı ve düğmeleri taşırmasın.
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3)),
          child: Column(children: <Widget>[
          _topBar(loc, pal),
          Expanded(
            child: LayoutBuilder(builder: (BuildContext ctx, BoxConstraints bc) {
              final Size sz = Size(bc.maxWidth, bc.maxHeight);
              if (sz != _lastSize) {
                _lastSize = sz;
                _checkShrunk(ctx, sz);
                _layout(sz.width, sz.height);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() {}); // araç çubuğundaki "Sığdır" düğmesi yeni yerleşime göre
                  _oneTimeTips();
                });
              }
              return Stack(children: <Widget>[
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerSignal: _wheel,
                    onPointerDown: _down,
                    onPointerMove: _move,
                    onPointerUp: (PointerUpEvent e) => _end(e, false),
                    onPointerCancel: (PointerCancelEvent e) => _end(e, true),
                    child: CustomPaint(painter: BoardPainter(model, _repaint), size: Size.infinite),
                  ),
                ),
                if (lv.diff != null)
                  Positioned(top: 6, left: 0, right: 0, child: IgnorePointer(child: Center(child: TierBadge(lv.diff!)))),
                if (tut != null && target >= 0) _hand(target),
                if (bubble != null) _bubble(bubble, loc, pal),
              ]);
            }),
          ),
          _toolbar(loc, pal),
        ]),
        ),
      ),
    );
  }

  bool _shrunkLogged = false;

  /// 1.1.6 (docs/23): oyun alanı yüksekliği ekranın <%60'ı ise (klavye payı yokken) Tanılama + Firebase'e bir kez yaz.
  void _checkShrunk(BuildContext ctx, Size sz) {
    final MediaQueryData mq = MediaQuery.of(ctx);
    final FlutterView view = View.of(ctx); // ScreenScaffold alt payı gövdeden sildiği için ham değer pencereden okunur
    final double inset = view.viewInsets.bottom / view.devicePixelRatio;
    final double avail = mq.size.height - mq.viewPadding.top - mq.viewPadding.bottom - 64 - 90;
    if (_shrunkLogged || avail <= 0 || sz.height >= avail * 0.6) return;
    _shrunkLogged = true;
    final int scale = (mq.textScaler.scale(100)).round();
    diag('layout', 'layout_shrunk', <String, Object?>{
      'screen': '${mq.size.width.round()}x${mq.size.height.round()}',
      'board': '${sz.width.round()}x${sz.height.round()}',
      'rawInsetB': inset.round(),
      'viewPadding': mq.viewPadding.toString(),
      'textScale': scale,
    });
    app.telemetry.layoutShrunk(
        screenH: mq.size.height.round(), boardH: sz.height.round(), insetB: inset.round(), padB: mq.viewPadding.bottom.round(), scale: scale);
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
                    // 1.2.1 (docs/27 §B3): kayıp can içi boş kalp (şekil), yalnızca soluk renk değil
                    child: i < g.lives
                        ? Icon(Icons.favorite, size: 26, color: pal.dangerC)
                        : Icon(Icons.favorite_border, size: 26, color: rgba(pal.inkSoft, 0.8)),
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
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(children: <Widget>[
        Expanded(
          child: _ToolButton(
            icon: Icons.lightbulb,
            iconColor: pal.starInkC,
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
        // 1.2.0: üçüncü düğme "Sığdır" (tüm tahta) ↔ "Yakınlaştır" (varsayılan) — yalnızca tahta ekrandan büyükse / yakınken
        if (_fitVisible) ...<Widget>[
          const SizedBox(width: 8),
          Expanded(
            child: _ToolButton(
              key: const ValueKey<String>('btn-fit'),
              icon: _overview() ? Icons.zoom_in : Icons.fit_screen,
              iconColor: pal.inkC,
              label: _overview() ? loc.gameZoomDefault : loc.gameFit,
              sub: ' ',
              subColor: pal.inkSoftC,
              onTap: () {
                app.sfx.button();
                _fitView();
              },
            ),
          ),
        ],
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
    super.key,
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
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: pal.boardC,
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: pal.edgeC, offset: const Offset(0, 4)),
                  if (widget.pulse) BoxShadow(color: rgba(pal.star, 0.7 * (1 - _c.value)), spreadRadius: 8 * _c.value),
                ],
              ),
              // 1.2.0: tek satır araç çubuğu (56 px): simge solda (RTL'de sağda), etiket + alt satır yanında
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                Icon(widget.icon, size: 24, color: widget.iconColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: <Widget>[
                    FitText(widget.label, style: TextStyle(color: pal.inkC, fontSize: 15, fontWeight: FontWeight.w800, height: 1.15), minFont: 11, maxLines: 2),
                    if (widget.sub.trim().isNotEmpty)
                      Text(widget.sub, maxLines: 1, style: TextStyle(color: widget.subColor, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
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
  final Celebration cel;
  final int stars, collisions, levelId;
  final eco.CompleteResult res;
  final bool relaxed, reduced, allDone;
  final Future<void> Function() onNext, onReplay, onMap;
  final ValueListenable<int> adWait;
  const _EndSheet({
    required this.cel,
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
            child: Text(t, style: const TextStyle(color: Color(0xFF22252B), fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        );
    final Celebration cel = widget.cel;
    final bool legend = cel.tier == 'extreme' && cel.perf == 'flawless';
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      // 1.2.0 kutlama: meşale/alev + kademe × performans mesajı (başlık), "Seviye tamamlandı!" alt satırda
      TorchFlame(cel: cel, reduced: widget.reduced),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(cel.msg,
            key: const ValueKey<String>('cel-msg'),
            textAlign: TextAlign.center,
            style: TextStyle(color: legend ? pal.starC : pal.inkC, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Text(loc.endTitle,
            textAlign: TextAlign.center, style: TextStyle(color: pal.inkSoftC, fontSize: 14, fontWeight: FontWeight.w700)),
      ),
      StarsBig(stars: widget.stars, reduced: widget.reduced),
      sheetText(context, widget.collisions == 0 ? loc.endPerfect : loc.endCollisions(widget.collisions)),
      if (widget.relaxed) sheetText(context, loc.endRelaxedNote, color: pal.successC, weight: FontWeight.w700),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(Icons.monetization_on, size: 28, color: pal.coinInkC),
          const SizedBox(width: 6),
          Flexible(child: Text(loc.endReward(res.coins), style: TextStyle(color: pal.coinInkC, fontSize: 26, fontWeight: FontWeight.w800))),
        ]),
      ),
      Wrap(alignment: WrapAlignment.center, children: <Widget>[
        if (cel.fast && cel.fastMsg != null)
          Padding(
            key: const ValueKey<String>('cel-fast'),
            padding: const EdgeInsets.all(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Color.alphaBlend(rgba(pal.star, 0.30), pal.cellC), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Icon(Icons.bolt, size: 16, color: pal.inkC),
                const SizedBox(width: 4),
                Flexible(child: Text(cel.fastMsg!, style: TextStyle(color: pal.inkC, fontSize: 14, fontWeight: FontWeight.w800))),
              ]),
            ),
          ),
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
