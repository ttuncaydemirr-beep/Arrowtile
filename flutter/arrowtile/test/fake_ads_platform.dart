// Testler için sahte reklam platformu (ads_rules_test + seviye geçişi donma testleri; docs/18). Gerçek AdMob/Billing çağrılmaz.
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

  @override
  Future<bool> ensureRewardedLoaded({Duration timeout = kRewardedLoadTimeout}) async {
    calls.add('ensure');
    if (throwOnLoad) throw StateError('boom');
    if (hangLoad) return Completer<bool>().future;
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

  // ---- 1.1.3: SDK modeli — ad.show() bir kez çağrılınca geri alınamaz; ancak dispose (abandon) edilen reklam gösterilemez
  @override
  void Function(bool onScreen)? onScreenChanged;
  @override
  void Function()? onLateAd;
  Duration? presentAfter; // reklam show() çağrısından bu kadar sonra belirir (bırakılmadıysa); showInterstitial süre sınırı kendi başına dolar
  int presentedI = 0; // gerçekten ekrana gelen geçiş reklamı sayısı
  int presentedR = 0;
  bool abandonedI = false;
  bool abandonedR = false;
  Completer<bool>? _ic;
  Timer? _it;
  Duration rewardedWatchdog = const Duration(seconds: 3);
  Duration? rewardedPresentAfter; // ödüllü: bu kadar sonra belirir; platform 3 sn'de show_timeout ile bırakır

  void _setScreen(bool on) {
    onScreen = on;
    onScreenChanged?.call(on);
  }

  @override
  void abandonInterstitial() {
    calls.add('abandonI');
    abandonedI = true;
    _it?.cancel();
    if (onScreen) _setScreen(false);
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
    abandonedI = false;
    final Duration? pa = presentAfter;
    if (pa != null) {
      final Completer<bool> c = _ic = Completer<bool>();
      _it = Timer(pa, () {
        if (abandonedI) return; // dispose edilmiş: SDK gösteremez
        presentedI++;
        _setScreen(true);
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
      }
      _it = Timer(d, () {
        if (onScreen) _setScreen(false);
        if (!c.isCompleted) c.complete(true);
      });
      return c.future;
    }
    return Future<bool>.value(true);
  }

  @override
  void abandonRewarded() {
    calls.add('abandonR');
    abandonedR = true;
  }

  @override
  Future<void> showRewarded(String placement, void Function() onReward, {bool Function()? allowed}) async {
    calls.add('rewarded:$placement');
    if (allowed != null && !allowed()) {
      calls.add('blockedR');
      errCode = 'cancelled';
      return;
    }
    abandonedR = false;
    final Duration? ra = rewardedPresentAfter;
    if (ra != null) {
      final Completer<void> c = Completer<void>();
      Timer(ra, () {
        if (abandonedR) return;
        presentedR++;
        _setScreen(true);
        if (rewardGiven) onReward();
        _setScreen(false);
        if (!c.isCompleted) c.complete();
      });
      Timer(rewardedWatchdog, () {
        if (presentedR > 0 || c.isCompleted) return; // platformun 3 sn bekçisi
        abandonedR = true;
        calls.add('abandonR');
        errCode = 'show_timeout';
        c.complete();
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

