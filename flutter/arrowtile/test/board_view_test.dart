// 1.2.0 (docs/26 §B): büyük tahta görünümü — web e2e (G2) karşılığı.
//  - 28x45 tahtada varsayılan hücre ≥ 20 px, tahta kaydırılabilir, "Sığdır" düğmesi görünür; Sığdır → tüm tahta (sMin) ↔ Yakınlaştır.
//  - Kaydırma (sürükleme) ASLA ok oynatmaz; kenarda durur.
//  - İsabet HÜCRE bazlı: okun her hücresinin her yerine (köşe dahil) dokunmak o oku seçer.
//  - Dokunuş çıkışı başlatır; 110 ms içinde ikinci dokunuş yok sayılır, sonra kabul edilir.
//  - Ok rengi ayarı (Renkli / Tek renk) kalıcıdır.
import 'package:arrowtile/core/engine.dart' show bestHint;
import 'package:arrowtile/core/levelgen.dart';
import 'package:arrowtile/core/models.dart';
import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:arrowtile/state/app_scope.dart';
import 'package:arrowtile/ui/board_painter.dart';
import 'package:arrowtile/ui/flow.dart';
import 'package:arrowtile/ui/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';

Future<AppController> _open(WidgetTester t, Level lv) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  BoardModel.testClock = () => t.binding.clock.now().microsecondsSinceEpoch / 1000.0;
  final AppController? made = await t.runAsync(() => AppController.create(adsPlatform: FakePlatform()));
  final AppController app = made!;
  app.save.lang = 'en';
  app.save.unlocked = lv.id;
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
  app.navKey.currentState!.push(fadeRoute<void>(GameScreen(level: lv)));
  for (int i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  return app;
}

Finder get _board => find.byWidgetPredicate((Widget w) => w is CustomPaint && w.painter is BoardPainter);

Future<void> _close(WidgetTester t, AppController app) async {
  app.navKey.currentState!.pop();
  await t.pump(const Duration(milliseconds: 500));
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 5));
}

void main() {
  tearDown(() => BoardModel.testClock = null);

  testWidgets('28x45: hücre ≥ 20 px, kaydırılabilir, Sığdır ↔ Yakınlaştır; kaydırma ok oynatmaz; hücre bazlı isabet', (WidgetTester t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final Level lv = makeLevel(176).toLevel(); // bölüm 9, Aşırı zor, 28x45
    expect(lv.w, 28);
    expect(lv.h, 45);
    final AppController app = await _open(t, lv);
    final dynamic st = t.state(find.byType(GameScreen));
    final dynamic v0 = st.debugView;
    expect(v0.cell as double, greaterThanOrEqualTo(20));
    expect(v0.pannable as bool, isTrue);
    expect(find.byKey(const ValueKey<String>('btn-fit')), findsOneWidget);
    final int before = st.debugRemaining as int;

    // sürükleme = kaydırma; hiçbir ok oynamaz
    final Offset c = t.getCenter(_board);
    final TestGesture gs = await t.startGesture(c);
    for (int k = 1; k <= 12; k++) {
      await gs.moveTo(c + Offset(-10.0 * k, -14.0 * k));
      await t.pump(const Duration(milliseconds: 16));
    }
    await gs.up();
    await t.pump(const Duration(milliseconds: 600));
    expect(st.debugRemaining, before, reason: 'kaydırma dokunuş sayılmamalı');
    final dynamic v1 = st.debugView;
    expect((v1.x as double) != (v0.x as double) || (v1.y as double) != (v0.y as double), isTrue, reason: 'görünüm kaymalı');

    // hücre bazlı isabet: her okun her hücresinin merkezi ve köşeye yakın noktası o oku verir
    for (int i = 0; i < lv.arrows.length; i += 7) {
      for (final List<int> q in lv.arrows[i].cells) {
        for (final Offset f in const <Offset>[Offset(0.5, 0.5), Offset(0.08, 0.92), Offset(0.93, 0.07)]) {
          final Offset p = st.debugBoardPoint(q[0] + f.dx, q[1] + f.dy) as Offset;
          final (int, List<int>?) h = st.debugHitTest(p.dx, p.dy) as (int, List<int>?);
          expect(h.$1, i, reason: 'ok $i hücre $q nokta $f');
        }
      }
    }

    // Sığdır → tüm tahta görünür (s = sMin < 1); tekrar → varsayılan yakınlık
    await t.tap(find.byKey(const ValueKey<String>('btn-fit')));
    await t.pump(const Duration(milliseconds: 400));
    final dynamic v2 = st.debugView;
    expect(v2.overview as bool, isTrue);
    expect(v2.s as double, closeTo(v2.sMin as double, 1e-6));
    await t.tap(find.byKey(const ValueKey<String>('btn-fit')));
    await t.pump(const Duration(milliseconds: 400));
    expect((st.debugView).s as double, closeTo(1, 1e-6));
    expect(st.debugRemaining, before);
    await _close(t, app);
  });

  testWidgets('dokunuş çıkışı başlatır; 110 ms giriş kilidi; küçük tahta sığar (Sığdır yok)', (WidgetTester t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final Level lv = makeLevel(25).toLevel(); // bölüm 2 Orta (9x14)
    final AppController app = await _open(t, lv);
    final dynamic st = t.state(find.byType(GameScreen));
    expect((st.debugView).pannable as bool, isFalse);
    expect(find.byKey(const ValueKey<String>('btn-fit')), findsNothing);
    final Offset tl = t.getTopLeft(_board);
    final List<bool> alive = List<bool>.filled(lv.arrows.length, true);
    final int a = bestHint(lv, alive);
    alive[a] = false;
    final int b = bestHint(lv, alive);
    expect(a >= 0 && b >= 0 && a != b, isTrue);
    Offset at(int i) {
      final List<int> q = lv.arrows[i].cells.first;
      return tl + (st.debugBoardPoint(q[0] + 0.5, q[1] + 0.5) as Offset);
    }

    final int n0 = st.debugRemaining as int;
    await t.tapAt(at(a));
    await t.pump(const Duration(milliseconds: 20));
    expect(st.debugRemaining, n0 - 1);
    await t.tapAt(at(b)); // kilit süresi içinde: yok sayılır
    await t.pump(const Duration(milliseconds: 20));
    expect(st.debugRemaining, n0 - 1, reason: '110 ms içinde ikinci dokunuş yok sayılmalı');
    await t.pump(const Duration(milliseconds: 120));
    await t.tapAt(at(b));
    await t.pump(const Duration(milliseconds: 20));
    expect(st.debugRemaining, n0 - 2, reason: 'kilit bitince dokunuş kabul edilir');
    await t.pump(const Duration(milliseconds: 1500));
    await _close(t, app);
  });

  testWidgets('ok rengi ayarı kalıcı (Renkli varsayılan, Tek renk)', (WidgetTester t) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppController? made = await t.runAsync(() => AppController.create(adsPlatform: FakePlatform()));
    final AppController app = made!;
    expect(app.save.arrowColor, 'color');
    app.setArrowColor('mono');
    app.setArrowColor('bogus'); // geçersiz: değişmez
    expect(app.save.arrowColor, 'mono');
    final AppController? again = await t.runAsync(() => AppController.create(adsPlatform: FakePlatform()));
    expect(again!.save.arrowColor, 'mono');
  });
}
