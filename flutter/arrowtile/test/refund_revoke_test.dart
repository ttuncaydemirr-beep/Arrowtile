// 1.2.3 (docs/29 §3): iade/geri ödeme sonrası "Reklamları kaldır" hakkı geri alınır.
//  - Play sorgusu BAŞARIYLA bitti ve ürün sahipliği var   → reklamsız verilir
//  - Play sorgusu BAŞARIYLA bitti ve ürün sahipliği YOK   → reklamsızlık kaldırılır ve kaydedilir (iade)
//  - sorgu başarısız (null / çevrimdışı / zaman aşımı / istisna) → kayıttaki değer korunur
//  - test modu (platform yok) reklamsızlığı bozulmaz
import 'package:arrowtile/core/ads_rules.dart';
import 'package:arrowtile/core/save_data.dart';
import 'package:arrowtile/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ads_platform.dart';

class _Rig {
  final FakePlatform p = FakePlatform();
  final AdsState ads = AdsState();
  int saves = 0;
  late final Monetization m = Monetization(
    platform: p,
    getAds: () => ads,
    persist: () => saves++,
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

    test('sorgu tamamlandı, sahiplik yok (iade) → adFree=false ve kaydedilir', () async {
      final _Rig r = _Rig()..p.restoreOwned = false;
      r.ads.adFree = true;
      final int before = r.saves;
      final RestoreResult rr = await r.m.restorePurchases();
      expect(rr.ok, isTrue);
      expect(rr.adFree, isFalse);
      expect(r.ads.adFree, isFalse);
      expect(r.saves, greaterThan(before), reason: 'iade sonrası kayıt yazılmalı');
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
    test('true → verir; false → kaldırır; test modu kaydına dokunmaz', () {
      final _Rig r = _Rig();
      r.m.applyOwnership(true);
      expect(r.ads.adFree, isTrue);
      expect(r.ads.test, isFalse);
      r.m.applyOwnership(false);
      expect(r.ads.adFree, isFalse);
      r.ads
        ..adFree = true
        ..test = true;
      r.m.applyOwnership(false);
      expect(r.ads.adFree, isTrue, reason: 'test modu reklamsızlığı iade kuralına girmez');
    });

    test('kayıt zaten reklamsız değilken false gereksiz kayıt yazmaz', () {
      final _Rig r = _Rig();
      r.m.applyOwnership(false);
      expect(r.saves, 0);
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

      cb(false); // Play sorgusu başarıyla bitti, ürün yok → iade
      expect(app.save.ads.adFree, isFalse);
      expect(app.store.load('tr').ads.adFree, isFalse, reason: 'iade kalıcı yazılmalı');
    });
  });
}
