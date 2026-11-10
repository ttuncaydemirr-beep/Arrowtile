// Arrowtile — consent_gate.dart: UMP onay formunun NE ZAMAN gösterilebileceğine karar veren saf mantık (test edilebilir).
// Google'ın belgelenmiş deseni: onay bilgisi güncellemesi her uygulama AÇILIŞINDA bir kez; form yalnızca gerekiyorsa ve
// yalnızca ön plandaki etkinlikten gösterilir; uygulama öne her gelişte kendiliğinden yeniden gösterilmez.
// Ek kural (docs/16): form oyun sırasında da açılmaz — oyun ekranı açıkken ya da uygulama arka plandayken gösterilmek
// istenen form "bekliyor" olur; uygulama öne gelince / oyundan çıkılınca en çok BİR kez gösterilir. (Kapalı testte form
// yavaş yüklenip oyunun üstüne çıkıyor, dönüşte yerel pencere dokunuşları yutuyordu.)
class ConsentFormGate {
  bool _started = false;
  bool _updating = false;
  bool _busy = false;
  bool _pending = false;

  /// Açılıştaki onay bilgisi güncellemesi başlatılabilir mi? Yalnızca ilk çağrıda true (yeniden çağrılar yok sayılır).
  bool beginSession() {
    if (_started) return false;
    _started = true;
    _updating = true;
    return true;
  }

  /// Onay bilgisi güncellemesi hata ile bitti (form istenmeyecek).
  void updateFailed() => _updating = false;

  /// Form (gerekiyorsa) şimdi yüklenip gösterilebilir mi? [foreground]: uygulama ön planda (resumed) mı;
  /// [interruptible]: oyuncu şu an kesilebilir mi (oyun ekranında değil). true dönerse form meşgul sayılır;
  /// bittiğinde [finished] çağrılmalıdır.
  bool tryShow({required bool foreground, bool interruptible = true}) {
    _updating = false;
    if (_busy) return false;
    if (!foreground || !interruptible) {
      _pending = true;
      return false;
    }
    _pending = false;
    _busy = true;
    return true;
  }

  /// Öne gelindi ya da oyundan çıkıldı: ertelenmiş bir form varsa şimdi gösterilebilir mi (yeni form TETİKLENMEZ).
  bool retryPending({required bool foreground, bool interruptible = true}) =>
      _pending && tryShow(foreground: foreground, interruptible: interruptible);

  /// Form yükleme/gösterme bitti (başarılı, hatalı ya da gerekmiyordu).
  void finished() => _busy = false;

  bool get pending => _pending;
  bool get busy => _busy;

  /// Onay akışı sürüyor mu (bilgi güncellemesi bekleniyor ya da form yükleniyor/gösteriliyor)? Oyun başlatma bunu kısa
  /// süre bekler, böylece form oyunun üstüne çıkmaz.
  bool get active => _updating || _busy;
}

/// Firebase Analytics onay sinyalleri (Consent Mode v2): analytics_storage / ad_storage / ad_user_data / ad_personalization.
/// Varsayılan HEPSİ reddedilmiştir (AndroidManifest varsayılanları da `false`); yalnızca UMP sonucu izin veriyorsa açılır.
class TelemetryConsent {
  final bool analyticsStorage;
  final bool adStorage;
  final bool adUserData;
  final bool adPersonalization;
  const TelemetryConsent({
    this.analyticsStorage = false,
    this.adStorage = false,
    this.adUserData = false,
    this.adPersonalization = false,
  });

  static const TelemetryConsent denied = TelemetryConsent();

  @override
  bool operator ==(Object other) =>
      other is TelemetryConsent &&
      other.analyticsStorage == analyticsStorage &&
      other.adStorage == adStorage &&
      other.adUserData == adUserData &&
      other.adPersonalization == adPersonalization;

  @override
  int get hashCode => Object.hash(analyticsStorage, adStorage, adUserData, adPersonalization);

  @override
  String toString() =>
      'TelemetryConsent(analytics=$analyticsStorage, adStorage=$adStorage, adUserData=$adUserData, adPersonalization=$adPersonalization)';
}

/// UMP sonucundan Firebase onay sinyallerini çıkarır (saf mantık, test edilebilir).
///  - [umpStatus]: `ConsentInformation.getConsentStatus()` adı: notRequired | required | obtained | unknown.
///  - [gdprApplies] / [purposeConsents]: UMP'nin varsayılan SharedPreferences'a yazdığı IABTCF_gdprApplies ve
///    IABTCF_PurposeConsents (her amaç için '0'/'1', 1. amaç = indeks 0). Yoksa null.
/// Kurallar: onay gerekmiyorsa (AEA/BK/İsviçre dışı) analiz açık; onay alındıysa (GDPR kapsamında) TCF amaçlarına göre
/// (analytics_storage/ad_storage = amaç 1; ad_user_data = amaç 1 ve 7); onay bekleniyor/bilinmiyorsa HEPSİ kapalı.
/// ad_personalization HER ZAMAN kapalıdır: Firebase'i reklam kişiselleştirme için kullanmıyoruz (Google sinyalleri kapalı).
TelemetryConsent deriveTelemetryConsent({required String umpStatus, bool gdprApplies = false, String? purposeConsents}) {
  switch (umpStatus) {
    case 'notRequired':
      return const TelemetryConsent(analyticsStorage: true, adStorage: true, adUserData: true);
    case 'obtained':
      if (!gdprApplies) {
        // GDPR dışı (ör. ABD eyalet mesajı): onay gerekli değildi, ama form gösterildi
        return const TelemetryConsent(analyticsStorage: true, adStorage: true, adUserData: true);
      }
      final String p = purposeConsents ?? '';
      bool purpose(int n) => p.length >= n && p[n - 1] == '1';
      final bool storage = purpose(1);
      return TelemetryConsent(analyticsStorage: storage, adStorage: storage, adUserData: storage && purpose(7));
    default:
      return TelemetryConsent.denied;
  }
}
