// 1.1.5 (docs/22): HARİTA banner'ı menüyle AYNI paylaşılan yuva (AdBannerSlot) ve aynı düzen: tam genişlikte alt şerit, harita listesi
// ŞERİDİN ÜSTÜNDE (Column + Expanded; Stack/Positioned örtüsü yok), yüklenmeden hiçbir şey bağlanmaz; menü haritanın altında kalınca
// reklamını bırakır (aynı anda tek canlı banner).
import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:arrowtile/state/app_scope.dart';
import 'package:arrowtile/ui/ad_banner.dart';
import 'package:arrowtile/ui/flow.dart';
import 'package:arrowtile/ui/screens/map_screen.dart';
import 'package:arrowtile/ui/screens/menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';

const Key _strip = ValueKey<String>('ad-banner-strip');
const Key _ad = ValueKey<String>('ad-banner');

Future<AppController> _boot(WidgetTester t, Widget home) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  // test yazı tipi (Ahem) çok geniştir: harita bölüm başlığındaki metin taşması bu testin konusu değil
  final FlutterExceptionHandler? prev = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails d) {
    if (d.exceptionAsString().contains('overflowed')) return;
    prev?.call(d);
  };
  addTearDown(() => FlutterError.onError = prev);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppController? made = await t.runAsync(() => AppController.create(adsPlatform: FakePlatform()));
  final AppController app = made!;
  app.save.lang = 'en';
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
      home: home,
    ),
  ));
  return app;
}

Future<void> _end(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 5));
}

void main() {
  late int disposed;
  late int made;
  setUp(() {
    disposed = 0;
    made = 0;
  });
  tearDown(() {
    AdBannerSlot.debugLoader = null;
    AdBannerSlot.retryAfter = const Duration(seconds: 60);
  });

  void loader({int delayMs = 100}) {
    AdBannerSlot.debugLoader = (int w, {required onLoaded, required onFailed, onImpression}) {
      final int n = ++made;
      Future<void>.delayed(Duration(milliseconds: delayMs), () {
        onLoaded(BannerHandle(ColoredBox(key: ValueKey<String>('fake-ad-$n'), color: Colors.red), const Size(320, 100), () => disposed++));
      });
    };
  }

  testWidgets('harita: yüklenmeden hiçbir şey bağlanmaz; yüklenince tam genişlikte alt şerit, harita içeriği örtülmez', (WidgetTester t) async {
    loader(delayMs: 300);
    await _boot(t, const MapScreen());
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    // yüklenmeden: şerit de reklam görünümü de yok; harita listesi tüm yüksekliği kullanır
    expect(find.byKey(_strip), findsNothing);
    expect(find.byKey(_ad), findsNothing);
    expect(find.byWidgetPredicate((Widget w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('fake-ad')), findsNothing);
    final double listBottomBefore = t.getRect(find.byType(ListView)).bottom;
    final Rect scaffoldBefore = t.getRect(find.byType(Scaffold).last);

    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(find.byKey(_strip), findsOneWidget);
    final Rect strip = t.getRect(find.byKey(_strip));
    final Rect scaffold = t.getRect(find.byType(Scaffold).last);
    expect(strip.width, scaffold.width, reason: 'şerit tam genişlikte (daracık kutu değil)');
    expect(strip.height, 100);
    expect(strip.bottom, scaffold.bottom, reason: 'şerit en altta (SafeArea payı yok)');
    // reklam görünümü tam reklam boyutunda ve şeridin ortasında
    final Rect ad = t.getRect(find.byKey(_ad));
    expect(ad.size, const Size(320, 100));
    expect(ad.center.dx, closeTo(strip.center.dx, 0.5));
    // harita içeriği ŞERİDİN ÜSTÜNDE: örtüşme yok
    final Rect list = t.getRect(find.byType(ListView));
    expect(list.bottom, lessThanOrEqualTo(strip.top + 0.01), reason: 'harita şeridin altına taşmamalı (Column + Expanded)');
    expect(list.bottom, closeTo(listBottomBefore - 100, 0.5));
    expect(scaffoldBefore, scaffold);
    // şerit, kaydırılan listenin / Stack örtüsünün içinde değil
    expect(find.descendant(of: find.byType(ListView), matching: find.byKey(_strip)), findsNothing);
    expect(find.ancestor(of: find.byKey(_ad), matching: find.byType(ListView)), findsNothing);
    expect(find.ancestor(of: find.byKey(_ad), matching: find.byType(Positioned)), findsNothing);
    expect(find.ancestor(of: find.byKey(_ad), matching: find.byType(Opacity)), findsNothing);
    expect(find.ancestor(of: find.byKey(_ad), matching: find.byType(Transform)), findsNothing);
    expect(find.ancestor(of: find.byKey(_ad), matching: find.byType(ClipRect)), findsNothing);
    await _end(t);
  });

  testWidgets('menü ve harita aynı yuvayı ve aynı şerit düzenini kullanır', (WidgetTester t) async {
    loader();
    await _boot(t, const MenuScreen());
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    final Rect menuStrip = t.getRect(find.byKey(_strip));
    expect(find.byType(AdBannerSlot), findsOneWidget);
    expect(menuStrip.width, t.getRect(find.byType(Scaffold).last).width);
    await _end(t);

    loader();
    made = 0;
    await _boot(t, const MapScreen());
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(AdBannerSlot), findsOneWidget);
    expect(t.getRect(find.byKey(_strip)), menuStrip, reason: 'harita şeridi menüyle birebir aynı konum/boyut');
    await _end(t);
  });

  testWidgets('menüden haritaya geçince menünün reklamı bırakılır: aynı anda tek canlı banner', (WidgetTester t) async {
    loader();
    final AppController app = await _boot(t, const MenuScreen());
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey<String>('fake-ad-1')), findsOneWidget);
    expect(disposed, 0);

    app.navKey.currentState!.push(fadeRoute<void>(const MapScreen()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300)); // geçiş bitti; menü Offstage
    await t.pump(const Duration(milliseconds: 300)); // harita reklamı yüklendi
    await t.pump();
    expect(disposed, 1, reason: 'altta kalan menünün banner reklamı bırakılmalı');
    expect(find.byType(AdBannerSlot), findsOneWidget);
    expect(find.byKey(_ad), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('fake-ad-1')), findsNothing);

    // geri dönünce menü reklamını yeniden ister
    app.navKey.currentState!.pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    expect(find.byType(MenuScreen), findsOneWidget);
    expect(find.byKey(_ad), findsOneWidget);
    await _end(t);
  });
}
