# Arrowtile — Durum ve devir notu

> **Yeni sohbet için:** Bu dosyayı baştan sona oku, sonra "Sıradaki işler" listesindeki ilk açık maddeden devam et.
> Her büyük adımdan sonra bu dosyayı güncelle (tarih + ne değişti). Son güncelleme: **28 Kasım 2026** (1.2.4 kod tarafı bitti).

## 1. Özet

| | |
|---|---|
| Uygulama | **Arrowtile: Ok Bulmacası** — `com.arrowtile.puzzle` (Flutter; web önizleme `game/`) |
| Geliştirici | **Demir Games Studio** (Play Console kişisel hesap, %15 hizmet ücreti grubu) |
| Üretimdeki sürüm | **1.2.3 (versionCode 15)** — 24 Kasım 2026'dan beri üretimde, %100, 177 ülke + dünyanın geri kalanı |
| Kapalı test (Alpha) | 1.2.3 (15); 35 adres davetli, test programı açık kalıyor (yeni sürümler önce oraya) |
| Dahili test | 1.2.3 |
| Diller | tr, en, de, ar (Arapça RTL). 1.3.0'da es, pt, id, ru eklenecek |
| Gizlilik | https://ttuncaydemirr-beep.github.io/privacy/arrowtile/ (stüdyo sitesi deposu ayrı; tarih 19 Kasım 2026) |
| Destek e-postası | nilkaren.tuncay.demir@gmail.com |
| AdMob | Uygulama **Hazır**, Google Play'e bağlı, app-ads.txt doğrulandı (25 Kasım). 3 reklam birimi (banner, geçiş, ödüllü). EEA onay mesajı yayında (Rıza ver / Rıza verme / Seçenekleri yönet; en, de, tr) |
| İçerik derecelendirmesi | PEGI 3; hedef kitle 13+ |
| Satın alma | `remove_ads` 2,99 USD (Play Billing 9.1.0, `in_app_purchase_android` 0.5.5) |

Sahip yalnızca telefondan çalışıyor (iPhone + bir Android). Tüm konuşma **Türkçe**. Para kazanmak ana hedef.

## 2. Kalıcı kurallar ve kararlar

- **Oyun kuralları:** seviye ortasında reklam yok; geçiş reklamı en erken 3 tamamlanan seviyede bir ve ≥3 dk arayla; **ilk 12 seviye reklamsız**; banner yalnızca **menü ve harita**da (56 dp sabit yuva, butonlarla ≥16 dp boşluk); süre sınırı yok; 3 can; geri alma yok.
- **Banner deneyi (Remote Config):** `banner_menu_enabled`, `banner_map_enabled`, `banner_holdout_pct` (varsayılan 50). Yani oyuncuların **yarısı banner görmüyor**. Karar tarihi **~8 Aralık 2026**: banner grubunda belirgin kayıp yoksa holdout'u 0 yap (herkese banner). Ayrıntı: docs/27. (Firebase konsolunda parametrelerin tanımlanıp tanımlanmadığı doğrulanmadı — yoksa koddaki varsayılanlar geçerli.)
- **E-posta kuralı:** yalnızca ilk yayında e-posta (24 Kasım'da 35 kişiye tek tek gönderildi); sonra **5 güncellemede bir**. Asla toplu/BCC değil, herkese ayrı e-posta.
- **Yorumlar:** yanıtla, kısa/samimi, kullanıcının dilinde, imza "– Demir Games Studio"; puan isteme, ödül vaat etme.
- **Ekip:** ajanlar Sonnet; en fazla 3 Opus. Her işten önce sahibe iş + büyüklük söyle, onay al.
- **Görseller:** varsayılan renk/font yok; renkler yalnızca `design/colors.json`'dan (CI kontrol ediyor).
- **Reklam güvenliği:** sahip/aile/test kullanıcıları reklamlara tıklamaz (uyarıldılar). Sahibin Android'i AdMob'da test cihazı ("Tuncay Android").

## 3. Yayın akışı (nasıl yüklenir)

1. Değişiklik bir dalda yapılır → `ci.yml` 13/13 yeşil olmalı (emülatör "resume" testi ara sıra kararsız; tekrar çalıştır).
2. `main`'e fast-forward (ruleset: main silinemez, force-push yok).
3. `release.yml` dispatch, `inputs[track]=internal+alpha` → **`production` ortamı sahibin onayını ister** (GitHub Actions → Review deployments → Approve). İç teste yükler, `tools/play_promote.py` kapalı teste (alpha) yükseltir; Play değişiklikleri **otomatik incelemeye** gönderiyor.
4. Üretime: sahip Play Console'da kapalı testteki sürümü **Sürümü yükselt → Üretim** ile çıkarır (servis hesabının üretim izni **yok**, bilinçli). Güncellemelerde **%20 kademeli yayın**.
5. Mağaza görselleri: `store/` + `play-listing.yml` (`dry_run` önce, sonra gerçek; yine production onayı).
- Gizli anahtarlar GitHub secrets'ta (depo düzeyi). Python bağımlılıkları `tools/requirements-play.txt` (hash'li).

## 4. Hesaplar ve anahtarlar

**Google Cloud `arrowtile-239be` → `play-upload@…` anahtarları (hepsi kullanımda, SİLME):**

| Key ID başı | Oluşturma | Kullanan |
|---|---|---|
| 3ab27e06 | 11–12 Kas | Arrowtile + Miyo |
| 2533e2e8 | 15 Kas | Bereket Çiftliği |
| f0bb7da9 | 16–17 Kas | Play Paneli |
| b32082eb | 22 Kas | Mozaik Mantık |

Zarfla (`zarfla-37da9`) ve Tidy Nook (`demir-games-play`) ayrı projeler; LiD Koçu otomatik yükleme kullanmıyor. Telefondaki tüm JSON anahtar dosyaları 25 Kasım'da silindi.

**Yükleme (upload) anahtarı:** Play'deki kayıtlı yükleme sertifikası SHA-1 `2C:A3:00:D9:23:EC:91:42:B7:B4:C6:EB:07:33:37:77:5C:79:16:10`. Bu keystore **yalnızca GitHub secret'ında** var, yedeği yok. Sahibin elindeki `arrowtile-yukleme-anahtari.zip` (SHA-1 `69:A3:D7:…:BF:8F`) **eski ve kullanılmıyor**. → Plan: 1.2.4'ten sonra kontrollü yükleme anahtarı sıfırlama (aşağıda).

**GitHub güvenlik ayarları (yapıldı):** `production` ortamı (yalnız main, onaylayıcı sahip, admin bypass kapalı); ruleset "main koruması"; Dependabot alerts + security updates + grouped; private vulnerability reporting; push protection; Pages kapalı.

**Hesap güvenliği:** Google ve GitHub'da 2FA açık. Play Console: geliştirici adı, web sitesi (stüdyo sitesi), **tacir** durumu (6 uygulamada beyan), gizlilik adresi tamam.

## 5. Sıradaki işler (sırayla)

- [ ] **İlk hafta takibi** (24 Kas – 1 Ara): yükleme, çökme/ANR, reklam geliri, yorumlar. Sahip "rapor" der.
- [ ] **1.2.4** (küçük-orta) — Claude Code'da, dal `claude/upbeat-turing-najevq`. **Kod + metinler bitti; sahip onayıyla main'e birleştirildi (28 Kasım 2026, e23c34e, main CI 13/13, Deneme APK güncel).** **Yayın akışı çalıştı (28 Kasım 2026, release #17, sahip onaylı):** versionCode 16 (1.2.4) iç teste yüklendi ve kapalı teste (alpha) yükseltildi, Play otomatik incelemeye gönderdi. Flutter 3.50.1, AAB sembolleri 4 kütüphane × 3 ABI tamam. Sırada: inceleme → sahip telefonda satın alma denemesi → Play Console'dan %20 üretim → v1.2.4 etiketi.
  - [x] CI: Flutter **3.50.1**'e sabit (ci + release, `FLUTTER_VERSION`), release'te önbellek kapalı; Dependabot `cooldown` 7 gün.
  - [x] Satın alma: iptalde 90 sn kilit kalktı (eklentinin ürün adı boş `canceled`/`error` öğesi işleniyor); iade: reklamsızlık art arda ≥2 "yok" yanıtı + ilk yanıttan 24 saat sonra kalkar (`ads.refundMiss/refundMissAt`, yalnızca sayaç varken kayda yazılır; 1.2.3 kaydı geçiş testi var). Testler: `billing_cancel_test`, `refund_revoke_test`. **Telefonda denenmeli** (lisans testçisiyle vazgeç / satın al / iade + 24 sa; adımlar Code oturumunda verildi).
  - [x] Yedekleme yalnızca `FlutterSharedPreferences.xml` (eskiden admob/UMP/Firebase dahil 8 dosya). Emülatörde yedek→sil→geri yükle testi CI'da (`.github/scripts/smoke-backup.sh`).
  - [x] Onay cümlesi: Sohbet'in 4 dil metni oyuna kondu (`game/js/i18n.js` `privacy.p_analytics` son kısmı → ARB; sahip talimatıyla Code yaptı). Gizlilik tarihi 2026-11-28 (`privacy.js` UPDATED = `AppInfo.privacyUpdated`). Taşma testi `privacy_layout_test` (de/ar/tr/en, 320x568 ve 360x640, yazı 1.3×). Stüdyo sitesindeki politika güncellemesi Sohbet'te (tarih 2026-11-28 ile aynı olmalı).
  - [x] Native debug sembolleri: AAB'de libflutter/libapp/libdartjni/libdatastore için `.sym` zaten var (Flutter 3.50 kendiliğinden). Ayar değişmedi; CI + release'e denetim eklendi (`tools/check-aab-symbols.py`). Play uyarısının tam metni sahipten bekleniyor; 1.2.4'te uyarı sürerse yeniden bakılacak.
  - [x] Dependabot #4–#8 (setup-java 6.3.0, setup-node 7.1.0, download-artifact 8.0.2, checkout 7.0.1, upload-artifact 7.0.2) uygulandı: SHA'lar etiketlerle doğrulandı, girdiler uyumlu, CI yeşil. `release.yml` bunlarla ilk kez gerçek yayında çalışacak. Sonraki sürüme ertelenen güncelleme yok.
  - [x] Sürüm 1.2.4+16.
  - [x] Sürüm notları (Sohbet metni) `release-notes/*.txt`'de (330–430 karakter).
  - [ ] Web önizleme (`game/js/ads.js`, `tools/test-ads.js` 8b) iade kuralı eşitlemesi → Sohbet (acil değil).
  - Sonra: sahip onayı → main → `release.yml` (internal+alpha) → %20 kademeli üretim → v1.2.4 etiketi (kural 14).
- [ ] Code: yayındaki 1.2.3 (versionCode 15) için geriye dönük v1.2.3 etiketi atılacak (1.2.4 bittikten sonra).
- [ ] 1.2.4 bittikten sonra Code: güvenlik denetimi (belgedeki standart görevle). Belge: "Geliştirme ve Güvenlik Kuralları" https://claude.ai/artifact/R1aCgNoiSAruVZ8dug9CSY ("Güvenlik denetimi" bölümü; önce yalnızca inceleme ve rapor, düzeltmeler onaydan sonra).
- [ ] **Yükleme anahtarı sıfırlama** (1.2.4 yayınlandıktan sonra): yeni keystore üret → sahibe zip (iki yere yedek) → Play Console "Sıfırlama talep edin" + PEM → GitHub secret'larını güncelle. ~2 gün güncelleme yüklenemez.
- [ ] **Banner deneyi kararı** (~8 Aralık).
- [ ] **1.3.0** (orta, Sonnet; Aralık başı): es/pt/id/ru oyun içi metinler + **Kiril font** (Readex Pro'da Kiril yok) + taşma testleri + bu dillerde mağaza sayfaları/ekran görüntüleri + gizlilik sayfası çevirileri (stüdyo sitesi sohbeti) + AdMob EEA mesajına es/pt. Not: Rusya'da Google reklam/IAP yok; Rusça CIS için.
- [ ] **Simge denemesi** (Play mağaza girişi deneyi, `store/icon-candidates/`), 1.3.0 ile.
- [ ] **Faz B** (Ocak): liderlik tablosu, WhatsApp davet.
- [ ] İleride: Play API anahtarlarını tek anahtarda toplama (yükleme anahtarı yenilemesiyle birlikte, sırayla).

## 6. Bilinen notlar

- Play Console uyarıları: Flutter motoru/eklentilerden gelen eski edge-to-edge API çağrıları (bizim kodda yok) — kütüphane güncellemeleriyle kalkar.
  28 Kasım 2026 kontrolü (sahibin ekran görüntüsü, 1.2.3): (1) "Uçtan uca ekran tüm kullanıcılara gösterilmeyebilir" — `enableEdgeToEdge()` 1.2.2'den beri MainActivity'de var, iş yok. (2) "Desteği sonlandırılmış API" = `LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES`, kaynak `k1.t` (küçültülmüş androidx.activity sınıfı; `enableEdgeToEdge()` bunu yalnızca Android 9–10'da ayarlar). Bizim kodda yok; bilinen kütüphane uyarısı, iş yok. Sembol uyarısı bu sayfada görünmedi → 1.2.4 yüklenince yeniden bakılacak.
- Harita başlığı tr/ar'da dar ekranda iki satıra bölünüyor (kesilmiyor).
- Güvenlik raporları: ilk denetim (19 Kas) bulguları 1.2.3'te kapandı; ikinci denetim (22 Kas) kalanları yukarıdaki 1.2.4 listesinde. "Secret'ları ortama taşı" ve "servis hesabını yalnız test kanalına sınırla" önerileri bilinçli olarak uygulanmadı (onay kapısı korumayı sağlıyor).
- Sürüm geçmişi ayrıntıları: docs/17 (changelog) ve docs/27–29.

## 7. Değişiklik günlüğü

- **28 Kasım 2026:** Kök dizine `CLAUDE.md` eklendi (sahibin yazdığı Claude çalışma kuralları: her oturumda önce CLAUDE.md ve bu dosya okunur, her iş ayrı dalda yapılır, onaysız ana dala birleştirme yok, raporlarda "test edildi / derlendi, test edilemedi / telefonda denenmeli" işaretleri). Yalnızca belge; oyun kodu değişmedi.
- **28 Kasım 2026:** 1.2.4 işi Claude Code tarafına verildi (sahip kararı). Sohbet tarafı 1.2.4'e dokunmaz.
- **28 Kasım 2026:** `CLAUDE.md`'ye iki ekleme (sahip onaylı): 7. maddeye "yalnızca 00-DURUM.md güncellemeleri onaysız ana dala gidebilir" istisnası; yeni "İş bölümü: Sohbet ve Code" bölümü (Code: kod/derleme/test/sürüm; Sohbet: karar, araştırma, mağaza, gizlilik, web önizleme, Code'u kontrol). Code'un 1.2.4 dalı bunları ana dalı aldığında görür.
- **28 Kasım 2026:** 1.2.4 kod tarafı bitti (Code, dal `claude/upbeat-turing-najevq`, CI 13/13): Flutter 3.50.1 sabit, satın alma iptal/iade düzeltmeleri, yedek yalnızca kayıt dosyası, AAB sembol denetimi, 5 GitHub Actions güncellemesi, sürüm 1.2.4+16. Bekleyen: Sohbet'ten onay cümlesi + sürüm notları, sahip onayıyla birleştirme ve yayın.
- **28 Kasım 2026:** 1.2.4 metinleri (Sohbet) oyuna kondu: onay cümlesi 4 dil + gizlilik tarihi 2026-11-28 + sürüm notları; taşma testi eklendi; CI 13/13. Bekleyen: sahip onayıyla main'e birleştirme ve yayın.
- **28 Kasım 2026:** 1.2.4 sahip onayıyla main'e birleştirildi (ileri sarma, e23c34e); main CI 13/13. Sırada: sahip onayıyla yayın (`release.yml` internal+alpha → %20 üretim) ve v1.2.4 etiketi.
- **28 Kasım 2026:** Stüdyo sitesindeki Arrowtile gizlilik politikası güncellendi (Sohbet, sahip onaylı; site deposu `5892ada`): tarih 28 Kasım 2026, 3.4 bölümünün son cümlesi 1.2.4 onay davranışıyla eşitlendi (Analytics yalnızca onayla; reklamlar form seçiminden sonra; onay yoksa kişiselleştirilmemiş/sınırlı reklam), 4 dil. Oyundaki metinle uyumlu.
- **28 Kasım 2026:** 1.2.4 yayın akışı (release #17) başarılı: iç test + kapalı test (versionCode 16), Play incelemesinde. Üretim sahip tarafından Play Console'dan, %20 kademeli.
