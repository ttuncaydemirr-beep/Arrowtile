// Reklam/satın alma kuralları (ads.js → ads_rules.dart): altın senaryolar + tools/test-ads.js vakalarının Dart karşılığı.
// Sahte saat + sahte platform; gerçek AdMob/Billing çağrılmaz.
import 'dart:async';

import 'package:arrowtile/core/ads_rules.dart';
import 'package:arrowtile/core/save_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class FakePlatform implements AdsPlatform {
  bool isAvailable = true;
  bool isOnline = true;
  bool owns = false;
  bool interstitialOk = true;
  bool rewardedOk = true;
  bool rewardGiven = true; // false: ödül hak edilmeden kapanır
  bool hangInterstitial = false;
  bool hangPurchase = false;
  PurchaseOutcome purchaseOutcome = PurchaseOutcome.purchased;
  bool? restoreOwned = false;
  bool privacyRequired = false;
  final List<String> calls = <String>[];

  @override
  bool get available => isAvailable;
  @override
  bool get online => isOnline;
  @override
  bool get ownsRemoveAds => owns;
  @override
  bool get interstitialReady => interstitialOk;
  @override
  bool get rewardedReady => rewardedOk;

  @override
  Future<bool> showInterstitial() {
    calls.add('interstitial');
    if (hangInterstitial) return Completer<bool>().future;
    return Future<bool>.value(true);
  }

  @override
  Future<void> showRewarded(String placement, void Function() onReward) async {
    calls.add('rewarded:$placement');
    if (rewardGiven) onReward();
  }

  @override
  Future<PurchaseOutcome> purchaseRemoveAds() {
    calls.add('purchase');
    if (hangPurchase) return Completer<PurchaseOutcome>().future;
    return Future<PurchaseOutcome>.value(purchaseOutcome);
  }

  @override
  Future<bool?> restorePurchases() {
    calls.add('restore');
    return Future<bool?>.value(restoreOwned);
  }

  @override
  bool get privacyOptionsRequired => privacyRequired;
  @override
  Future<void> showPrivacyOptions() async {
    calls.add('privacy');
  }
}

class Rig {
  final FakePlatform p = FakePlatform();
  final AdsState ads = AdsState();
  int t = 1000000;
  int saves = 0;
  late final Monetization m;
  Rig({Duration timeout = const Duration(milliseconds: 40)}) {
    m = Monetization(platform: p, getAds: () => ads, persist: () => saves++, now: () => t, nativeTimeout: timeout);
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
}
