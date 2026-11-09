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
