// Testler için sahte reklam platformu (ads_rules_test + seviye geçişi donma testleri; docs/18). Gerçek AdMob/Billing çağrılmaz.
import 'dart:async';

import 'package:arrowtile/core/ads_rules.dart';

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

  @override
  Future<bool> showInterstitial() {
    calls.add('interstitial');
    if (throwOnShow) throw StateError('show boom');
    if (hangInterstitial) return Completer<bool>().future;
    if (failToShow) return Future<bool>.value(false);
    final Duration? d = showAfter;
    if (d != null) {
      if (appearsOnScreen) onScreen = true;
      return Future<bool>.delayed(d, () {
        onScreen = false;
        return true;
      });
    }
    return Future<bool>.value(true);
  }

  @override
  Future<void> showRewarded(String placement, void Function() onReward) async {
    calls.add('rewarded:$placement');
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

