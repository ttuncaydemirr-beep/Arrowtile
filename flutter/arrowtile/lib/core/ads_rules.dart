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
//  - Banner (v1.1, docs/15 §3): yalnızca Ana menü ve Harita ekranlarında ([kBannerScreens]); oyun, seviye sonu, mağaza, ayarlar ve
//    günlük bulmacada yok; "Reklamları kaldır" alınmışsa yok ([Monetization.bannerVisible]).
//  - Önceden yükleme (docs/15 §4): ödüllü reklam oyun ekranı açılınca ve can 1'e düşünce ([Monetization.preloadRewarded]), geçiş
//    reklamı seviye bitmeden, son oklar çıkarken ([Monetization.preloadInterstitial]); zaten yükleniyor/hazırsa tekrar başlatılmaz.
//  - Reklam gösterilirken oyun animasyon döngüsü ve ses duraklar ([Monetization.addAdListener]): reklam açılmadan ÖNCE true,
//    kapanınca false (iç içe çağrılara dayanıklı).
import 'dart:async';
import 'dart:math' as math;

import 'save_data.dart';

/// Dinleyiciyi kaldıran işlev.
typedef Unsubscribe = void Function();

const int kFreeUntilLevel = 12;
const int kEveryLevels = 3;
const int kMinGapMs = 3 * 60 * 1000;
const Duration kNativeTimeout = Duration(seconds: 90); // reklam EKRANDAYKEN (oyuncu izlerken) üst sınır
/// 1.1.1 (docs/18): gösterim denemesi bu süre içinde "ekranda" olmazsa (yüklenmedi / gösterilemedi / geri çağrı gelmedi)
/// sessizce atlanır, oyun sonraki seviyeye devam eder. 90 sn'lik bekleme donma gibi görünüyordu.
const Duration kInterstitialShowTimeout = Duration(seconds: 3);
const Duration kRewardedLoadTimeout = Duration(seconds: 10); // dokunuşta ödüllü reklam yükleme bekleme sınırı
const String kProductRemoveAds = 'remove_ads';

/// "Reklam yükleniyor…" kaplaması yalnızca bekleme bu süreden uzun sürerse görünür (docs/15 §4).
const Duration kLoadingOverlayDelay = Duration(milliseconds: 300);

/// Banner'ın görüneceği ekranlar (docs/15 §3).
enum AdScreen { menu, map, game, levelEnd, shop, settings, daily, privacy }

const Set<AdScreen> kBannerScreens = <AdScreen>{AdScreen.menu, AdScreen.map};

/// Önceden yükleme sonucu (ads.js preloadRewarded/preloadInterstitial ile aynı sözlük).
enum PreloadState {
  /// Gerekmiyor / destek yok / çevrimdışı / SDK hazır değil.
  skip,

  /// Zaten hazır.
  ready,

  /// Yükleme sürüyor (ikinci yükleme başlatılmadı).
  loading,

  /// Yükleme şimdi başlatıldı.
  started,

  /// Yakın zamanda başarısız oldu; bekleme süresi dolana dek yeniden denenmez.
  wait,
}

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

  /// Reklam SDK'sı başlatıldı mı (UMP onayı alındı, MobileAds.initialize bitti). Banner yalnızca SDK hazırken istenir.
  bool get sdkReady;

  /// Ödüllü reklam şu an yükleniyor mu (önceden yükleme dahil).
  bool get rewardedLoading;

  /// Sessiz önceden yükleme (oyun ekranı açılınca / can 1'e düşünce). Hazırsa ya da yükleniyorsa YENİ yükleme başlatmaz.
  PreloadState preloadRewarded();

  /// Geçiş reklamı için sessiz önceden yükleme (seviye bitmeden). Hazırsa ya da yükleniyorsa yeni yükleme başlatmaz.
  PreloadState preloadInterstitial();

  /// Dokunuşta: ödüllü reklam hazır değilse yüklemeyi BAŞLATIR (başarısız yükleme sonrası bekleme süresi yok sayılır) ve
  /// yüklenince true, başarısız olunca ya da [timeout] dolunca false ile tamamlanır. Her durumda tamamlanır.
  Future<bool> ensureRewardedLoaded({Duration timeout = kRewardedLoadTimeout});

  /// Son ödüllü reklam hatası: AdMob hata kodu ("3" = no fill …) ya da 'timeout' | 'sdk_not_ready' | 'not_ready' | 'busy' …
  String? get lastRewardedErrorCode;
  String? get lastRewardedErrorMessage;

  /// Geçiş reklamını gösterir; reklam kapanınca true, gösterilemezse/başarısızsa false döner.
  Future<bool> showInterstitial();

  /// Geçiş reklamı şu an gerçekten ekranda mı (SDK "gösterildi" olayı geldi, henüz kapanmadı)? [Monetization.continueAfterLevel]
  /// bunu ancak gösterim denemesi [kInterstitialShowTimeout] içinde ekrana gelmediyse "atla" kararı için kullanır.
  bool get interstitialOnScreen;

  /// Ödüllü reklamı gösterir; ödül hak edilince [onReward] çağrılır; reklam kapanınca Future tamamlanır.
  Future<void> showRewarded(String placement, void Function() onReward);

  Future<PurchaseOutcome> purchaseRemoveAds();

  /// Play'e sorar: sahiplik var mı? Sorgu başarısızsa null.
  Future<bool?> restorePurchases();

  /// UMP: Ayarlar'da "Gizlilik seçenekleri" gösterilmeli mi.
  bool get privacyOptionsRequired;
  Future<void> showPrivacyOptions();
}

/// [Monetization.watchRewarded] sonucu.
enum RewardedOutcome {
  /// Reklam gösterildi ve ödül hak edildi.
  rewarded,

  /// Reklam gösterildi ama ödül hak edilmeden kapandı (ya da gösterim başarısız oldu).
  closed,

  /// Reklam yüklenemedi / hazır değil: hiçbir şey gösterilmedi. [RewardedResult.errorCode] nedeni söyler.
  unavailable,
}

class RewardedResult {
  final RewardedOutcome outcome;
  final String? errorCode; // yalnızca unavailable için
  const RewardedResult(this.outcome, {this.errorCode});
  bool get rewarded => outcome == RewardedOutcome.rewarded;
  bool get unavailable => outcome == RewardedOutcome.unavailable;
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

  /// Geçiş reklamı gösterim denemesinin ekrana gelmesi için bekleme sınırı (docs/18).
  final Duration showTimeout;

  /// Geçiş reklamı gösterim sonucu (analiz için; docs/19): 'shown' | 'skipped' (zamanı geldi ama hazır değildi) |
  /// 'failed' (gösterim denendi ama ekrana gelmedi / hata). Yalnızca reklamın zamanı geldiyse çağrılır. Hata fırlatsa bile yutulur.
  final void Function(String result)? onInterstitialResult;

  Monetization({
    required this.platform,
    required this.getAds,
    required this.persist,
    int Function()? now,
    this.nativeTimeout = kNativeTimeout,
    this.showTimeout = kInterstitialShowTimeout,
    this.onInterstitialResult,
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

  // ---- banner (docs/15 §3) ----
  /// Bu ekranda banner gösterilir mi? Yalnızca Ana menü ve Harita; "Reklamları kaldır" alınmışsa asla.
  /// (Reklamın yüklenip yüklenmediği ayrıca bakılır: yüklenmezse banner yer kaplamaz.)
  bool bannerVisible(AdScreen screen) => kBannerScreens.contains(screen) && !isAdFree();

  // ---- reklam gösterimi dinleyicisi (docs/15 §4: oyun döngüsü + ses duraklar) ----
  final List<void Function(bool active)> _adListeners = <void Function(bool active)>[];
  int _adActive = 0;

  /// Reklam gösterimi başlayınca true, bitince false ile çağrılır (yalnızca durum DEĞİŞİNCE). Dönen işlev dinleyiciyi kaldırır.
  Unsubscribe addAdListener(void Function(bool active) fn) {
    _adListeners.add(fn);
    return () => _adListeners.remove(fn);
  }

  /// Şu an tam ekran reklam gösteriliyor mu.
  bool get isAdShowing => _adActive > 0;

  void _adState(bool on) {
    final bool was = _adActive > 0;
    _adActive = math.max(0, _adActive + (on ? 1 : -1));
    final bool now = _adActive > 0;
    if (was == now) return;
    for (final void Function(bool) f in List<void Function(bool)>.of(_adListeners)) {
      try {
        f(now);
      } catch (_) {}
    }
  }

  // ---- önceden yükleme (docs/15 §4) ----
  /// Bu seviye bitince geçiş reklamı gösterilecek mi (sayaç + bölüm + reklamsızlık + bağlantı; 3 dk aralığı gösterim anında bakılır)?
  bool interstitialWillBeDue(int levelId) {
    final AdsState a = getAds();
    if (!(levelId > kFreeUntilLevel)) return false;
    if (isAdFree()) return false;
    if (a.since + 1 < kEveryLevels) return false;
    if (!_bridge || !_online) return false;
    return true;
  }

  /// Seviye bitmeden (son oklar çıkarken) çağrılır: reklam gerekecekse ve hazır/yükleniyor değilse yüklemeyi başlatır.
  PreloadState preloadInterstitial(int levelId) {
    if (!interstitialWillBeDue(levelId)) return PreloadState.skip;
    return platform.preloadInterstitial();
  }

  /// Oyun ekranı açılınca ve can 1'e düşünce çağrılır: hazır değilse ve yüklenmiyorsa yüklemeyi sessizce başlatır.
  PreloadState preloadRewarded() {
    if (!_bridge || !_online) return PreloadState.skip;
    return platform.preloadRewarded();
  }

  /// Ödüllü reklam şu an yükleniyor mu? "Reklam yükleniyor…" kaplaması yalnızca gerçekten bekleniyorsa gösterilir.
  bool get rewardedLoading => _bridge && platform.rewardedLoading;

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
  /// Her durumda biter; oyun asla takılmaz (docs/18):
  ///  - Reklam hazır değilse hemen false.
  ///  - Gösterim denemesi [showTimeout] içinde ekrana gelmezse (geri çağrı hiç gelmedi / yavaş) false: sessizce devam.
  ///  - Reklam ekrana geldiyse kapanışı en çok [nativeTimeout] bekler.
  ///  - [_adState] (ticker + ses duraklatma) her yolda `finally` ile geri alınır; tamamlayıcı tam bir kez tamamlanır.
  Future<bool> continueAfterLevel(int levelId) async {
    if (!interstitialDue(levelId)) return false;
    bool ready = false;
    try {
      ready = platform.interstitialReady;
    } catch (_) {
      ready = false;
    }
    if (!ready) {
      _reportInterstitial('skipped');
      return false; // doldurulamadı: hemen devam, sayaç sıfırlanmaz
    }
    final AdsState a = getAds();
    a.since = 0;
    a.lastAt = now();
    persist();
    final Completer<bool> done = Completer<bool>();
    void finish(bool v) {
      if (!done.isCompleted) done.complete(v);
    }

    Timer? preTimer;
    Timer? capTimer;
    _adState(true); // yerel çağrıdan ÖNCE duraklat: reklam açılırken oyun döngüsü/ses çalışmaya devam etmesin
    try {
      final Duration pre = showTimeout < nativeTimeout ? showTimeout : nativeTimeout;
      preTimer = Timer(pre, () {
        if (!platform.interstitialOnScreen) finish(false); // ekrana gelmedi: atla
      });
      capTimer = Timer(nativeTimeout, () => finish(false));
      try {
        platform.showInterstitial().then<void>(finish, onError: (Object _) => finish(false));
      } catch (_) {
        finish(false);
      }
      final bool shown = await done.future;
      _reportInterstitial(shown ? 'shown' : 'failed');
      return shown;
    } catch (_) {
      _reportInterstitial('failed');
      return false;
    } finally {
      preTimer?.cancel();
      capTimer?.cancel();
      _adState(false);
    }
  }

  void _reportInterstitial(String result) {
    try {
      onInterstitialResult?.call(result);
    } catch (_) {}
  }

  // ---- ödüllü reklam (isteğe bağlı; reklamsız sürümde de kullanılabilir) ----
  /// Ödüllü reklam düğmeleri GÖRÜNSÜN mü? Önceden yüklenmiş olmaya ve DNS ölçümüne ([AdsPlatform.online]) bağlı DEĞİL:
  /// reklam SDK'sı varsa düğme görünür, yükleme dokunuşta [watchRewarded] içinde yapılır; karar SDK'ya aittir.
  bool rewardedOffered() => _bridge;

  /// Şu an gösterime hazır ödüllü reklam var mı (çevrimiçi durumu yalnızca ipucudur, engellemez).
  bool rewardedAvailable() {
    if (!_bridge) return false;
    return platform.rewardedReady;
  }

  /// Hazır değilse yüklemeyi başlatır ([loadTimeout] sınırıyla); sonunda reklam hazır mı. İstisna fırlatmaz.
  Future<bool> ensureRewarded({Duration loadTimeout = kRewardedLoadTimeout}) async {
    if (!_bridge) return false;
    if (platform.rewardedReady) return true;
    try {
      // dış bekçi: platform kendi süresini aşsa bile asla takılmaz
      final bool ok = await platform
          .ensureRewardedLoaded(timeout: loadTimeout)
          .timeout(loadTimeout + const Duration(milliseconds: 500), onTimeout: () => false);
      return ok && platform.rewardedReady;
    } catch (_) {
      return false;
    }
  }

  /// Dokunuşta tam akış: hazır değilse [onLoading] → yükle → [onLoadingDone] → göster. [onReward] ödül hak edilirse en çok bir kez.
  /// Reklam yüklenemezse hiçbir şey gösterilmez ve [RewardedOutcome.unavailable] döner (neden: [RewardedResult.errorCode]).
  Future<RewardedResult> watchRewarded(
    String placement, {
    void Function()? onReward,
    void Function()? onLoading,
    void Function()? onLoadingDone,
    Duration loadTimeout = kRewardedLoadTimeout,
  }) async {
    if (!_bridge) return const RewardedResult(RewardedOutcome.unavailable, errorCode: 'no_platform');
    if (!platform.rewardedReady) {
      onLoading?.call();
      final bool ok = await ensureRewarded(loadTimeout: loadTimeout); // istisna fırlatmaz
      onLoadingDone?.call();
      if (!ok) return RewardedResult(RewardedOutcome.unavailable, errorCode: platform.lastRewardedErrorCode ?? 'unknown');
    }
    if (!platform.rewardedReady) {
      // yükleme ile gösterim arasında süresi doldu / tüketildi
      return RewardedResult(RewardedOutcome.unavailable, errorCode: platform.lastRewardedErrorCode ?? 'expired');
    }
    final bool rewarded = await showRewarded(placement, onReward: onReward);
    if (rewarded) return const RewardedResult(RewardedOutcome.rewarded);
    // gösterim hiç başlamadıysa (başarısız / zaman aşımı) "kapandı" değil "reklam yok" sayılır (docs/18)
    final String? showErr = platform.lastRewardedErrorCode;
    if (showErr != null && showErr.startsWith('show_')) {
      return RewardedResult(RewardedOutcome.unavailable, errorCode: showErr);
    }
    return const RewardedResult(RewardedOutcome.closed);
  }

  /// [onReward] ödül hak edilirse en çok bir kez çağrılır. Dönen değer: ödül verildi mi. Hazır ödüllü reklam gerekir
  /// (yüklemeyi de yapan tam akış için [watchRewarded]).
  Future<bool> showRewarded(String placement, {void Function()? onReward}) async {
    if (!rewardedAvailable()) return false;
    bool rewarded = false;
    _adState(true); // yerel çağrıdan önce duraklat
    try {
      await platform.showRewarded(placement, () {
        if (rewarded) return;
        rewarded = true;
        onReward?.call();
      }).timeout(nativeTimeout, onTimeout: () {});
    } catch (_) {
      // yut: oyun devam eder
    } finally {
      _adState(false);
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
