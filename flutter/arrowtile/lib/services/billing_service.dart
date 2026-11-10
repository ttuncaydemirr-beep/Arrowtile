// Arrowtile — billing_service.dart: Google Play Billing (in_app_purchase) ile tek tüketilmeyen ürün "remove_ads".
// Android BillingManager.java mantığının Dart karşılığı:
//  - Açılışta ve uygulama öne gelince sahiplik sorgulanır (restorePurchases → purchaseStream).
//  - PURCHASED → hak verilir, onaylanmamışsa completePurchase (acknowledge). 3 gün içinde onaylanmayan satın alma iade edilir.
//  - PENDING → hak VERİLMEZ, onaylanmaz; "ödeme bekleniyor" denir. Tamamlanınca purchaseStream'den ya da bir sonraki
//    sorgudan gelir.
//  - Sunucu doğrulaması yoktur (tek kişilik, sunucusuz oyun). Sunucu eklenirse purchaseToken Google Play Developer API ile
//    doğrulanmalıdır.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart' show PurchaseStateWrapper;
import 'package:in_app_purchase_android/in_app_purchase_android.dart' show GooglePlayPurchaseDetails;

import '../config/ads_config.dart';
import '../core/ads_rules.dart';

class BillingService {
  // tembel: platform kaydı olmayan ortamlarda (birim/widget testi) yalnızca kullanılınca erişilir
  late final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  Completer<PurchaseOutcome>? _purchase;
  Completer<bool?>? _restore;
  bool _available = false;
  bool _disposed = false;

  /// Play'den doğrulanmış sahiplik (başlangıç değeri: kayıttaki bayrak; çevrimdışı açılışta da doğru yanıt verir).
  bool owned;

  /// Sahiplik değişince (ör. bekleyen satın alma tamamlandı) çağrılır.
  void Function(bool owned)? onOwnedChanged;

  BillingService({this.owned = false});

  bool get available => _available;

  /// Play'in bildirdiği ürün fiyatı (analiz satın alma olayı için; ürün sorgulanmadıysa null).
  double? get priceValue => _product?.rawPrice;
  String? get priceCurrency => _product?.currencyCode;

  Future<void> start() async {
    try {
      _available = await _iap.isAvailable();
      _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
        if (kDebugMode) debugPrint('purchaseStream hata: $e');
      });
      if (_available) {
        unawaited(_queryProduct());
        unawaited(restore()); // sahiplik denetimi (sessiz)
      }
    } catch (e) {
      if (kDebugMode) debugPrint('BillingService.start: $e');
      _available = false;
    }
  }

  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _sub = null;
  }

  Future<ProductDetails?> _queryProduct() async {
    try {
      final ProductDetailsResponse r = await _iap.queryProductDetails(<String>{AdsConfig.removeAdsProductId});
      if (r.error != null || r.productDetails.isEmpty) {
        if (kDebugMode) debugPrint("remove_ads bulunamadı (Play Console'da etkin mi?) ${r.error?.message}");
        return null;
      }
      _product = r.productDetails.first;
      return _product;
    } catch (e) {
      if (kDebugMode) debugPrint('queryProductDetails: $e');
      return null;
    }
  }

  void _setOwned(bool v) {
    if (v == owned) return;
    owned = v;
    onOwnedChanged?.call(v);
  }

  /// Satın alma akışını başlatır; sonuç purchaseStream'den gelir.
  Future<PurchaseOutcome> purchase() async {
    if (!_available) return PurchaseOutcome.unavailable;
    final ProductDetails? pd = _product ?? await _queryProduct();
    if (pd == null) return PurchaseOutcome.failed;
    _purchase?.complete(PurchaseOutcome.failed); // yanıtsız kalmış önceki akışı kapat
    final Completer<PurchaseOutcome> c = Completer<PurchaseOutcome>();
    _purchase = c;
    try {
      final bool started = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: pd));
      if (!started) {
        _purchase = null;
        // Çoğunlukla ITEM_ALREADY_OWNED: sahipliği yeniden sorgula
        final bool? o = await restore();
        return o == true ? PurchaseOutcome.purchased : PurchaseOutcome.failed;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('buyNonConsumable: $e');
      _purchase = null;
      return PurchaseOutcome.failed;
    }
    return c.future;
  }

  /// Play'e sahipliği sorar. true/false = Play'in yanıtı, null = sorgu başarısız (kayıtlı değer korunur).
  Future<bool?> restore() async {
    if (!_available) return null;
    _restore?.complete(null);
    final Completer<bool?> c = Completer<bool?>();
    _restore = c;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      if (kDebugMode) debugPrint('restorePurchases: $e');
      if (identical(_restore, c)) _restore = null;
      if (!c.isCompleted) c.complete(null);
      return null;
    }
    return c.future.timeout(const Duration(seconds: 20), onTimeout: () {
      if (identical(_restore, c)) _restore = null;
      return null;
    });
  }

  /// Android: restorePurchases bekleyen (PENDING) satın almaları da "restored" olarak bildirir; gerçek durumu ayıkla.
  bool _isReallyPurchased(PurchaseDetails p) {
    if (p is GooglePlayPurchaseDetails) {
      return p.billingClientPurchase.purchaseState == PurchaseStateWrapper.purchased;
    }
    return p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored;
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    if (_disposed) return;
    bool sawPurchased = false;
    bool sawPending = false;
    bool sawFailed = false;
    bool sawCancelled = false;
    bool sawRestored = false;
    for (final PurchaseDetails p in list) {
      if (p.productID != AdsConfig.removeAdsProductId) {
        if (p.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(p);
          } catch (_) {}
        }
        continue;
      }
      if (p.status == PurchaseStatus.restored) sawRestored = true;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_isReallyPurchased(p)) {
            sawPurchased = true;
            if (p.pendingCompletePurchase) {
              try {
                await _iap.completePurchase(p); // acknowledge
              } catch (e) {
                if (kDebugMode) debugPrint('completePurchase: $e');
              }
            }
          } else {
            sawPending = true;
          }
        case PurchaseStatus.pending:
          sawPending = true;
        case PurchaseStatus.canceled:
          sawCancelled = true;
        case PurchaseStatus.error:
          sawFailed = true;
      }
    }
    // Yeni satın alma sonucu
    final Completer<PurchaseOutcome>? pc = _purchase;
    if (pc != null && !pc.isCompleted && list.isNotEmpty) {
      if (sawPurchased) {
        _purchase = null;
        _setOwned(true);
        pc.complete(PurchaseOutcome.purchased);
      } else if (sawPending) {
        _purchase = null;
        pc.complete(PurchaseOutcome.pending);
      } else if (sawCancelled) {
        _purchase = null;
        pc.complete(PurchaseOutcome.cancelled);
      } else if (sawFailed) {
        _purchase = null;
        pc.complete(PurchaseOutcome.failed);
      }
    } else if (sawPurchased) {
      // uygulama açıkken bekleyen ödeme tamamlandı
      _setOwned(true);
    }
    // Geri yükleme sonucu: boş liste ya da "restored" öğeleri restorePurchases'ın yanıtıdır
    final Completer<bool?>? rc = _restore;
    if (rc != null && !rc.isCompleted && (list.isEmpty || sawRestored)) {
      _restore = null;
      _setOwned(sawPurchased); // iade edilmişse sahiplik kalkar
      rc.complete(sawPurchased);
    }
  }
}
