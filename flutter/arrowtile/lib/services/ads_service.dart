// Arrowtile — ads_service.dart: AdMob (geçiş + ödüllü) + UMP onay akışı + Play Billing'i [AdsPlatform] arayüzüne bağlar.
// Android AdsManager.java / ConsentManager.java mantığının karşılığı. NE ZAMAN reklam gösterileceğine KARAR VERMEZ:
// sıklık/bölüm/süre kuralları core/ads_rules.dart (Monetization) içindedir; burası yalnızca "hazır mı" ve "göster" sağlar.
//  - Reklam SDK'sı ancak UMP canRequestAds() true olduktan sonra başlatılır.
//  - Reklamlar önceden yüklenir; ~1 saat geçerlidir (55 dk sonra yenilenir); başarısız yüklemede artan bekleme (15 sn … 10 dk).
//  - Ödüllü reklam DOKUNUŞTA da yüklenebilir ([ensureRewardedLoaded]): hazır değilse yükleme (bekleme süresi yok sayılarak)
//    başlatılır; yüklendi/başarısız/zaman aşımında tamamlanır. Son hata kodu [lastRewardedErrorCode] ile okunur.
//  - `_showing` her yolda (kapanış, hata, istisna, uygulamadan dönüşte bırakma) sıfırlanır; Completer'lar tamamlanır.
//  - 1.1.4 (docs/21): gösterimde süre sınırı YOK; bekleme kararı Monetization'dadır (show() sonrası sonraki seviye başlamaz).
//  - Tüm yükleme/gösterim olayları tanılama kaydına (core/diag.dart) yazılır.
//  - Önceden yükleme (docs/15 §4): [preloadRewarded] / [preloadInterstitial] hazırsa ya da yükleniyorsa YENİ yükleme başlatmaz;
//    ödüllü reklam dokunuşta istenirse sürmekte olan yüklemeye katılır ([ensureRewardedLoaded] → [_loadRewarded] yüklüyorsa çıkar).
//  - Banner (docs/15 §3): bu sınıf yalnızca "SDK hazır mı" ([sdkReady]) bilgisini verir; banner widget'ı ui/ad_banner.dart içindedir.
//  - İçerik derecesi PG (genel kitle; çocuklara yönelik değil — docs/10 "Hedef kitle").
import 'dart:async';
import 'dart:io' show InternetAddress;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_config.dart';
import '../core/ads_rules.dart';
import '../core/consent_gate.dart';
import '../core/diag.dart';
import 'billing_service.dart';

class FlutterAdsPlatform implements AdsPlatform {
  FlutterAdsPlatform({required this.billing, this.onChanged, this.inGame, this.onConsentStatus});

  final BillingService billing;

  /// Gizlilik seçenekleri gerekliliği değişince (Ayarlar yenilensin).
  final VoidCallback? onChanged;

  /// Oyuncu şu an bir oyun ekranında mı (onay formu oyunun üstüne açılmaz).
  final bool Function()? inGame;

  /// UMP onay durumu her güncellendiğinde (açılış, form kapanışı, gizlilik seçenekleri) durum adıyla çağrılır:
  /// notRequired | required | obtained | unknown. Firebase Analytics onay sinyalleri buradan türetilir (docs/19).
  /// Geri çağrı reklam akışını ASLA bekletmez ve hata fırlatsa bile yutulur.
  final void Function(String umpStatus)? onConsentStatus;

  static const int _maxAgeMs = 55 * 60 * 1000;
  static const int _retryMinMs = 15000;
  static const int _retryMaxMs = 10 * 60 * 1000;
  static const int _closeDelayMs = 350; // ödül olayı nadiren kapanıştan sonra gelir
  static const int _loadStaleMs = 30 * 1000; // SDK yükleme yanıtı hiç gelmezse yükleme bu süreden sonra "bayat" sayılır

  bool _started = false;
  bool _sdkReady = false;
  bool _online = true;
  bool _privacyRequired = false;
  bool _showing = false;
  bool _disposed = false;
  final ConsentFormGate _gate = ConsentFormGate(); // form ne zaman gösterilebilir (core/consent_gate.dart)

  InterstitialAd? _interstitial;
  int _interstitialAt = 0;
  bool _loadingI = false;
  int _loadStartI = 0;
  int _genI = 0; // her yükleme denemesine yeni numara: bayat yanıtlar durumu bozmaz (1.1.1)
  Timer? _retryTimerI;
  bool _interstitialOnScreen = false;
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


  static int _now() => DateTime.now().millisecondsSinceEpoch;
  static bool _expired(int at) => at > 0 && _now() - at > _maxAgeMs;

  // ------------------------------------------------------------------ UMP onayı
  /// Uygulama açılışında BİR kez çağrılır (yeniden çağrılırsa yok sayılır): onay bilgisi güncellenir, gerekiyorsa form
  /// gösterilir, sonra SDK başlatılır. Google'ın belgelenmiş deseni: bilgi güncellemesi her uygulama açılışında; form yalnızca
  /// gerekiyorsa ve yalnızca ÖN PLANDAKİ etkinlikten; uygulama öne her gelişte kendiliğinden yeniden gösterilmez
  /// (arka plandayken gösterilmek istenen form ön plana dönünce en çok bir kez gösterilir).
  Future<void> gatherConsent() async {
    if (_disposed || !_gate.beginSession()) return;
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
          _log('UMP: onay bilgisi güncellendi');
          _showConsentFormIfForeground();
        },
        (FormError error) {
          _log('UMP update: ${error.message}');
          _gate.updateFailed();
          unawaited(_afterConsentUpdate());
        },
      );
    } catch (e) {
      _gate.updateFailed();
      _log('gatherConsent: $e');
    }
    // Önceki oturumda alınmış onay varsa reklamlar beklemeden başlayabilir.
    await _afterConsentUpdate();
  }

  /// Formu yalnızca uygulama ön plandayken (resumed) yükleyip gösterir; değilse [onResume] bir kez dener.
  void _showConsentFormIfForeground() {
    if (_disposed) return;
    final bool fg = _foreground;
    final bool free = !(inGame?.call() ?? false);
    if (!_gate.tryShow(foreground: fg, interruptible: free)) {
      if (_gate.pending) _log('UMP: form ertelendi (ön plan=$fg, oyunda değil=$free); uygun olunca bir kez gösterilecek');
      return;
    }
    _loadAndShowForm();
  }

  bool get _foreground {
    final AppLifecycleState? st = WidgetsBinding.instance.lifecycleState;
    return st == null || st == AppLifecycleState.resumed;
  }

  /// Ertelenmiş form varsa ve artık uygunsa (ön plan + oyunda değil) gösterir. Öne gelince / oyundan çıkınca çağrılır.
  void retryConsentForm() {
    if (_disposed) return;
    if (_gate.retryPending(foreground: _foreground, interruptible: !(inGame?.call() ?? false))) _loadAndShowForm();
  }

  /// Onay akışı sürerken (bilgi güncellemesi / form) en çok [timeout] bekler; oyun formun altında başlamasın diye.
  Future<void> waitConsentIdle({Duration timeout = const Duration(seconds: 8)}) async {
    final Stopwatch sw = Stopwatch()..start();
    while (_gate.active && !_disposed && sw.elapsed < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void _loadAndShowForm() {
    try {
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) {
        _gate.finished();
        if (formError != null) _log('UMP form: ${formError.message}');
        unawaited(_afterConsentUpdate());
      });
    } catch (e) {
      _gate.finished();
      _log('UMP form istisna: $e');
      unawaited(_afterConsentUpdate());
    }
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
      unawaited(_reportConsentStatus()); // Firebase onay sinyalleri; reklam başlatmayı beklemez
      final bool can = await ConsentInformation.instance.canRequestAds();
      diag('ad', 'consent', <String, Object?>{'canRequestAds': can, 'privacyRequired': req});
      if (can) await _initSdk();
    } catch (e) {
      _log('afterConsentUpdate: $e');
    }
  }

  Future<void> _reportConsentStatus() async {
    try {
      final ConsentStatus st = await ConsentInformation.instance.getConsentStatus();
      diag('ad', 'ump_status', <String, Object?>{'status': st.name});
      onConsentStatus?.call(st.name);
    } catch (e) {
      _log('consent status: $e');
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
      diag('ad', 'sdk_ready');
      _loadInterstitial();
      _loadRewarded();
      onChanged?.call(); // banner (menü/harita) artık istenebilir
    } catch (e) {
      _log('MobileAds.initialize: $e');
      diag('ad', 'sdk_init_failed', <String, Object?>{'e': e});
      _started = false;
    }
  }

  /// Uygulama öne gelince: süresi dolan reklamı yenile, bağlantıyı yeniden ölç.
  void onResume() {
    if (_disposed) return;
    unawaited(refreshOnline());
    retryConsentForm(); // yalnızca ertelenmiş form; yeni form tetiklenmez
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
    _screen(false);
    _showing = false;
    _retryTimerR?.cancel();
    _retryTimerI?.cancel();
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
  bool get interstitialOnScreen => _interstitialOnScreen;

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
  bool get sdkReady => _sdkReady && !_disposed;

  @override
  bool get rewardedLoading => _loadingR && _now() - _loadStartR < _loadStaleMs;

  @override
  PreloadState preloadRewarded() {
    if (!_sdkReady || _disposed) return PreloadState.skip;
    if (_rewarded != null && !_expired(_rewardedAt)) return PreloadState.ready;
    if (rewardedLoading) return PreloadState.loading; // zaten yükleniyor: ikinci yükleme başlatılmaz
    if (_now() < _nextR) return PreloadState.wait; // yakın zamanda başarısız oldu
    _loadRewarded();
    return _loadingR ? PreloadState.started : PreloadState.wait;
  }

  @override
  PreloadState preloadInterstitial() {
    if (!_sdkReady || _disposed) return PreloadState.skip;
    if (_interstitial != null && !_expired(_interstitialAt)) return PreloadState.ready;
    if (_loadingI && _now() - _loadStartI < _loadStaleMs) return PreloadState.loading;
    if (_now() < _nextI) return PreloadState.wait;
    _loadInterstitial();
    return _loadingI ? PreloadState.started : PreloadState.wait;
  }

  @override
  void Function(bool onScreen)? onScreenChanged;
  @override
  void Function()? onLateAd;

  void _screen(bool on) {
    try {
      onScreenChanged?.call(on);
    } catch (_) {}
  }

  void Function()? _releaseI; // bekleyen geçiş gösterimini unutur (uygulama reklamdan döndü, olay gelmedi)
  void Function()? _releaseR;

  @override
  void releaseInterstitial() => _releaseI?.call();

  @override
  void releaseRewarded() => _releaseR?.call();

  /// 1.1.4 (docs/21): show() YALNIZCA [allowed] true iken ve reklam ZATEN yüklüyken, en çok bir kez çağrılır (çağıran tek yol:
  /// Monetization.continueAfterLevel). Hiçbir yükleme/zamanlayıcı geri çağrısı show() çağırmaz. SÜRE SINIRI YOK: dönen Future yalnızca
  /// onAdDismissed / onAdFailedToShow / istisna / [releaseInterstitial] ile tamamlanır. Eski 3 sn'lik "ekrana gelmedi → dispose ve devam"
  /// zamanlayıcısı kaldırıldı: dispose başlamış bir gösterimi iptal etmiyor, reklam sonraki seviyenin ortasında beliriyordu.
  @override
  Future<bool> showInterstitial({bool Function()? allowed}) {
    final InterstitialAd? ad = _interstitial;
    if (ad == null || _showing || _disposed || _expired(_interstitialAt)) return Future<bool>.value(false);
    if (allowed != null && !allowed()) {
      _log('interstitial: yerleştirme geçersiz, show() çağrılmadı');
      diag('ad', 'sdk_show_refused', <String, Object?>{'format': 'interstitial'});
      return Future<bool>.value(false);
    }
    _interstitial = null;
    final Completer<bool> c = Completer<bool>();
    bool dead = false; // kapandı / gösterilemedi / unutuldu
    bool showed = false;
    // Tamamlayıcı TAM BİR KEZ tamamlanır; her çıkış yolu buradan geçer.
    void finish(bool v) {
      _interstitialOnScreen = false;
      _releaseI = null;
      _showing = false;
      _screen(false);
      if (!c.isCompleted) c.complete(v);
    }

    _showing = true;
    _releaseI = () {
      if (dead) return;
      dead = true;
      _log('interstitial: released');
      diag('ad', 'sdk_released', <String, Object?>{'format': 'interstitial', 'showed': showed});
      try {
        ad.dispose();
      } catch (_) {}
      finish(showed);
      _loadInterstitial();
    };
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (InterstitialAd a) {
        if (dead) {
          // unutulmuş gösterim sonradan belirdi: kalkan (oyun duraklar + late_blocked)
          _log('interstitial: GEÇ gösterildi, engellendi');
          diag('ad', 'sdk_showed_late', <String, Object?>{'format': 'interstitial'});
          try {
            onLateAd?.call();
          } catch (_) {}
          return;
        }
        showed = true;
        _log('interstitial: showed');
        diag('ad', 'sdk_showed', <String, Object?>{'format': 'interstitial'});
        _interstitialOnScreen = true;
        _screen(true); // ses YALNIZCA şimdi susar
      },
      onAdImpression: (InterstitialAd a) {
        diag('ad', 'sdk_impression', <String, Object?>{'format': 'interstitial'});
      },
      onAdDismissedFullScreenContent: (InterstitialAd a) {
        _log('interstitial: dismissed');
        diag('ad', 'sdk_dismissed', <String, Object?>{'format': 'interstitial'});
        a.dispose();
        if (dead) {
          _screen(false);
          return;
        }
        dead = true;
        finish(true);
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd a, AdError error) {
        _log('interstitial show failed: ${error.message}');
        diag('ad', 'sdk_failed_to_show', <String, Object?>{'format': 'interstitial', 'code': error.code, 'msg': error.message});
        a.dispose();
        if (dead) return;
        dead = true;
        finish(false);
        _loadInterstitial();
      },
    );
    _log('interstitial: show() çağrıldı');
    void doShow() {
      if (dead || _disposed) return;
      try {
        ad.show().catchError((Object e) {
          _log('interstitial show exception: $e');
          diag('ad', 'sdk_show_exception', <String, Object?>{'format': 'interstitial', 'e': e});
          if (dead) return;
          dead = true;
          finish(false);
        });
      } catch (e) {
        _log('interstitial show exception: $e');
        diag('ad', 'sdk_show_exception', <String, Object?>{'format': 'interstitial', 'e': e});
        dead = true;
        finish(false);
      }
    }

    final int delay = AdsConfig.debugPresentDelayMs;
    if (delay > 0) {
      // yalnızca debug/profile (CI smoke-ads "slow"): gerçek cihazdaki yavaş sunumu taklit eder
      _log('interstitial: yapay sunum gecikmesi $delay ms');
      Timer(Duration(milliseconds: delay), doShow);
    } else {
      doShow();
    }
    return c.future;
  }

  /// Ödüllü gösterim (yalnızca kullanıcı dokunuşundan, Monetization.showRewarded üzerinden). Süre sınırı yok (bkz. [showInterstitial]).
  @override
  Future<void> showRewarded(String placement, void Function() onReward, {bool Function()? allowed}) {
    final RewardedAd? ad = _rewarded;
    if (ad == null || _showing || _disposed) {
      _setRewardedError(_showing ? 'busy' : 'not_ready', _showing ? 'another ad is showing' : 'no rewarded ad loaded');
      return Future<void>.value();
    }
    if (allowed != null && !allowed()) {
      _setRewardedError('cancelled', 'rewarded request no longer valid');
      return Future<void>.value();
    }
    _rewarded = null;
    _lastRewardedErrorCode = null; // bu gösterimin sonucu: eski hata kodu "reklam yok" sayılmasın
    _lastRewardedErrorMessage = null;
    final Completer<void> c = Completer<void>();
    bool dead = false;
    bool noReward = false; // bırakıldı / gösterilemedi: geç gelen ödül olayı yok sayılır
    void done() {
      _releaseR = null;
      _showing = false;
      _screen(false);
      if (!c.isCompleted) c.complete();
    }

    _showing = true;
    _releaseR = () {
      if (dead) return;
      dead = true;
      noReward = true;
      diag('ad', 'sdk_released', <String, Object?>{'format': 'rewarded'});
      try {
        ad.dispose();
      } catch (_) {}
      done();
      _loadRewarded();
    };
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: (RewardedAd a) {
        if (dead) {
          _log('rewarded: GEÇ gösterildi, engellendi');
          diag('ad', 'sdk_showed_late', <String, Object?>{'format': 'rewarded'});
          try {
            onLateAd?.call();
          } catch (_) {}
          return;
        }
        diag('ad', 'sdk_showed', <String, Object?>{'format': 'rewarded', 'p': placement});
        _screen(true);
      },
      onAdImpression: (RewardedAd a) {
        diag('ad', 'sdk_impression', <String, Object?>{'format': 'rewarded'});
      },
      onAdDismissedFullScreenContent: (RewardedAd a) {
        diag('ad', 'sdk_dismissed', <String, Object?>{'format': 'rewarded'});
        a.dispose();
        if (dead) {
          _screen(false);
          return;
        }
        dead = true;
        _releaseR = null;
        _showing = false;
        _screen(false);
        // ödül olayı kapanıştan hemen sonra gelebilir: kapanışı kısa süre geciktir
        Timer(const Duration(milliseconds: _closeDelayMs), () {
          if (!c.isCompleted) c.complete();
        });
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd a, AdError error) {
        _setRewardedError('show_${error.code}', error.message);
        _log('rewarded show failed (${error.code}): ${error.message}');
        diag('ad', 'sdk_failed_to_show', <String, Object?>{'format': 'rewarded', 'code': error.code, 'msg': error.message});
        a.dispose();
        if (dead) return;
        dead = true;
        noReward = true;
        done();
        _loadRewarded();
      },
    );
    try {
      ad.show(onUserEarnedReward: (AdWithoutView a, RewardItem reward) {
        diag('ad', 'sdk_reward', <String, Object?>{'format': 'rewarded'});
        if (!noReward) onReward(); // kapanıştan hemen sonra gelen ödül de geçerli
      }).catchError((Object e) {
        _setRewardedError('show_exception', '$e');
        if (dead) return;
        dead = true;
        done();
      });
    } catch (e) {
      dead = true;
      _setRewardedError('show_exception', '$e');
      done();
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
    if (!_sdkReady || _disposed) return;
    if (_loadingI) {
      if (_now() - _loadStartI < _loadStaleMs) return;
      _log('interstitial load bayat sayıldı, yeniden deneniyor'); // SDK hiç yanıt vermediyse sonsuza dek "yükleniyor" kalmaz (1.1.1)
    }
    if (_now() < _nextI) return; // başarısız yüklemeden sonra bekleme süresi
    if (_interstitial != null && !_expired(_interstitialAt)) return;
    _loadingI = true;
    _loadStartI = _now();
    final int gen = ++_genI;
    diag('ad', 'load', <String, Object?>{'format': 'interstitial'});
    try {
      InterstitialAd.load(
        adUnitId: AdsConfig.interstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            if (gen == _genI) _loadingI = false;
            if (_disposed) {
              ad.dispose();
              return;
            }
            _interstitial?.dispose();
            _interstitial = ad;
            _interstitialAt = _now();
            _retryI = _retryMinMs;
            _nextI = 0;
            _online = true;
            _log('interstitial loaded');
            diag('ad', 'loaded', <String, Object?>{'format': 'interstitial', 'ms': _now() - _loadStartI});
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (gen != _genI) return; // bayat yanıt
            _loadingI = false;
            _interstitial = null;
            _log('interstitial onAdFailedToLoad: Ad failed to load (${error.code}): ${error.message}');
            diag('ad', 'load_failed', <String, Object?>{'format': 'interstitial', 'code': error.code, 'msg': error.message});
            if (error.code == 2) _online = false; // ERROR_CODE_NETWORK_ERROR
            final int wait = _retryI;
            _retryI = math.min(_retryMaxMs, _retryI * 2);
            _nextI = _now() + wait;
            _retryTimerI?.cancel();
            _retryTimerI = Timer(Duration(milliseconds: wait), _loadInterstitial);
          },
        ),
      );
    } catch (e) {
      _loadingI = false;
      _log('interstitial load exception: $e');
    }
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
    diag('ad', 'load', <String, Object?>{'format': 'rewarded', 'force': force});
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
            diag('ad', 'loaded', <String, Object?>{'format': 'rewarded', 'ms': _now() - _loadStartR});
            _completeWaiters(true);
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (gen != _genR) return; // bayat yanıt
            _loadingR = false;
            _rewarded = null;
            _setRewardedError('${error.code}', error.message);
            _log('rewarded onAdFailedToLoad: Ad failed to load (${error.code}): ${error.message}');
            diag('ad', 'load_failed', <String, Object?>{'format': 'rewarded', 'code': error.code, 'msg': error.message});
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
