// Reklam/satın alma kuralları (ads.js → ads_rules.dart): altın senaryolar + tools/test-ads.js vakalarının Dart karşılığı.
// Sahte saat + sahte platform; gerçek AdMob/Billing çağrılmaz.
import 'package:arrowtile/core/ads_rules.dart';
import 'package:arrowtile/core/save_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_ads_platform.dart';
import 'helpers.dart';

class Rig {
  final FakePlatform p = FakePlatform();
  final AdsState ads = AdsState();
  int t = 1000000;
  int saves = 0;
  late final Monetization m;
  Rig({Duration timeout = const Duration(milliseconds: 40), Duration? showTimeout}) {
    m = Monetization(
        platform: p,
        getAds: () => ads,
        persist: () => saves++,
        now: () => t,
        nativeTimeout: timeout,
        showTimeout: showTimeout ?? timeout);
  }
  Future<bool> complete(int id) async {
    m.onLevelComplete(id);
    return m.continueAfterLevel(id);
  }
}

void main() {
  const int min = 60 * 1000;

  group('altın senaryolar (ads.js çıktısı)', () {
    final Map<String, dynamic> g = golden('ads_golden.json') as Map<String, dynamic>;
    g.forEach((String name, dynamic sc) {
      test(name, () async {
        final Rig r = Rig();
        r.t = (sc as Map<String, dynamic>)['start'] as int;
        final List<dynamic> ops = sc['ops'] as List<dynamic>;
        final List<dynamic> log = sc['log'] as List<dynamic>;
        int li = 0;
        for (final dynamic o in ops) {
          final List<dynamic> op = o as List<dynamic>;
          switch (op[0] as String) {
            case 'c':
              final bool shown = await r.complete(op[1] as int);
              final Map<String, dynamic> eC = log[li++] as Map<String, dynamic>;
              expect(shown, eC['shown'], reason: '$name #$li $op');
              expect(r.ads.since, eC['since'], reason: '$name #$li $op');
              expect(r.ads.lastAt, eC['lastAt'], reason: '$name #$li $op');
            case 't':
              r.t += op[1] as int;
            case 'o':
              r.p.isOnline = op[1] as bool;
            case 'buy':
              final PurchaseResult pr = await r.m.purchaseRemoveAds();
              final Map<String, dynamic> eB = log[li++] as Map<String, dynamic>;
              expect(pr.ok, (eB['r'] as Map<String, dynamic>)['ok']);
              expect(r.ads.adFree, eB['adFree']);
            case 'due':
              final Map<String, dynamic> eD = log[li++] as Map<String, dynamic>;
              expect(r.m.interstitialDue(op[1] as int), eD['due']);
          }
        }
        expect(li, log.length);
      });
    });
  });

  test('seviye 1-12 tamamen reklamsız, sayaç ilerlemez', () async {
    final Rig r = Rig();
    int shown = 0;
    for (int id = 1; id <= 12; id++) {
      if (await r.complete(id)) shown++;
      r.t += 10 * min;
    }
    expect(shown, 0);
    expect(r.p.calls, isEmpty);
    expect(r.ads.since, 0);
  });

  test('çevrimdışı: reklam çağrılmaz; internet gelince (sayaç korunur) gösterilir', () async {
    final Rig r = Rig()..p.isOnline = false;
    for (int id = 13; id <= 15; id++) {
      r.m.onLevelComplete(id);
    }
    expect(await r.m.continueAfterLevel(15), isFalse);
    expect(r.p.calls, isEmpty);
    r.p.isOnline = true;
    expect(await r.m.continueAfterLevel(15), isTrue);
    expect(r.p.calls, <String>['interstitial']);
  });

  test('platform yok: reklam gösterilmez, satın alma test modunda taklit edilir, ödüllü sunulmaz', () async {
    final Rig r = Rig()..p.isAvailable = false;
    for (int id = 13; id <= 15; id++) {
      r.m.onLevelComplete(id);
    }
    expect(await r.m.continueAfterLevel(15), isFalse);
    final PurchaseResult pr = await r.m.purchaseRemoveAds();
    expect(pr.ok && pr.test, isTrue);
    expect(r.ads.adFree && r.ads.test, isTrue);
    final RestoreResult rr = await r.m.restorePurchases();
    expect(rr.ok && rr.adFree && rr.test, isTrue);
    expect(r.m.rewardedAvailable(), isFalse);
    expect(r.m.isTestMode, isTrue);
  });

  test('test modu reklamsızlığı gerçek platformda geçerli sayılmaz', () {
    final Rig r = Rig();
    r.ads
      ..since = 3
      ..adFree = true
      ..test = true;
    expect(r.m.isAdFree(), isFalse);
    expect(r.m.interstitialDue(15), isTrue);
  });

  test('satın alma: purchased → reklamsız; reklamsızda geçiş reklamı yok, ödüllü çalışır', () async {
    final Rig r = Rig();
    final PurchaseResult pr = await r.m.purchaseRemoveAds();
    expect(pr.ok, isTrue);
    expect(r.ads.adFree, isTrue);
    for (int id = 13; id <= 20; id++) {
      await r.complete(id);
      r.t += 10 * min;
    }
    expect(r.p.calls.where((String c) => c == 'interstitial'), isEmpty);
    int rew = 0;
    final bool got = await r.m.showRewarded('hint', onReward: () => rew++);
    expect(got && rew == 1, isTrue);
  });

  test('Play sahipliği (yeniden kurulum) → reklam yok ve kayda işlenir', () {
    final Rig r = Rig()..p.owns = true;
    for (int id = 13; id <= 16; id++) {
      r.m.onLevelComplete(id);
    }
    expect(r.m.interstitialDue(16), isFalse);
    expect(r.ads.adFree, isTrue);
  });

  test('satın alma iptal / bekleyen / hata / zaman aşımı', () async {
    for (final MapEntry<PurchaseOutcome, String> c in <PurchaseOutcome, String>{
      PurchaseOutcome.cancelled: 'cancelled',
      PurchaseOutcome.pending: 'pending',
      PurchaseOutcome.failed: 'failed',
    }.entries) {
      final Rig r = Rig()..p.purchaseOutcome = c.key;
      final PurchaseResult pr = await r.m.purchaseRemoveAds();
      expect(pr.ok, isFalse);
      expect(pr.reason, c.value);
      expect(r.ads.adFree, isFalse, reason: c.value);
    }
    final Rig r = Rig()..p.hangPurchase = true;
    final PurchaseResult pr = await r.m.purchaseRemoveAds();
    expect(pr.ok, isFalse);
    expect(pr.reason, 'timeout');
  });

  test('geri yükleme: sahiplik varsa reklamsız, yoksa değişmez', () async {
    final Rig a = Rig()..p.restoreOwned = true;
    final RestoreResult ra = await a.m.restorePurchases();
    expect(ra.ok && ra.adFree && a.ads.adFree, isTrue);
    final Rig b = Rig()..p.restoreOwned = false;
    final RestoreResult rb = await b.m.restorePurchases();
    expect(rb.ok && !rb.adFree && !b.ads.adFree, isTrue);
    final Rig c = Rig()..p.restoreOwned = null;
    final RestoreResult rc = await c.m.restorePurchases();
    expect(rc.ok, isFalse);
    expect(rc.reason, 'failed');
  });

  test('geçiş reklamı kapanmazsa zaman aşımıyla devam; reklam hazır değilse hemen devam, sayaç sıfırlanmaz', () async {
    final Rig r = Rig()..p.hangInterstitial = true;
    for (int id = 13; id <= 15; id++) {
      r.m.onLevelComplete(id);
    }
    expect(await r.m.continueAfterLevel(15), isFalse); // zaman aşımı → false, oyun devam eder
    final Rig r2 = Rig()..p.interstitialOk = false;
    for (int id = 13; id <= 15; id++) {
      r2.m.onLevelComplete(id);
    }
    expect(await r2.m.continueAfterLevel(15), isFalse);
    expect(r2.ads.since, 3);
  });

  test('ödüllü reklam: yarıda kapatılırsa ödül yok; hazır değilse sunulmaz', () async {
    final Rig r = Rig()..p.rewardGiven = false;
    int rew = 0;
    expect(await r.m.showRewarded('life', onReward: () => rew++), isFalse);
    expect(rew, 0);
    final Rig r2 = Rig()..p.rewardedOk = false;
    expect(r2.m.rewardedAvailable(), isFalse);
    expect(await r2.m.showRewarded('life'), isFalse);
  });

  test('gizlilik seçenekleri (UMP): yoksa gizli; gerekliyse form açılır', () async {
    final Rig r0 = Rig()..p.isAvailable = false;
    expect(r0.m.privacyOptionsRequired, isFalse);
    final Rig r = Rig();
    expect(r.m.privacyOptionsRequired, isFalse);
    r.p.privacyRequired = true;
    expect(r.m.privacyOptionsRequired, isTrue);
    expect(await r.m.showPrivacyOptions(), isTrue);
    expect(r.p.calls, <String>['privacy']);
  });

  group('ödüllü reklam: dokunuşta yükleme (deterministik akış)', () {
    const Duration lt = Duration(milliseconds: 30);

    test('düğme görünürlüğü önceden yüklenmeye ve DNS ölçümüne bağlı değil; platform yoksa gizli', () {
      final Rig r = Rig()
        ..p.rewardedOk = false
        ..p.isOnline = false;
      expect(r.m.rewardedOffered(), isTrue);
      expect(r.m.rewardedAvailable(), isFalse); // hazır değil
      r.p.rewardedOk = true;
      expect(r.m.rewardedAvailable(), isTrue); // çevrimdışı ipucu engellemez; karar SDK'nın
      final Rig n = Rig()..p.isAvailable = false;
      expect(n.m.rewardedOffered(), isFalse);
    });

    test('hazırsa yükleme çağrılmaz, yükleme penceresi açılmaz, ödül bir kez', () async {
      final Rig r = Rig();
      int rew = 0, loading = 0;
      final RewardedResult res = await r.m.watchRewarded('life', onReward: () => rew++, onLoading: () => loading++, loadTimeout: lt);
      expect(res.outcome, RewardedOutcome.rewarded);
      expect(rew, 1);
      expect(loading, 0);
      expect(r.p.calls, <String>['rewarded:life']);
    });

    test('hazır değil: yükleme penceresi aç → yükle → kapat → göster', () async {
      final Rig r = Rig()..p.rewardedOk = false;
      final List<String> order = <String>[];
      final RewardedResult res = await r.m.watchRewarded('coins',
          onReward: () => order.add('reward'),
          onLoading: () => order.add('loading'),
          onLoadingDone: () => order.add('loadingDone'),
          loadTimeout: lt);
      expect(res.rewarded, isTrue);
      expect(order, <String>['loading', 'loadingDone', 'reward']);
      expect(r.p.calls, <String>['ensure', 'rewarded:coins']);
    });

    test('yükleme başarısız: hiçbir şey gösterilmez, AdMob hata kodu döner, pencere kapanır', () async {
      final Rig r = Rig()
        ..p.rewardedOk = false
        ..p.loadOk = false;
      int done = 0;
      final RewardedResult res = await r.m.watchRewarded('life', onLoading: () {}, onLoadingDone: () => done++, loadTimeout: lt);
      expect(res.outcome, RewardedOutcome.unavailable);
      expect(res.errorCode, '3');
      expect(done, 1);
      expect(r.p.calls, <String>['ensure']);
    });

    test('platform yükleme tamamlamazsa zaman aşımıyla biter (takılmaz), pencere kapanır', () async {
      final Rig r = Rig()
        ..p.rewardedOk = false
        ..p.hangLoad = true;
      int done = 0;
      final RewardedResult res = await r.m.watchRewarded('life', onLoading: () {}, onLoadingDone: () => done++, loadTimeout: lt);
      expect(res.unavailable, isTrue);
      expect(res.errorCode, 'unknown');
      expect(done, 1);
      expect(r.p.calls, <String>['ensure']);
    });

    test('yükleme istisna fırlatırsa unavailable (istisna sızmaz)', () async {
      final Rig r = Rig()
        ..p.rewardedOk = false
        ..p.throwOnLoad = true;
      final RewardedResult res = await r.m.watchRewarded('hint', onLoading: () {}, onLoadingDone: () {}, loadTimeout: lt);
      expect(res.unavailable, isTrue);
    });

    test('yüklendi ama gösterimden önce süresi doldu: gösterilmez, unavailable', () async {
      final Rig r = Rig()
        ..p.rewardedOk = false
        ..p.expireAfterLoad = true;
      final RewardedResult res = await r.m.watchRewarded('life', loadTimeout: lt);
      expect(res.unavailable, isTrue);
      expect(r.p.calls.where((String c) => c.startsWith('rewarded:')), isEmpty);
    });

    test('ödül hak edilmeden kapatılırsa closed (unavailable değil)', () async {
      final Rig r = Rig()..p.rewardGiven = false;
      int rew = 0;
      final RewardedResult res = await r.m.watchRewarded('life', onReward: () => rew++, loadTimeout: lt);
      expect(res.outcome, RewardedOutcome.closed);
      expect(rew, 0);
    });

    test('reklam gösterimi hiç bitmezse nativeTimeout ile biter', () async {
      final Rig r = Rig()..p.hangRewardedShow = true;
      final RewardedResult res = await r.m.watchRewarded('life', loadTimeout: lt);
      expect(res.outcome, RewardedOutcome.closed);
    });

    test('platform yok: no_platform', () async {
      final Rig r = Rig()..p.isAvailable = false;
      final RewardedResult res = await r.m.watchRewarded('life', loadTimeout: lt);
      expect(res.unavailable, isTrue);
      expect(res.errorCode, 'no_platform');
    });

    test('ensureRewarded: hazırsa true; başarısızsa false', () async {
      expect(await (Rig()).m.ensureRewarded(loadTimeout: lt), isTrue);
      final Rig r = Rig()
        ..p.rewardedOk = false
        ..p.loadOk = false;
      expect(await r.m.ensureRewarded(loadTimeout: lt), isFalse);
    });
  });

  // ------------------------------------------------------------------ v1.1: banner (docs/15 §3)
  group('banner: yalnızca menü ve harita, reklamsızda asla', () {
    test('görünür ekranlar kümesi tam olarak {menu, map}', () {
      expect(kBannerScreens, <AdScreen>{AdScreen.menu, AdScreen.map});
    });

    test('her ekran için: yalnızca menü ve harita görünür', () {
      final Rig r = Rig();
      for (final AdScreen sc in AdScreen.values) {
        expect(r.m.bannerVisible(sc), sc == AdScreen.menu || sc == AdScreen.map, reason: '$sc');
      }
      // oyun, seviye sonu, mağaza, ayarlar, günlük bulmaca, gizlilik: asla
      for (final AdScreen sc in <AdScreen>[AdScreen.game, AdScreen.levelEnd, AdScreen.shop, AdScreen.settings, AdScreen.daily, AdScreen.privacy]) {
        expect(r.m.bannerVisible(sc), isFalse, reason: '$sc');
      }
    });

    test('"Reklamları kaldır" satın alınmışsa hiçbir ekranda banner yok', () async {
      final Rig r = Rig();
      expect(r.m.bannerVisible(AdScreen.menu), isTrue);
      final PurchaseResult pr = await r.m.purchaseRemoveAds();
      expect(pr.ok, isTrue);
      expect(r.ads.adFree, isTrue);
      for (final AdScreen sc in AdScreen.values) {
        expect(r.m.bannerVisible(sc), isFalse, reason: 'adFree: $sc');
      }
    });

    test('kayıttaki adFree (gerçek satın alma) ve Play sahipliği banner\'ı kapatır', () {
      final Rig a = Rig();
      a.ads
        ..adFree = true
        ..test = false;
      expect(a.m.bannerVisible(AdScreen.menu), isFalse);
      expect(a.m.bannerVisible(AdScreen.map), isFalse);
      final Rig b = Rig()..p.owns = true; // yeniden kurulum: Play'de sahiplik var
      expect(b.m.bannerVisible(AdScreen.map), isFalse);
      expect(b.ads.adFree, isTrue); // kayda işlenir
    });

    test('test modu "satın alma" gerçek platformda geçerli sayılmaz: banner görünür', () {
      final Rig r = Rig();
      r.ads
        ..adFree = true
        ..test = true;
      expect(r.m.bannerVisible(AdScreen.menu), isTrue);
    });

    test('banner kuralı geçiş reklamı sıklığına dokunmaz (sayaç/zaman değişmez)', () {
      final Rig r = Rig();
      r.m.bannerVisible(AdScreen.menu);
      r.m.bannerVisible(AdScreen.map);
      expect(r.ads.since, 0);
      expect(r.ads.lastAt, 0);
      expect(r.p.calls, isEmpty);
    });
  });

  // ------------------------------------------------------------------ v1.1: önceden yükleme (docs/15 §4)
  group('önceden yükleme', () {
    test('ödüllü: oyun açılınca yüklenir; hazır/yükleniyorsa ikinci yükleme başlamaz', () {
      final Rig r = Rig()..p.rewardedOk = false;
      expect(r.m.preloadRewarded(), PreloadState.started);
      expect(r.m.preloadRewarded(), PreloadState.loading); // can 1'e düşünce tekrar çağrılsa da
      expect(r.p.rStarts, 1);
      r.p.rLoading = false;
      r.p.rewardedOk = true;
      expect(r.m.preloadRewarded(), PreloadState.ready);
      expect(r.p.rStarts, 1);
    });

    test('ödüllü: çevrimdışı / platform yok / SDK hazır değil → atlanır', () {
      expect((Rig()..p.isOnline = false).m.preloadRewarded(), PreloadState.skip);
      final Rig n = Rig()..p.isAvailable = false;
      expect(n.m.preloadRewarded(), PreloadState.skip);
      expect(n.p.calls, isEmpty);
      final Rig s = Rig()
        ..p.sdk = false
        ..p.rewardedOk = false;
      expect(s.m.preloadRewarded(), PreloadState.skip);
    });

    test('geçiş: yalnızca bu seviye bitince reklam gösterilecekse (13+, sayaç, reklamsız değil, çevrimiçi) yüklenir', () {
      final Rig r = Rig()..p.interstitialOk = false;
      // seviye 12 ve öncesi: asla
      expect(r.m.preloadInterstitial(12), PreloadState.skip);
      expect(r.p.calls, isEmpty);
      // sayaç: since + 1 < 3 → henüz değil
      r.ads.since = 0;
      expect(r.m.interstitialWillBeDue(13), isFalse);
      r.ads.since = 1;
      expect(r.m.interstitialWillBeDue(13), isFalse);
      expect(r.m.preloadInterstitial(13), PreloadState.skip);
      // since = 2: bu seviye bitince 3. tamamlanan olacak → yükle
      r.ads.since = 2;
      expect(r.m.interstitialWillBeDue(13), isTrue);
      expect(r.m.preloadInterstitial(13), PreloadState.started);
      expect(r.m.preloadInterstitial(13), PreloadState.loading); // son iki okta iki kez çağrılsa da tek yükleme
      expect(r.p.iStarts, 1);
      r.p.iLoading = false;
      r.p.interstitialOk = true;
      expect(r.m.preloadInterstitial(13), PreloadState.ready);
      expect(r.p.iStarts, 1);
    });

    test('geçiş: reklamsız / çevrimdışı / platform yok → atlanır; 3 dk aralığı gösterim anında bakılır', () async {
      final Rig a = Rig()..ads.since = 2;
      a.ads
        ..adFree = true
        ..test = false;
      expect(a.m.preloadInterstitial(20), PreloadState.skip);
      final Rig o = Rig()
        ..ads.since = 2
        ..p.isOnline = false;
      expect(o.m.preloadInterstitial(20), PreloadState.skip);
      final Rig n = Rig()
        ..ads.since = 2
        ..p.isAvailable = false;
      expect(n.m.preloadInterstitial(20), PreloadState.skip);
      // son reklamdan 1 dk sonra: yine de yüklenir (süre dolunca gösterilebilsin); gösterim kuralı değişmez
      final Rig g = Rig()
        ..ads.since = 2
        ..p.interstitialOk = false;
      g.ads.lastAt = g.t - min;
      expect(g.m.preloadInterstitial(20), PreloadState.started);
      g.m.onLevelComplete(20);
      expect(g.m.interstitialDue(20), isFalse); // 3 dk dolmadı
    });

    test('yükleme önceden başlatma sayaç ve zamanı değiştirmez (reklam kuralı aynı)', () {
      final Rig r = Rig()
        ..ads.since = 2
        ..p.interstitialOk = false;
      r.m.preloadInterstitial(13);
      r.m.preloadRewarded();
      expect(r.ads.since, 2);
      expect(r.ads.lastAt, 0);
      expect(r.saves, 0);
    });

    test('rewardedLoading platformu yansıtır', () {
      final Rig r = Rig();
      expect(r.m.rewardedLoading, isFalse);
      r.p.rLoading = true;
      expect(r.m.rewardedLoading, isTrue);
      expect((Rig()..p.isAvailable = false).m.rewardedLoading, isFalse);
    });
  });

  // ------------------------------------------------------------------ v1.1: reklam gösterilirken duraklat (docs/15 §4)
  group('reklam dinleyicisi (oyun döngüsü + ses duraklatma)', () {
    test('geçiş reklamı: gösterimden ÖNCE true, kapanınca false; yalnızca durum değişince', () async {
      final Rig r = Rig();
      final List<bool> ev = <bool>[];
      final List<bool> nativeCalledAtEvent = <bool>[];
      r.m.addAdListener((bool a) {
        ev.add(a);
        nativeCalledAtEvent.add(r.p.calls.contains('interstitial'));
      });
      expect(r.m.isAdShowing, isFalse);
      r.ads.since = 3;
      expect(await r.m.continueAfterLevel(15), isTrue);
      expect(ev, <bool>[true, false]);
      // duraklatma yerel gösterim çağrısından ÖNCE; kapanış bildirimi ondan SONRA
      expect(nativeCalledAtEvent, <bool>[false, true]);
      expect(r.m.isAdShowing, isFalse);
    });

    test('reklam gösterilmezse (kural dışı) dinleyici çağrılmaz', () async {
      final Rig r = Rig();
      final List<bool> ev = <bool>[];
      r.m.addAdListener(ev.add);
      expect(await r.m.continueAfterLevel(5), isFalse); // seviye ≤ 12
      r.p.interstitialOk = false;
      r.ads.since = 3;
      expect(await r.m.continueAfterLevel(15), isFalse); // hazır değil
      expect(ev, isEmpty);
    });

    test('ödüllü reklam: true → false; ödül verilmese de takılı kalmaz', () async {
      final Rig r = Rig();
      final List<bool> ev = <bool>[];
      r.m.addAdListener(ev.add);
      expect(await r.m.showRewarded('life'), isTrue);
      expect(ev, <bool>[true, false]);
      r.p.rewardGiven = false;
      expect(await r.m.showRewarded('life'), isFalse);
      expect(ev, <bool>[true, false, true, false]);
      expect(r.m.isAdShowing, isFalse);
    });

    test('gösterim hiç bitmezse nativeTimeout sonunda false (oyun donmaz)', () async {
      final Rig r = Rig()..p.hangInterstitial = true;
      final List<bool> ev = <bool>[];
      r.m.addAdListener(ev.add);
      r.ads.since = 3;
      await r.m.continueAfterLevel(15);
      expect(ev, <bool>[true, false]);
      expect(r.m.isAdShowing, isFalse);
    });

    test('dinleyici kaldırılabilir; istisna atan dinleyici akışı bozmaz', () async {
      final Rig r = Rig();
      final List<bool> ev = <bool>[];
      final Unsubscribe off = r.m.addAdListener(ev.add);
      r.m.addAdListener((bool a) => throw StateError('boom'));
      off();
      expect(await r.m.showRewarded('life'), isTrue);
      expect(ev, isEmpty);
    });
  });

  // docs/18 (1.1.1): seviye 15/16 → 17 geçişinde ilk geçiş reklamı denemesi ASLA oyunu tutmamalı.
  group('geçiş reklamı denemesi sınırlı ve geri alınabilir (1.1.1)', () {
    // seviye 13, 14, 15 tamamlandı → sayaç 3: ilk deneme
    Rig armed({Duration native = const Duration(seconds: 5), Duration show = const Duration(milliseconds: 150)}) {
      final Rig r = Rig(timeout: native, showTimeout: show);
      r.m.onLevelComplete(13);
      r.m.onLevelComplete(14);
      r.m.onLevelComplete(15);
      return r;
    }

    Future<(bool, int)> timed(Rig r) async {
      final Stopwatch sw = Stopwatch()..start();
      final bool shown = await r.m.continueAfterLevel(15);
      return (shown, sw.elapsedMilliseconds);
    }

    List<bool> listen(Rig r) {
      final List<bool> ev = <bool>[];
      r.m.addAdListener(ev.add);
      return ev;
    }

    test('doldurulamadı (no fill): anında false, platform gösterilmez, duraklatma hiç açılmaz, sayaç korunur', () async {
      final Rig r = armed()..p.interstitialOk = false;
      final List<bool> ev = listen(r);
      final (bool shown, int ms) = await timed(r);
      expect(shown, isFalse);
      expect(ms, lessThan(100));
      expect(r.p.calls, isNot(contains('interstitial')));
      expect(ev, isEmpty);
      expect(r.ads.since, 3);
    });

    test('geri çağrı HİÇ gelmez: gösterim süresi içinde false, duraklatma geri alınır', () async {
      final Rig r = armed()..p.hangInterstitial = true;
      final List<bool> ev = listen(r);
      final (bool shown, int ms) = await timed(r);
      expect(shown, isFalse);
      expect(ms, lessThan(1500), reason: '90 sn beklememeli');
      expect(ev, <bool>[true, false]);
      expect(r.m.isAdShowing, isFalse);
    });

    test('gösterilemedi (onAdFailedToShow): false, duraklatma geri alınır', () async {
      final Rig r = armed()..p.failToShow = true;
      final List<bool> ev = listen(r);
      final (bool shown, int ms) = await timed(r);
      expect(shown, isFalse);
      expect(ms, lessThan(500));
      expect(ev, <bool>[true, false]);
    });

    test('platform senkron istisna fırlatır: false, duraklatma geri alınır', () async {
      final Rig r = armed()..p.throwOnShow = true;
      final List<bool> ev = listen(r);
      expect(await r.m.continueAfterLevel(15), isFalse);
      expect(ev, <bool>[true, false]);
    });

    test('yavaş yükleme/gösterim (süreden uzun, ekrana gelmez): atlanır; geç gelen sonuç hatasız yok sayılır', () async {
      final Rig r = armed()..p.showAfter = const Duration(milliseconds: 600);
      final List<bool> ev = listen(r);
      final (bool shown, int ms) = await timed(r);
      expect(shown, isFalse);
      expect(ms, lessThan(450));
      expect(ev, <bool>[true, false]);
      await Future<void>.delayed(const Duration(milliseconds: 700)); // geç tamamlanma: ikinci tamamlama/istisna yok
      expect(r.m.isAdShowing, isFalse);
    });

    test('reklam gerçekten ekrana geldiyse kapanışı beklenir (oyuncu izliyor), sonra true', () async {
      final Rig r = armed()
        ..p.showAfter = const Duration(milliseconds: 500)
        ..p.appearsOnScreen = true;
      final List<bool> ev = listen(r);
      final (bool shown, int ms) = await timed(r);
      expect(shown, isTrue);
      expect(ms, greaterThanOrEqualTo(450), reason: 'ekrandaki reklam 150 ms gösterim süresinde kesilmemeli');
      expect(ev, <bool>[true, false]);
    });

    test('ekrandaki reklam kapanış olayı hiç göndermezse nativeTimeout ile biter', () async {
      final Rig r = armed(native: const Duration(milliseconds: 400))
        ..p.hangInterstitial = true
        ..p.onScreen = true;
      final List<bool> ev = listen(r);
      final (bool shown, int ms) = await timed(r);
      expect(shown, isFalse);
      expect(ms, greaterThanOrEqualTo(350));
      expect(ms, lessThan(1500));
      expect(ev, <bool>[true, false]);
    });

    test('art arda iki seviye sonu denemesi: sayaç ve duraklatma dengeli kalır', () async {
      final Rig r = armed()..p.hangInterstitial = true;
      final List<bool> ev = listen(r);
      expect(await r.m.continueAfterLevel(15), isFalse);
      r.t += 4 * min;
      r.m.onLevelComplete(16);
      r.m.onLevelComplete(17);
      r.m.onLevelComplete(18);
      expect(await r.m.continueAfterLevel(18), isFalse);
      expect(ev, <bool>[true, false, true, false]);
      expect(r.m.isAdShowing, isFalse);
    });
  });
}
