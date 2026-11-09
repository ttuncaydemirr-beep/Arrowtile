# 16 - Arka plandan dönünce oyunun donması (kapalı test, Avusturya)

Bildirim: Avusturya'daki test kullanıcısı (Almanca arayüz, yayın derlemesi, gerçek AdMob kimlikleri): "Başka bir şey açıp oyuna dönünce donuyor."
Ekran görüntüsü: "Pausiert" penceresi (Weiter / Neustart / Zur Karte) KOYU, BOŞ bir arka planın üstünde; tahta görünmüyor, düğmeler tepki vermiyor; uygulama zorla kapatılmış.

Web referansı (game/js/main.js:1356): `visibilitychange` → sayfa gizlenirse ve oyun açık, `busy` değil, pencere yoksa `btn-pause.click()`. Dönüşte pencere görünür ve tamamen yanıt verir, tahta çizili kalır.

## İlerleme günlüğü
- Adım 1: kod incelemesi (game_screen.dart, app.dart, app_controller.dart, ads_service.dart, ads_rules.dart, rewarded_flow.dart).
- Adım 2: yeniden üretim için emülatör testi yazıldı (`.github/scripts/smoke-resume.sh`, `ui.py`): oyun aç → HOME → yeniden aç → "Paused" penceresi + 3 düğme → Resume → pencere kapandı, tahta çiziliyor; ayrıca EEA (UMP) hata ayıklama coğrafyalı debug APK ile ikinci geçiş (`UMP_DEBUG_EEA`).

## Kod incelemesi bulguları (değişiklik öncesi)
1. `game_screen.dart` `didChangeAppLifecycleState`: `hidden`/`paused` olunca `_openPause()` ARKA PLANDA çağrılıyordu. Android'de
   uygulama arka plandayken çerçeveler durdurulur ve yüzey yok edilir; o sırada `showDialog` ile rota eklemek, dönüşte
   pencerenin yarım kalmış bir geçişle/boş yüzeyle çizilmesine açıktı. Ayrıca `hidden` ve `paused` art arda gelir: tek bir
   `_modalOpen` denetimine güveniliyordu, kendi bayrağı yoktu (iki kez açılma riski).
2. Dönüşte (`resumed`) GameScreen hiçbir şey yapmıyordu: tahta yeniden çizim (`_repaint`) tetiklenmiyor, ticker
   canlandırılmıyordu.
3. `ads_service.dart` `gatherConsent`: yeniden giriş koruması yoktu ve `loadAndShowConsentFormIfRequired` ön plan denetimi
   yapmadan çağrılıyordu. Açılışta form ağdan yüklenirken kullanıcı uygulamadan çıkarsa form arka plandaki etkinliğe
   gösterilmeye çalışılabilir (Google'ın "yalnızca ön plandaki etkinlikten" kuralına aykırı).
4. `app_controller.dart` `onAppResumed` → `platform.onResume()`: formu yeniden tetiklemiyor (yalnızca `canRequestAds`
   sorgusu), takılabilecek `await` yok (`refreshOnline` 3 sn zaman aşımlı, `billing.restore` 20 sn zaman aşımlı ve beklenmiyor).
5. Girdi engelleyicileri: `rewarded_flow` yükleme penceresi her yolda tek `pop` ile kapanıyor; `rewardBusy`, `_showing`
   (5 dk bekçi) sıfırlanıyor. `AbsorbPointer` kullanılmıyor; `IgnorePointer` yalnızca süs katmanlarında.

## Yeniden üretim (CI emülatörü, 1. tur — kod DEĞİŞMEDEN)
- Yayın APK'sı (`smoke`): normal emülatörde (ABD coğrafyası, onay formu yok) geri dönüş testi GEÇTİ — duraklatma penceresi tek,
  Resume kapatıyor, tahta çiziliyor. Yani yalnızca "HOME → geri dön" mantığı tek başına donmayı üretmiyor.
- EEA debug APK'sı (`smoke-eea`, `UMP_DEBUG_EEA=true`): BAŞARISIZ. Oyun açıldı, HOME + yeniden açış sonrası ekranda
  duraklatma penceresi YERİNE UMP onay formu ("Welcome to Publisher Test Ads … Consent / Do not consent / Manage options")
  vardı. Form menüde değil, oyun başladıktan SONRA (ağdan geç yüklendiği için) oyunun üstüne çıktı. `uiautomator dump`
  yalnızca form penceresinin düğümlerini gördü; Flutter penceresi altında kalmıştı.
- Sonuç (bulgu 3 doğrulandı): onay formu, oyuncu çoktan oyundayken ve/veya uygulama arka plandayken gösterilmeye çalışılıyor.
  Avusturya'daki (AEA) kullanıcıda form yerel bir pencere olarak Flutter'ın üstüne biner: altta duraklatma penceresi
  ("Pausiert") kararmış bir katmanın arkasında görünür, dokunuşlar yerel pencereye gider → "düğmeler yanıt vermiyor, tahta yok".
