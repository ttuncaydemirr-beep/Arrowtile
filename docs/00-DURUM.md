# Arrowtile — Durum ve devir notu

> **Yeni sohbet için:** Bu dosyayı baştan sona oku, sonra "Sıradaki işler" listesindeki ilk açık maddeden devam et.
> Her büyük adımdan sonra bu dosyayı güncelle (tarih + ne değişti). Son güncelleme: **28 Kasım 2026**.

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
- [ ] **1.2.4** (küçük-orta) — **1.2.4 Claude Code'da yapılıyor** (sahip kararı, 28 Kasım 2026; sohbet tarafı bu işe başlamaz):
  - CI: `release.yml`'de flutter-action önbelleği kapat (`cache: false`), Flutter sürümünü sabitle; Dependabot'a 7 gün bekleme (`cooldown`).
  - Satın alma: iptalde 90 sn kilidi kaldır (ürün adı boş "canceled" olayını işle); iade sonrası reklamsızlığı **art arda iki boş sorgu + 24 saat** sonra kaldır.
  - Yedekleme yalnızca oyun kaydı dosyasıyla sınırlı (`dataExtractionRules`/`fullBackupContent`); uygulama içi onay cümlesi düzeltmesi.
  - Native debug sembolleri (Play'deki uyarı) yüklensin.
  - Dependabot PR #4–#8'i değerlendir (major sürümler — testle).
  - Sürüm 1.2.4+16, %20 kademeli üretim.
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
- Harita başlığı tr/ar'da dar ekranda iki satıra bölünüyor (kesilmiyor).
- Güvenlik raporları: ilk denetim (19 Kas) bulguları 1.2.3'te kapandı; ikinci denetim (22 Kas) kalanları yukarıdaki 1.2.4 listesinde. "Secret'ları ortama taşı" ve "servis hesabını yalnız test kanalına sınırla" önerileri bilinçli olarak uygulanmadı (onay kapısı korumayı sağlıyor).
- Sürüm geçmişi ayrıntıları: docs/17 (changelog) ve docs/27–29.

## 7. Değişiklik günlüğü

- **28 Kasım 2026:** Kök dizine `CLAUDE.md` eklendi (sahibin yazdığı Claude çalışma kuralları: her oturumda önce CLAUDE.md ve bu dosya okunur, her iş ayrı dalda yapılır, onaysız ana dala birleştirme yok, raporlarda "test edildi / derlendi, test edilemedi / telefonda denenmeli" işaretleri). Yalnızca belge; oyun kodu değişmedi.
- **28 Kasım 2026:** 1.2.4 işi Claude Code tarafına verildi (sahip kararı). Sohbet tarafı 1.2.4'e dokunmaz.
- **28 Kasım 2026:** `CLAUDE.md`'ye iki ekleme (sahip onaylı): 7. maddeye "yalnızca 00-DURUM.md güncellemeleri onaysız ana dala gidebilir" istisnası; yeni "İş bölümü: Sohbet ve Code" bölümü (Code: kod/derleme/test/sürüm; Sohbet: karar, araştırma, mağaza, gizlilik, web önizleme, Code'u kontrol). Code'un 1.2.4 dalı bunları ana dalı aldığında görür.
