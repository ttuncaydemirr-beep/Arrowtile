// 1.2.4: BillingService gerçek in_app_purchase zinciriyle (sahte Play platformu) sınanır.
//  - Kullanıcı ödeme ekranını kapatınca Android eklentisi ürün adı BOŞ bir "canceled" öğesi yayınlar
//    (in_app_purchase_android 0.5.5 `_getPurchaseDetailsFromResult`). Satın alma akışı hemen "cancelled" ile bitmeli
//    (eskiden yanıtsız kalıp 90 sn kilitleniyordu).
//  - Boş adlı "error" öğesi → "failed".
//  - Başka bir ürünün olayı remove_ads akışını bitirmez.
//  - Her başarılı sahiplik sorgusu (yalnızca değişince değil) onOwnedChanged ile bildirilir.
import 'dart:async';

import 'package:arrowtile/config/ads_config.dart';
import 'package:arrowtile/core/ads_rules.dart';
import 'package:arrowtile/services/billing_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

class _FakeIap extends InAppPurchasePlatform {
  final StreamController<List<PurchaseDetails>> ctl = StreamController<List<PurchaseDetails>>.broadcast();
  int restores = 0;
  List<PurchaseDetails> Function() restoreList = () => <PurchaseDetails>[];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => ctl.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async => ProductDetailsResponse(
        productDetails: <ProductDetails>[
          ProductDetails(
              id: AdsConfig.removeAdsProductId,
              title: 'Remove ads',
              description: '',
              price: r'$2.99',
              rawPrice: 2.99,
              currencyCode: 'USD'),
        ],
        notFoundIDs: <String>[],
      );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async => true;

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restores++;
    final List<PurchaseDetails> l = restoreList();
    scheduleMicrotask(() => ctl.add(l));
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}

/// Eklentinin ödeme ekranı kapatıldığında / hata olduğunda yayınladığı öğe (ürün adı boş).
PurchaseDetails _empty(PurchaseStatus st) => PurchaseDetails(
      purchaseID: '',
      productID: '',
      status: st,
      transactionDate: null,
      verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: '', source: 'google_play'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeIap fake;

  setUpAll(() {
    // InAppPurchase.instance ilk erişimde Android platformunu kaydeder; testte sahtesi kalsın diye hedef platformu geçici değiştir.
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() {
    fake = _FakeIap();
    InAppPurchasePlatform.instance = fake;
  });

  Future<BillingService> started() async {
    final BillingService b = BillingService();
    await b.start();
    await pumpEventQueue();
    return b;
  }

  test('ödeme ekranı kapatıldı (boş adlı canceled) → hemen cancelled, kilit yok', () async {
    final BillingService b = await started();
    final Future<PurchaseOutcome> f = b.purchase();
    await pumpEventQueue();
    fake.ctl.add(<PurchaseDetails>[_empty(PurchaseStatus.canceled)]);
    final PurchaseOutcome out = await f.timeout(const Duration(seconds: 2));
    expect(out, PurchaseOutcome.cancelled);
    expect(b.owned, isFalse);

    // ikinci deneme hemen yapılabilir ve gerçek satın alma sonucu alınır
    final Future<PurchaseOutcome> f2 = b.purchase();
    await pumpEventQueue();
    fake.ctl.add(<PurchaseDetails>[
      PurchaseDetails(
          purchaseID: 'GPA.1',
          productID: AdsConfig.removeAdsProductId,
          status: PurchaseStatus.purchased,
          transactionDate: '0',
          verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: 't', source: 'google_play')),
    ]);
    expect(await f2.timeout(const Duration(seconds: 2)), PurchaseOutcome.purchased);
    expect(b.owned, isTrue);
    b.dispose();
  });

  test('boş adlı error → failed (zaman aşımı beklenmez)', () async {
    final BillingService b = await started();
    final Future<PurchaseOutcome> f = b.purchase();
    await pumpEventQueue();
    fake.ctl.add(<PurchaseDetails>[_empty(PurchaseStatus.error)]);
    expect(await f.timeout(const Duration(seconds: 2)), PurchaseOutcome.failed);
    b.dispose();
  });

  test('başka ürünün olayı remove_ads akışını bitirmez', () async {
    final BillingService b = await started();
    bool done = false;
    final Future<PurchaseOutcome> f = b.purchase()..then((_) => done = true);
    await pumpEventQueue();
    fake.ctl.add(<PurchaseDetails>[
      PurchaseDetails(
          purchaseID: 'x',
          productID: 'other_product',
          status: PurchaseStatus.canceled,
          transactionDate: null,
          verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: '', source: 'google_play')),
    ]);
    await pumpEventQueue();
    expect(done, isFalse);
    fake.ctl.add(<PurchaseDetails>[_empty(PurchaseStatus.canceled)]);
    expect(await f.timeout(const Duration(seconds: 2)), PurchaseOutcome.cancelled);
    b.dispose();
  });

  test('her başarılı sahiplik sorgusu bildirilir (değişmese de)', () async {
    final List<bool> calls = <bool>[];
    final BillingService b = BillingService(owned: true)..onOwnedChanged = calls.add;
    await b.start(); // açılış sorgusu: ürün yok
    await pumpEventQueue();
    expect(await b.restore(), isFalse);
    expect(calls, <bool>[false, false], reason: 'iki ayrı sorgu → iki bildirim (iade kuralı sayabilsin)');
    expect(b.owned, isFalse);
    b.dispose();
  });
}
