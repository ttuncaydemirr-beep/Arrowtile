// 1.1.4 (docs/21): banner görünürlüğü — menü/haritada yüklenince görünür (yer kaplar), yüklenemezse yer kaplamaz ve yeniden denenir;
// her olay tanılama kaydına ve telemetriye yazılır. Gerçek AdMob yerine sahte yükleyici (AdBannerSlot.debugLoader).
import 'package:arrowtile/core/ads_rules.dart';
import 'package:arrowtile/core/diag.dart';
import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:arrowtile/state/app_scope.dart';
import 'package:arrowtile/ui/ad_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';
import 'fake_telemetry.dart';

Future<AppController> _boot(WidgetTester t, FakePlatform fp, AdScreen screen, {FakeTelemetry? tel}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppController? made = await t.runAsync(() => AppController.create(adsPlatform: fp, telemetry: tel));
  final AppController app = made!;
  app.save.lang = 'en';
  await t.pumpWidget(AppScope(
    controller: app,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Column(children: <Widget>[
          const Expanded(child: SizedBox.expand(key: ValueKey<String>('content'))),
          AdBannerSlot(screen: screen),
        ]),
      ),
    ),
  ));
  return app;
}

void main() {
  late List<int> widths;
  tearDown(() {
    AdBannerSlot.debugLoader = null;
    AdBannerSlot.retryAfter = const Duration(seconds: 60);
  });
  setUp(() => widths = <int>[]);

  void loaderOk() {
    AdBannerSlot.debugLoader = (int w, {required onLoaded, required onFailed, onImpression}) {
      widths.add(w);
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        onLoaded(BannerHandle(const ColoredBox(key: ValueKey<String>('fake-ad'), color: Colors.red), const Size(320, 50), () {}));
        onImpression?.call();
      });
    };
  }

  for (final AdScreen screen in <AdScreen>[AdScreen.menu, AdScreen.map]) {
    testWidgets('${screen.name}: yüklenince banner görünür ve 50 px yer kaplar; olaylar kayda/telemetriye yazılır', (WidgetTester t) async {
      DiagLog.I.clear();
      loaderOk();
      final FakeTelemetry tel = FakeTelemetry();
      await _boot(t, FakePlatform(), screen, tel: tel);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey<String>('fake-ad')), findsOneWidget);
      expect(t.getSize(find.byKey(const ValueKey<String>('ad-banner'))), const Size(320, 50));
      expect(widths.single, greaterThan(0), reason: 'genişlik 0 ile istenmemeli');
      expect(DiagLog.I.where('banner', 'loaded'), isNotEmpty);
      expect(tel.named('banner').map((LoggedEvent e) => e.params['result']), containsAll(<String>['load', 'loaded', 'impression']));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 5));
    });
  }

  testWidgets('yüklenemezse (no fill, kod 3) yer kaplamaz; hata kodu kayda yazılır; süre sonra yeniden denenir', (WidgetTester t) async {
    DiagLog.I.clear();
    AdBannerSlot.retryAfter = const Duration(seconds: 2);
    int calls = 0;
    AdBannerSlot.debugLoader = (int w, {required onLoaded, required onFailed, onImpression}) {
      calls++;
      Future<void>.delayed(const Duration(milliseconds: 20), () => onFailed(3, 'No fill.'));
    };
    final FakeTelemetry tel = FakeTelemetry();
    await _boot(t, FakePlatform(), AdScreen.menu, tel: tel);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey<String>('ad-banner')), findsNothing);
    final double contentH = t.getSize(find.byKey(const ValueKey<String>('content'))).height;
    expect(contentH, t.getSize(find.byType(Scaffold)).height, reason: 'başarısız banner boşluk bırakmaz');
    final DiagEntry e = DiagLog.I.where('banner', 'failed').last;
    expect(e.f['code'], 3);
    expect(tel.named('banner').any((LoggedEvent x) => x.params['result'] == 'failed' && x.params['code'] == 3), isTrue);
    expect(calls, 1);
    await t.pump(const Duration(seconds: 3));
    await t.pump();
    expect(calls, 2, reason: 'yeniden deneme');
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('uyarlanabilir boyut alınamazsa (kod -3) da yeniden denenir (1.1.3 hiç denemiyordu)', (WidgetTester t) async {
    AdBannerSlot.retryAfter = const Duration(seconds: 1);
    int calls = 0;
    AdBannerSlot.debugLoader = (int w, {required onLoaded, required onFailed, onImpression}) {
      calls++;
      if (calls == 1) {
        onFailed(-3, 'adaptive size null');
      } else {
        onLoaded(BannerHandle(const SizedBox(key: ValueKey<String>('fake-ad')), const Size(320, 50), () {}));
      }
    };
    await _boot(t, FakePlatform(), AdScreen.map);
    await t.pump();
    await t.pump(const Duration(milliseconds: 1500));
    await t.pump();
    await t.pump();
    expect(calls, 2);
    expect(find.byKey(const ValueKey<String>('fake-ad')), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('oyun / mağaza / ayarlar ekranında, reklamsızda ve SDK hazır değilken banner istenmez', (WidgetTester t) async {
    loaderOk();
    for (final AdScreen s in <AdScreen>[AdScreen.game, AdScreen.shop, AdScreen.settings, AdScreen.levelEnd, AdScreen.daily]) {
      await _boot(t, FakePlatform(), s);
      await t.pump(const Duration(milliseconds: 200));
    }
    final FakePlatform noSdk = FakePlatform()..sdk = false;
    await _boot(t, noSdk, AdScreen.menu);
    await t.pump(const Duration(milliseconds: 200));
    final FakePlatform owned = FakePlatform()..owns = true;
    await _boot(t, owned, AdScreen.menu);
    await t.pump(const Duration(milliseconds: 200));
    expect(widths, isEmpty);
    expect(find.byKey(const ValueKey<String>('ad-banner')), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 5));
  });
}
