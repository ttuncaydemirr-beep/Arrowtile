# 16 - Arka plandan dönünce oyunun donması (kapalı test, Avusturya)

Bildirim: Avusturya'daki test kullanıcısı (Almanca arayüz, yayın derlemesi, gerçek AdMob kimlikleri): "Başka bir şey açıp oyuna dönünce donuyor."
Ekran görüntüsü: "Pausiert" penceresi (Weiter / Neustart / Zur Karte) KOYU, BOŞ bir arka planın üstünde; tahta görünmüyor, düğmeler tepki vermiyor; uygulama zorla kapatılmış.

Web referansı (game/js/main.js:1356): `visibilitychange` → sayfa gizlenirse ve oyun açık, `busy` değil, pencere yoksa `btn-pause.click()`. Dönüşte pencere görünür ve tamamen yanıt verir, tahta çizili kalır.

## İlerleme günlüğü
- Adım 1: kod incelemesi (game_screen.dart, app.dart, app_controller.dart, ads_service.dart, ads_rules.dart, rewarded_flow.dart).
- Adım 2: yeniden üretim için emülatör testi yazıldı (`.github/scripts/smoke-resume.sh`, `ui.py`): oyun aç → HOME → yeniden aç → "Paused" penceresi + 3 düğme → Resume → pencere kapandı, tahta çiziliyor; ayrıca EEA (UMP) hata ayıklama coğrafyalı debug APK ile ikinci geçiş (`UMP_DEBUG_EEA`).
