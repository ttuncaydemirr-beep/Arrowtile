// Seviye 15/16 → 17 geçişinde İLK geçiş reklamı denemesi (docs/18) + 1.1.4 TUTMA tasarımı (docs/21): show() çağrıldıysa sonraki seviye,
// reklam kapanana / gösterilemeyene / uygulama reklamdan dönene dek AÇILMAZ; reklam asla sonraki seviyenin ortasında belirmez.
// Gerçek akış: oyun otomatik oynanır (AdsConfig.autoPlayTestOverride) → seviye sonu penceresi → "Next level" (900 ms sonra kendiliğinden)
// → Monetization.continueAfterLevel → sonraki seviye. Sahte platform: doldurulamadı, geri çağrı hiç gelmez, gösterilemedi,
// yavaş yükleme/gösterim, ekranda izlenen reklam. Beklenen: sonraki seviye süre içinde açılır, animasyon döngüsü (ticker) çalışır
// (seviye sonraki bir kez daha çözülüp sonu penceresi gelir), reklam bayrağı takılı kalmaz, açık pencere/duraklatma kalmaz.
import 'package:arrowtile/config/ads_config.dart';
import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:arrowtile/state/app_scope.dart';
import 'package:arrowtile/ui/board_painter.dart' show BoardModel;
import 'package:arrowtile/ui/flow.dart';
import 'package:arrowtile/ui/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';
import 'fake_telemetry.dart';

const Duration _step = Duration(milliseconds: 100);

Future<AppController> _boot(WidgetTester t, FakePlatform fp, {required int level, FakeTelemetry? tel}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  AdsConfig.autoPlayTestOverride = true;
  // tahta animasyonları BoardModel.nowMs ile ilerler (gerçek Stopwatch); widget testinde sanal saate bağlanır
  BoardModel.testClock = () => t.binding.clock.now().microsecondsSinceEpoch / 1000.0;
  final AppController? made = await t.runAsync(() => AppController.create(adsPlatform: fp, telemetry: tel));
  final AppController app = made!;
  app.save.lang = 'en';
  app.save.unlocked = level;
  app.save.ads.since = 2; // seviye 13, 14 tamamlanmış gibi: bu seviye bitince sayaç 3 → ilk geçiş reklamı denemesi
  app.save.ads.lastAt = 0;
  await t.pumpWidget(AppScope(
    controller: app,
    child: MaterialApp(
      navigatorKey: app.navKey,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: SizedBox.expand()),
    ),
  ));
  app.navKey.currentState!.push(fadeRoute<void>(GameScreen(level: app.getLevel(level)!)));
  await t.pump(const Duration(milliseconds: 300));
  return app;
}

Finder _game(int id) => find.byWidgetPredicate((Widget w) => w is GameScreen && w.level.id == id);

/// [cond] gerçekleşene dek 100 ms'lik adımlarla ilerler; geçen sanal süreyi (ms) döner, [maxMs] aşılırsa -1.
Future<int> _until(WidgetTester t, bool Function() cond, {int maxMs = 120000}) async {
  int ms = 0;
  while (ms <= maxMs) {
    if (cond()) return ms;
    await t.pump(_step);
    ms += 100;
  }
  return -1;
}

bool _endSheetVisible() => find.text('Level complete!').evaluate().isNotEmpty;

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 5));
}

/// level → level+1 geçişi: seviye bitir, seviye sonu penceresinden sonrakine geç. Dönen: pencere göründükten sonraki bekleme (ms).
Future<int> _transition(WidgetTester t, AppController app, int level) async {
  final int toEnd = await _until(t, _endSheetVisible);
  expect(toEnd, greaterThanOrEqualTo(0), reason: 'seviye $level otomatik çözülüp seviye sonu penceresi gelmeli');
  final int wait = await _until(t, () => _game(level + 1).evaluate().isNotEmpty, maxMs: 30000);
  expect(wait, greaterThanOrEqualTo(0), reason: 'seviye ${level + 1} AÇILMADI (donma)');
  return wait;
}

/// Açılan seviyede animasyon döngüsü gerçekten çalışıyor: seviye çözülüp seviye sonu penceresi tekrar gelir (kazanma ticker'a bağlı).
Future<void> _expectPlayable(WidgetTester t, AppController app, int id) async {
  await t.pump(const Duration(milliseconds: 500));
  expect(_game(id), findsOneWidget);
  final dynamic st = t.state(_game(id));
  expect(st.debugAdPaused, isFalse, reason: 'reklam bayrağı takılı kalmamalı');
  expect(app.mon.isAdShowing, isFalse);
  final int solved = await _until(t, _endSheetVisible);
  expect(solved, greaterThanOrEqualTo(0), reason: 'seviye $id çözülemedi: ticker/animasyon döngüsü durmuş olabilir');
  expect(app.sfx.held, isFalse, reason: 'ses duraklatması geri alınmalı');
}

void main() {
  tearDown(() {
    AdsConfig.autoPlayTestOverride = false;
    BoardModel.testClock = null;
  });

  // 900 ms: seviye sonu penceresinde otomatik "Next level" gecikmesi + geçiş animasyonu payı
  const int fastMs = 900 + 700;

  for (final int level in <int>[15, 16]) {
    group('seviye $level → ${level + 1}', () {
      testWidgets('doldurulamadı (no fill): sonraki seviye hemen açılır', (WidgetTester t) async {
        final FakePlatform fp = FakePlatform()..interstitialOk = false;
        final AppController app = await _boot(t, fp, level: level);
        final int wait = await _transition(t, app, level);
        expect(wait, lessThanOrEqualTo(fastMs));
        expect(fp.calls, isNot(contains('interstitial')));
        await _expectPlayable(t, app, level + 1);
        await _finish(t);
      });

      testWidgets('gösterilemedi (failedToShow): sonraki seviye hemen açılır', (WidgetTester t) async {
        final FakePlatform fp = FakePlatform()..failToShow = true;
        final AppController app = await _boot(t, fp, level: level);
        final int wait = await _transition(t, app, level);
        expect(wait, lessThanOrEqualTo(fastMs));
        await _expectPlayable(t, app, level + 1);
        await _finish(t);
      });

      testWidgets('platform istisna fırlatır: sonraki seviye açılır', (WidgetTester t) async {
        final FakePlatform fp = FakePlatform()..throwOnShow = true;
        final AppController app = await _boot(t, fp, level: level);
        final int wait = await _transition(t, app, level);
        expect(wait, lessThanOrEqualTo(fastMs));
        await _expectPlayable(t, app, level + 1);
        await _finish(t);
      });
    });
  }

  testWidgets('1.1.4: yüklü reklam show() sonrası 8 sn geç belirir → sonraki seviye reklam KAPANANA dek açılmaz; seviye ortasında reklam yok',
      (WidgetTester t) async {
    final FakePlatform fp = FakePlatform()
      ..presentAfter = const Duration(seconds: 8)
      ..watchFor = const Duration(seconds: 3);
    final AppController app = await _boot(t, fp, level: 15);
    bool nextOpenAtPresent = true;
    fp.onPresented = () => nextOpenAtPresent = _game(16).evaluate().isNotEmpty;
    expect(await _until(t, _endSheetVisible), greaterThanOrEqualTo(0));
    expect(await _until(t, () => fp.calls.contains('interstitial'), maxMs: 4000), greaterThanOrEqualTo(0));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Opening ad…'), findsOneWidget, reason: '300 ms sonra nötr bekleme göstergesi');
    expect(app.sfx.held, isFalse, reason: 'ses yalnızca reklam ekrandayken susar');
    await t.pump(const Duration(seconds: 6));
    expect(_game(16), findsNothing, reason: 'show() sürerken sonraki seviye başlamamalı (eski kod 3 sn sonra başlatıyordu)');
    final int wait = await _until(t, () => _game(16).evaluate().isNotEmpty, maxMs: 20000);
    expect(wait, greaterThanOrEqualTo(0));
    expect(fp.presentedI, 1);
    expect(nextOpenAtPresent, isFalse, reason: 'reklam belirdiğinde sonraki seviye henüz açık olmamalı');
    expect(fp.releasedI, 0);
    final int before = fp.presentedI;
    await t.pump(const Duration(seconds: 10));
    expect(fp.presentedI, before, reason: 'seviye 16 sırasında reklam yok');
    expect(app.sfx.held, isFalse);
    await _expectPlayable(t, app, 16);
    await _finish(t);
  });

  testWidgets('1.1.4: SDK hiç yanıt vermez → 20 sn sonra "gecikiyor" ipucu, sonraki seviye YİNE açılmaz; uygulamadan çıkıp dönünce açılır',
      (WidgetTester t) async {
    final FakeTelemetry tel = FakeTelemetry();
    final FakePlatform fp = FakePlatform()..hangInterstitial = true;
    final AppController app = await _boot(t, fp, level: 15, tel: tel);
    expect(await _until(t, _endSheetVisible), greaterThanOrEqualTo(0));
    expect(await _until(t, () => fp.calls.contains('interstitial'), maxMs: 4000), greaterThanOrEqualTo(0));
    await t.pump(const Duration(seconds: 21));
    expect(find.textContaining('The ad is taking a while'), findsOneWidget);
    expect(_game(16), findsNothing);
    expect(tel.named('interstitial_stage').map((LoggedEvent e) => e.params['stage']), containsAll(<String>['show_called', 'stuck']));
    app.onAppBackgrounded();
    await t.pump(const Duration(milliseconds: 100));
    app.onAppResumed();
    final int wait = await _until(t, () => _game(16).evaluate().isNotEmpty, maxMs: 6000);
    expect(wait, greaterThanOrEqualTo(0));
    expect(fp.calls, contains('releaseI'));
    await _expectPlayable(t, app, 16);
    await _finish(t);
  });

  testWidgets('ekranda izlenen reklam: kapanana dek tutulur (ticker duraklar), kapanınca sonraki seviye açılır ve ticker çalışır',
      (WidgetTester t) async {
    final FakePlatform fp = FakePlatform()
      ..showAfter = const Duration(seconds: 6)
      ..appearsOnScreen = true;
    final AppController app = await _boot(t, fp, level: 15);
    expect(await _until(t, _endSheetVisible), greaterThanOrEqualTo(0));
    expect(await _until(t, () => app.mon.isAdShowing, maxMs: 5000), greaterThanOrEqualTo(0));
    await t.pump(const Duration(seconds: 4));
    expect(_game(16), findsNothing, reason: 'izlenen reklam sırasında sonraki seviye açılmamalı');
    final dynamic old = t.state(_game(15));
    expect(old.debugAdPaused, isTrue);
    expect(old.debugTickerActive, isFalse);
    expect(app.sfx.held, isTrue);
    final int wait = await _until(t, () => _game(16).evaluate().isNotEmpty, maxMs: 10000);
    expect(wait, greaterThanOrEqualTo(0));
    expect(app.mon.isAdShowing, isFalse);
    await _expectPlayable(t, app, 16);
    await _finish(t);
  });

  testWidgets('(c) yükleme sonraki seviye sırasında tamamlanır: seviye bitene dek show() yok; seviye sonunda tam bir kez', (WidgetTester t) async {
    final FakePlatform fp = FakePlatform()..interstitialOk = false;
    final AppController app = await _boot(t, fp, level: 15);
    await _transition(t, app, 15); // no fill → anında atlandı
    expect(fp.calls, isNot(contains('interstitial')));
    fp.interstitialOk = true; // yükleme seviye 16 sırasında tamamlandı
    int guard = 0;
    while (!_endSheetVisible() && guard++ < 1200) {
      await t.pump(_step);
      expect(fp.calls.where((String c) => c == 'interstitial'), isEmpty, reason: 'seviye ortasında show() çağrılmamalı');
    }
    expect(_endSheetVisible(), isTrue);
    await _transition(t, app, 16);
    expect(fp.calls.where((String c) => c == 'interstitial').length, 1, reason: 'sonraki uygun seviye sonunda bir kez');
    await _finish(t);
  });

  testWidgets('kalkan: dönüşle bırakılan gösterimden sonra seviye sürerken uygulama arka plana düşerse late_blocked + duraklat, dönünce devam',
      (WidgetTester t) async {
    final FakeTelemetry tel = FakeTelemetry();
    final FakePlatform fp = FakePlatform()..hangInterstitial = true;
    final AppController app = await _boot(t, fp, level: 15, tel: tel);
    expect(await _until(t, () => fp.calls.contains('interstitial')), greaterThanOrEqualTo(0));
    app.onAppBackgrounded();
    app.onAppResumed();
    expect(await _until(t, () => _game(16).evaluate().isNotEmpty, maxMs: 6000), greaterThanOrEqualTo(0));
    await t.pump(const Duration(milliseconds: 300));
    final dynamic st = t.state(_game(16));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive); // geç gelen reklam etkinliği öne çıktı
    await t.pump(const Duration(milliseconds: 50));
    expect(tel.named('interstitial').map((LoggedEvent e) => e.params['result']), contains('late_blocked'));
    expect(st.debugAdPaused, isTrue, reason: 'oyun duraklar (ticker)');
    expect(app.sfx.held, isTrue);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump(const Duration(milliseconds: 50));
    expect(st.debugAdPaused, isFalse);
    expect(app.sfx.held, isFalse);
    expect(app.mon.isAdShowing, isFalse);
    await _expectPlayable(t, app, 16);
    await _finish(t);
  });

  testWidgets('seviye sürerken ses bayrağı her zaman false (reklam yalnızca seviye sonunda ekrandaydı)', (WidgetTester t) async {
    final FakePlatform fp = FakePlatform()
      ..presentAfter = const Duration(seconds: 2)
      ..watchFor = const Duration(seconds: 1);
    final AppController app = await _boot(t, fp, level: 15);
    expect(await _until(t, () => _game(16).evaluate().isNotEmpty, maxMs: 30000), greaterThanOrEqualTo(0));
    int steps = 0;
    while (!_endSheetVisible() && steps++ < 1200) {
      await t.pump(_step);
      expect(app.sfx.held, isFalse, reason: 'seviye 16 sırasında ses susturulmamalı');
    }
    await _finish(t);
  });
}
