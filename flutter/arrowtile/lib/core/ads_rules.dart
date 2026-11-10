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
//  - 1.1.3 (docs/20): geçiş reklamı YALNIZCA etkin seviye sonu yerleştirmesinde ([Monetization.openLevelEnd] belirteci), YALNIZCA
//    zaten yüklenmişse ve en çok BİR kez gösterilir; yüklenmemişse beklemeden atlanır.
//    Ses yalnızca reklam gerçekten ekrandayken susar ([Monetization.addScreenListener]).
//  - 1.1.4 (docs/21) TUTMA (hold) tasarımı: show() çağrıldıktan sonra SDK gösterimi geri alınamaz (dispose iptal etmez; gerçek cihazda
//    AdActivity 3 sn'den geç açılabiliyor). Bu yüzden show() çağrıldıysa sonraki seviye, SDK "kapandı"/"gösterilemedi" bildirene ya da
//    uygulama arka plandan (reklamdan) geri dönene dek BAŞLAMAZ. Süre sınırı (20 sn, [kAdHoldMax]) yalnızca "yavaş" uyarısı içindir;
//    bekleme o zaman da sürer. show() dışında hiçbir yol (yükleme geri çağrısı, zamanlayıcı, öne gelme) reklam göstermez.
//  - Banner (v1.1, docs/15 §3): yalnızca Ana menü ve Harita ekranlarında ([kBannerScreens]); oyun, seviye sonu, mağaza, ayarlar ve
//    günlük bulmacada yok; "Reklamları kaldır" alınmışsa yok ([Monetization.bannerVisible]).
//  - Önceden yükleme (docs/15 §4): ödüllü reklam oyun ekranı açılınca ve can 1'e düşünce ([Monetization.preloadRewarded]), geçiş
//    reklamı seviye bitmeden, son oklar çıkarken ([Monetization.preloadInterstitial]); zaten yükleniyor/hazırsa tekrar başlatılmaz.
//  - Reklam gösterilirken oyun animasyon döngüsü ve ses duraklar ([Monetization.addAdListener]): reklam açılmadan ÖNCE true,
//    kapanınca false (iç içe çağrılara dayanıklı).
import 'dart:async';
import 'dart:math' as math;

import 'diag.dart';
import 'save_data.dart';

/// Dinleyiciyi kaldıran işlev.
typedef Unsubscribe = void Function();

const int kFreeUntilLevel = 12;
const int kEveryLevels = 3;
const int kMinGapMs = 3 * 60 * 1000;
const Duration kNativeTimeout = Duration(seconds: 90); // satın alma / gizlilik formu yanıt sınırı; reklam GÖSTERİMİNDE kullanılmaz (1.1.4)
/// 1.1.4 (docs/21): show() çağrıldıktan sonra bu süre içinde SDK'dan haber yoksa "reklam gecikiyor" uyarısı gösterilir ve telemetriye
/// `stuck` yazılır. Bekleme SÜRER: geç gelen reklam sonraki seviyenin ortasına düşmesin diye sonraki seviye yine başlatılmaz.
const Duration kAdHoldMax = Duration(seconds: 20);
/// Gösterim sürerken uygulama arka plana gidip döndüyse (AdActivity açıldı/kapandı) ve SDK kapanış olayı gelmediyse bu süre sonra devam.
const Duration kAdReturnGrace = Duration(milliseconds: 1500);
const Duration kRewardedLoadTimeout = Duration(seconds: 5); // dokunuşta ödüllü reklam yükleme bekleme sınırı (1.1.4: 10 → 5 sn)
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
  /// [allowed] (1.1.3, docs/20): `ad.show()` çağrılmadan hemen önce sorulur; false ise reklam GÖSTERİLMEZ.
  /// 1.1.4 (docs/21): Future YALNIZCA SDK olayıyla (kapandı / gösterilemedi) ya da senkron/asenkron istisnayla tamamlanır;
  /// platformda süre sınırı YOKTUR (eski 3 sn'lik "bırak" zamanlayıcısı seviye ortasında reklama yol açıyordu).
  Future<bool> showInterstitial({bool Function()? allowed});

  /// 1.1.4: uygulama reklamdan/arka plandan döndü ama SDK kapanış olayı gelmedi: platform gösterim durumunu unutur
  /// (tamamlayıcıyı bitirir, `_showing` sıfırlanır). Reklamı YENİDEN göstermez. İdempotent.
  void releaseInterstitial();

  /// Tam ekran reklam gerçekten ekrana gelince true, kapanınca/başarısız olunca/bırakılınca false (1.1.3: ses YALNIZCA bu sırada susar).
  void Function(bool onScreen)? onScreenChanged;

  /// Bekleyen gösterim yokken bir tam ekran reklam "gösterildi" olayı geldiyse çağrılır (kalkan: oyun duraklatılır, telemetri late_blocked).
  void Function()? onLateAd;

  /// Geçiş reklamı şu an gerçekten ekranda mı (SDK "gösterildi" olayı geldi, henüz kapanmadı)?
  bool get interstitialOnScreen;

  /// Ödüllü reklamı gösterir; ödül hak edilince [onReward] çağrılır; reklam kapanınca / gösterilemeyince Future tamamlanır.
  /// [allowed] false ise gösterilmez (dokunuş isteği artık geçerli değil). 1.1.4: platformda süre sınırı yok (bkz. [showInterstitial]).
  Future<void> showRewarded(String placement, void Function() onReward, {bool Function()? allowed});

  /// 1.1.4: [releaseInterstitial] karşılığı (ödüllü). İdempotent.
  void releaseRewarded();

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

  /// 1.1.4: show() sonrası "yavaş" uyarısı süresi ([kAdHoldMax]). Bekleme bu sürede BİTMEZ.
  final Duration holdMax;

  /// 1.1.4: gösterim sürerken uygulama reklamdan/arka plandan döndü ama SDK olayı gelmediyse bekleme süresi ([kAdReturnGrace]).
  final Duration returnGrace;

  /// Geçiş reklamı gösterim sonucu (analiz için; docs/19): 'shown' | 'skipped' (zamanı geldi ama hazır değildi) |
  /// 'failed' (gösterim denendi ama ekrana gelmedi / hata). Yalnızca reklamın zamanı geldiyse çağrılır. Hata fırlatsa bile yutulur.
  final void Function(String result)? onInterstitialResult;

  /// 1.1.4 (docs/21): tam ekran reklam aşamaları + gecikme (ms). [format]: interstitial | rewarded;
  /// [stage]: show_called | showed | dismissed | failed_to_show | stuck | released | late_blocked. Hata fırlatsa bile yutulur.
  final void Function(String format, String stage, int latencyMs)? onAdStage;

  Monetization({
    required this.platform,
    required this.getAds,
    required this.persist,
    int Function()? now,
    this.nativeTimeout = kNativeTimeout,
    this.holdMax = kAdHoldMax,
    this.returnGrace = kAdReturnGrace,
    this.onInterstitialResult,
    this.onAdStage,
  }) : now = now ?? (() => DateTime.now().millisecondsSinceEpoch) {
    platform.onScreenChanged = _screenChanged;
    platform.onLateAd = lateAdSurfaced;
  }

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

  // ---- 1.1.3 (docs/20): ses yalnızca reklam GERÇEKTEN ekrandayken susar ----
  final List<void Function(bool onScreen)> _screenListeners = <void Function(bool onScreen)>[];
  bool _onScreen = false;

  /// Tam ekran reklam ekrana gelince true, kapanınca false (yalnızca değişimde). Ses bu olaya bağlanır; [addAdListener] (ticker) değil.
  Unsubscribe addScreenListener(void Function(bool onScreen) fn) {
    _screenListeners.add(fn);
    return () => _screenListeners.remove(fn);
  }

  bool get adOnScreen => _onScreen;

  void _screenChanged(bool on) {
    final _Hold? h = _hold;
    if (on && h != null && !h.showed) {
      h.showed = true;
      diag('ad', 'showed', <String, Object?>{'format': h.format, 'lvl': h.level, 'ms': now() - h.t0});
      _stage(h.format, 'showed', now() - h.t0);
    }
    if (_onScreen == on) return;
    _onScreen = on;
    for (final void Function(bool) f in List<void Function(bool)>.of(_screenListeners)) {
      try {
        f(on);
      } catch (_) {}
    }
  }

  // ---- 1.1.3: yerleştirme (placement) oturumu — geçiş reklamı yalnızca seviye sonu ekranı etkinken ----
  int _placementSeq = 0;
  int _placementOpen = 0; // 0: açık yok
  int _placementLevel = 0;
  int _placementUsed = 0; // show() çağrılmış belge: bir yerleştirmede en çok BİR kez

  /// Seviye sonu ekranı açılınca çağrılır; belirteç döner. Yeni oturum eskisini geçersiz kılar.
  int openLevelEnd(int levelId) {
    _placementOpen = ++_placementSeq;
    _placementLevel = levelId;
    return _placementOpen;
  }

  /// Seviye sonu ekranı kapanırken / yeni seviye başlarken. [token] verilirse yalnızca eşleşirse kapatılır.
  void closeLevelEnd([int? token]) {
    if (token == null || token == _placementOpen) _placementOpen = 0;
  }

  bool placementValid(int token, [int? levelId]) =>
      token != 0 && token == _placementOpen && (levelId == null || levelId == _placementLevel);

  bool get levelEndActive => _placementOpen != 0;

  // ---- 1.1.4 (docs/21): tam ekran gösterim TUTMA (hold) durumu ----
  _Hold? _hold;

  /// Şu an show() çağrılmış ve SDK'dan sonuç beklenen bir tam ekran reklam var mı? true iken yeni seviye BAŞLATILMAZ.
  bool get adHoldActive => _hold != null;

  /// Bekleyen gösterimin biçimi (interstitial | rewarded) ya da null.
  String? get adHoldFormat => _hold?.format;

  void _stage(String format, String stage, int ms) {
    try {
      onAdStage?.call(format, stage, ms < 0 ? 0 : ms);
    } catch (_) {}
  }

  /// Uygulama yaşam döngüsü (AppController → app.dart). [hard]: hidden/paused (uygulama gerçekten arka planda); false: yalnızca
  /// inactive (AdMob AdActivity saydam temalıdır, açıldığında çoğu zaman yalnızca inactive gelir; bildirim perdesi de inactive yapar).
  /// Gösterim beklenirken uygulama (a) gerçekten arka plana gidip dönerse ya da (b) reklam ekrana geldikten sonra inactive→resumed
  /// olursa ve [returnGrace] içinde SDK olayı gelmezse bekleme biter (reklam bitmiş sayılır). Reklam henüz ekrana gelmemişken yalnızca
  /// inactive→resumed (ör. bildirim perdesi) beklemeyi BİTİRMEZ: geç sunulan reklam sonraki seviyeye düşmesin.
  void onAppLifecycle({required bool foreground, bool hard = true}) {
    final _Hold? h = _hold;
    if (h == null) return;
    if (!foreground) {
      h.wentAway = true;
      if (hard) h.wentHard = true;
      h.grace?.cancel();
      h.grace = null;
      return;
    }
    if (!(h.wentHard || (h.wentAway && h.showed))) return;
    h.wentAway = false;
    h.wentHard = false;
    h.grace?.cancel();
    h.grace = Timer(returnGrace, () {
      if (_hold != h || h.done.isCompleted) return;
      diag('ad', 'released_on_return', <String, Object?>{'format': h.format, 'lvl': h.level, 'showed': h.showed, 'ms': now() - h.t0});
      _stage(h.format, 'released', now() - h.t0);
      try {
        if (h.format == 'interstitial') {
          platform.releaseInterstitial();
        } else {
          platform.releaseRewarded();
        }
      } catch (_) {}
      if (!h.showed) _openLateWindow(); // ekrana hiç gelmemişti: olası geç gelişe karşı kalkan penceresi
      if (!h.done.isCompleted) h.done.complete(h.showed);
    });
  }

  /// Tutmayı başlatır: [start] show() çağrısını yapar ve sonuç Future'ını döner. Sonuç YALNIZCA SDK'dan (kapandı/gösterilemedi/istisna)
  /// ya da [onAppLifecycle] dönüşünden gelir. [holdMax] dolarsa [onSlow] çağrılır, bekleme sürer.
  Future<bool> _holdFor(String format, int level, Future<bool> Function() start, {void Function()? onSlow}) async {
    final _Hold h = _Hold(format, level, now());
    _hold = h;
    diag('ad', 'show_called', <String, Object?>{'format': format, 'lvl': level});
    _stage(format, 'show_called', 0);
    final Timer slow = Timer(holdMax, () {
      if (h.done.isCompleted || _hold != h) return;
      h.stuck = true;
      diag('ad', 'stuck', <String, Object?>{'format': format, 'lvl': level, 'showed': h.showed, 'ms': now() - h.t0});
      _stage(format, 'stuck', now() - h.t0);
      try {
        onSlow?.call();
      } catch (_) {}
    });
    try {
      start().then<void>((bool v) {
        if (!h.done.isCompleted) h.done.complete(v);
      }, onError: (Object e) {
        diag('ad', 'show_error', <String, Object?>{'format': format, 'e': e});
        if (!h.done.isCompleted) h.done.complete(false);
      });
    } catch (e) {
      diag('ad', 'show_exception', <String, Object?>{'format': format, 'e': e});
      if (!h.done.isCompleted) h.done.complete(false);
    }
    try {
      final bool v = await h.done.future;
      final int ms = now() - h.t0;
      if (h.showed || v) {
        diag('ad', 'dismissed', <String, Object?>{'format': format, 'lvl': level, 'ms': ms});
        _stage(format, 'dismissed', ms);
      } else {
        diag('ad', 'failed_to_show', <String, Object?>{'format': format, 'lvl': level, 'ms': ms});
        _stage(format, 'failed_to_show', ms);
      }
      return v;
    } finally {
      slow.cancel();
      h.grace?.cancel();
      if (_hold == h) _hold = null;
    }
  }

  // ---- geç gelen reklam kalkanı (1.1.3; 1.1.4'te yalnızca "uygulamadan dönüşle bırakılan" gösterimden sonra açılır) ----
  static const int kLateWindowMs = 30 * 1000;
  int _lateUntil = 0;
  bool _lateHeld = false;
  Timer? _lateCap;

  /// Ekrana gelmeden bırakılmış bir gösterimin hâlâ ekrana gelebileceği pencere açık mı.
  bool get lateWindowOpen => _lateUntil != 0 && now() < _lateUntil;

  void _openLateWindow() => _lateUntil = now() + kLateWindowMs;

  /// Seviye SIRASINDA tam ekran reklam belirdi: telemetri `late_blocked`, oyun (ticker + ses) duraklatılır. [lateAdGone] ile geri alınır;
  /// en geç [kNativeTimeout] sonra kendiliğinden.
  void lateAdSurfaced() {
    _reportInterstitial('late_blocked');
    diag('ad', 'late_blocked');
    _stage('interstitial', 'late_blocked', 0);
    _lateUntil = 0;
    if (_lateHeld) return;
    _lateHeld = true;
    _screenChanged(true);
    _adState(true);
    _lateCap?.cancel();
    _lateCap = Timer(nativeTimeout, lateAdGone);
  }

  void lateAdGone() {
    _lateCap?.cancel();
    _lateCap = null;
    if (!_lateHeld) return;
    _lateHeld = false;
    _screenChanged(false);
    _adState(false);
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

  /// Seviye bitmeden (son oklar çıkarken) çağrılır: reklam gerekecekse ve hazır/yükleniyor değilse yüklemeyi başlatır. ASLA göstermez.
  PreloadState preloadInterstitial(int levelId) {
    if (!interstitialWillBeDue(levelId)) return PreloadState.skip;
    return platform.preloadInterstitial();
  }

  /// Oyun ekranı açılınca ve can 1'e düşünce çağrılır: hazır değilse ve yüklenmiyorsa yüklemeyi sessizce başlatır. ASLA göstermez.
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

  /// Seviye sonu ekranında oyuncu devam edince çağrılır (show() çağıran TEK yol). Reklam gösterilip kapandıysa true.
  ///  - Reklam yüklü değilse HİÇ beklemeden false (yükleme arka planda sürer; hiçbir yükleme geri çağrısı show() çağırmaz).
  ///  - Yüklüyse show() BİR kez çağrılır ve dönüş SDK "kapandı"/"gösterilemedi" bildirene ya da uygulama reklamdan dönene dek
  ///    BEKLER (1.1.4). [holdMax] dolarsa [onSlow] (arayüz "reklam gecikiyor" der); bekleme yine sürer. Böylece reklam asla
  ///    sonraki seviyenin ortasına düşmez.
  ///  - [_adState] (ticker duraklatması) ve ses durumu her yolda `finally` ile geri alınır.
  Future<bool> continueAfterLevel(int levelId, {required int placement, void Function()? onSlow}) async {
    // 1.1.3: yalnızca etkin seviye sonu yerleştirmesinde ve belirteç eşleşirse
    if (!placementValid(placement, levelId)) {
      _reportInterstitial('blocked');
      diag('ad', 'blocked', <String, Object?>{'format': 'interstitial', 'lvl': levelId});
      return false;
    }
    if (_placementUsed == placement) return false; // bu yerleştirmede show() zaten çağrıldı
    if (_hold != null) return false; // başka bir tam ekran gösterim sürüyor
    if (!interstitialDue(levelId)) return false;
    bool ready = false;
    try {
      ready = platform.interstitialReady;
    } catch (_) {
      ready = false;
    }
    if (!ready) {
      _reportInterstitial('skipped');
      diag('ad', 'skip_not_loaded', <String, Object?>{'format': 'interstitial', 'lvl': levelId});
      return false; // yüklenmemiş: HİÇ beklemeden devam
    }
    final AdsState a = getAds();
    a.since = 0;
    a.lastAt = now();
    persist();
    _placementUsed = placement; // show() en çok bir kez
    _adState(true); // ticker duraklatması (ses DEĞİL)
    try {
      final bool shown = await _holdFor('interstitial', levelId, () {
        return platform.showInterstitial(allowed: () => placementValid(placement, levelId));
      }, onSlow: onSlow);
      _reportInterstitial(shown ? 'shown' : 'failed');
      return shown;
    } catch (_) {
      _reportInterstitial('failed');
      return false;
    } finally {
      _adState(false);
      if (!_lateHeld && !platform.interstitialOnScreen) _screenChanged(false); // ses her yolda geri alınır
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

  /// Hazır değilse yüklemeyi başlatır ([loadTimeout] sınırıyla); sonunda reklam hazır mı. İstisna fırlatmaz. ASLA göstermez:
  /// süre dolduktan sonra tamamlanan yükleme reklamı yalnızca saklar (sonraki DOKUNUŞTA kullanılır).
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

  /// Dokunuşta tam akış: hazır değilse [onLoading] → yükle (≤ [loadTimeout]) → [onLoadingDone] → göster ve kapanana dek bekle.
  /// [onReward] ödül hak edilirse en çok bir kez. Reklam yüklenemezse hiçbir şey gösterilmez ve [RewardedOutcome.unavailable] döner.
  /// Yükleme süreden sonra tamamlanırsa reklam KENDİLİĞİNDEN gösterilmez (yalnızca sonraki dokunuşta).
  Future<RewardedResult> watchRewarded(
    String placement, {
    void Function()? onReward,
    void Function()? onLoading,
    void Function()? onLoadingDone,
    void Function()? onShowStart,
    void Function()? onSlow,
    Duration loadTimeout = kRewardedLoadTimeout,
    bool Function()? stillWanted,
  }) async {
    if (!_bridge) return const RewardedResult(RewardedOutcome.unavailable, errorCode: 'no_platform');
    if (!platform.rewardedReady) {
      diag('ad', 'load_on_tap', <String, Object?>{'format': 'rewarded', 'p': placement});
      onLoading?.call();
      final bool ok = await ensureRewarded(loadTimeout: loadTimeout); // istisna fırlatmaz
      onLoadingDone?.call();
      if (!ok) {
        diag('ad', 'unavailable', <String, Object?>{'format': 'rewarded', 'p': placement, 'code': platform.lastRewardedErrorCode});
        return RewardedResult(RewardedOutcome.unavailable, errorCode: platform.lastRewardedErrorCode ?? 'unknown');
      }
    }
    if (!platform.rewardedReady) {
      // yükleme ile gösterim arasında süresi doldu / tüketildi
      return RewardedResult(RewardedOutcome.unavailable, errorCode: platform.lastRewardedErrorCode ?? 'expired');
    }
    if (stillWanted != null && !stillWanted()) {
      // yükleme beklerken ekran kapandı: dokunuşun sonucu artık geçerli değil → ASLA gösterme
      diag('ad', 'cancelled', <String, Object?>{'format': 'rewarded', 'p': placement});
      return const RewardedResult(RewardedOutcome.unavailable, errorCode: 'cancelled');
    }
    onShowStart?.call();
    final bool rewarded = await showRewarded(placement, onReward: onReward, stillWanted: stillWanted, onSlow: onSlow);
    if (rewarded) return const RewardedResult(RewardedOutcome.rewarded);
    // gösterim hiç başlamadıysa (başarısız) "kapandı" değil "reklam yok" sayılır (docs/18)
    final String? showErr = platform.lastRewardedErrorCode;
    if (showErr != null && showErr.startsWith('show_')) {
      return RewardedResult(RewardedOutcome.unavailable, errorCode: showErr);
    }
    return const RewardedResult(RewardedOutcome.closed);
  }

  /// [onReward] ödül hak edilirse en çok bir kez çağrılır. Dönen değer: ödül verildi mi. Hazır ödüllü reklam gerekir
  /// (yüklemeyi de yapan tam akış için [watchRewarded]). Kapanana dek bekler (1.1.4: süre sınırıyla bırakılmaz).
  Future<bool> showRewarded(String placement,
      {void Function()? onReward, bool Function()? stillWanted, void Function()? onSlow}) async {
    if (!rewardedAvailable()) return false;
    if (_hold != null) return false;
    bool rewarded = false;
    final int req = ++_rewardedSeq; // 1.1.3: ödüllü reklam yalnızca bu dokunuş isteği sürerken gösterilir
    _rewardedActive = req;
    _adState(true); // ticker duraklatması (ses DEĞİL)
    try {
      await _holdFor('rewarded', 0, () async {
        await platform.showRewarded(placement, () {
          if (rewarded) return;
          rewarded = true;
          onReward?.call();
        }, allowed: () => _rewardedActive == req && (stillWanted?.call() ?? true));
        return rewarded || _onScreenSeen;
      }, onSlow: onSlow);
    } catch (_) {
      // yut: oyun devam eder
    } finally {
      if (_rewardedActive == req) _rewardedActive = 0;
      _adState(false);
      if (!_lateHeld) _screenChanged(false); // ses her yolda geri alınır
    }
    return rewarded;
  }

  bool get _onScreenSeen => _hold?.showed ?? false;

  int _rewardedSeq = 0;
  int _rewardedActive = 0;

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

/// 1.1.4: bekleyen tam ekran gösterim (show() çağrıldı, SDK sonucu bekleniyor).
class _Hold {
  final String format;
  final int level;
  final int t0;
  bool showed = false;
  bool wentAway = false;
  bool wentHard = false;
  bool stuck = false;
  Timer? grace;
  final Completer<bool> done = Completer<bool>();
  _Hold(this.format, this.level, this.t0);
}
