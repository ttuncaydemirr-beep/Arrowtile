// 1.2.3 (docs/29 §3): iade/geri ödeme sonrası "Reklamları kaldır" hakkı geri alınır.
//  - Play sorgusu BAŞARIYLA bitti ve ürün sahipliği var   → reklamsız verilir
//  - Play sorgusu BAŞARIYLA bitti ve ürün sahipliği YOK   → 1.2.4: art arda en az 2 "yok" yanıtı VE ilk yanıttan bu yana
//    24 saat geçince reklamsızlık kaldırılır ve kaydedilir (iade); daha önce yalnızca sayaç kaydedilir
//  - sorgu başarısız (null / çevrimdışı / zaman aşımı / istisna) → kayıttaki değer korunur
//  - test modu (platform yok) reklamsızlığı bozulmaz
import 'dart:convert';

import 'package:arrowtile/core/ads_rules.dart';
import 'package:arrowtile/core/save_data.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';

const int _h = 60 * 60 * 1000;

class _Rig {
  final FakePlatform p = FakePlatform();
  final AdsState ads = AdsState();
  int saves = 0;
  int t = 1000000;
  late final Monetization m = Monetization(
    platform: p,
    getAds: () => ads,
    persist: () => saves++,
    now: () => t,
    nativeTimeout: const Duration(milliseconds: 40),
  );
}

class _ThrowingPlatform extends FakePlatform {
  @override
  Future<bool?> restorePurchases() async => throw StateError('billing hata');
}

class _HangingRestorePlatform extends FakePlatform {
  @override
  Future<bool?> restorePurchases() => Future<bool?>.delayed(const Duration(seconds: 5));
}

void main() {
  group('Monetization.restorePurchases', () {
    test('sahiplik var (owned=true) → reklamsız verilir ve kaydedilir', () async {
      final _Rig r = _Rig()..p.restoreOwned = true;
      final RestoreResult rr = await r.m.restorePurchases();
      expect(rr.ok && rr.adFree, isTrue);
      expect(r.ads.adFree, isTrue);
      expect(r.saves, greaterThan(0));
    });

    test('sorgu tamamlandı, sahiplik yok (iade) → ilk yanıtta korunur, 24 sa sonraki yanıtta adFree=false ve kaydedilir', () async {
      final _Rig r = _Rig()..p.restoreOwned = false;
      r.ads.adFree = true;
      final int before = r.saves;
      RestoreResult rr = await r.m.restorePurchases();
      expect(rr.ok, isTrue);
      expect(rr.adFree, isFalse, reason: "Play'in yanıtı olduğu gibi bildirilir");
      expect(r.ads.adFree, isTrue, reason: 'tek boş yanıt reklamsızlığı kaldırmaz');
      expect(r.ads.refundMiss, 1);
      expect(r.saves, greaterThan(before), reason: 'sayaç kalıcı yazılmalı');

      r.t += 24 * _h;
      final int mid = r.saves;
      rr = await r.m.restorePurchases();
      expect(rr.ok, isTrue);
      expect(r.ads.adFree, isFalse);
      expect(r.ads.refundMiss, 0);
      expect(r.ads.refundMissAt, 0);
      expect(r.saves, greaterThan(mid), reason: 'iade sonrası kayıt yazılmalı');
      expect(r.m.isAdFree(), isFalse);
    });

    test('sorgu null (çevrimdışı/başarısız) → kayıttaki adFree korunur', () async {
      final _Rig r = _Rig()..p.restoreOwned = null;
      r.ads.adFree = true;
      final RestoreResult rr = await r.m.restorePurchases();
      expect(rr.ok, isFalse);
      expect(r.ads.adFree, isTrue);
    });

    test('platform istisna fırlatırsa → adFree korunur', () async {
      final _Rig r = _Rig();
      final Monetization m = Monetization(
        platform: _ThrowingPlatform(),
        getAds: () => r.ads,
        persist: () => r.saves++,
        nativeTimeout: const Duration(milliseconds: 40),
      );
      r.ads.adFree = true;
      final RestoreResult rr = await m.restorePurchases();
      expect(rr.ok, isFalse);
      expect(r.ads.adFree, isTrue);
    });

    test('zaman aşımı → adFree korunur', () async {
      final _Rig r = _Rig();
      final Monetization m = Monetization(
        platform: _HangingRestorePlatform(),
        getAds: () => r.ads,
        persist: () => r.saves++,
        nativeTimeout: const Duration(milliseconds: 40),
      );
      r.ads.adFree = true;
      final RestoreResult rr = await m.restorePurchases();
      expect(rr.ok, isFalse);
      expect(rr.reason, 'timeout');
      expect(r.ads.adFree, isTrue);
    });

    test('platform yok (test modu): reklamsızlık ve test bayrağı bozulmaz', () async {
      final _Rig r = _Rig()..p.isAvailable = false;
      r.ads
        ..adFree = true
        ..test = true;
      final RestoreResult rr = await r.m.restorePurchases();
      expect(rr.ok && rr.adFree && rr.test, isTrue);
      expect(r.ads.adFree && r.ads.test, isTrue);
    });
  });

  group('Monetization.applyOwnership', () {
    test('true → verir; false (2 yanıt + 24 sa) → kaldırır; test modu kaydına dokunmaz', () {
      final _Rig r = _Rig();
      r.m.applyOwnership(true);
      expect(r.ads.adFree, isTrue);
      expect(r.ads.test, isFalse);
      r.m.applyOwnership(false);
      r.t += 24 * _h;
      r.m.applyOwnership(false);
      expect(r.ads.adFree, isFalse);
      r.ads
        ..adFree = true
        ..test = true;
      r.m.applyOwnership(false);
      expect(r.ads.adFree, isTrue, reason: 'test modu reklamsızlığı iade kuralına girmez');
    });

    test('1.2.4: iki boş yanıt ama 24 sa dolmadı → korunur; dolunca kaldırılır', () {
      final _Rig r = _Rig();
      r.ads.adFree = true;
      r.m.applyOwnership(false);
      r.t += 1 * _h;
      r.m.applyOwnership(false);
      r.t += 22 * _h; // ilk yanıttan bu yana 23 sa
      r.m.applyOwnership(false);
      expect(r.ads.adFree, isTrue, reason: '24 saat dolmadan kaldırılmaz');
      expect(r.ads.refundMiss, 3);
      r.t += 1 * _h; // tam 24 sa
      r.m.applyOwnership(false);
      expect(r.ads.adFree, isFalse);
    });

    test('1.2.4: 24 sa geçti ama yalnızca tek boş yanıt var → korunur', () {
      final _Rig r = _Rig();
      r.ads.adFree = true;
      r.t += 48 * _h;
      r.m.applyOwnership(false);
      expect(r.ads.adFree, isTrue, reason: 'ilk boş yanıt yalnızca sayacı başlatır');
      expect(r.ads.refundMissAt, r.t);
    });

    test('1.2.4: arada "var" yanıtı gelirse sayaç sıfırlanır', () {
      final _Rig r = _Rig();
      r.ads.adFree = true;
      r.m.applyOwnership(false);
      r.t += 30 * _h;
      r.m.applyOwnership(true); // geçici hataydı, Play yine "var" dedi
      expect(r.ads.refundMiss, 0);
      expect(r.ads.refundMissAt, 0);
      r.t += 1 * _h;
      r.m.applyOwnership(false);
      expect(r.ads.adFree, isTrue, reason: 'sayaç yeniden başladı; 24 sa daha gerekir');
      expect(r.ads.refundMiss, 1);
    });

    test('1.2.4: cihaz saati geri alınırsa sayaç yeniden başlar (erken kaldırma yok)', () {
      final _Rig r = _Rig();
      r.ads.adFree = true;
      r.m.applyOwnership(false);
      r.t -= 10 * _h;
      r.m.applyOwnership(false);
      expect(r.ads.adFree, isTrue);
      expect(r.ads.refundMissAt, r.t);
    });

    test('1.2.4: sahipken tekrarlanan "var" yanıtı gereksiz kayıt yazmaz', () {
      final _Rig r = _Rig();
      r.m.applyOwnership(true);
      final int n = r.saves;
      r.m.applyOwnership(true);
      expect(r.saves, n);
    });

    test('kayıt zaten reklamsız değilken false gereksiz kayıt yazmaz', () {
      final _Rig r = _Rig();
      r.m.applyOwnership(false);
      expect(r.saves, 0);
    });
  });

  group('1.2.4: iade sayacı kaydı', () {
    test('sayaç kayda yazılır ve geri okunur; sayaç yoksa kayıt biçimi değişmez', () {
      final SaveData d = SaveData.defaults('tr');
      expect(d.toJson()['ads'], isNot(contains('refundMiss')));
      expect(d.toJson()['ads'], isNot(contains('refundMissAt')));
      d.ads
        ..adFree = true
        ..refundMiss = 2
        ..refundMissAt = 1700000000000;
      final SaveData back = sanitize(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>, 'tr');
      expect(back.ads.refundMiss, 2);
      expect(back.ads.refundMissAt, 1700000000000);
      expect(back.ads.adFree, isTrue);
    });
  });

  group('1.2.4: eski (1.2.3) kayıt biçimi geçişi', () {
    test('iade sayacı alanları olmayan 1.2.3 kaydı sorunsuz okunur; satın alma ve ilerleme korunur', () {
      // 1.2.3'ün yazdığı biçim: ads içinde refundMiss / refundMissAt YOK
      final Map<String, dynamic> old = <String, dynamic>{
        'lang': 'tr',
        'coins': 340,
        'unlocked': 27,
        'stars': <String, int>{'1': 3, '2': 2},
        'ads': <String, dynamic>{
          'since': 2,
          'lastAt': 1700000000000,
          'adFree': true,
          'test': false,
          'coinDate': '2026-11-20',
          'coinCount': 1,
        },
      };
      final SaveData s = sanitize(jsonDecode(jsonEncode(old)), 'tr');
      expect(s.ads.adFree, isTrue, reason: 'satın alma korunur');
      expect(s.ads.refundMiss, 0);
      expect(s.ads.refundMissAt, 0);
      expect(s.coins, 340);
      expect(s.unlocked, 27);
      expect(s.stars[1], 3);
      expect(s.ads.coinCount, 1);
      // geri yazılınca biçim 1.2.3 ile aynı kalır (sayaç yokken yeni alan eklenmez)
      expect((s.toJson()['ads'] as Map<String, dynamic>).keys, isNot(contains('refundMiss')));
    });
  });

  group('AppController: BillingService.onOwnedChanged', () {
    testWidgets('owned=true verir, owned=false (iade) kaldırır ve cihaza yazar', (WidgetTester t) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppController? made = await t.runAsync(() => AppController.create(adsPlatform: FakePlatform()));
      final AppController app = made!;
      final void Function(bool)? cb = app.billing.onOwnedChanged;
      expect(cb, isNotNull);

      cb!(true);
      expect(app.save.ads.adFree, isTrue);
      expect(app.store.load('tr').ads.adFree, isTrue, reason: 'satın alma kalıcı yazılmalı');

      cb(false); // Play sorgusu başarıyla bitti, ürün yok → 1.2.4: önce yalnızca sayaç (kalıcı)
      expect(app.save.ads.adFree, isTrue);
      expect(app.store.load('tr').ads.refundMiss, 1, reason: 'iade sayacı kalıcı yazılmalı');
      app.save.ads.refundMissAt -= 24 * _h; // ilk boş yanıt 24 saat önceymiş gibi
      cb(false); // ikinci boş yanıt → iade
      expect(app.save.ads.adFree, isFalse);
      expect(app.store.load('tr').ads.adFree, isFalse, reason: 'iade kalıcı yazılmalı');
    });
  });
}
