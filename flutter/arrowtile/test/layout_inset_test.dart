// 1.1.6 (docs/23): hayalet alt pay (viewInsets.bottom) ve büyük yazı ölçeğinde oyun düzeni.
// Hata: Scaffold varsayılanı resizeToAvoidBottomInset:true klavye payı kadar gövdeyi küçültüyordu; arayüz üst %55'e sıkışıyordu.
import 'package:arrowtile/config/ads_config.dart';
import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:arrowtile/state/app_scope.dart';
import 'package:arrowtile/ui/board_painter.dart' show BoardModel, BoardPainter;
import 'package:arrowtile/ui/flow.dart';
import 'package:arrowtile/ui/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';

Future<AppController> _boot(WidgetTester t, String lang) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  AdsConfig.autoPlayTestOverride = false;
  BoardModel.testClock = () => t.binding.clock.now().microsecondsSinceEpoch / 1000.0;
  final AppController? made = await t.runAsync(() => AppController.create(adsPlatform: FakePlatform()));
  final AppController app = made!;
  app.save.lang = lang;
  app.save.unlocked = 100;
  await t.pumpWidget(AppScope(
    controller: app,
    child: MaterialApp(
      navigatorKey: app.navKey,
      locale: Locale(lang),
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
  app.navKey.currentState!.push(fadeRoute<void>(GameScreen(level: app.getLevel(89)!)));
  await t.pump(const Duration(milliseconds: 400));
  return app;
}

void _setView(WidgetTester t, {double insetBottom = 0}) {
  t.view.devicePixelRatio = 1.0;
  t.view.physicalSize = const Size(412, 915);
  t.view.viewInsets = FakeViewPadding(bottom: insetBottom);
  addTearDown(t.view.reset);
}

void main() {
  tearDown(() {
    BoardModel.testClock = null;
  });

  testWidgets('viewInsets.bottom=400: oyun alanı araç çubuğuna kadar uzar, araç çubuğu ekranın dibinde', (WidgetTester t) async {
    _setView(t, insetBottom: 400);
    await _boot(t, 'de');
    final Rect tool = t.getRect(find.byIcon(Icons.lightbulb));
    expect(tool.bottom, greaterThan(915 * 0.8), reason: 'araç çubuğu ekranın altında olmalı (klavye payı gövdeyi küçültmemeli)');
    final Rect paint = t.getRect(find.byWidgetPredicate((Widget w) => w is CustomPaint && w.painter is BoardPainter));
    expect(paint.height, greaterThan(915 * 0.6), reason: 'tahta alanı ekranın büyük kısmını doldurmalı');
    expect(paint.bottom, lessThanOrEqualTo(tool.top + 1));
    expect(t.takeException(), isNull);
  });

  testWidgets('yazı ölçeği 1,5, 412x915: taşma yok, araç çubuğu altta', (WidgetTester t) async {
    _setView(t);
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await _boot(t, 'de');
    expect(t.takeException(), isNull, reason: 'RenderFlex taşması olmamalı');
    final Rect tool = t.getRect(find.byIcon(Icons.lightbulb));
    expect(tool.bottom, greaterThan(915 * 0.8));
    final Rect paint = t.getRect(find.byWidgetPredicate((Widget w) => w is CustomPaint && w.painter is BoardPainter));
    expect(paint.height, greaterThan(915 * 0.6));
  });
}
