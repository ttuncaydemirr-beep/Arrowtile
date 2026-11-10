// Testler için sahte reklam platformu (ads_rules_test + seviye geçişi testleri; docs/18, docs/21). Gerçek AdMob/Billing çağrılmaz.
import 'dart:async';

import 'package:arrowtile/core/ads_rules.dart';

/// Testlerde seviye sonu yerleştirmesini açıp devam eder (1.1.3: continueAfterLevel belirteç ister).
extension LevelEndTest on Monetization {
  Future<bool> endScreen(int id) {
    final int t = openLevelEnd(id);
    return continueAfterLevel(id, placement: t).whenComplete(() => closeLevelEnd(t));
  }
}

class FakePlatform implements AdsPlatform {
  bool isAvailable = true;
  bool isOnline = true;
  bool owns = false;
  bool interstitialOk = true;
  bool rewardedOk = true;
  bool rewardGiven = true; // false: ödül hak edilmeden kapanır
  bool hangInterstitial = false;
  bool failToShow = false; // onAdFailedToShowFullScreenContent: false ile tamamlanır
  bool throwOnShow = false; // showInterstitial senkron istisna fırlatır
  bool onScreen = false; // geçiş reklamı gerçekten ekranda (gösterildi olayı geldi)
  Duration? showAfter; // gösterim bu kadar sonra "kapandı" (true) ile tamamlanır (yavaş yükleme/gösterim)
  bool appearsOnScreen = false; // showAfter ile birlikte: gösterim ekrana gelir (oyuncu izliyor)
  bool hangRewardedShow = false;
  bool hangLoad = false; // ensureRewardedLoaded hiç tamamlanmaz (platform da takılırsa Monetization takılmamalı)
  bool loadOk = true; // ensureRewardedLoaded sonucu
  bool throwOnLoad = false;
  bool expireAfterLoad = false; // yükleme başarılı ama gösterimden önce süresi doldu
  String? errCode;
  bool hangPurchase = false;
  PurchaseOutcome purchaseOutcome = PurchaseOutcome.purchased;
  bool? restoreOwned = false;
  bool privacyRequired = false;
  final List<String> calls = <String>[];

  @override
  bool get available => isAvailable;
  @override
  bool get online => isOnline;
  @override
  bool get ownsRemoveAds => owns;
  @override
  bool get interstitialReady => interstitialOk;
  @override
  bool get rewardedReady => rewardedOk;
  @override
  bool get sdkReady => sdk;
  @override
  bool get rewardedLoading => rLoading;

  // v1.1 (docs/15 §4): önceden yükleme — sahte platform "hazırsa/yükleniyorsa yenisini başlatma" kuralını uygular
  bool sdk = true;
  bool rLoading = false;
  bool iLoading = false;
  int rStarts = 0;
  int iStarts = 0;
  @override
  PreloadState preloadRewarded() {
    calls.add('preloadR');
    if (!sdk) return PreloadState.skip;
    if (rewardedOk) return PreloadState.ready;
    if (rLoading) return PreloadState.loading;
    rLoading = true;
    rStarts++;
    return PreloadState.started;
  }

  @override
  PreloadState preloadInterstitial() {
    calls.add('preloadI');
    if (!sdk) return PreloadState.skip;
    if (interstitialOk) return PreloadState.ready;
    if (iLoading) return PreloadState.loading;
    iLoading = true;
    iStarts++;
    return PreloadState.started;
  }

  /// 1.1.4: yükleme bu kadar sürer (süre sınırından uzunsa platform zamanında false döner, reklam SONRADAN hazır olur: "geç yükleme").
  Duration? loadAfter;
  int lateLoads = 0;

  @override
  Future<bool> ensureRewardedLoaded({Duration timeout = kRewardedLoadTimeout}) async {
    calls.add('ensure');
    if (throwOnLoad) throw StateError('boom');
    if (hangLoad) return Completer<bool>().future;
    final Duration? la = loadAfter;
    if (la != null) {
      final Completer<bool> c = Completer<bool>();
      Timer(la, () {
        rewardedOk = true; // yükleme tamamlandı (belki süre dolduktan sonra)
        if (!c.isCompleted) {
          c.complete(true);
        } else {
          lateLoads++;
        }
      });
      if (la > timeout) {
        Timer(timeout, () {
          errCode = 'timeout';
          if (!c.isCompleted) c.complete(false);
        });
      }
      return c.future;
    }
    if (loadOk) {
      rewardedOk = !expireAfterLoad;
      return true;
    }
    errCode = '3';
    return false;
  }

  @override
  String? get lastRewardedErrorCode => errCode;
  @override
  String? get lastRewardedErrorMessage => errCode == null ? null : 'Ad failed to load';

  @override
  bool get interstitialOnScreen => onScreen;

  // ---- 1.1.4: SDK modeli — ad.show() bir kez çağrılınca geri ALINAMAZ (dispose iptal etmez). Reklam [presentAfter] sonra belirir,
  // [watchFor] boyunca ekranda kalır, sonra "kapandı" (true). [releaseInterstitial] yalnızca platformun bekleyen durumunu unutur;
  // gösterimi DURDURMAZ (gerçek SDK gibi) — reklam yine belirir. Testler bu yüzden "sonraki seviye show() bitmeden başlamaz"ı doğrular.
  @override
  void Function(bool onScreen)? onScreenChanged;
  @override
  void Function()? onLateAd;
  Duration? presentAfter;
  Duration watchFor = const Duration(seconds: 1);
  int presentedI = 0; // gerçekten ekrana gelen geçiş reklamı sayısı
  int presentedR = 0;
  int releasedI = 0;
  int releasedR = 0;
  Completer<bool>? _ic;
  Timer? _it;
  Duration? rewardedPresentAfter; // ödüllü: bu kadar sonra belirir, ödül verir, kapanır

  /// Ekrana gelme anında çağrılır (testler seviye ortası denetimi için).
  void Function()? onPresented;

  void _setScreen(bool on) {
    onScreen = on;
    onScreenChanged?.call(on);
  }

  @override
  void releaseInterstitial() {
    calls.add('releaseI');
    releasedI++;
    final Completer<bool>? c = _ic;
    if (c != null && !c.isCompleted) c.complete(false);
  }

  @override
  Future<bool> showInterstitial({bool Function()? allowed}) {
    calls.add('interstitial');
    if (allowed != null && !allowed()) {
      calls.add('blocked');
      return Future<bool>.value(false);
    }
    if (throwOnShow) throw StateError('show boom');
    final Duration? pa = presentAfter;
    if (pa != null) {
      final Completer<bool> c = _ic = Completer<bool>();
      _it = Timer(pa, () {
        presentedI++; // gerçek SDK: show() sonrası iptal edilemez
        _setScreen(true);
        onPresented?.call();
        Timer(watchFor, () {
          _setScreen(false);
          if (!c.isCompleted) c.complete(true);
        });
      });
      return c.future;
    }
    if (hangInterstitial) return (_ic = Completer<bool>()).future;
    if (failToShow) return Future<bool>.value(false);
    final Duration? d = showAfter;
    if (d != null) {
      final Completer<bool> c = _ic = Completer<bool>();
      if (appearsOnScreen) {
        presentedI++;
        _setScreen(true);
        onPresented?.call();
      }
      _it = Timer(d, () {
        if (onScreen) _setScreen(false);
        if (!c.isCompleted) c.complete(true);
      });
      return c.future;
    }
    return Future<bool>.value(true);
  }

  /// Test temizliği.
  void cancelTimers() => _it?.cancel();

  @override
  void releaseRewarded() {
    calls.add('releaseR');
    releasedR++;
  }

  @override
  Future<void> showRewarded(String placement, void Function() onReward, {bool Function()? allowed}) async {
    calls.add('rewarded:$placement');
    if (allowed != null && !allowed()) {
      calls.add('blockedR');
      errCode = 'cancelled';
      return;
    }
    final Duration? ra = rewardedPresentAfter;
    if (ra != null) {
      final Completer<void> c = Completer<void>();
      Timer(ra, () {
        presentedR++;
        _setScreen(true);
        onPresented?.call();
        if (rewardGiven) onReward();
        _setScreen(false);
        if (!c.isCompleted) c.complete();
      });
      return c.future;
    }
    if (hangRewardedShow) return Completer<void>().future;
    if (rewardGiven) onReward();
  }

  @override
  Future<PurchaseOutcome> purchaseRemoveAds() {
    calls.add('purchase');
    if (hangPurchase) return Completer<PurchaseOutcome>().future;
    return Future<PurchaseOutcome>.value(purchaseOutcome);
  }

  @override
  Future<bool?> restorePurchases() {
    calls.add('restore');
    return Future<bool?>.value(restoreOwned);
  }

  @override
  bool get privacyOptionsRequired => privacyRequired;
  @override
  Future<void> showPrivacyOptions() async {
    calls.add('privacy');
  }
}

