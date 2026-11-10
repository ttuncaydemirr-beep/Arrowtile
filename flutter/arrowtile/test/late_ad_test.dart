// 1.1.3 (docs/20): geç gelen (seviye ortası) reklam yok + reklam sırasında/sonrasında ses davranışı.
// Kök neden: show() çağrıldıktan sonra SDK geri alınamaz; 1.1.2 zamanında bırakıp (dispose) oyunu sürdürüyordu ama reklam
// ekrana yine geliyordu. Burada SDK modeli: "dispose edilen reklam gösterilemez"; kurallar: yalnızca etkin seviye sonu yerleştirmesinde,
// yalnızca yüklüyse, en çok bir kez, ekrana gelmeyen bırakılır, ses yalnızca ekrandayken susar ve ASLA sıraya alınmaz.
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
  _Rig({int showMs = 50}) {
    m = Monetization(
        platform: p,
        getAds: () => ads,
        persist: () {},
        nativeTimeout: const Duration(seconds: 5),
        showTimeout: Duration(milliseconds: showMs),
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
    expect(r.m.levelEndActive, isFalse);
    // sonraki uygun seviye sonu: hazır → tam bir kez
    r.m.onLevelComplete(16);
    expect(await r.m.endScreen(16), isTrue);
    expect(r.p.calls.where((String c) => c == 'interstitial').length, 1);
  });

  test('(b) show() çağrıldı, reklam 5 sn sonra belirecekti: bırakılır (dispose), asla gösterilmez, ses hiç susmaz', () async {
    final _Rig r = _Rig(showMs: 60)..p.presentAfter = const Duration(milliseconds: 400);
    expect(await r.m.endScreen(15), isFalse);
    expect(r.p.abandonedI, isTrue, reason: 'ad.dispose() eşdeğeri çağrılmalı');
    expect(r.m.isAdShowing, isFalse);
    expect(r.sfx.held, isFalse);
    r.sfx.slideOut(); // sonraki dokunuş: hemen, tam bir kez
    expect(r.plays, <String>['slide_out_0']);
    await _wait(600); // reklamın "belirme" zamanı geçti
    expect(r.p.presentedI, 0, reason: 'bırakılan reklam asla ekrana gelmemeli');
    expect(r.p.onScreen, isFalse);
    expect(r.screen, isEmpty, reason: 'ses ekrana gelmeyen reklam için hiç susturulmadı');
    expect(r.plays, hasLength(1), reason: 'dokunuşsuz ses çalmamalı / ertelenmiş ses olmamalı');
    expect(r.m.lateWindowOpen, isTrue);
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
    final _Rig r = _Rig(showMs: 1000)
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

  test('gösterilemedi / istisna / yanıt yok: ses bayrağı her yolda false, sonraki dokunuşta tam bir ses', () async {
    for (final void Function(FakePlatform) cfg in <void Function(FakePlatform)>[
      (FakePlatform p) => p.failToShow = true,
      (FakePlatform p) => p.throwOnShow = true,
      (FakePlatform p) => p.hangInterstitial = true,
    ]) {
      final _Rig r = _Rig();
      cfg(r.p);
      expect(await r.m.endScreen(15), isFalse);
      expect(r.sfx.held, isFalse);
      expect(r.m.adOnScreen, isFalse);
      r.sfx.slideOut();
      expect(r.plays, <String>['slide_out_0']);
      await _wait(80);
      expect(r.plays, hasLength(1));
    }
  });

  test('(d) ödüllü yavaş: bırakılır, "reklam yok" sonucu (mesaj), sonradan asla gösterilmez, ödül verilmez', () async {
    final _Rig r = _Rig();
    r.p
      ..rewardedPresentAfter = const Duration(milliseconds: 400)
      ..rewardedWatchdog = const Duration(milliseconds: 80);
    int rew = 0;
    final RewardedResult res = await r.m.watchRewarded('life', onReward: () => rew++);
    expect(res.unavailable, isTrue, reason: 'arayüz "Şu an reklam yok" iletisini gösterir');
    expect(res.errorCode, 'show_timeout');
    expect(r.p.abandonedR, isTrue);
    expect(r.m.isAdShowing, isFalse);
    expect(r.sfx.held, isFalse);
    await _wait(600);
    expect(r.p.presentedR, 0);
    expect(rew, 0);
    expect(r.screen, isEmpty);
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
    expect(r.p.calls, contains('abandonI'));
    r.m.lateAdGone();
  });
}
