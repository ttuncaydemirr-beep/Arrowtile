// Arrowtile — app_controller.dart: uygulama durumu (kayıt, servisler, seviye sağlayıcı, bildirim).
// UI, bu sınıfı AppScope ile alır. Kural/ekonomi mantığı core/ içindedir; burası yalnızca bağlar ve kaydeder.
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show GlobalKey, NavigatorState;
import 'package:flutter/services.dart' show rootBundle;

import '../core/ads_rules.dart';
import '../core/daily.dart' as daily;
import '../core/economy.dart' as eco;
import '../core/levelgen.dart';
import '../core/models.dart';
import '../core/save_data.dart';
import '../services/ads_service.dart';
import '../services/audio_service.dart';
import '../services/billing_service.dart';
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
  }) {
    sfx.enabled = save.sound;
    haptics.enabled = save.vibration;
    platform = FlutterAdsPlatform(billing: billing, onChanged: notifyListeners);
    mon = Monetization(platform: platform, getAds: () => save.ads, persist: persist);
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

  static Future<AppController> create() async {
    final SaveStore store = await SaveStore.open();
    final SaveData save = store.load(detectLang());
    final List<dynamic> raw = jsonDecode(await rootBundle.loadString('lib/data/levels.json')) as List<dynamic>;
    final List<Level> prebuilt = <Level>[
      for (final dynamic j in raw) Level.fromJson(j as Map<String, dynamic>)
    ];
    final BillingService billing = BillingService(owned: save.ads.adFree && !save.ads.test);
    return AppController._(store: store, save: save, prebuilt: prebuilt, billing: billing);
  }

  /// İlk kare çizildikten sonra çağrılır: ses, satın alma, onay/reklam.
  Future<void> startServices() async {
    unawaited(sfx.init());
    unawaited(billing.start());
    unawaited(platform.refreshOnline());
    unawaited(platform.gatherConsent());
  }

  void onAppResumed() {
    platform.onResume();
  }

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
  }

  void setAim(bool v) {
    save.aim = v;
    commit();
  }

  void setAppearance(String m) {
    if (!<String>['auto', 'light', 'dark'].contains(m)) return;
    save.appearance = m;
    commit();
  }

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

  void toast(String msg) {
    toastText = msg;
    final int my = ++_toastSeq;
    notifyListeners();
    Timer(const Duration(milliseconds: 1600), () {
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
        // son 4 seviye bellekte kalır
        if (_endless.length > 4) {
          final List<int> ids = _endless.keys.toList()..sort((int a, int b) => b.compareTo(a));
          for (final int old in ids.skip(4)) {
            _endless.remove(old);
          }
        }
        return lv;
      } finally {
        _inflight.remove(id);
      }
    });
  }

  /// Sıradaki sonsuz seviyeyi oyuncu oynarken önceden üret.
  void prefetchNext(int id) {
    if (id + 1 > prebuilt.length && id + 1 <= kMaxLevel) {
      unawaited(ensureLevel(id + 1).then((Level _) {}, onError: (Object _) {}));
    }
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
}
