// 1.1.3 → 1.1.4 (docs/20, docs/21): seviye ortasında reklam yok + reklam sırasında/sonrasında ses davranışı.
// Gerçek kök neden (1.1.4): show() çağrıldıktan sonra SDK gösterimi geri alınamaz; 1.1.3 3 sn sonra "bırakıp" (dispose) sonraki seviyeyi
// başlatıyordu, gerçek cihazda geç açılan AdActivity sonraki seviyenin ortasında beliriyordu. Buradaki SDK modeli bunu birebir taklit eder:
// show() çağrılan reklam [presentAfter] sonra MUTLAKA belirir (bırakma onu durdurmaz). Doğrulanan: bekleme reklam kapanana dek sürer.
import 'dart:async';

import 'package:arrowtile/core/ads_rules.dart';
import 'package:arrowtile/core/save_data.dart';
import 'package:arrowtile/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_ads_platform.dart';

class _Rig {
  final FakePlatform p = FakePlatform();
  final AdsState ads = AdsState()..since = 3;
  final List<String> results = <String>[];
  final List<String> plays = <String>[];
  final List<bool> screen = <bool>[];
  final AudioService sfx = AudioService();
  late final Monetization m;
  _Rig({int holdMs = 200}) {
    m = Monetization(
        platform: p,
        getAds: () => ads,
        persist: () {},
        nativeTimeout: const Duration(seconds: 5),
        holdMax: Duration(milliseconds: holdMs),
        returnGrace: const Duration(milliseconds: 30),
        onInterstitialResult: results.add);
    sfx.debugReady(onPlay: plays.add);
    m.addScreenListener((bool on) {
      screen.add(on);
      sfx.setHeld(on);
    });
  }
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('(a) yüklenmemiş: seviye sonunda anında atlanır, sonradan yüklense de SEVİYE ORTASINDA show() çağrılmaz', () async {
    final _Rig r = _Rig()..p.interstitialOk = false;
    final Stopwatch sw = Stopwatch()..start();
    expect(await r.m.endScreen(15), isFalse);
    expect(sw.elapsedMilliseconds, lessThan(30), reason: 'beklemeden atlamalı');
    expect(r.p.calls, isNot(contains('interstitial')));
    expect(r.results, <String>['skipped']);
    expect(r.ads.since, 3, reason: 'sayaç korunur: gelecekteki uygun seviye sonu');
    r.p.interstitialOk = true; // yükleme seviye sırasında tamamlandı
    await _wait(200);
    expect(r.p.calls, isNot(contains('interstitial')), reason: 'hiçbir yükleme geri çağrısı/zamanlayıcı show() çağırmaz');
    r.m.onAppLifecycle(foreground: false);
    r.m.onAppLifecycle(foreground: true);
    await _wait(60);
    expect(r.p.calls, isNot(contains('interstitial')), reason: 'öne gelme show() çağırmaz');
    expect(r.m.levelEndActive, isFalse);
    // sonraki uygun seviye sonu: hazır → tam bir kez
    r.m.onLevelComplete(16);
    expect(await r.m.endScreen(16), isTrue);
    expect(r.p.calls.where((String c) => c == 'interstitial').length, 1);
  });

  test('(b) yüklü reklam show() sonrası 800 ms (gerçekte ~8 sn) geç belirir: bekleme reklam KAPANANA dek sürer, sonra reklam yok', () async {
    final _Rig r = _Rig()
      ..p.presentAfter = const Duration(milliseconds: 800)
      ..p.watchFor = const Duration(milliseconds: 150);
    bool done = false;
    int presentedAfterDone = 0;
    r.p.onPresented = () {
      if (done) presentedAfterDone++;
    };
    bool slow = false;
    final Future<bool> f = r.m.continueAfterLevel(15, placement: r.m.openLevelEnd(15), onSlow: () => slow = true);
    await _wait(300);
    expect(r.m.adHoldActive, isTrue, reason: 'show() bekleniyor: sonraki seviye başlamamalı');
    expect(r.sfx.held, isFalse, reason: 'reklam ekranda değilken ses susmaz');
    r.sfx.slideOut(); // seviye sonu penceresi sesleri çalabilir
    expect(r.plays, <String>['slide_out_0']);
    expect(await f, isTrue);
    done = true;
    expect(slow, isTrue);
    expect(r.p.presentedI, 1);
    expect(r.p.releasedI, 0, reason: 'süre sınırıyla bırakılmadı');
    expect(r.m.adHoldActive, isFalse);
    expect(r.sfx.held, isFalse);
    await _wait(1200);
    expect(presentedAfterDone, 0, reason: 'bekleme bittikten sonra (seviye sırasında) reklam belirmemeli');
    expect(r.screen, <bool>[true, false]);
    r.sfx.slideOut();
    expect(r.plays, <String>['slide_out_0', 'slide_out_0'], reason: 'sonraki dokunuşta TAM bir ses');
  });

  test('geçersiz / kapanmış yerleştirme: show() çağrılmaz; bir yerleştirmede en çok bir show()', () async {
    final _Rig r = _Rig();
    expect(await r.m.continueAfterLevel(15, placement: 999), isFalse);
    final int t = r.m.openLevelEnd(15);
    r.m.closeLevelEnd(t);
    expect(await r.m.continueAfterLevel(15, placement: t), isFalse);
    final int t2 = r.m.openLevelEnd(15);
    expect(await r.m.continueAfterLevel(16, placement: t2), isFalse, reason: 'başka seviyenin belirteci');
    expect(r.p.calls, isNot(contains('interstitial')));
    expect(r.results.where((String e) => e == 'blocked').length, 3);
    expect(await r.m.continueAfterLevel(15, placement: t2), isTrue);
    expect(await r.m.continueAfterLevel(15, placement: t2), isFalse);
    expect(r.p.calls.where((String c) => c == 'interstitial').length, 1);
  });

  test('ses yalnızca reklam EKRANDAYKEN susar; susarken düşer (kuyruğa alınmaz), kapanınca bir şey kendiliğinden çalmaz', () async {
    final _Rig r = _Rig()
      ..p.showAfter = const Duration(milliseconds: 200)
      ..p.appearsOnScreen = true;
    final Future<bool> f = r.m.endScreen(15);
    await _wait(60);
    expect(r.sfx.held, isTrue);
    r.sfx.slideOut();
    r.sfx.tap();
    expect(r.plays, isEmpty, reason: 'reklam ekrandayken ses düşer');
    expect(await f, isTrue);
    expect(r.sfx.held, isFalse);
    await _wait(150);
    expect(r.plays, isEmpty, reason: 'düşen ses sonradan ÇALINMAZ');
    r.sfx.slideOut();
    expect(r.plays, <String>['slide_out_0']);
    expect(r.screen, <bool>[true, false]);
  });

  test('gösterilemedi / istisna / yanıt yok + uygulamadan dönüş: ses bayrağı her yolda false, sonraki dokunuşta tam bir ses', () async {
    for (final void Function(FakePlatform) cfg in <void Function(FakePlatform)>[
      (FakePlatform p) => p.failToShow = true,
      (FakePlatform p) => p.throwOnShow = true,
      (FakePlatform p) => p.hangInterstitial = true,
    ]) {
      final _Rig r = _Rig();
      cfg(r.p);
      final Future<bool> f = r.m.endScreen(15);
      await _wait(20);
      r.m.onAppLifecycle(foreground: false);
      r.m.onAppLifecycle(foreground: true);
      expect(await f, isFalse);
      expect(r.sfx.held, isFalse);
      expect(r.m.adOnScreen, isFalse);
      r.sfx.slideOut();
      expect(r.plays, <String>['slide_out_0']);
      await _wait(80);
      expect(r.plays, hasLength(1));
    }
  });

  test('(d) ödüllü yavaş sunum: süre sınırıyla bırakılmaz, ekrana gelince ödül verilir (tek kez)', () async {
    final _Rig r = _Rig();
    r.p.rewardedPresentAfter = const Duration(milliseconds: 500);
    int rew = 0;
    bool slow = false;
    final RewardedResult res = await r.m.watchRewarded('life', onReward: () => rew++, onSlow: () => slow = true);
    expect(res.rewarded, isTrue);
    expect(rew, 1);
    expect(slow, isTrue);
    expect(r.p.releasedR, 0);
    expect(r.m.adHoldActive, isFalse);
    expect(r.sfx.held, isFalse);
  });

  test('ödüllü: yükleme süreden uzun sürer → "reklam yok"; sonradan tamamlanan yükleme reklamı ASLA kendiliğinden göstermez', () async {
    final _Rig r = _Rig()
      ..p.rewardedOk = false
      ..p.loadAfter = const Duration(milliseconds: 300);
    final RewardedResult res = await r.m.watchRewarded('coins', loadTimeout: const Duration(milliseconds: 100));
    expect(res.unavailable, isTrue);
    await _wait(500); // yükleme şimdi tamamlandı
    expect(r.p.rewardedOk, isTrue);
    expect(r.p.lateLoads, 1);
    r.m.onAppLifecycle(foreground: false);
    r.m.onAppLifecycle(foreground: true);
    await _wait(100);
    expect(r.p.calls.where((String c) => c.startsWith('rewarded:')), isEmpty, reason: 'geç yükleme gösterim tetiklemez');
    expect(r.p.presentedR, 0);
    // sonraki DOKUNUŞ hazır reklamı kullanır
    final RewardedResult res2 = await r.m.watchRewarded('coins');
    expect(res2.rewarded, isTrue);
  });

  test('ödüllü: bekleme sırasında ekran kapandıysa (stillWanted=false) ASLA gösterilmez', () async {
    final _Rig r = _Rig()..p.rewardedOk = false;
    bool wanted = true;
    final Future<RewardedResult> f = r.m.watchRewarded('coins', stillWanted: () => wanted, loadTimeout: const Duration(seconds: 2));
    wanted = false; // kullanıcı ekrandan çıktı
    final RewardedResult res = await f;
    expect(res.unavailable, isTrue);
    expect(r.p.calls.where((String c) => c.startsWith('rewarded:')), isEmpty);
  });

  test('geçiş gösterimi sürerken ödüllü gösterilmez (aynı anda tek tam ekran)', () async {
    final _Rig r = _Rig()..p.hangInterstitial = true;
    final Future<bool> f = r.m.endScreen(15);
    await _wait(10);
    expect(await r.m.showRewarded('life'), isFalse);
    expect(r.p.calls.where((String c) => c.startsWith('rewarded:')), isEmpty);
    r.m.onAppLifecycle(foreground: false);
    r.m.onAppLifecycle(foreground: true);
    await f;
  });

  test('kalkan: seviye sırasında tam ekran reklam belirirse telemetri late_blocked, oyun+ses duraklar, kayıp yok; gidince geri alınır', () async {
    final _Rig r = _Rig();
    r.m.lateAdSurfaced();
    expect(r.results, <String>['late_blocked']);
    expect(r.m.isAdShowing, isTrue);
    expect(r.sfx.held, isTrue);
    r.sfx.slideOut();
    expect(r.plays, isEmpty);
    r.m.lateAdGone();
    expect(r.m.isAdShowing, isFalse);
    expect(r.sfx.held, isFalse);
    r.sfx.slideOut();
    expect(r.plays, <String>['slide_out_0']);
    r.m.lateAdGone(); // idempotent
    expect(r.m.isAdShowing, isFalse);
  });

  test('platform "geç gösterildi" bildirimi (onLateAd) kalkanı çalıştırır', () async {
    final _Rig r = _Rig();
    r.p.onLateAd!.call();
    expect(r.results, contains('late_blocked'));
    r.m.lateAdGone();
  });

  test('uygulamadan dönüşle bırakılan (ekrana gelmemiş) gösterim kalkan penceresini açar', () async {
    final _Rig r = _Rig()..p.hangInterstitial = true;
    final Future<bool> f = r.m.endScreen(15);
    await _wait(10);
    r.m.onAppLifecycle(foreground: false);
    r.m.onAppLifecycle(foreground: true);
    expect(await f, isFalse);
    expect(r.p.releasedI, 1);
    expect(r.m.lateWindowOpen, isTrue);
  });
}
