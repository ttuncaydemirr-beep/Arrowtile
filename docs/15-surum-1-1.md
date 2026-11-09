# Arrowtile 1.1.0 — kapalı test geri bildirimleri (kullanıcı kararları, 09.11.2026)

Süreç kuralı: önce **web önizleme** (game/) → kullanıcı dener ve onaylar → aynı değişiklik **Flutter**'a (flutter/arrowtile/) taşınır → CI yeşil → versionCode +1 → kapalı teste yeni sürüm.
Tüm yeni metinler 4 dilde (tr/en/de/ar), Arapça RTL.

## 1. "Ok sesi dışında fazladan bir ses var" — ses EKLENMEYECEK
Testçiler oka dokununca ok kayma sesinin yanında **istenmeyen ek bir ses** duyuyor. Müzik eklenmeyecek.
- Oka dokunma anında hangi seslerin çaldığını (web ve Flutter) tespit et; ok hareketi başına **yalnızca tek** hareket sesi (çıkış: slideOut, çarpma: bump) çalsın. Ok dokunuşunda ayrıca `tap`/`button` gibi ikinci bir ses çalıyorsa kaldır.
- Flutter'da AudioPool/oynatıcı yeniden kullanımı nedeniyle çift çalma, gecikmeli yankı veya yanlış dosya çalma olasılığını incele.
- Raporla: hangi ses, hangi anda, neden; ne değişti.

## 2. Reklam kuralı DEĞİŞMEZ
Geçiş reklamı: seviye 1–12 reklamsız, sonra en erken 3 tamamlanan seviyede bir, en az 3 dk ara. Dokunma.
(Testçilerde reklam görülmemesinin sebebi AdMob hesabının/uygulamanın henüz onaylanmamış olması; kod hatası değil.)

## 3. Banner reklam: yalnızca Ana menü ve Harita ekranları
- Uyarlanabilir (adaptive) banner, ekranın altında, güvenli alanın üstünde. Oyun ekranında, seviye sonunda, mağazada, ayarlarda, günlük bulmacada **yok**.
- "Reklamları kaldır" satın alındıysa banner da gösterilmez.
- Reklam yüklenmezse yer kaplamaz (boşluk bırakmaz); içerik banner yüksekliği kadar yukarı itilir, hiçbir düğme banner altında kalmaz.
- Yeni AdMob birimi: `ADMOB_BANNER_ID` (debug/test: Google resmi banner test kimliği). release.yml'e 8. secret olarak eklenir ve biçim denetimine girer; web önizlemede banner yerine kesikli çerçeveli "Reklam alanı" yer tutucu.
- ads_rules testleri: banner hangi ekranlarda görünür, adFree'de görünmez.

## 4. Reklam açılış gecikmesi / takılma
- Ödüllü reklam önceden yüklensin: oyun ekranı açılınca ve can 1'e düşünce yükleme başlasın (zaten yükleniyorsa tekrar başlatma). Geçiş reklamı seviye bitmeden (son okların çıkışında) hazır olsun.
- Reklam gösterilirken oyun animasyon döngüsü (ticker) ve ses duraklasın; reklam kapanınca devam etsin.
- "Reklam yükleniyor…" kaplaması yalnızca gerçekten bekleniyorsa ve 300 ms'den uzun sürerse görünsün.

## 5. Zorluk döngüsü seviye bazında + 10 seviyelik bölümler + 5.000 seviye
- **Bölüm = 10 seviye.** Her bölümde sıra: seviye 1-2-3 **Kolay**, 4-5-6 **Orta**, 7-8 **Zor**, 9-10 **Aşırı zor**. (Bölüm 1'de öğretici seviyeler 1–3 kolay olarak kalır.)
- Tahta boyutu bölüm bölüm büyür (bölüm içinde sabit ya da çok hafif artış); en büyük boyuta (≈22x31) ulaşınca orada kalır. Küçük ekranda hücre ≥16 px kuralı geçerli.
- Kademe bantları (doluluk / başta çıkabilen / derinlik / kıvrımlı oran) docs/09'daki gibi; doğrulayıcı her seviyenin kendi kademe bandında olduğunu ve aynı bölüm içinde Kolay < Orta < Zor < Aşırı zor olduğunu denetler; aynı kademe bölümden bölüme (tahta büyürken) gevşek monoton artar.
- **Toplam 5.000 seviye** (500 bölüm). Seviye 5.000'den sonra oyun sonsuz devam eder (aynı kural).
  - Uygulama boyutu için: ilk N seviye (ör. 200) pakette hazır; geri kalanı oyun içinde seviye numarası tohumlu belirlenimli üretici ile. Herkes aynı seviyeyi görür.
  - **5.000 seviyenin tamamı CI'da üretilip doğrulanır** (çözülebilirlik, kademe bandı, süre). Her seviyenin özeti (ör. FNV hash) tek bir dosyada saklanır ve Flutter altın testi rastgele örneklenmiş seviyelerde Dart üreticisinin aynı özeti verdiğini denetler. Üretim süresi raporlanır; arka planda önceden üretim (mevcut mekanizma) korunur.
- Bölüm adları: mevcut 18 ad döngüyle + Roma rakamı (ör. "Mağara II"), 4 dilde. Harita 500 bölümü akıcı göstermeli (tembel liste, mevcut bölüme kaydırarak açılış).
- Ekonomi: seviye jeton çarpanı kademeye göre aynı (Kolay ×1, Orta ×1,5, Zor ×2, Aşırı zor ×3). Bölüm bonusu artık tek: bölüm tamamlanınca 150 jeton. Testlerdeki beklentiler güncellenir.
- Kayıt: seviye numaraları korunur; içerik değişse de kazanılmış yıldız/jeton silinmez (yayın öncesi olduğu için kabul).
- Günlük bulmaca değişmez.

## 6. Ertelenen küçük işler
- Gizlilik sayfası + oyun içi gizlilik: Google'ın iş ortağı veri kullanımı bağlantısı (https://policies.google.com/technologies/partner-sites) ve "Bu oyun 13 yaş altındaki çocuklara yönelik değildir." cümlesi (4 dil). dist/privacy-site de güncellenir.
- Mağaza metinleri (docs/07 + i18n store.*): "216 seviye" → "5.000 seviye", "4 kat" → "5 kat" (4 dil, karakter sınırları).
- (Flutter sürümü bittikten sonra) mağaza ekran görüntüleri gerçek Flutter uygulamasından emülatörde yeniden çekilir.

## İlerleme
- **Web 1/4 — üretici ve seviye yapısı (§5) — tamam.** `levelgen.js`: `specFor(id)` saf fonksiyon (bölüm = 10 seviye, kademe `CYCLE[(id-1)%10]`, tahta yalnızca bölüme bağlı: bölüm 1 = 7x9 … bölüm 21+ = 22x31, tamsayı formülü; derinlik penceresi E = 6,3 + 0,0677·hücre katı), `seedFor`, `levelJob/makeLevel` (hazır paket ve oyun içi üretim aynı yol), `canon/levelHash` (FNV-1a 32). Taşınabilirlik: `Math.pow` → `v·√v`, kararlı sıralama (indeks eşitlik bozucu). Onarım parametreleri hafifletildi (effort 12 / passes 6 / cycles 2): Aşırı zor 22x31 tur başına 280 → 60 ms, kabul oranı aynı. `tools/generate-levels.js` ilk 200'ü `makeLevel` ile üretir; `tools/validate-levels.js` yeniden yazıldı (bölüm 1–12 + örneklenmiş bölümler 13–500); `tools/level-checks.js` ortak denetim.
- **Web 2/4 — ses, banner, reklam, harita, ekonomi, metinler — tamam.** §1: web'de ok dokunuşunda `SFX.tap()` + `slideOut/bump` birlikte çalıyordu (ikinci "tık" = istenmeyen ek ses); `tapArrow` içinden `tap` kaldırıldı (tap yalnızca "önce seç" seçiminde). Flutter `game_screen.dart` `_tapArrow` aynı deseni uyguluyor (`sfx.tap()` + `slideOut/bump`), Flutter'a taşınacak. §3: `Monetization.bannerVisible(ekran)` (yalnızca menu/map, adFree'de yok) + kesikli çerçeveli "Reklam alanı" yer tutucusu. §4: `preloadRewarded` (oyun açılınca, can 1'de), `preloadInterstitial` (son 2 ok), ortak yükleme, `setAdListener` ile döngü + ses duraklatma, yükleniyor kaplaması 300 ms eşikli. §5: tembel harita (500 bölüm), bölüm adı + Roma rakamı, düğümde kademe noktası, tek bölüm bonusu 150. §6: gizlilik (iş ortağı bağlantısı, 13 yaş cümlesi), mağaza metinleri (5.000 seviye, 5 kat), dist/privacy-site, docs/07, ARB yeniden üretildi.
- **Web 3/4 — doğrulama — tamam.** `tools/verify-5000.js`: 5.000 seviye, 2 işçi, 6,8 dk; hata 0, bölüm içi sıra ihlali 0; Aşırı zor 22x31 ort. 562 ms (p95 1,7 sn, en çok 3,5 sn). `tools/level-hashes.json` yazıldı. validate-levels, validate-i18n, test-ads (92), test-daily (14), e2e (366), qa (157) geçti.

