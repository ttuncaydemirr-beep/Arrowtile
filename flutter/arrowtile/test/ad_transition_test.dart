// Seviye 15/16 → 17 geçişinde İLK geçiş reklamı denemesi oyunu tutmamalı (docs/18, kapalı test 1.1.0 "17. seviye açılmadı, oyun dondu").
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

const Duration _step = Duration(milliseconds: 100);

Future<AppController> _boot(WidgetTester t, FakePlatform fp, {required int level}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  AdsConfig.autoPlayTestOverride = true;
  // tahta animasyonları BoardModel.nowMs ile ilerler (gerçek Stopwatch); widget testinde sanal saate bağlanır
  BoardModel.testClock = () => t.binding.clock.now().microsecondsSinceEpoch / 1000.0;
  final AppController? made = await t.runAsync(() => AppController.create(adsPlatform: fp));
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

  // 900 ms: seviye sonu penceresinde otomatik "Next level" gecikmesi; + gösterim denemesi sınırı (3 sn) + geçiş animasyonu payı
  const int limitMs = 900 + 3000 + 700;

  for (final int level in <int>[15, 16]) {
    group('seviye $level → ${level + 1}', () {
      testWidgets('doldurulamadı (no fill): sonraki seviye hemen açılır', (WidgetTester t) async {
        final FakePlatform fp = FakePlatform()..interstitialOk = false;
        final AppController app = await _boot(t, fp, level: level);
        final int wait = await _transition(t, app, level);
        expect(wait, lessThanOrEqualTo(1500));
        expect(fp.calls, isNot(contains('interstitial')));
        await _expectPlayable(t, app, level + 1);
        await _finish(t);
      });

      testWidgets('geri çağrı HİÇ gelmez: sonraki seviye gösterim süresi içinde açılır, ticker çalışır', (WidgetTester t) async {
        final FakePlatform fp = FakePlatform()..hangInterstitial = true;
        final AppController app = await _boot(t, fp, level: level);
        final int wait = await _transition(t, app, level);
        expect(wait, lessThanOrEqualTo(limitMs), reason: 'en çok ~3 sn beklenmeli (eski kod 90 sn beklerdi)');
        expect(fp.calls, contains('interstitial'));
        await _expectPlayable(t, app, level + 1);
        await _finish(t);
      });

      testWidgets('gösterilemedi (failedToShow): sonraki seviye açılır', (WidgetTester t) async {
        final FakePlatform fp = FakePlatform()..failToShow = true;
        final AppController app = await _boot(t, fp, level: level);
        final int wait = await _transition(t, app, level);
        expect(wait, lessThanOrEqualTo(limitMs));
        await _expectPlayable(t, app, level + 1);
        await _finish(t);
      });

      testWidgets('platform istisna fırlatır: sonraki seviye açılır', (WidgetTester t) async {
        final FakePlatform fp = FakePlatform()..throwOnShow = true;
        final AppController app = await _boot(t, fp, level: level);
        final int wait = await _transition(t, app, level);
        expect(wait, lessThanOrEqualTo(limitMs));
        await _expectPlayable(t, app, level + 1);
        await _finish(t);
      });

      testWidgets('yavaş yükleme/gösterim (10 sn, süreyi aşar): atlanır, sonraki seviye açılır', (WidgetTester t) async {
        final FakePlatform fp = FakePlatform()..showAfter = const Duration(seconds: 10);
        final AppController app = await _boot(t, fp, level: level);
        final int wait = await _transition(t, app, level);
        expect(wait, lessThanOrEqualTo(limitMs));
        await _expectPlayable(t, app, level + 1);
        await _finish(t);
      });
    });
  }

  testWidgets('ekranda izlenen reklam: kapanana dek tutulur (ticker duraklar), kapanınca sonraki seviye açılır ve ticker çalışır',
      (WidgetTester t) async {
    final FakePlatform fp = FakePlatform()
      ..showAfter = const Duration(seconds: 6)
      ..appearsOnScreen = true;
    final AppController app = await _boot(t, fp, level: 15);
    expect(await _until(t, _endSheetVisible), greaterThanOrEqualTo(0));
    // reklam açıldı: sonraki seviye henüz yok, eski ekranda reklam bayrağı açık, ticker durmuş
    expect(await _until(t, () => app.mon.isAdShowing, maxMs: 5000), greaterThanOrEqualTo(0));
    await t.pump(const Duration(seconds: 4)); // 3 sn gösterim sınırından uzun: ekrandaki reklam kesilmemeli
    expect(_game(16), findsNothing, reason: 'izlenen reklam sırasında sonraki seviye açılmamalı');
    final dynamic old = t.state(_game(15));
    expect(old.debugAdPaused, isTrue);
    expect(old.debugTickerActive, isFalse);
    expect(app.sfx.held, isTrue);
    // reklam kapandı
    final int wait = await _until(t, () => _game(16).evaluate().isNotEmpty, maxMs: 10000);
    expect(wait, greaterThanOrEqualTo(0));
    expect(app.mon.isAdShowing, isFalse);
    await _expectPlayable(t, app, 16);
    await _finish(t);
  });

  testWidgets('reklam yokken seviye 17 sonrası da akış sürer (art arda iki seviye geçişi)', (WidgetTester t) async {
    final FakePlatform fp = FakePlatform()..hangInterstitial = true;
    final AppController app = await _boot(t, fp, level: 15);
    await _transition(t, app, 15);
    await _transition(t, app, 16);
    await _expectPlayable(t, app, 17);
    await _finish(t);
  });
}
