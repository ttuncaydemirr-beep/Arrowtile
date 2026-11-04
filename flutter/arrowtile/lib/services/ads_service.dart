// Arrowtile — ads_service.dart: AdMob (geçiş + ödüllü) + UMP onay akışı + Play Billing'i [AdsPlatform] arayüzüne bağlar.
// Android AdsManager.java / ConsentManager.java mantığının karşılığı. NE ZAMAN reklam gösterileceğine KARAR VERMEZ:
// sıklık/bölüm/süre kuralları core/ads_rules.dart (Monetization) içindedir; burası yalnızca "hazır mı" ve "göster" sağlar.
//  - Reklam SDK'sı ancak UMP canRequestAds() true olduktan sonra başlatılır.
//  - Reklamlar önceden yüklenir; ~1 saat geçerlidir (55 dk sonra yenilenir); başarısız yüklemede artan bekleme (15 sn … 10 dk).
//  - İçerik derecesi PG (genel kitle; çocuklara yönelik değil — docs/10 "Hedef kitle").
import 'dart:async';
import 'dart:io' show InternetAddress;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_config.dart';
import '../core/ads_rules.dart';
import 'billing_service.dart';

class FlutterAdsPlatform implements AdsPlatform {
  FlutterAdsPlatform({required this.billing, this.onChanged});

  final BillingService billing;

  /// Gizlilik seçenekleri gerekliliği değişince (Ayarlar yenilensin).
  final VoidCallback? onChanged;

  static const int _maxAgeMs = 55 * 60 * 1000;
  static const int _retryMinMs = 15000;
  static const int _retryMaxMs = 10 * 60 * 1000;
  static const int _closeDelayMs = 350; // ödül olayı nadiren kapanıştan sonra gelir

  bool _started = false;
  bool _sdkReady = false;
  bool _online = true;
  bool _privacyRequired = false;
  bool _showing = false;
  bool _disposed = false;

  InterstitialAd? _interstitial;
  int _interstitialAt = 0;
  bool _loadingI = false;
  int _retryI = _retryMinMs;
  int _nextI = 0;

  RewardedAd? _rewarded;
  int _rewardedAt = 0;
  bool _loadingR = false;
  int _retryR = _retryMinMs;
  int _nextR = 0;

  static int _now() => DateTime.now().millisecondsSinceEpoch;
  static bool _expired(int at) => at > 0 && _now() - at > _maxAgeMs;

  // ------------------------------------------------------------------ UMP onayı
  /// Uygulama açılışında çağrılır: onay bilgisi güncellenir, gerekiyorsa form gösterilir, sonra SDK başlatılır.
  Future<void> gatherConsent() async {
    try {
      ConsentDebugSettings? dbg;
      if (kDebugMode && (AdsConfig.umpDebugGeographyEea || AdsConfig.umpTestDeviceId.isNotEmpty)) {
        dbg = ConsentDebugSettings(
          debugGeography: AdsConfig.umpDebugGeographyEea ? DebugGeography.debugGeographyEea : null,
          testIdentifiers: AdsConfig.umpTestDeviceId.isEmpty ? null : <String>[AdsConfig.umpTestDeviceId],
        );
      }
      final ConsentRequestParameters params =
          ConsentRequestParameters(tagForUnderAgeOfConsent: false, consentDebugSettings: dbg);
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) {
            if (formError != null && kDebugMode) debugPrint('UMP form: ${formError.message}');
            unawaited(_afterConsentUpdate());
          });
        },
        (FormError error) {
          if (kDebugMode) debugPrint('UMP update: ${error.message}');
          unawaited(_afterConsentUpdate());
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('gatherConsent: $e');
    }
    // Önceki oturumda alınmış onay varsa reklamlar beklemeden başlayabilir.
    await _afterConsentUpdate();
  }

  Future<void> _afterConsentUpdate() async {
    if (_disposed) return;
    try {
      final bool req = (await ConsentInformation.instance.getPrivacyOptionsRequirementStatus()) ==
          PrivacyOptionsRequirementStatus.required;
      if (req != _privacyRequired) {
        _privacyRequired = req;
        onChanged?.call();
      }
      if (await ConsentInformation.instance.canRequestAds()) await _initSdk();
    } catch (e) {
      if (kDebugMode) debugPrint('afterConsentUpdate: $e');
    }
  }

  Future<void> _initSdk() async {
    if (_started) return;
    _started = true;
    try {
      // Genel kitleye uygun reklam içeriği (oyun "her yaş" kitleye hitap ediyor; çocuklara yönelik değil).
      await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg));
      await MobileAds.instance.initialize();
      _sdkReady = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      if (kDebugMode) debugPrint('MobileAds.initialize: $e');
      _started = false;
    }
  }

  /// Uygulama öne gelince: süresi dolan reklamı yenile, bağlantıyı yeniden ölç.
  void onResume() {
    if (_disposed) return;
    unawaited(refreshOnline());
    if (!_sdkReady) {
      unawaited(_afterConsentUpdate());
      return;
    }
    if (_interstitial == null || _expired(_interstitialAt)) _loadInterstitial();
    if (_rewarded == null || _expired(_rewardedAt)) _loadRewarded();
    unawaited(billing.restore()); // uygulama kapalıyken tamamlanan bekleyen satın almaları yakala
  }

  void dispose() {
    _disposed = true;
    _interstitial?.dispose();
    _rewarded?.dispose();
    _interstitial = null;
    _rewarded = null;
  }

  /// Basit bağlantı denetimi (DNS). Başarısızsa reklam ve satın alma "çevrimdışı" sayılır.
  Future<void> refreshOnline() async {
    try {
      final List<InternetAddress> r = await InternetAddress.lookup('www.google.com').timeout(const Duration(seconds: 3));
      _online = r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      _online = false;
    }
  }

  // ------------------------------------------------------------------ AdsPlatform
  /// Flutter uygulamasında platform her zaman vardır (web'deki "köprü yok / test modu" durumu yalnızca birim testlerindedir).
  /// SDK'nın hazır olup olmadığı [interstitialReady] / [rewardedReady] ile ayrıca sorulur.
  @override
  bool get available => true;

  @override
  bool get online => _online;

  @override
  bool get ownsRemoveAds => billing.owned;

  @override
  bool get interstitialReady {
    final bool ok = _sdkReady && _interstitial != null && !_expired(_interstitialAt);
    if (!ok && _sdkReady) _loadInterstitial();
    return ok;
  }

  @override
  bool get rewardedReady {
    final bool ok = _sdkReady && _rewarded != null && !_expired(_rewardedAt);
    if (!ok && _sdkReady) _loadRewarded();
    return ok;
  }

  @override
  Future<bool> showInterstitial() {
    final InterstitialAd? ad = _interstitial;
    if (ad == null || _showing || _disposed) return Future<bool>.value(false);
    _interstitial = null;
    _showing = true;
    final Completer<bool> c = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (InterstitialAd a) {
        _showing = false;
        a.dispose();
        if (!c.isCompleted) c.complete(true);
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd a, AdError error) {
        _showing = false;
        if (kDebugMode) debugPrint('interstitial show failed: ${error.message}');
        a.dispose();
        if (!c.isCompleted) c.complete(false);
        _loadInterstitial();
      },
    );
    ad.show().catchError((Object e) {
      _showing = false;
      if (!c.isCompleted) c.complete(false);
    });
    return c.future;
  }

  @override
  Future<void> showRewarded(String placement, void Function() onReward) {
    final RewardedAd? ad = _rewarded;
    if (ad == null || _showing || _disposed) return Future<void>.value();
    _rewarded = null;
    _showing = true;
    final Completer<void> c = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (RewardedAd a) {
        _showing = false;
        a.dispose();
        // ödül olayı kapanıştan hemen sonra gelebilir: kapanışı kısa süre geciktir
        Timer(const Duration(milliseconds: _closeDelayMs), () {
          if (!c.isCompleted) c.complete();
        });
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd a, AdError error) {
        _showing = false;
        if (kDebugMode) debugPrint('rewarded show failed: ${error.message}');
        a.dispose();
        if (!c.isCompleted) c.complete();
        _loadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (AdWithoutView a, RewardItem reward) => onReward()).catchError((Object e) {
      _showing = false;
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }

  @override
  Future<PurchaseOutcome> purchaseRemoveAds() async {
    await refreshOnline();
    if (!_online) return PurchaseOutcome.unavailable;
    return billing.purchase();
  }

  @override
  Future<bool?> restorePurchases() async {
    await refreshOnline();
    if (!_online) return null;
    return billing.restore();
  }

  @override
  bool get privacyOptionsRequired => _privacyRequired;

  @override
  Future<void> showPrivacyOptions() async {
    final Completer<void> c = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? e) {
      if (e != null && kDebugMode) debugPrint('privacy options: ${e.message}');
      if (!c.isCompleted) c.complete();
    });
    await c.future;
    await _afterConsentUpdate();
  }

  // ------------------------------------------------------------------ yükleme
  void _loadInterstitial() {
    if (!_sdkReady || _disposed || _loadingI) return;
    if (_now() < _nextI) return; // başarısız yüklemeden sonra bekleme süresi
    if (_interstitial != null && !_expired(_interstitialAt)) return;
    _loadingI = true;
    InterstitialAd.load(
      adUnitId: AdsConfig.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _loadingI = false;
          if (_disposed) {
            ad.dispose();
            return;
          }
          _interstitial?.dispose();
          _interstitial = ad;
          _interstitialAt = _now();
          _retryI = _retryMinMs;
          _online = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _loadingI = false;
          _interstitial = null;
          if (kDebugMode) debugPrint('interstitial load failed (${error.code}): ${error.message}');
          if (error.code == 2) _online = false; // ERROR_CODE_NETWORK_ERROR
          final int wait = _retryI;
          _retryI = math.min(_retryMaxMs, _retryI * 2);
          _nextI = _now() + wait;
          Timer(Duration(milliseconds: wait), _loadInterstitial);
        },
      ),
    );
  }

  void _loadRewarded() {
    if (!_sdkReady || _disposed || _loadingR) return;
    if (_now() < _nextR) return;
    if (_rewarded != null && !_expired(_rewardedAt)) return;
    _loadingR = true;
    RewardedAd.load(
      adUnitId: AdsConfig.rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _loadingR = false;
          if (_disposed) {
            ad.dispose();
            return;
          }
          _rewarded?.dispose();
          _rewarded = ad;
          _rewardedAt = _now();
          _retryR = _retryMinMs;
          _online = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _loadingR = false;
          _rewarded = null;
          if (kDebugMode) debugPrint('rewarded load failed (${error.code}): ${error.message}');
          if (error.code == 2) _online = false;
          final int wait = _retryR;
          _retryR = math.min(_retryMaxMs, _retryR * 2);
          _nextR = _now() + wait;
          Timer(Duration(milliseconds: wait), _loadRewarded);
        },
      ),
    );
  }
}
