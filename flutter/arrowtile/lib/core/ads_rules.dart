// Arrowtile — ads_rules.dart: ads.js (window.Monetization) kurallarının Dart karşılığı. Saf Dart.
//
// Oyun kodu reklam/satın alma SDK'sını DOĞRUDAN çağırmaz; yalnızca bu katmanı çağırır. SDK'ya bağlı kısım
// [AdsPlatform] arayüzünün arkasındadır (bu dosyada tanımlı; gerçek uygulaması services/ads_service.dart içindeki
// FlutterAdsPlatform); testlerde sahte uygulama + sahte saat kullanılır.
//
// KURALLAR (docs/00 "Reklam ve satın alma")
//  - Yalnızca geçiş reklamı, yalnızca seviye SONU ekranından oyuncu devam edince (continueAfterLevel).
//    Seviye ortası, duraklatma, öğretici, günlük bulmaca: reklam yok (bu yollar API'yi çağırmaz).
//  - Bölüm 1 (seviye 1-12) tamamen reklamsız; sayaç yalnızca 13+ seviyelerde ilerler.
//  - En erken her 3 tamamlanan seviyede bir (başarısız deneme sayılmaz), iki reklam arası en az 3 dakika.
//  - İnternet yoksa ya da reklam SDK'sı yoksa reklam gösterilmez, oyun normal devam eder.
//  - "Reklamları kaldır" (tüketilmeyen `remove_ads`): geçiş reklamları kalıcı kapanır, ödüllü reklamlar isteğe bağlı kalır.
//    Platform yoksa (testler) satın alma TEST MODUNDA taklit edilir.
//  - Bu katman hiçbir zaman oyunu bekletmez: platform yanıt vermezse [nativeTimeout] sonra oyun devam eder.
import 'dart:async';

import 'save_data.dart';

const int kFreeUntilLevel = 12;
const int kEveryLevels = 3;
const int kMinGapMs = 3 * 60 * 1000;
const Duration kNativeTimeout = Duration(seconds: 90);
const String kProductRemoveAds = 'remove_ads';

enum PurchaseOutcome { purchased, pending, cancelled, failed, unavailable }

/// Reklam/satın alma platformu (AdMob + UMP + Play Billing). Android köprüsündeki (AndroidBridge) metotların karşılığı.
abstract class AdsPlatform {
  /// JS: bridge() != null — SDK kullanılabilir mi (başlatıldı, onay alındı).
  bool get available;

  /// Cihaz internete bağlı mı.
  bool get online;

  /// Play'den doğrulanmış "remove_ads" sahipliği (önbellekli; çevrimdışı açılışta da doğru).
  bool get ownsRemoveAds;

  bool get interstitialReady;
  bool get rewardedReady;

  /// Geçiş reklamını gösterir; reklam kapanınca true, gösterilemezse/başarısızsa false döner.
  Future<bool> showInterstitial();

  /// Ödüllü reklamı gösterir; ödül hak edilince [onReward] çağrılır; reklam kapanınca Future tamamlanır.
  Future<void> showRewarded(String placement, void Function() onReward);

  Future<PurchaseOutcome> purchaseRemoveAds();

  /// Play'e sorar: sahiplik var mı? Sorgu başarısızsa null.
  Future<bool?> restorePurchases();

  /// UMP: Ayarlar'da "Gizlilik seçenekleri" gösterilmeli mi.
  bool get privacyOptionsRequired;
  Future<void> showPrivacyOptions();
}

class PurchaseResult {
  final bool ok;
  final bool already;
  final bool test;
  final String? reason; // cancelled | pending | failed | offline | timeout
  const PurchaseResult({required this.ok, this.already = false, this.test = false, this.reason});
}

class RestoreResult {
  final bool ok;
  final bool adFree;
  final bool test;
  final String? reason;
  const RestoreResult({required this.ok, this.adFree = false, this.test = false, this.reason});
}

class Monetization {
  final AdsPlatform platform;
  final AdsState Function() getAds;
  final void Function() persist;
  final int Function() now;
  final Duration nativeTimeout;

  Monetization({
    required this.platform,
    required this.getAds,
    required this.persist,
    int Function()? now,
    this.nativeTimeout = kNativeTimeout,
  }) : now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  bool get _bridge => platform.available;
  bool get _online => platform.online;

  /// "Reklamları kaldır" sahipliği. Test modunda "satın alınan" reklamsızlık gerçek platform varken geçerli sayılmaz.
  bool isAdFree() {
    final AdsState a = getAds();
    if (a.adFree && !(a.test && _bridge)) return true;
    if (_bridge && platform.ownsRemoveAds) {
      a.adFree = true;
      a.test = false;
      persist();
      return true;
    }
    return false;
  }

  bool get isTestMode => !_bridge;

  // ---- geçiş reklamı ----
  /// Bir seviye başarıyla tamamlandı (yalnızca 13+ sayılır).
  void onLevelComplete(int levelId) {
    if (!(levelId > kFreeUntilLevel)) return;
    final AdsState a = getAds();
    a.since = a.since + 1;
    persist();
  }

  bool interstitialDue(int levelId) {
    final AdsState a = getAds();
    if (!(levelId > kFreeUntilLevel)) return false;
    if (isAdFree()) return false;
    if (a.since < kEveryLevels) return false;
    if (a.lastAt != 0 && now() - a.lastAt < kMinGapMs) return false;
    if (!_bridge || !_online) return false;
    return true;
  }

  /// Seviye sonu ekranında oyuncu devam edince çağrılır. Reklam gösterilip kapandıysa true.
  /// Her durumda biter (zaman aşımı korumalı); oyun asla takılmaz.
  Future<bool> continueAfterLevel(int levelId) async {
    if (!interstitialDue(levelId)) return false;
    if (!platform.interstitialReady) return false; // doldurulamadı: hemen devam, sayaç sıfırlanmaz
    final AdsState a = getAds();
    a.since = 0;
    a.lastAt = now();
    persist();
    try {
      return await platform.showInterstitial().timeout(nativeTimeout, onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  // ---- ödüllü reklam (isteğe bağlı; reklamsız sürümde de kullanılabilir) ----
  bool rewardedAvailable() {
    if (!_bridge || !_online) return false;
    return platform.rewardedReady;
  }

  /// [onReward] ödül hak edilirse en çok bir kez çağrılır. Dönen değer: ödül verildi mi.
  Future<bool> showRewarded(String placement, {void Function()? onReward}) async {
    if (!rewardedAvailable()) return false;
    bool rewarded = false;
    try {
      await platform.showRewarded(placement, () {
        if (rewarded) return;
        rewarded = true;
        onReward?.call();
      }).timeout(nativeTimeout, onTimeout: () {});
    } catch (_) {
      // yut: oyun devam eder
    }
    return rewarded;
  }

  // ---- satın alma ----
  Future<PurchaseResult> purchaseRemoveAds() async {
    if (isAdFree()) return const PurchaseResult(ok: true, already: true);
    final AdsState a = getAds();
    if (!_bridge) {
      // platform yok: test modu
      a.adFree = true;
      a.test = true;
      persist();
      return const PurchaseResult(ok: true, test: true);
    }
    PurchaseOutcome out;
    try {
      out = await platform.purchaseRemoveAds().timeout(nativeTimeout);
    } on TimeoutException {
      return const PurchaseResult(ok: false, reason: 'timeout');
    } catch (_) {
      return PurchaseResult(ok: false, reason: _online ? 'failed' : 'offline');
    }
    switch (out) {
      case PurchaseOutcome.purchased:
        a.adFree = true;
        a.test = false;
        persist();
        return const PurchaseResult(ok: true);
      case PurchaseOutcome.cancelled:
        return const PurchaseResult(ok: false, reason: 'cancelled');
      case PurchaseOutcome.pending:
        return const PurchaseResult(ok: false, reason: 'pending');
      case PurchaseOutcome.failed:
        return const PurchaseResult(ok: false, reason: 'failed');
      case PurchaseOutcome.unavailable:
        return PurchaseResult(ok: false, reason: _online ? 'failed' : 'offline');
    }
  }

  Future<RestoreResult> restorePurchases() async {
    final AdsState a = getAds();
    if (!_bridge) return RestoreResult(ok: true, adFree: a.adFree, test: true);
    bool? owned;
    try {
      owned = await platform.restorePurchases().timeout(nativeTimeout);
    } on TimeoutException {
      return const RestoreResult(ok: false, reason: 'timeout');
    } catch (_) {
      return RestoreResult(ok: false, reason: _online ? 'failed' : 'offline');
    }
    if (owned == null) return RestoreResult(ok: false, reason: _online ? 'failed' : 'offline');
    if (owned) {
      a.adFree = true;
      a.test = false;
    }
    persist();
    return RestoreResult(ok: true, adFree: owned);
  }

  // ---- gizlilik seçenekleri (UMP; yalnızca platform varsa ve bölge gerektiriyorsa) ----
  bool get privacyOptionsRequired => _bridge && platform.privacyOptionsRequired;

  /// Form kapanınca (ya da gösterilemezse) biter. Form açıldıysa true.
  Future<bool> showPrivacyOptions() async {
    if (!privacyOptionsRequired) return false;
    try {
      await platform.showPrivacyOptions().timeout(nativeTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }
}
