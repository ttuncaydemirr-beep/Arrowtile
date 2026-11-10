// Telemetri (docs/19): olay adları/parametreleri, gizlilik kuralları (yalnızca sayı + sabit sözcük), onay sinyalleri, çökme
// kancaları, hata dayanıklılığı ve oyuna bağlantılar. Gerçek Firebase çağrılmaz.
import 'dart:ui';

import 'package:arrowtile/core/ads_rules.dart';
import 'package:arrowtile/core/consent_gate.dart';
import 'package:arrowtile/core/save_data.dart';
import 'package:arrowtile/core/telemetry.dart';
import 'package:arrowtile/l10n/app_localizations.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:arrowtile/state/app_scope.dart';
import 'package:arrowtile/ui/flow.dart';
import 'package:arrowtile/ui/screens/game_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';
import 'fake_telemetry.dart';

/// Parametre değeri yalnızca sayı ya da kısa, sabit sözcük (küçük harf/rakam/_ ) olabilir: serbest metin yok.
final RegExp _safeWord = RegExp(r'^[a-z0-9_]{1,24}$');

void _expectAnonymous(LoggedEvent e) {
  expect(e.name.length <= 40, isTrue, reason: e.name);
  e.params.forEach((String k, Object v) {
    expect(k.length <= 40, isTrue, reason: k);
    expect(v is int || v is double || (v is String && _safeWord.hasMatch(v)), isTrue, reason: '${e.name}.$k=$v');
  });
}

void main() {
  group('olay yardımcıları', () {
    test('level_start / level_complete / level_fail / hint_used', () async {
      final FakeTelemetry t = FakeTelemetry();
      t.levelStart(level: 17, tier: 'hard', chapter: 2);
      t.levelComplete(level: 17, tier: 'hard', stars: 2, mistakes: 1, hintsUsed: 1, durationS: 42);
      t.levelFail(level: 18, tier: null);
      t.hintUsed(level: 17);
      await Future<void>.delayed(Duration.zero);
      expect(t.events.map((LoggedEvent e) => e.name), <String>['level_start', 'level_complete', 'level_fail', 'hint_used']);
      expect(t.events[0].params, <String, Object>{'level': 17, 'tier': 'hard', 'chapter': 2});
      expect(t.events[1].params,
          <String, Object>{'level': 17, 'tier': 'hard', 'stars': 2, 'mistakes': 1, 'hints_used': 1, 'duration_s': 42});
      expect(t.events[2].params, <String, Object>{'level': 18, 'tier': 'unknown'}); // kademe yoksa 'unknown'
      expect(t.events[3].params, <String, Object>{'level': 17});
    });

    test('süre 0..3600 saniyeye kırpılır (arka planda kalan oyun uç değer üretmesin)', () async {
      final FakeTelemetry t = FakeTelemetry();
      t.levelComplete(level: 1, tier: 'easy', stars: 3, mistakes: 0, hintsUsed: 0, durationS: 99999);
      t.levelComplete(level: 1, tier: 'easy', stars: 3, mistakes: 0, hintsUsed: 0, durationS: -5);
      t.dailyPuzzleComplete(stars: 1, mistakes: 3, durationS: 7200);
      await Future<void>.delayed(Duration.zero);
      expect(t.events[0].params['duration_s'], 3600);
      expect(t.events[1].params['duration_s'], 0);
      expect(t.events[2].params['duration_s'], 3600);
    });

    test('reklam, satın alma, ayar ve dil olayları', () async {
      final FakeTelemetry t = FakeTelemetry();
      t.dailyPuzzleComplete(stars: 3, mistakes: 0, durationS: 30);
      t.rewardedAd(placement: 'life', result: 'rewarded');
      t.interstitial(result: 'shown');
      t.settingChanged(name: 'relaxed_mode', value: 'on');
      t.purchaseRemoveAds(currency: 'TRY', value: 59.99);
      t.setLanguage('de');
      await Future<void>.delayed(Duration.zero);
      expect(t.events.map((LoggedEvent e) => e.name),
          <String>['daily_puzzle_complete', 'rewarded_ad', 'interstitial', 'setting_changed']);
      expect(t.events[1].params, <String, Object>{'placement': 'life', 'result': 'rewarded'});
      expect(t.events[2].params, <String, Object>{'result': 'shown'});
      expect(t.events[3].params, <String, Object>{'name': 'relaxed_mode', 'value': 'on'});
      expect(t.purchases, <Map<String, Object?>>[
        <String, Object?>{'id': 'remove_ads', 'currency': 'TRY', 'value': 59.99}
      ]);
      expect(t.userProps['app_lang'], 'de');
      t.events.forEach(_expectAnonymous);
    });

    test('hiçbir olay serbest metin / kimlik içermez', () async {
      final FakeTelemetry t = FakeTelemetry();
      t.levelStart(level: 1, tier: 'easy', chapter: 1);
      t.levelComplete(level: 1, tier: 'extreme', stars: 1, mistakes: 4, hintsUsed: 2, durationS: 9);
      t.levelFail(level: 1, tier: 'medium');
      t.hintUsed(level: 1);
      t.dailyPuzzleComplete(stars: 2, mistakes: 1, durationS: 11);
      for (final String p in <String>['coins', 'life', 'hint']) {
        for (final String r in <String>['rewarded', 'closed', 'unavailable']) {
          t.rewardedAd(placement: p, result: r);
        }
      }
      for (final String r in <String>['shown', 'skipped', 'failed']) {
        t.interstitial(result: r);
      }
      for (final String n in <String>['relaxed_mode', 'aim_mode']) {
        t.settingChanged(name: n, value: 'off');
      }
      t.settingChanged(name: 'appearance', value: 'dark');
      t.settingChanged(name: 'arrow_theme', value: 'ocean');
      await Future<void>.delayed(Duration.zero);
      expect(t.events, isNotEmpty);
      t.events.forEach(_expectAnonymous);
    });

    test('telemetri bozulsa bile istisna sızmaz (oyun etkilenmez)', () async {
      final FakeTelemetry t = FakeTelemetry()..throwOnLog = true;
      t.levelStart(level: 1, tier: 'easy', chapter: 1);
      t.hintUsed(level: 1);
      t.interstitial(result: 'failed');
      await Future<void>.delayed(Duration.zero);
      expect(t.events, isEmpty);
    });

    test('NoopTelemetry hiçbir şey yapmaz, başlatma false döner', () async {
      const Telemetry n = NoopTelemetry();
      expect(await n.init(), isFalse);
      n.levelStart(level: 1, tier: 'easy', chapter: 1);
      n.purchaseRemoveAds();
      n.setLanguage('tr');
      await n.setConsent(TelemetryConsent.denied);
      n.recordFatal(StateError('x'), StackTrace.current);
    });
  });

  group('onay sinyalleri (UMP → Firebase Consent Mode)', () {
    test('varsayılan hepsi reddedilmiş', () {
      expect(TelemetryConsent.denied.analyticsStorage, isFalse);
      expect(TelemetryConsent.denied.adStorage, isFalse);
      expect(TelemetryConsent.denied.adUserData, isFalse);
      expect(TelemetryConsent.denied.adPersonalization, isFalse);
    });

    test('onay gerekmiyor (AEA dışı): analiz açık, kişiselleştirme kapalı', () {
      final TelemetryConsent c = deriveTelemetryConsent(umpStatus: 'notRequired');
      expect(c, const TelemetryConsent(analyticsStorage: true, adStorage: true, adUserData: true));
      expect(c.adPersonalization, isFalse);
    });

    test('onay bekleniyor / bilinmiyor: hepsi kapalı', () {
      expect(deriveTelemetryConsent(umpStatus: 'required'), TelemetryConsent.denied);
      expect(deriveTelemetryConsent(umpStatus: 'unknown'), TelemetryConsent.denied);
      expect(deriveTelemetryConsent(umpStatus: 'whatever'), TelemetryConsent.denied);
    });

    test('AEA onay alındı: TCF amaçlarına göre', () {
      // amaç 1 + 7 verildi
      expect(deriveTelemetryConsent(umpStatus: 'obtained', gdprApplies: true, purposeConsents: '1000001000'),
          const TelemetryConsent(analyticsStorage: true, adStorage: true, adUserData: true));
      // yalnızca amaç 1
      expect(deriveTelemetryConsent(umpStatus: 'obtained', gdprApplies: true, purposeConsents: '1000000000'),
          const TelemetryConsent(analyticsStorage: true, adStorage: true));
      // reddetti
      expect(deriveTelemetryConsent(umpStatus: 'obtained', gdprApplies: true, purposeConsents: '0000000000'), TelemetryConsent.denied);
      // amaçlar okunamadı: güvenli varsayılan
      expect(deriveTelemetryConsent(umpStatus: 'obtained', gdprApplies: true, purposeConsents: null), TelemetryConsent.denied);
      expect(deriveTelemetryConsent(umpStatus: 'obtained', gdprApplies: true, purposeConsents: ''), TelemetryConsent.denied);
    });

    test('ad_personalization hiçbir durumda açılmaz', () {
      for (final String st in <String>['notRequired', 'obtained', 'required', 'unknown']) {
        expect(deriveTelemetryConsent(umpStatus: st, gdprApplies: true, purposeConsents: '1111111111').adPersonalization, isFalse, reason: st);
        expect(deriveTelemetryConsent(umpStatus: st).adPersonalization, isFalse, reason: st);
      }
    });

    test('AEA dışı form gösterildi (GDPR uygulanmıyor): analiz açık', () {
      expect(deriveTelemetryConsent(umpStatus: 'obtained', gdprApplies: false).analyticsStorage, isTrue);
    });
  });

  group('çökme kancaları', () {
    late FlutterExceptionHandler? savedFlutter;
    late ErrorCallback? savedPlatform;
    setUp(() {
      savedFlutter = FlutterError.onError;
      savedPlatform = PlatformDispatcher.instance.onError;
    });
    tearDown(() {
      FlutterError.onError = savedFlutter;
      PlatformDispatcher.instance.onError = savedPlatform;
    });

    test('FlutterError.onError → recordFlutterFatal; önceki işleyici de çalışır', () {
      final FakeTelemetry t = FakeTelemetry();
      int prev = 0;
      FlutterError.onError = (FlutterErrorDetails d) => prev++;
      installCrashHandlers(t);
      final FlutterErrorDetails d = FlutterErrorDetails(exception: StateError('a'));
      FlutterError.onError!(d);
      expect(prev, 1);
      expect(t.flutterFatals, <FlutterErrorDetails>[d]);
    });

    test('PlatformDispatcher.onError → recordFatal ve true (işlendi)', () {
      final FakeTelemetry t = FakeTelemetry();
      installCrashHandlers(t);
      final bool handled = PlatformDispatcher.instance.onError!(StateError('b'), StackTrace.current);
      expect(handled, isTrue);
      expect(t.fatals.single, isA<StateError>());
    });
  });

  group('Monetization → interstitial olayı', () {
    Future<List<String>> run(void Function(FakePlatform p) setup) async {
      final FakePlatform p = FakePlatform();
      setup(p);
      final AdsState ads = AdsState()..since = 3;
      final List<String> results = <String>[];
      final Monetization m = Monetization(
          platform: p,
          getAds: () => ads,
          persist: () {},
          nativeTimeout: const Duration(milliseconds: 40),
          showTimeout: const Duration(milliseconds: 40),
          onInterstitialResult: results.add);
      await m.endScreen(20);
      return results;
    }

    test('gösterildi → shown', () async => expect(await run((FakePlatform p) {}), <String>['shown']));
    test('hazır değil → skipped', () async => expect(await run((FakePlatform p) => p.interstitialOk = false), <String>['skipped']));
    test('gösterilemedi → failed', () async => expect(await run((FakePlatform p) => p.failToShow = true), <String>['failed']));
    test('ekrana gelmedi (zaman aşımı) → failed', () async => expect(await run((FakePlatform p) => p.hangInterstitial = true), <String>['failed']));

    test('zamanı gelmediyse olay yok; geri çağrı hata fırlatsa da akış sürer', () async {
      final FakePlatform p = FakePlatform();
      final AdsState ads = AdsState(); // since 0: zamanı gelmedi
      int n = 0;
      final Monetization m = Monetization(
          platform: p, getAds: () => ads, persist: () {}, onInterstitialResult: (String r) => n++);
      expect(await m.endScreen(20), isFalse);
      expect(n, 0);
      final AdsState ads2 = AdsState()..since = 3;
      final Monetization m2 = Monetization(
          platform: FakePlatform(),
          getAds: () => ads2,
          persist: () {},
          onInterstitialResult: (String r) => throw StateError('telemetri bozuk'));
      expect(await m2.endScreen(20), isTrue);
    });
  });

  group('oyuna bağlantılar (widget)', () {
    Future<AppController> openApp(WidgetTester t, FakeTelemetry fake) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppController? made = await t.runAsync(() => AppController.create(telemetry: fake));
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
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ));
      return app;
    }

    testWidgets('seviye açılınca level_start (level, tier, chapter) gönderilir', (WidgetTester t) async {
      final FakeTelemetry fake = FakeTelemetry();
      final AppController app = await openApp(t, fake);
      final int level = 5;
      app.navKey.currentState!.push(fadeRoute<void>(GameScreen(level: app.getLevel(level)!)));
      for (int i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final List<LoggedEvent> starts = fake.named('level_start').toList();
      expect(starts, hasLength(1));
      expect(starts.single.params['level'], level);
      expect(starts.single.params['tier'], app.getLevel(level)!.diff ?? 'unknown');
      expect(starts.single.params['chapter'], 1);
      // ekranı kapat: bekleyen zamanlayıcılar kalmasın
      app.navKey.currentState!.pop();
      await t.pump(const Duration(milliseconds: 500));
    });

    testWidgets('ayarlar ve dil değişimi olay/kullanıcı özelliği üretir', (WidgetTester t) async {
      final FakeTelemetry fake = FakeTelemetry();
      final AppController app = await openApp(t, fake);
      app.setRelaxed(true);
      app.setAim(false);
      app.setAppearance('dark');
      app.setAppearance('bogus'); // geçersiz: olay yok
      app.themeEquipped('ocean');
      app.setLang('de');
      app.setLang('xx'); // geçersiz: olay yok
      await t.pump();
      expect(fake.named('setting_changed').map((LoggedEvent e) => '${e.params['name']}=${e.params['value']}'),
          <String>['relaxed_mode=on', 'aim_mode=off', 'appearance=dark', 'arrow_theme=ocean']);
      expect(fake.userProps['app_lang'], 'de');
      fake.events.forEach(_expectAnonymous);
    });
  });
}
