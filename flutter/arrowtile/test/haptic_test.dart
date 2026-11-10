// 1.1.5 (docs/22): ok hareketi başına TEK kısa titreşim. Eskiden _tapArrow önce buzz('tap'), sonra slideOut/bump titretiyordu;
// telefon yüzeyde dururken iki titreşim ok sesinden önce fazladan "tık" gibi duyuluyordu.
import 'package:arrowtile/config/ads_config.dart';
import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/services/haptics_service.dart';
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

void main() {
  tearDown(() {
    AdsConfig.autoPlayTestOverride = false;
    BoardModel.testClock = null;
    HapticsService.debugSink = null;
  });

  testWidgets('otomatik oynanan seviyede her ok için tam bir titreşim (slideOut/bump); "tap" titreşimi yok', (WidgetTester t) async {
    final List<String> buzzes = <String>[];
    HapticsService.debugSink = buzzes.add;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AdsConfig.autoPlayTestOverride = true;
    BoardModel.testClock = () => t.binding.clock.now().microsecondsSinceEpoch / 1000.0;
    final AppController? made = await t.runAsync(() => AppController.create(adsPlatform: FakePlatform()));
    final AppController app = made!;
    app.save.lang = 'en';
    app.save.unlocked = 5;
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
    final int arrows = app.getLevel(5)!.arrows.length;
    app.navKey.currentState!.push(fadeRoute<void>(GameScreen(level: app.getLevel(5)!)));
    await t.pump(const Duration(milliseconds: 300));
    int ms = 0;
    while (find.text('Level complete!').evaluate().isEmpty && ms < 120000) {
      await t.pump(const Duration(milliseconds: 100));
      ms += 100;
    }
    expect(find.text('Level complete!'), findsOneWidget, reason: 'seviye otomatik çözülmeli');
    expect(buzzes.where((String b) => b == 'tap'), isEmpty, reason: 'ok hareketinde ayrı "tap" titreşimi olmamalı');
    final int moves = buzzes.where((String b) => b == 'slideOut' || b == 'bump').length;
    expect(buzzes.where((String b) => b == 'slideOut').length, arrows, reason: 'her ok çıkışında tek slideOut');
    expect(moves, greaterThanOrEqualTo(arrows));
    // ardışık iki titreşim aynı ok hareketinden gelmez: slideOut'tan hemen önce 'tap' yok
    for (int i = 0; i < buzzes.length - 1; i++) {
      expect(buzzes[i] == 'tap' && (buzzes[i + 1] == 'slideOut' || buzzes[i + 1] == 'bump'), isFalse);
    }
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 5));
  });
}
