// 1.2.1 (docs/27 §A): banner düzeni ve politikası.
//  - 360×640 dp ekranda (en/tr/ar-RTL, yazı ölçeği 1,0 ve 1,3) menüde ve haritada hiçbir dokunulabilir öğe banner yuvasına 16 dp'den yakın değil.
//  - Ayarlar üst çubukta (dişli, erişilebilir etiket); alt "Ayarlar" düğmesi yok.
//  - Kontrol grubu (holdout) ve yerleştirme başına uzaktan kapatma: yuva hiç yer kaplamaz.
//  - "Reklamları kaldır" satın alımı banner'ı ve ayrılan yeri HEMEN kaldırır.
import 'dart:math' as math;

import 'package:arrowtile/core/ads_rules.dart';
import 'package:arrowtile/core/banner_policy.dart';
import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/services/save_store.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:arrowtile/state/app_scope.dart';
import 'package:arrowtile/ui/ad_banner.dart';
import 'package:arrowtile/ui/screens/diag_screen.dart' show diagReport;
import 'package:arrowtile/ui/screens/map_screen.dart';
import 'package:arrowtile/ui/screens/menu_screen.dart';
import 'package:arrowtile/ui/widgets.dart' show Pressable;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';
import 'fake_telemetry.dart';

const Key _strip = ValueKey<String>('ad-banner-strip');
const Key _ad = ValueKey<String>('ad-banner');

Future<AppController> _boot(WidgetTester t, Widget home,
    {String lang = 'en', double scale = 1.0, int? bucket, RemoteFlags? remote, FakePlatform? fp, FakeTelemetry? tel}) async {
  t.view.physicalSize = const Size(360, 640);
  t.view.devicePixelRatio = 1.0;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  // test yazı tipi (Ahem) çok geniştir: metin taşması bu testin konusu değil (yerleşim ölçülür)
  final void Function(FlutterErrorDetails)? prev = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails d) {
    if (d.exceptionAsString().contains('overflowed')) return;
    prev?.call(d);
  };
  addTearDown(() => FlutterError.onError = prev);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppController? made = await t.runAsync(
      () => AppController.create(adsPlatform: fp ?? FakePlatform(), telemetry: tel, bannerBucket: bucket, remote: remote));
  final AppController app = made!;
  app.save.lang = lang;
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
  await t.pump(const Duration(milliseconds: 300));
  return app;
}

Future<void> _end(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 5));
}

/// Görünen dokunulabilir öğelerin (Pressable: AppButton, IconSquareButton, harita düğümleri) ekranda görünen dikdörtgenleri
/// (kaydırılan içerikte görünüm alanıyla kırpılmış).
List<Rect> _visibleTappables(WidgetTester t) {
  final Rect screen = Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;
  final List<Rect> out = <Rect>[];
  for (final Element e in find.byType(Pressable).evaluate()) {
    final RenderBox? box = e.renderObject as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) continue;
    Rect r = box.localToGlobal(Offset.zero) & box.size;
    final Finder scroll = find.ancestor(of: find.byElementPredicate((Element x) => identical(x, e)), matching: find.byType(Scrollable));
    if (scroll.evaluate().isNotEmpty) r = r.intersect(t.getRect(scroll.first));
    r = r.intersect(screen);
    if (r.width <= 0 || r.height <= 0) continue;
    out.add(r);
  }
  return out;
}

void _expectGap(WidgetTester t, String what) {
  expect(find.byKey(_strip), findsOneWidget, reason: '$what: banner yuvası ayrılmış olmalı');
  final Rect strip = t.getRect(find.byKey(_strip));
  final List<Rect> taps = _visibleTappables(t);
  expect(taps, isNotEmpty, reason: what);
  double minGap = double.infinity;
  for (final Rect r in taps) {
    // yuva en altta: her öğe yuvanın ÜSTÜNDE ve en az 16 dp uzakta olmalı
    final double gap = strip.top - r.bottom;
    if (gap < minGap) minGap = gap;
    expect(gap, greaterThanOrEqualTo(16), reason: '$what: $r banner yuvasına (${strip.top}) ${gap.toStringAsFixed(1)} dp');
  }
  // ignore: avoid_print
  print('BANNER_GAP $what min=${minGap.toStringAsFixed(1)} dp (öğe: ${taps.length})');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    AdBannerSlot.debugLoader = null;
    AdBannerSlot.retryAfter = const Duration(seconds: 60);
  });

  // Reklam hiç gelmez (yalnızca ayrılmış yer): en kötü durum ölçümü düzen için aynıdır (yer sabit).
  void neverLoads() => AdBannerSlot.debugLoader = (int w, {required onLoaded, required onFailed, onImpression}) {};

  for (final String lang in <String>['en', 'tr', 'ar']) {
    for (final double scale in <double>[1.0, 1.3]) {
      testWidgets('360×640 $lang yazı ×$scale: menüde hiçbir düğme banner yuvasına 16 dp\'den yakın değil', (WidgetTester t) async {
        neverLoads();
        await _boot(t, const MenuScreen(), lang: lang, scale: scale);
        _expectGap(t, 'menu/$lang/$scale');
        // Ayarlar üst çubukta (yuvadan en uzak bölge), en altta değil
        final Rect gear = t.getRect(find.byKey(const ValueKey<String>('menu-settings')));
        expect(gear.top, lessThan(80));
        await _end(t);
      });

      testWidgets('360×640 $lang yazı ×$scale: haritada hiçbir düğüm banner yuvasına 16 dp\'den yakın değil', (WidgetTester t) async {
        neverLoads();
        await _boot(t, const MapScreen(), lang: lang, scale: scale);
        _expectGap(t, 'map/$lang/$scale');
        // harita listesinin sonu ile yuva arasında ≥ 16 dp
        expect(t.getRect(find.byKey(_strip)).top - t.getRect(find.byType(ListView)).bottom, greaterThanOrEqualTo(16));
        await _end(t);
      });
    }
  }

  testWidgets('Ayarlar düğmesi üst çubukta, erişilebilir etiketi 4 dilde; altta Ayarlar düğmesi yok', (WidgetTester t) async {
    for (final String lang in <String>['tr', 'en', 'de', 'ar']) {
      neverLoads();
      await _boot(t, const MenuScreen(), lang: lang);
      final AppLocalizations loc = AppLocalizations.of(t.element(find.byType(MenuScreen)));
      expect(find.byWidgetPredicate((Widget w) => w is Semantics && w.properties.label == loc.menuSettings && w.properties.button == true),
          findsOneWidget,
          reason: lang);
      expect(find.descendant(of: find.byKey(const ValueKey<String>('menu-settings')), matching: find.byIcon(Icons.settings_outlined)), findsOneWidget);
      expect(find.text(loc.menuSettings), findsNothing, reason: '$lang: menü gövdesinde yazılı Ayarlar düğmesi kalmadı');
      await _end(t);
    }
  });

  testWidgets('kontrol grubu (kova < %50): menü ve haritada banner yok, yer de ayrılmaz; istek atılmaz', (WidgetTester t) async {
    int calls = 0;
    AdBannerSlot.debugLoader = (int w, {required onLoaded, required onFailed, onImpression}) => calls++;
    final AppController app = await _boot(t, const MenuScreen(), bucket: 10);
    expect(app.bannerPolicy.holdout, isTrue);
    expect(app.bannerPolicy.group, 'holdout');
    expect(find.byKey(_strip), findsNothing);
    await _end(t);
    await _boot(t, const MapScreen(), bucket: 49);
    expect(find.byKey(_strip), findsNothing);
    expect(calls, 0);
    await _end(t);
    // sınır: kova 50 → banner grubu
    final AppController b = await _boot(t, const MenuScreen(), bucket: 50);
    expect(b.bannerPolicy.group, 'banner');
    expect(find.byKey(_strip), findsOneWidget);
    await _end(t);
  });

  testWidgets('Tanılama raporu banner grubunu ve ayarları gösterir', (WidgetTester t) async {
    neverLoads();
    final AppController app = await _boot(t, const MenuScreen(), bucket: 10);
    final String rep = diagReport(app);
    expect(rep, contains('banner_group: holdout'));
    expect(rep, contains('banner_bucket: 10'));
    expect(rep, contains('banner_holdout_pct: 50'));
    expect(rep, contains('banner_menu: true'));
    expect(rep, contains('banner_cfg: default'));
    await _end(t);
  });

  testWidgets('uzaktan kapatma yerleştirme başına: banner_menu_enabled=false → menüde yok, haritada var', (WidgetTester t) async {
    neverLoads();
    const RemoteFlags rf = StaticRemoteFlags(<String, Object>{kRcBannerMenu: false, kRcBannerHoldoutPct: 0});
    await _boot(t, const MenuScreen(), bucket: 0, remote: rf);
    expect(find.byKey(_strip), findsNothing);
    await _end(t);
    await _boot(t, const MapScreen(), bucket: 0, remote: rf);
    expect(find.byKey(_strip), findsOneWidget);
    await _end(t);
  });

  testWidgets('"Reklamları kaldır" satın alınınca banner ve ayrılan yer HEMEN kalkar (reklam bırakılır)', (WidgetTester t) async {
    int disposed = 0;
    AdBannerSlot.debugLoader = (int w, {required onLoaded, required onFailed, onImpression}) {
      onLoaded(BannerHandle(const ColoredBox(key: ValueKey<String>('fake-ad'), color: Colors.red), const Size(320, 50), () => disposed++));
    };
    final FakePlatform fp = FakePlatform();
    final AppController app = await _boot(t, const MenuScreen(), fp: fp);
    await t.pump();
    expect(find.byKey(_ad), findsOneWidget);
    final Future<PurchaseResult> f = app.mon.purchaseRemoveAds();
    await t.pump();
    final PurchaseResult r = await f;
    expect(r.ok, isTrue);
    app.commit(); // AdsCard satın alma sonrası
    await t.pump();
    await t.pump();
    expect(find.byKey(_ad), findsNothing);
    expect(find.byKey(_strip), findsNothing);
    expect(disposed, 1);
    expect(app.mon.bannerVisible(AdScreen.menu), isFalse);
    expect(app.mon.bannerVisible(AdScreen.map), isFalse);
    await _end(t);
  });

  group('BannerPolicy', () {
    test('varsayılanlar: menü + harita açık, %50 kontrol grubu; kova kararlı', () {
      for (int b = 0; b < 100; b++) {
        final BannerPolicy p = BannerPolicy.from(const DefaultRemoteFlags(), b);
        expect(p.holdout, b < 50, reason: 'kova $b');
        expect(p.allows(AdScreen.menu), b >= 50);
        expect(p.allows(AdScreen.map), b >= 50);
        expect(p.allows(AdScreen.game), isFalse);
        expect(p.source, 'default');
      }
    });

    test('yüzde 0..100 kırpılır; 0 → herkes banner, 100 → herkes holdout', () {
      expect(BannerPolicy.from(const StaticRemoteFlags(<String, Object>{kRcBannerHoldoutPct: -5}), 0).holdout, isFalse);
      expect(BannerPolicy.from(const StaticRemoteFlags(<String, Object>{kRcBannerHoldoutPct: 500}), 99).holdout, isTrue);
      expect(BannerPolicy.from(const StaticRemoteFlags(<String, Object>{kRcBannerHoldoutPct: 0}), 0).group, 'banner');
    });

    test('Monetization varsayılanı kısıtsız (eski davranış)', () {
      expect(BannerPolicy.allOn.holdout, isFalse);
      expect(BannerPolicy.allOn.allows(AdScreen.menu), isTrue);
      expect(BannerPolicy.allOn.allows(AdScreen.map), isTrue);
    });

    test('kurulum kovası kalıcı (ikinci açılışta aynı grup); bozuk değer yenilenir', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final int b1 = (await SaveStore.open()).bannerBucket(math.Random(7));
      expect(b1, inInclusiveRange(0, 99));
      expect((await SaveStore.open()).bannerBucket(math.Random(8)), b1);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(SaveStore.bannerBucketKey), b1);
      SharedPreferences.setMockInitialValues(<String, Object>{SaveStore.bannerBucketKey: 250});
      final int b2 = (await SaveStore.open()).bannerBucket(math.Random(9));
      expect(b2, inInclusiveRange(0, 99));
    });

    test('telemetri: banner_group yalnızca holdout | banner; banner_loaded / banner_failed parametreleri', () async {
      final FakeTelemetry tel = FakeTelemetry();
      tel.setBannerGroup('holdout');
      tel.setBannerGroup('xyz');
      tel.bannerLoaded(placement: 'map');
      tel.bannerFailed(placement: 'menu', code: 3);
      await Future<void>.delayed(Duration.zero);
      expect(tel.userProps['banner_group'], 'holdout');
      expect(tel.named('banner_loaded').single.params, <String, Object>{'placement': 'map'});
      expect(tel.named('banner_failed').single.params, <String, Object>{'placement': 'menu', 'code': 3});
    });
  });
}
