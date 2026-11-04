// Arrowtile — ads_service.dart: AdMob (geçiş + ödüllü) + UMP onay akışı + Play Billing'i [AdsPlatform] arayüzüne bağlar.
// Android AdsManager.java / ConsentManager.java mantığının karşılığı. NE ZAMAN reklam gösterileceğine KARAR VERMEZ:
// sıklık/bölüm/süre kuralları core/ads_rules.dart (Monetization) içindedir; burası yalnızca "hazır mı" ve "göster" sağlar.
//  - Reklam SDK'sı ancak UMP canRequestAds() true olduktan sonra başlatılır.
//  - Reklamlar önceden yüklenir; ~1 saat geçerlidir (55 dk sonra yenilenir); başarısız yüklemede artan bekleme (15 sn … 10 dk).
//  - Ödüllü reklam DOKUNUŞTA da yüklenebilir ([ensureRewardedLoaded]): hazır değilse yükleme (bekleme süresi yok sayılarak)
//    başlatılır; yüklendi/başarısız/zaman aşımında tamamlanır. Son hata kodu [lastRewardedErrorCode] ile okunur.
//  - `_showing` her yolda (kapanış, hata, istisna, bekçi zamanlayıcısı) sıfırlanır; Completer'lar her zaman tamamlanır.
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
  static const int _showMaxMs = 5 * 60 * 1000; // bekçi: reklam olayı hiç gelmezse `_showing` en geç bu sürede sıfırlanır
  static const int _loadStaleMs = 30 * 1000; // SDK yükleme yanıtı hiç gelmezse yükleme bu süreden sonra "bayat" sayılır

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
  int _loadStartR = 0;
  int _genR = 0; // her yükleme denemesine yeni numara: bayat yanıtlar durumu bozmaz
  int _retryR = _retryMinMs;
  int _nextR = 0;
  Timer? _retryTimerR;
  Timer? _showWatchdog;
  final List<Completer<bool>> _waitersR = <Completer<bool>>[];
  String? _lastRewardedErrorCode;
  String? _lastRewardedErrorMessage;

  /// Teşhis kaydı: debug ve test kimlikli yayın derlemesinde logcat'e (etiket `flutter`) yazılır.
  static void _log(String m) {
    if (kDebugMode || AdsConfig.usingTestIdsInRelease) debugPrint('Ads: $m');
  }

  void _setRewardedError(String code, String message) {
    _lastRewardedErrorCode = code;
    _lastRewardedErrorMessage = message;
  }

  void _endShow() {
    _showing = false;
    _showWatchdog?.cancel();
    _showWatchdog = null;
  }

  void _beginShow(void Function() onTimeout) {
    _showing = true;
    _showWatchdog?.cancel();
    _showWatchdog = Timer(const Duration(milliseconds: _showMaxMs), () {
      _log('show watchdog: reklam olayı gelmedi, durum sıfırlandı');
      _endShow();
      onTimeout();
    });
  }

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
      _log('afterConsentUpdate: $e');
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
      _log('MobileAds initialized');
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      _log('MobileAds.initialize: $e');
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
    _endShow();
    _retryTimerR?.cancel();
    _completeWaiters(false);
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
    final Completer<bool> c = Completer<bool>();
    _beginShow(() {
      if (!c.isCompleted) c.complete(false);
    });
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (InterstitialAd a) {
        _endShow();
        a.dispose();
        if (!c.isCompleted) c.complete(true);
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd a, AdError error) {
        _endShow();
        _log('interstitial show failed: ${error.message}');
        a.dispose();
        if (!c.isCompleted) c.complete(false);
        _loadInterstitial();
      },
    );
    try {
      ad.show().catchError((Object e) {
        _endShow();
        if (!c.isCompleted) c.complete(false);
      });
    } catch (_) {
      _endShow();
      if (!c.isCompleted) c.complete(false);
    }
    return c.future;
  }

  @override
  Future<void> showRewarded(String placement, void Function() onReward) {
    final RewardedAd? ad = _rewarded;
    if (ad == null || _showing || _disposed) {
      _setRewardedError(_showing ? 'busy' : 'not_ready', _showing ? 'another ad is showing' : 'no rewarded ad loaded');
      return Future<void>.value();
    }
    _rewarded = null;
    final Completer<void> c = Completer<void>();
    _beginShow(() {
      if (!c.isCompleted) c.complete();
    });
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (RewardedAd a) {
        _endShow();
        a.dispose();
        // ödül olayı kapanıştan hemen sonra gelebilir: kapanışı kısa süre geciktir
        Timer(const Duration(milliseconds: _closeDelayMs), () {
          if (!c.isCompleted) c.complete();
        });
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd a, AdError error) {
        _endShow();
        _setRewardedError('show_${error.code}', error.message);
        _log('rewarded show failed (${error.code}): ${error.message}');
        a.dispose();
        if (!c.isCompleted) c.complete();
        _loadRewarded();
      },
    );
    try {
      ad.show(onUserEarnedReward: (AdWithoutView a, RewardItem reward) => onReward()).catchError((Object e) {
        _endShow();
        _setRewardedError('show_exception', '$e');
        if (!c.isCompleted) c.complete();
      });
    } catch (e) {
      _endShow();
      _setRewardedError('show_exception', '$e');
      if (!c.isCompleted) c.complete();
    }
    return c.future;
  }

  @override
  String? get lastRewardedErrorCode => _lastRewardedErrorCode;

  @override
  String? get lastRewardedErrorMessage => _lastRewardedErrorMessage;

  @override
  Future<bool> ensureRewardedLoaded({Duration timeout = const Duration(seconds: 10)}) async {
    if (_disposed) {
      _setRewardedError('disposed', 'platform disposed');
      return false;
    }
    final Stopwatch sw = Stopwatch()..start();
    if (!_sdkReady) {
      // SDK henüz başlamadıysa (onay/başlatma sürüyor ya da önceki deneme başarısız) bir kez daha dene
      try {
        await _afterConsentUpdate().timeout(timeout);
      } catch (_) {}
      while (!_sdkReady && !_disposed && sw.elapsed < timeout) {
        await Future<void>.delayed(const Duration(milliseconds: 200)); // başlatma sürüyorsa bekle
      }
      if (!_sdkReady) {
        _setRewardedError('sdk_not_ready', 'ads SDK not initialized (consent or init pending)');
        _log('ensureRewardedLoaded: SDK hazır değil');
        return false;
      }
    }
    if (_rewarded != null && !_expired(_rewardedAt)) return true;
    final Duration left = timeout - sw.elapsed;
    if (left <= Duration.zero) {
      _setRewardedError('timeout', 'timed out waiting for ads SDK');
      return false;
    }
    final Completer<bool> c = Completer<bool>();
    _waitersR.add(c);
    final Timer t = Timer(left, () {
      _waitersR.remove(c);
      if (!c.isCompleted) {
        _setRewardedError('timeout', 'rewarded ad load timed out after ${timeout.inSeconds}s');
        _log('ensureRewardedLoaded: zaman aşımı');
        c.complete(false);
      }
    });
    _loadRewarded(force: true);
    try {
      return await c.future;
    } finally {
      t.cancel();
      _waitersR.remove(c);
    }
  }

  void _completeWaiters(bool ok) {
    final List<Completer<bool>> ws = List<Completer<bool>>.of(_waitersR);
    _waitersR.clear();
    for (final Completer<bool> w in ws) {
      if (!w.isCompleted) w.complete(ok);
    }
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
          _log('interstitial loaded');
        },
        onAdFailedToLoad: (LoadAdError error) {
          _loadingI = false;
          _interstitial = null;
          _log('interstitial onAdFailedToLoad: Ad failed to load (${error.code}): ${error.message}');
          if (error.code == 2) _online = false; // ERROR_CODE_NETWORK_ERROR
          final int wait = _retryI;
          _retryI = math.min(_retryMaxMs, _retryI * 2);
          _nextI = _now() + wait;
          Timer(Duration(milliseconds: wait), _loadInterstitial);
        },
      ),
    );
  }

  /// [force]: kullanıcı dokunuşu — başarısız yüklemeden sonraki bekleme süresi yok sayılır.
  void _loadRewarded({bool force = false}) {
    if (!_sdkReady || _disposed) return;
    if (_loadingR) {
      if (_now() - _loadStartR < _loadStaleMs) return; // yükleme sürüyor; sonucu bekleyenlere iletilecek
      _log('rewarded load bayat sayıldı, yeniden deneniyor');
    }
    if (!force && _now() < _nextR) return;
    if (_rewarded != null && !_expired(_rewardedAt)) {
      _completeWaiters(true);
      return;
    }
    _loadingR = true;
    _loadStartR = _now();
    final int gen = ++_genR;
    try {
      RewardedAd.load(
        adUnitId: AdsConfig.rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            if (gen == _genR) _loadingR = false;
            if (_disposed) {
              ad.dispose();
              _completeWaiters(false);
              return;
            }
            _rewarded?.dispose();
            _rewarded = ad;
            _rewardedAt = _now();
            _retryR = _retryMinMs;
            _nextR = 0;
            _online = true;
            _log('rewarded loaded');
            _completeWaiters(true);
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (gen != _genR) return; // bayat yanıt
            _loadingR = false;
            _rewarded = null;
            _setRewardedError('${error.code}', error.message);
            _log('rewarded onAdFailedToLoad: Ad failed to load (${error.code}): ${error.message}');
            if (error.code == 2) _online = false; // ERROR_CODE_NETWORK_ERROR
            final int wait = _retryR;
            _retryR = math.min(_retryMaxMs, _retryR * 2);
            _nextR = _now() + wait;
            _retryTimerR?.cancel();
            _retryTimerR = Timer(Duration(milliseconds: wait), _loadRewarded);
            _completeWaiters(false);
          },
        ),
      );
    } catch (e) {
      // SDK senkron istisna fırlatırsa yükleme durumu takılı kalmasın
      _loadingR = false;
      _setRewardedError('load_exception', '$e');
      _log('rewarded load exception: $e');
      _completeWaiters(false);
    }
  }
}
