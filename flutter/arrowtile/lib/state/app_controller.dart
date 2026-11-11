// Arrowtile — app_controller.dart: uygulama durumu (kayıt, servisler, seviye sağlayıcı, bildirim).
// UI, bu sınıfı AppScope ile alır. Kural/ekonomi mantığı core/ içindedir; burası yalnızca bağlar ve kaydeder.
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show GlobalKey, NavigatorState;
import 'package:flutter/services.dart' show rootBundle;

import '../config/ads_config.dart';
import '../core/ads_rules.dart';
import '../core/consent_gate.dart' show TelemetryConsent;
import '../core/daily.dart' as daily;
import '../core/diag.dart';
import '../core/economy.dart' as eco;
import '../core/levelgen.dart';
import '../core/models.dart';
import '../core/save_data.dart';
import '../core/telemetry.dart';
import '../services/ads_service.dart';
import '../services/audio_service.dart';
import '../services/billing_service.dart';
import '../services/consent_signals.dart';
import '../services/haptics_service.dart';
import '../services/save_store.dart';

/// Arka plan izolatında sonsuz seviye üretir (UI takılmaz). Üst düzey işlev: izolata yalnızca int geçer.
Map<String, dynamic> _generateLevelJson(int id) => makeLevel(id).toLevel().toJson();

Map<String, dynamic>? _generateDailyJson(String ymd) => daily.puzzleFor(ymd)?.toJson();

// Isolate.run'a verilen kapanış bir örnek yöntemi içinde oluşturulursa `this`'i (AppController) yakalayıp gönderilemez;
// bu yüzden kapanışlar yalnızca basit parametre yakalayan üst düzey işlevlerde oluşturulur.
Future<Map<String, dynamic>> _genLevelInIsolate(int id) =>
    Isolate.run<Map<String, dynamic>>(() => _generateLevelJson(id));
Future<Map<String, dynamic>?> _genDailyInIsolate(String ymd) =>
    Isolate.run<Map<String, dynamic>?>(() => _generateDailyJson(ymd));

class AppController extends ChangeNotifier {
  AppController._({
    required this.store,
    required this.save,
    required this.prebuilt,
    required this.billing,
    this.telemetry = const NoopTelemetry(),
    AdsPlatform? adsPlatform,
  }) {
    sfx.enabled = save.sound;
    haptics.enabled = save.vibration;
    platform = FlutterAdsPlatform(
        billing: billing,
        onChanged: notifyListeners,
        inGame: () => _gameDepth > 0,
        onConsentStatus: _onConsentStatus);
    // adsPlatform: yalnızca testlerde sahte platform enjekte eder (docs/18); normalde gerçek FlutterAdsPlatform
    mon = Monetization(
        platform: adsPlatform ?? platform,
        getAds: () => save.ads,
        persist: persist,
        onInterstitialResult: (String r) => telemetry.interstitial(result: r),
        onAdStage: (String f, String st, int ms) => telemetry.adStage(format: f, stage: st, latencyMs: ms));
    // docs/15 §4: tam ekran reklam gösterilirken ses duraklar (oyun ekranı ayrıca animasyon döngüsünü duraklatır)
    mon.addScreenListener((bool onScreen) => sfx.setHeld(onScreen)); // 1.1.3: ses yalnızca reklam EKRANDAYKEN susar
    sfx.onDeadRecovered = (String reason) => telemetry.audioDeadRecovered(reason: reason); // 1.1.4 (docs/21)
    billing.onOwnedChanged = (bool owned) {
      if (owned) {
        save.ads.adFree = true;
        save.ads.test = false;
        persist();
      }
      notifyListeners();
    };
    _endless = store.loadEndless();
  }

  final SaveStore store;
  SaveData save;
  final List<Level> prebuilt;
  final BillingService billing;

  /// Analiz + çökme raporu (docs/19). Testlerde ve yapılandırma yokken [NoopTelemetry]; arayüz Firebase'e doğrudan dokunmaz.
  final Telemetry telemetry;
  final AudioService sfx = AudioService();
  final HapticsService haptics = HapticsService();
  late final FlutterAdsPlatform platform;
  late final Monetization mon;

  Map<int, Level> _endless = <int, Level>{};
  /// Uygulama gezgini (oyun ekranı kapandıktan sonra pencere açmak için).
  final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  final Map<int, Future<Level>> _inflight = <int, Future<Level>>{};
  final Map<String, Level?> _dailyCache = <String, Level?>{};

  static String detectLang() {
    try {
      final String l = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
      return kLangs.contains(l) ? l : 'en';
    } catch (_) {
      return 'en';
    }
  }

  static Future<AppController> create({AdsPlatform? adsPlatform, Telemetry? telemetry}) async {
    final SaveStore store = await SaveStore.open();
    final SaveData save = store.load(detectLang());
    if (AdsConfig.autoPlayFrom > 0 && !kReleaseMode) {
      // docs/18 donma testi tohumu: seviye açık, bir seviye sonra geçiş reklamı zamanı
      save.unlocked = math.max(save.unlocked, AdsConfig.autoPlayFrom).clamp(1, kMaxLevel).toInt();
      save.ads.since = kEveryLevels - 1;
      save.ads.lastAt = 0;
      save.ads.adFree = false;
    }
    final List<dynamic> raw = jsonDecode(await rootBundle.loadString('lib/data/levels.json')) as List<dynamic>;
    final List<Level> prebuilt = <Level>[
      for (final dynamic j in raw) Level.fromJson(j as Map<String, dynamic>)
    ];
    final BillingService billing = BillingService(owned: save.ads.adFree && !save.ads.test);
    return AppController._(
        store: store,
        save: save,
        prebuilt: prebuilt,
        billing: billing,
        telemetry: telemetry ?? const NoopTelemetry(),
        adsPlatform: adsPlatform);
  }

  /// İlk kare çizildikten sonra çağrılır: ses, satın alma, onay/reklam.
  Future<void> startServices() async {
    telemetry.setLanguage(save.lang);
    unawaited(sfx.init());
    unawaited(billing.start());
    unawaited(platform.refreshOnline());
    unawaited(platform.gatherConsent());
  }

  /// UMP durumu güncellendi: Firebase Analytics onay sinyallerini (analytics_storage / ad_storage / ad_user_data /
  /// ad_personalization) türetip uygular. Onay bilinene dek hepsi kapalıdır (AndroidManifest + FirebaseTelemetry varsayılanı).
  void _onConsentStatus(String umpStatus) {
    unawaited(() async {
      try {
        final TelemetryConsent c = await ConsentSignals.resolve(umpStatus);
        await telemetry.setConsent(c);
        telemetry.setLanguage(save.lang); // toplama onayla açıldıysa kullanıcı özelliği şimdi yazılır
      } catch (_) {}
    }());
  }

  /// Uygulama öne geldi (app.dart). 1.1.4: bekleyen tam ekran gösterim varsa Monetization "reklamdan dönüldü" sayabilir.
  void onAppResumed() {
    diag('app', 'resumed', <String, Object?>{'adHold': mon.adHoldFormat});
    sfx.onLifecycle(foreground: true); // takılı/bozuk ses oyuncularını yeniden kur (1.1.4)
    mon.onAppLifecycle(foreground: true);
    platform.onResume();
  }

  void onAppBackgrounded() {
    diag('app', 'background', <String, Object?>{'adHold': mon.adHoldFormat});
    sfx.onLifecycle(foreground: false);
    mon.onAppLifecycle(foreground: false);
  }

  /// Yalnızca inactive (saydam AdActivity, bildirim perdesi, sistem penceresi).
  void onAppInactive() => mon.onAppLifecycle(foreground: false, hard: false);

  // ------------------------------------------------------------------ oyun ekranı sayacı
  // Açık oyun ekranı sayısı (seviye geçişinde kısa süre 2). Onay formu (UMP) oyunun üstüne açılmaz: oyundan çıkılınca gösterilir.
  int _gameDepth = 0;
  bool get inGame => _gameDepth > 0;

  void gameEntered() => _gameDepth++;

  void gameLeft() {
    if (_gameDepth > 0) _gameDepth--;
    if (_gameDepth == 0) platform.retryConsentForm();
  }

  /// Oyun başlatmadan önce çağrılır: onay akışı (bilgi güncellemesi / form) sürüyorsa en çok 8 sn bekler.
  Future<void> waitConsentIdle() => platform.waitConsentIdle();

  @override
  void dispose() {
    platform.dispose();
    billing.dispose();
    sfx.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ kayıt
  void persist() {
    store.save(save);
  }

  /// Kaydet + arayüzü yenile.
  void commit() {
    persist();
    notifyListeners();
  }

  String get lang => save.lang;
  bool get isRtl => save.lang == 'ar';

  // ------------------------------------------------------------------ ayarlar
  void setLang(String l) {
    if (!kLangs.contains(l)) return;
    save.lang = l;
    commit();
    telemetry.setLanguage(l);
  }

  void setSound(bool v) {
    save.sound = v;
    sfx.enabled = v;
    commit();
    if (v) sfx.button();
  }

  void setVibration(bool v) {
    save.vibration = v;
    haptics.enabled = v;
    commit();
    if (v) haptics.buzz('button');
  }

  void setRelaxed(bool v) {
    save.relaxed = v;
    commit();
    telemetry.settingChanged(name: 'relaxed_mode', value: v ? 'on' : 'off');
  }

  void setAim(bool v) {
    save.aim = v;
    commit();
    telemetry.settingChanged(name: 'aim_mode', value: v ? 'on' : 'off');
  }

  /// 1.2.0: Ayarlar → Görünüm → Ok rengi: 'color' (Renkli, varsayılan) | 'mono' (Tek renk ince çizgi). Kalıcı.
  void setArrowColor(String m) {
    if (m != 'color' && m != 'mono') return;
    save.arrowColor = m;
    commit();
    telemetry.settingChanged(name: 'arrow_color', value: m);
  }

  void setAppearance(String m) {
    if (!<String>['auto', 'light', 'dark'].contains(m)) return;
    save.appearance = m;
    commit();
    telemetry.settingChanged(name: 'appearance', value: m);
  }

  /// Ok teması giyildi / satın alınıp giyildi (Mağaza). Tema kimlikleri sabit bir kümedir (serbest metin değil).
  void themeEquipped(String themeId) => telemetry.settingChanged(name: 'arrow_theme', value: themeId);

  void resetAll() {
    save = eco.resetProgress(save);
    store.clearProgress();
    sfx.enabled = save.sound;
    haptics.enabled = save.vibration;
    commit();
  }

  /// "Dışa aktar" kodu (ARROWTILE1-…); dil ve satın alma durumu koda girmez.
  String exportBackupCode() => eco.exportCode(save);

  bool isValidBackupCode(String code) => eco.parseCode(code, save.lang) != null;

  /// Yedek kodunu uygular; geçersizse false.
  bool importBackup(String code) {
    final SaveData? s = eco.importCode(save, code);
    if (s == null) return false;
    save = s;
    sfx.enabled = save.sound;
    haptics.enabled = save.vibration;
    commit();
    return true;
  }

  // ------------------------------------------------------------------ ses / titreşim kısayolları
  void buzz(String name) => haptics.buzz(name);

  // ------------------------------------------------------------------ bildirim (toast)
  String? toastText;
  int _toastSeq = 0;

  /// Bildirim. [ms]: görünme süresi (1.2.0: çarpma uyarısı 2,5 sn, büyük tahta ipucu 2,6 sn; diğerleri 1,6 sn).
  void toast(String msg, {int ms = 1600}) {
    toastText = msg;
    final int my = ++_toastSeq;
    notifyListeners();
    Timer(Duration(milliseconds: ms), () {
      if (my == _toastSeq) {
        toastText = null;
        notifyListeners();
      }
    });
  }

  void clearToast() {
    if (toastText != null) {
      _toastSeq++;
      toastText = null;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ seviyeler
  Level? getLevel(int id) {
    if (id < 1 || id > kMaxLevel) return null;
    if (id <= prebuilt.length) return prebuilt[id - 1];
    return _endless[id];
  }

  /// Seviyeyi döndürür; sonsuz seviye henüz yoksa arka planda üretir.
  Future<Level> ensureLevel(int id) {
    final Level? have = getLevel(id);
    if (have != null) return Future<Level>.value(have);
    return _inflight.putIfAbsent(id, () async {
      try {
        final Map<String, dynamic> j = await _genLevelInIsolate(id);
        final Level lv = Level.fromJson(j);
        _endless[id] = lv;
        store.saveEndless(_endless);
        // en yüksek numaralı 6 seviye bellekte kalır (oynanan + önceden üretilen 2 + geri dönüş)
        if (_endless.length > 6) {
          final List<int> ids = _endless.keys.toList()..sort((int a, int b) => b.compareTo(a));
          for (final int old in ids.skip(6)) {
            _endless.remove(old);
          }
        }
        return lv;
      } finally {
        _inflight.remove(id);
      }
    });
  }

  /// Sıradaki seviyeleri oyuncu oynarken arka plan izolatında önceden üret (1.2.0: paket 100 seviye; sonrası izolatta).
  /// Sırayla (biri bitince diğeri) — aynı anda tek izolat; UI iş parçacığı hiç üretim yapmaz.
  void prefetchNext(int id, {int ahead = 2}) {
    Future<void> chain = Future<void>.value();
    for (int k = 1; k <= ahead; k++) {
      final int n = id + k;
      if (n <= prebuilt.length || n > kMaxLevel) continue;
      chain = chain.then((_) => ensureLevel(n).then((Level _) {}, onError: (Object _) {}));
    }
    unawaited(chain);
  }

  /// Günlük bulmaca (tarih tohumlu; izolatta üretilir).
  Future<Level?> dailyLevel(String ymd) async {
    if (_dailyCache.containsKey(ymd) && _dailyCache[ymd] != null) return _dailyCache[ymd];
    final Map<String, dynamic>? j = await _genDailyInIsolate(ymd);
    final Level? lv = j == null ? null : Level.fromJson(j);
    _dailyCache[ymd] = lv;
    return lv;
  }

  // ------------------------------------------------------------------ oyun sonu kayıtları
  eco.CompleteResult finishLevel(int id, int stars, bool relaxed) {
    final eco.CompleteResult r = eco.completeLevel(save, id, stars, relaxed);
    mon.onLevelComplete(id); // reklam sayacı: yalnızca başarıyla tamamlanan seviyeler (13+) sayılır
    if (id <= 3 && !save.tutorialDone.contains(id)) save.tutorialDone.add(id);
    commit();
    return r;
  }

  daily.SolveRecord finishDaily(String ymd, int stars) {
    final daily.SolveRecord r = daily.recordSolve(save.dp, ymd, stars);
    commit();
    return r;
  }

  // ------------------------------------------------------------------ ipuçları (tek seferlik)
  bool hasTip(String k) => save.tips.contains(k);
  void markTip(String k) {
    if (!hasTip(k)) {
      save.tips.add(k);
      persist();
    }
  }

  String today() => eco.ymd(DateTime.now());

  /// Ödüllü +1 can kullanılan seviye (baştan başlayınca sıfırlanmaz; main.js revivedFor). Kalıcı değildir.
  String? revivedFor;

  /// Bir ödüllü reklam akışı (yükleme + gösterim) sürerken true: çift dokunuş ikinci akışı başlatmaz. Her yolda sıfırlanır.
  bool rewardBusy = false;
}
