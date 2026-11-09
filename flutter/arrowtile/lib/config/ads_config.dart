// Arrowtile — ads_config.dart: AdMob kimlikleri ve uygulama sabitleri.
//
// YAYINDAN ÖNCE DEĞİŞTİR: aşağıdaki [releaseInterstitialId], [releaseRewardedId] ve [releaseBannerId] Google'ın resmi TEST
// kimlikleridir. AdMob hesabınızda uygulamayı ve 3 reklam birimini (geçiş, ödüllü, banner) oluşturup kendi kimliklerinizi
// buraya yazın (docs/10 §2). İmzalı AAB'yi CI üretiyorsa (release.yml) bu üç değer GitHub secrets'tan derleme kopyasına yazılır:
// ADMOB_INTERSTITIAL_ID, ADMOB_REWARDED_ID, ADMOB_BANNER_ID (docs/14).
// AdMob UYGULAMA kimliği (~ işaretli) ise Dart'ta değil, android/app/src/main/res/values/ads.xml içindedir.
// DEBUG ve PROFILE derlemeleri HER ZAMAN test kimliklerini kullanır (gerçek kimlikle geliştirme sırasında reklama
// tıklamak AdMob hesabının kapatılmasına yol açabilir).
import 'package:flutter/foundation.dart';

class AdsConfig {
  AdsConfig._();

  // Google resmi test reklam birimleri — kaynak: https://developers.google.com/admob/flutter/test-ads
  static const String testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String testBannerId = 'ca-app-pub-3940256099942544/6300978111'; // Android banner (uyarlanabilir boyutla da çalışır)

  // ↓↓↓ Yayından önce kendi kimliklerinizle değiştirin (yalnızca release derlemesinde kullanılır) ↓↓↓
  static const String releaseInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String releaseRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String releaseBannerId = 'ca-app-pub-3940256099942544/6300978111';

  /// `--dart-define=ADS_FORCE_INVALID=true` (yalnızca debug/profile): üç reklam birimi de geçersiz kimlikle istenir → "doldurulamadı"
  /// (no fill / invalid request). Onaylanmamış AdMob hesabındaki (sınırlı reklam gösterimi) durumu CI emülatöründe taklit eder (docs/18).
  static const bool adsForceInvalid = bool.fromEnvironment('ADS_FORCE_INVALID');
  static const String invalidAdUnitId = 'ca-app-pub-0000000000000000/0000000000';
  static bool get _forceInvalid => adsForceInvalid && !kReleaseMode;

  static String get interstitialId =>
      _forceInvalid ? invalidAdUnitId : (kReleaseMode ? releaseInterstitialId : testInterstitialId);
  static String get rewardedId => _forceInvalid ? invalidAdUnitId : (kReleaseMode ? releaseRewardedId : testRewardedId);
  static String get bannerId => _forceInvalid ? invalidAdUnitId : (kReleaseMode ? releaseBannerId : testBannerId);

  /// `--dart-define=AUTOPLAY_FROM=13` (yalnızca debug/profile): kayıt o seviyeye kadar açılmış ve geçiş reklamı sayacı "bir seviye
  /// sonra reklam zamanı" olarak tohumlanır; uygulama o seviyeyi kendiliğinden açıp oyunu çözer, seviye sonunda "Sonraki"ne basar
  /// (donma testi, docs/18). 0 = kapalı. Logcat'te `AUTOPLAY: level N opened` satırları yazılır.
  static const int autoPlayFrom = int.fromEnvironment('AUTOPLAY_FROM');

  /// Birim testlerinde otomatik oynatmayı açar (yayın derlemesinde hiçbir etkisi yoktur).
  static bool autoPlayTestOverride = false;
  static bool get autoPlayOn => !kReleaseMode && (autoPlayFrom > 0 || autoPlayTestOverride);

  /// true iken release derlemesinde hâlâ Google test kimlikleri kullanılıyordur (gelir getirmez).
  static bool get usingTestIdsInRelease =>
      kReleaseMode &&
      (releaseInterstitialId == testInterstitialId || releaseRewardedId == testRewardedId || releaseBannerId == testBannerId);

  // UMP onay formunu AEA dışında test etmek için (yalnızca debug'da kullanılır). Uygulamayı bir kez çalıştırın,
  // Logcat'te "Use new ConsentDebugSettings.Builder().addTestDeviceHashedId(...)" satırındaki kimliği yazın.
  static const String umpTestDeviceId = '';
  /// `--dart-define=UMP_DEBUG_EEA=true` ile (yalnızca debug derlemede) UMP'ye "AEA'dayım" dedirtir; CI'daki EEA duman testi
  /// (docs/16) kullanır. Varsayılan false: normal/yayın derlemelerinde hiçbir hata ayıklama ayarı uygulanmaz.
  static const bool umpDebugGeographyEea = bool.fromEnvironment('UMP_DEBUG_EEA');

  /// Play Billing ürün kimliği (tüketilmeyen).
  static const String removeAdsProductId = 'remove_ads';
}

class AppInfo {
  AppInfo._();
  static const String version = '1.1.1'; // pubspec.yaml version: 1.1.1+5 ile aynı
  static const String supportEmail = 'nilkaren.tuncay.demir@gmail.com';
  static const String privacyUpdated = '2026-11-09';
  // Herkese açık gizlilik politikası adresi (Play Console'a girilen adresle aynı). GitHub Pages: .github/workflows/pages.yml
  static const String privacyPolicyUrl = 'https://ttuncaydemirr-beep.github.io/Arrowtile/privacy.html';
}
