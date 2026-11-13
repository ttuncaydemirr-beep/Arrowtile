// 1.2.2 (docs/28): büyük ekran / yatay / katlanabilir desteği.
//  - Yön politikası: en kısa kenar < 600 dp → yalnızca dikey; ≥ 600 dp → tüm yönler.
//  - 1280×800 (tablet yatay), 800×1280 (tablet dikey), 2208×1840 (katlanabilir açık): menü, harita, oyun, ayarlar ve mağaza taşmadan çizilir
//    (tr ve ar-RTL), içerik en çok 520 dp genişliğinde ortalanmış sütundur; menü/haritada banner yuvası 56 dp ve ≥ 16 dp boşluklu kalır.
import 'package:arrowtile/config/ads_config.dart';
import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:arrowtile/state/app_scope.dart';
import 'package:arrowtile/ui/ad_banner.dart';
import 'package:arrowtile/ui/board_painter.dart' show BoardModel, BoardPainter;
import 'package:arrowtile/ui/flow.dart';
import 'package:arrowtile/ui/orientation_policy.dart';
import 'package:arrowtile/ui/screens/game_screen.dart';
import 'package:arrowtile/ui/screens/map_screen.dart';
import 'package:arrowtile/ui/screens/menu_screen.dart';
import 'package:arrowtile/ui/screens/settings_screen.dart';
import 'package:arrowtile/ui/screens/shop_screen.dart';
import 'package:arrowtile/ui/widgets.dart' show AppButton, Pressable, kContentMaxWidth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';

const Key _strip = ValueKey<String>('ad-banner-strip');

const Map<String, Size> _sizes = <String, Size>{
  '1280x800': Size(1280, 800),
  '800x1280': Size(800, 1280),
  '2208x1840': Size(2208, 1840),
};

Future<AppController> _boot(WidgetTester t, Size size, String lang, {Widget home = const MenuScreen()}) async {
  t.view.devicePixelRatio = 1.0;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  AdsConfig.autoPlayTestOverride = false;
  BoardModel.testClock = () => t.binding.clock.now().microsecondsSinceEpoch / 1000.0;
  AdBannerSlot.debugLoader = (int w, {required onLoaded, required onFailed, onImpression}) {}; // reklam gelmez, yer ayrılı kalır
  final AppController? made = await t.runAsync(() => AppController.create(adsPlatform: FakePlatform(), bannerBucket: 99));
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
      home: home,
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  return app;
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 5));
}

/// Banner yuvası 56 dp; hiçbir görünen dokunulabilir öğe yuvaya 16 dp'den yakın değil.
void _expectBannerRules(WidgetTester t, String what) {
  expect(find.byKey(_strip), findsOneWidget, reason: '$what: banner yuvası ayrılmış olmalı');
  final Rect strip = t.getRect(find.byKey(_strip));
  expect(strip.height, closeTo(kBannerSlotHeight, 0.5), reason: '$what: yuva 56 dp');
  final Rect screen = Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;
  for (final Element e in find.byType(Pressable).evaluate()) {
    final RenderBox? box = e.renderObject as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) continue;
    Rect r = box.localToGlobal(Offset.zero) & box.size;
    final Finder scroll = find.ancestor(of: find.byElementPredicate((Element x) => identical(x, e)), matching: find.byType(Scrollable));
    if (scroll.evaluate().isNotEmpty) r = r.intersect(t.getRect(scroll.first));
    r = r.intersect(screen);
    if (r.width <= 0 || r.height <= 0) continue;
    expect(strip.top - r.bottom, greaterThanOrEqualTo(16), reason: '$what: $r banner yuvasına çok yakın');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    AdBannerSlot.debugLoader = null;
    BoardModel.testClock = null;
  });

  group('yön politikası', () {
    test('telefon (en kısa kenar < 600) yalnızca dikey', () {
      expect(isLargeScreen(const Size(360, 640)), isFalse);
      expect(isLargeScreen(const Size(599, 1200)), isFalse);
      expect(orientationsFor(const Size(412, 915)), <DeviceOrientation>[DeviceOrientation.portraitUp]);
      expect(orientationsFor(const Size(915, 412)), <DeviceOrientation>[DeviceOrientation.portraitUp]);
    });
    test('tablet / açık katlanabilir (en kısa kenar ≥ 600) tüm yönler', () {
      expect(isLargeScreen(const Size(600, 960)), isTrue);
      for (final Size s in _sizes.values) {
        expect(isLargeScreen(s), isTrue, reason: '$s');
        expect(orientationsFor(s).toSet(), DeviceOrientation.values.toSet(), reason: '$s');
      }
    });
  });

  for (final MapEntry<String, Size> e in _sizes.entries) {
    for (final String lang in <String>['tr', 'ar']) {
      final String tag = '${e.key} $lang';

      testWidgets('$tag: menü taşmaz, sütun ≤ $kContentMaxWidth dp ve ortada, banner kuralları sürer', (WidgetTester t) async {
        await _boot(t, e.value, lang);
        expect(t.takeException(), isNull);
        final Rect play = t.getRect(find.byType(AppButton).first); // oynat / devam düğmesi
        expect(play.width, lessThanOrEqualTo(kContentMaxWidth));
        expect((play.center.dx - e.value.width / 2).abs(), lessThan(1.0), reason: 'oynat düğmesi pencerenin ortasında');
        _expectBannerRules(t, 'menu/$tag');
        await _finish(t);
      });

      testWidgets('$tag: harita taşmaz, banner kuralları sürer', (WidgetTester t) async {
        await _boot(t, e.value, lang, home: const MapScreen());
        expect(t.takeException(), isNull);
        _expectBannerRules(t, 'map/$tag');
        await _finish(t);
      });

      testWidgets('$tag: oyun ekranı taşmaz, tahta sütunda ve ekran yüksekliğine sığar', (WidgetTester t) async {
        final AppController app = await _boot(t, e.value, lang, home: const Scaffold(body: SizedBox.expand()));
        app.navKey.currentState!.push(fadeRoute<void>(GameScreen(level: app.getLevel(89)!)));
        await t.pump(const Duration(milliseconds: 400));
        await t.pump(const Duration(milliseconds: 400));
        expect(t.takeException(), isNull);
        final Rect paint = t.getRect(find.byWidgetPredicate((Widget w) => w is CustomPaint && w.painter is BoardPainter));
        expect(paint.width, lessThanOrEqualTo(kContentMaxWidth + 0.5));
        expect(paint.height, greaterThan(e.value.height * 0.5), reason: 'tahta alanı yüksekliğin büyük kısmını kullanır');
        expect(paint.bottom, lessThanOrEqualTo(e.value.height));
        await _finish(t);
      });

      testWidgets('$tag: ayarlar ve mağaza taşmaz', (WidgetTester t) async {
        await _boot(t, e.value, lang, home: const SettingsScreen());
        expect(t.takeException(), isNull);
        await _finish(t);
        await _boot(t, e.value, lang, home: const ShopScreen());
        expect(t.takeException(), isNull);
        await _finish(t);
      });
    }
  }
}
