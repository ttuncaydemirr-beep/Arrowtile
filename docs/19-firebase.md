# Sürüm 1.1.2 — Firebase Analytics + Crashlytics

Sürüm: `1.1.2+6` (`AppInfo.version = '1.1.2'`). Amaç: (1) testçilerin "oyun çok kolay" geri bildirimini **ölçmek** için seviye başına
tamamlama/hata/ipucu/süre verisi toplamak, (2) çökmeleri görmek. Ayrıca gizlilik metinleri ve Play "Veri güvenliği" formu güncellenir.

> **Kullanıcının yapacakları (özet; ayrıntı aşağıda):**
> 1. GitHub secret `GOOGLE_SERVICES_JSON` ekle → [docs/14 §3.1](14-ci-imzali-derleme.md) (bu olmadan `release.yml` bilerek durur).
> 2. Firebase konsolunda Crashlytics'i etkinleştir ve Analytics gizlilik ayarlarını yap → §4.
> 3. Play Console **Veri güvenliği** formunu güncelle (1.1.2 yayınlanmadan önce) → §5.
> 4. Gizlilik sayfası (GitHub Pages) bu değişiklikle kendiliğinden yeniden yayınlanır (`pages.yml`); Actions'ta yeşil olduğunu kontrol et.

## 1. Ne değişti

| Alan | Değişiklik |
|---|---|
| Bağımlılıklar | `firebase_core ^5.1.0`, `firebase_analytics ^13.0.1`, `firebase_crashlytics ^6.0.1` (FlutterFire BoM 5.1.0; minSdk 24 zaten karşılanıyor) |
| Tek giriş noktası | `lib/core/telemetry.dart` (soyut `Telemetry` + olay yardımcıları + `NoopTelemetry` + `installCrashHandlers`). Gerçek uygulama: `lib/services/firebase_telemetry.dart`. Uygulamanın geri kalanı Firebase'e **hiç** dokunmaz; testler `test/fake_telemetry.dart` kullanır |
| Savunmacı başlatma | `main.dart`: `Firebase.initializeApp()` **seçeneksiz** (Android'de `google-services.json`'dan yerel başlatma), 5 sn zaman aşımı, `try/catch`. Yapılandırma yoksa ya da hata olursa `NoopTelemetry`: oyun aynen çalışır, çökme kancaları takılmaz. `firebase_options.dart` **yoktur** (depoda gerçek anahtar yok) |
| Gradle | `settings.gradle.kts`: `com.google.gms.google-services 4.5.0` ve `com.google.firebase.crashlytics 3.0.8` `apply false`. `app/build.gradle.kts` bunları **yalnızca** `android/app/google-services.json` varsa uygular. CI/PR/fork derlemelerinde dosya yok → eklentiler hiç çalışmaz |
| Release | `release.yml`: `GOOGLE_SERVICES_JSON` secret'ı zorunlu; geçerli JSON ve `package_name == com.arrowtile.puzzle` denetimi (açık `::error::` mesajı); dosya yalnızca derleme çalışma kopyasına yazılır, iş sonunda silinir. Crashlytics eklentisi R8 eşleme dosyasını release'te otomatik yükler |
| `.gitignore` | `google-services.json` (kökte ve `flutter/arrowtile/`) |
| R8 | `proguard-rules.pro`: `-keep public class * extends java.lang.Exception` (+ mevcut `SourceFile,LineNumberTable`). Firebase kendi tüketici kurallarını getirir |
| Manifest | `google_analytics_default_allow_ad_personalization_signals=false` ve `..._analytics_storage / _ad_storage / _ad_user_data = false` (her şey varsayılan **kapalı**) |
| Onay | UMP sonucu `core/consent_gate.dart` içindeki `deriveTelemetryConsent` ile Firebase onay sinyallerine çevrilir (§3). `MainActivity.kt` yalnızca UMP'nin yazdığı `IABTCF_*` değerlerini okuyan küçük bir köprü içerir |
| Gizlilik | `game/js/i18n.js` `privacy.h_analytics / privacy.p_analytics` (+ `privacy.p_data` güncellendi); ARB yeniden üretildi; `privacy.js` yeni bölümü çizer; `dist/privacy-site/js/` kopyalandı; `AppInfo.privacyUpdated = 2026-11-10`; oyun içi `PrivacyScreen` yeni bölümü gösterir. 13 yaş altı cümlesi ve Google iş ortağı bağlantısı korunur; yeni bağlantı: <https://firebase.google.com/support/privacy> (tr/en/de/ar) |
| CI | Yeni `firebase-apk` + `smoke-firebase` işleri: **sahte** `google-services.json` ile release APK derler (eklentiler AGP 9 + R8 ile çalışıyor mu) ve emülatörde Firebase başlatma + onay sinyali günlüklerini doğrular. Sahte dosya yalnızca işin çalışma kopyasındadır |
| Testler | `test/telemetry_test.dart` (olaylar, anonimlik, onay eşlemesi, çökme kancaları, `Monetization` → `interstitial`, widget'ta `level_start`), `privacy_test.dart` genişletildi |

## 2. Olaylar (hepsi anonim: yalnızca sayı ve sabit sözcük; serbest metin / kimlik yok)

| Olay | Parametreler | Ne zaman |
|---|---|---|
| `level_start` | `level`, `tier` (easy/medium/hard/extreme), `chapter` | Seviye açıldığında ve **her yeniden denemede** (günlük bulmaca hariç) |
| `level_complete` | `level`, `tier`, `stars`, `mistakes` (çarpışma), `hints_used`, `duration_s` (0–3600 kırpılır) | Seviye çözüldüğünde (o denemenin ipucu/süresi) |
| `level_fail` | `level`, `tier` | Canlar bitti |
| `hint_used` | `level` | İpucu harcandı |
| `daily_puzzle_complete` | `stars`, `mistakes`, `duration_s` | Günlük bulmaca çözüldü |
| `rewarded_ad` | `placement` (coins/life/hint), `result` (rewarded/closed/unavailable) | Ödüllü reklam akışı bitince |
| `interstitial` | `result` (shown/skipped/failed) | Geçiş reklamının zamanı geldiğinde: `shown` gösterildi, `skipped` hazır değildi, `failed` denendi ama ekrana gelmedi |
| `purchase` (`logPurchase`) | `remove_ads`, Play'in bildirdiği para birimi/fiyat | **Yalnızca** başarılı gerçek satın alma (iptal/bekleyen/hata/test modu/zaten sahip değil) |
| `setting_changed` | `name` (relaxed_mode/aim_mode/appearance/arrow_theme), `value` (on/off, auto/light/dark, tema kimliği) | Ayar değişince |
| Kullanıcı özelliği `app_lang` | tr/en/de/ar | Açılışta ve dil değişince |

Firebase'in otomatik olayları (açılış, oturum, ekran) ayrıca toplanır. Seviye ekranından **çıkış** (terk) olayı yoktur: terk oranı
`level_start − level_complete − level_fail` farkından kabaca okunur.

### Zorluk ayarı için nasıl okunur
- **Tamamlama oranı** (seviye başına) = `level_complete` / `level_start`; "çok kolay" belirtisi: oran ~%100 ve `mistakes` ortalaması ~0, `stars` ortalaması ~3.
- **Hata/başarısızlık**: `level_fail` / `level_start`. **Ortalama hata** (`mistakes`) ve **ipucu** (`hints_used`) kademeye (`tier`) göre.
- **Süre**: `duration_s` ortalaması/medyanı. Çok kısa süre + 3 yıldız = kolay seviye. Rahat mod açık oyuncular (`setting_changed relaxed_mode on`) ayrı değerlendirilmeli (rahat modda en çok 2 yıldız).
- Seviye numarası 5.000'e kadar çıktığı için `level` boyutu GA4 standart raporlarında **(other)** satırına düşer (günlük ~500 benzersiz değer sınırı). Seviye bazlı analiz için **Keşfet (Explorations)** ya da **BigQuery dışa aktarma** kullanın.

## 3. Onay ve gizlilik davranışı

| Durum (UMP) | analytics_storage | ad_storage | ad_user_data | ad_personalization | Analytics toplaması |
|---|---|---|---|---|---|
| Onay gerekmiyor (AEA/BK/İsviçre dışı) | verildi | verildi | verildi | **reddedildi** | açık |
| AEA/BK/İsviçre, onay alındı | TCF amaç 1 | TCF amaç 1 | amaç 1 **ve** 7 | **reddedildi** | amaç 1 verildiyse açık, aksi halde **tamamen kapalı** |
| Onay bekleniyor / bilinmiyor / amaçlar okunamadı | reddedildi | reddedildi | reddedildi | reddedildi | **kapalı** (olaylar atılır) |

- Açılışta `setAnalyticsCollectionEnabled(false)` ile başlanır; yalnızca onay sinyali `analytics_storage`'a izin verirse açılır. Manifest varsayılanları da hep `false`.
- `ad_personalization` hiçbir durumda açılmaz: Firebase verisi reklam kişiselleştirme için kullanılmıyor; Google sinyalleri kapalı.
- Onay durumu her UMP güncellemesinde (açılış, form kapanışı, "Gizlilik seçenekleri" formundan dönüş) yeniden hesaplanır (`ads_service.dart` → `onConsentStatus`). Reklam akışı bunu **beklemez** (docs/16 ve docs/18 düzeltmelerine dokunulmadı; yalnızca `_afterConsentUpdate` içine bekletmeyen bir çağrı ve `continueAfterLevel`'e sonucu bildiren bir geri çağrı eklendi).
- **Crashlytics onaya bağlı değildir**: çökme raporları uygulamanın kararlılığı için gönderilir (gizlilik metninde belirtildi). Hukuki dayanak (meşru menfaat) kararı sizindir; AEA'da katı yaklaşım istenirse Crashlytics de `analytics_storage`'a bağlanabilir.
- **Debug derlemede toplama kapalıdır** (Analytics + Crashlytics). Cihazda denemek için `--dart-define=TELEMETRY_IN_DEBUG=true` ile açılır. CI deneme APK'sı (release modu) `google-services.json` içermediği için zaten Firebase'siz çalışır.

## 4. Firebase konsolunda yapılacaklar (bir kez)

Proje: Arrowtile Firebase projesi, Android uygulaması `com.arrowtile.puzzle`.

1. **Crashlytics'i etkinleştir:** Sol menü **Build (Derleme) → Crashlytics → Enable Crashlytics / Crashlytics'i etkinleştir**. İlk raporlar, 1.1.2 AAB'si (içinde `google-services.json` olan sürüm) cihazlarda açılıp ilk çökme yaşandıktan sonra görünür; "Waiting for your app to send data" ekranı o zamana kadar normaldir. (Uygulamada kasıtlı bir "test çökmesi" düğmesi yoktur.)
2. **Analytics veri paylaşım ayarlarını kapat** (Play formundaki "paylaşılmıyor" yanıtının dayanağı): **Analytics → Yönetici (⚙) → Veri toplama ve değiştirme → Veri paylaşım ayarları**: *Google ürünleri ve hizmetleri*, *Kıyaslama*, *Teknik destek*, *Hesap uzmanları* — **hepsini kapatın**.
3. **Google sinyallerini etkinleştirmeyin:** Yönetici → **Veri toplama ve değiştirme → Veri toplama**: *Google sinyalleri veri toplama* **kapalı** kalsın. **Raporlama kimliği** (Reporting identity): *Cihaz tabanlı* seçin.
4. **Veri saklama süresi:** Yönetici → **Veri toplama ve değiştirme → Veri saklama** → Olay verisi saklama: **2 ay** (en kısa). *Kullanıcı etkinliklerinde yeni etkinlikte sıfırla* kapalı.
5. **Veri işleme şartları:** Proje ayarları → **Entegrasyonlar/Analytics** ya da Yönetici → **Hesap ayarları** altında *Veri İşleme Şartları*'nın kabul edildiğini doğrulayın (Google'ın sizin adınıza işlemesinin dayanağı).
6. **Özel tanımlar** (olay parametrelerini raporlarda kullanabilmek için; Yönetici → **Veri görüntüleme → Özel tanımlar → Özel boyut / Özel ölçüm oluştur**, kapsam: **Etkinlik**):

   | Tür | Parametre adı |
   |---|---|
   | Özel boyut | `level`, `tier`, `chapter`, `placement`, `result`, `name`, `value` |
   | Özel ölçüm | `stars`, `mistakes`, `hints_used`, `duration_s` (birim: standart/saniye) |

   Tanım oluşturulmadan önceki olayların parametreleri geriye dönük raporlanmaz (ham veri BigQuery'ye gider). **Hemen** oluşturun.
7. (İsteğe bağlı, seviye bazlı analiz için) **BigQuery bağlantısı:** Proje ayarları → Entegrasyonlar → BigQuery → Bağla → Analytics günlük dışa aktarma. Saklama süresi 2 ay olduğundan BigQuery'deki kopya sizin sorumluluğunuzdadır.
8. **Doğrulama:** 1.1.2 kapalı test sürümü kurulup oynandıktan birkaç dakika sonra **Analytics → Raporlar → Gerçek zamanlı** ekranında olaylar (`level_start` …) görünmelidir; olay tablosu ~24 saat sonra dolar. Onay formu çıkan bir AEA cihazında formu **reddederseniz** hiç olay görünmemelidir (beklenen davranış).

## 5. Play Console "Veri güvenliği" formu (adım adım)

**Ne zaman:** 1.1.2 yayınlanmadan önce. Yol: Play Console → uygulama → **Politika ve programlar → Uygulama içeriği → Veri güvenliği → Yönet** (ya da *Başlayın / Düzenle*).

Dayanak (Google'ın yönergesi): Verileri **sizin adınıza işleyen bir hizmet sağlayıcıya** aktarmak Play'in tanımında *"paylaşım"* sayılmaz. Firebase Analytics/Crashlytics'te Google bu rolde
(Firebase Veri İşleme ve Güvenlik Şartları), **yalnızca** §4 adım 2'deki veri paylaşım ayarları kapalıysa. Bu yüzden o ayarlar kapatılır. Google'ın güncel metni için:
<https://firebase.google.com/docs/android/play-data-disclosure> ve <https://support.google.com/googleplay/android-developer/answer/10787469> (bu sayfalar yazım sırasında doğrulanamadı; form sorularının adı Play tarafında değişmiş olabilir; ilke aynıdır).

**Adım 1 — Veri toplama ve güvenlik (ilk ekran)**
- "Uygulamanız gerekli kullanıcı verilerini topluyor veya paylaşıyor mu?" → **Evet** (zaten Evet'ti).
- "Tüm kullanıcı verileri aktarım sırasında şifreleniyor mu?" → **Evet** (Firebase, AdMob, Play Billing TLS kullanır).
- "Kullanıcılar verilerinin silinmesini isteyebilir mi?" → **Evet** (değişmedi). Açıklama: hesap yok; oyun verisi yalnızca cihazda; kullanıcı Ayarlar > İlerlemeyi sıfırla ile ya da uygulamayı kaldırarak siler; Analytics verisi 2 ay sonra otomatik silinir; e-posta ile silme/bilgi isteği gizlilik politikasında.

**Adım 2 — Veri türleri.** Aşağıdakileri **işaretli** bırakın/ekleyin; listede olmayan türleri (Kişisel bilgiler, Hassas/kesin konum, Mesajlar, Fotoğraf, Kişiler vb.) **işaretlemeyin**:

| Play kategorisi → tür | Toplanıyor | Paylaşılıyor | Amaçlar (işaretle) | Zorunlu mu |
|---|---|---|---|---|
| Konum → **Yaklaşık konum** | Evet | **Evet** (AdMob; değişmedi) | Reklamlar veya pazarlama, Analiz, Dolandırıcılık önleme/güvenlik | Zorunlu |
| Uygulama etkinliği → **Uygulama etkileşimleri** | Evet | **Evet** (AdMob; değişmedi) | Reklamlar veya pazarlama, **Analiz**, Dolandırıcılık önleme/güvenlik | Zorunlu |
| Uygulama bilgileri ve performansı → **Kilitlenme günlükleri (Crash logs)** — **YENİ** | Evet | **Hayır** (Crashlytics: hizmet sağlayıcı)¹ | **Analiz**, **Uygulama işlevleri** | Zorunlu |
| Uygulama bilgileri ve performansı → **Tanılama (Diagnostics)** | Evet | **Evet** (AdMob; değişmedi) | **Uygulama işlevleri** (yeni ekle), Analiz, Dolandırıcılık önleme/güvenlik | Zorunlu |
| Cihaz veya diğer kimlikler → **Cihaz veya diğer kimlikler** (reklam kimliği, uygulama örneği/Firebase yükleme kimliği, Crashlytics yükleme kimliği) | Evet | **Evet** (AdMob; değişmedi) | Reklamlar veya pazarlama, **Analiz**, Dolandırıcılık önleme/güvenlik | Zorunlu |
| Finansal bilgiler → **Satın alma geçmişi** | Evet | **Hayır** | Uygulama işlevleri, **Analiz** (yeni ekle: `purchase` olayı ürün/fiyat taşır) | Zorunlu |

¹ Play, bir veri türünü AdMob nedeniyle zaten "paylaşılıyor" işaretlediyseniz o türde Firebase'in ayrıca bir şey değiştirmesini gerektirmez. Kilitlenme günlükleri satırı AdMob'un güncel açıklamasında "paylaşılıyor" geçiyorsa, formda da **Evet** bırakın; tutarlı olan Google'ın AdMob/Firebase sayfalarındaki en güncel liste ile eşleşmektir.

"Zorunlu mu?" sorusu: toplama kullanıcı tarafından kapatılamıyorsa *Veri toplama zorunludur*. (AEA'da analiz onayla çalışır, ama dünyanın geri kalanında kapatılamadığı için "zorunlu" demek doğrudur.)

**Adım 3 — Gönder.** Önizlemeyi (Önizleme) kontrol edin: *Toplanan veriler* listesinde yukarıdaki türler; *Paylaşılan veriler* listesinde yalnızca AdMob kaynaklı türler olmalı. **Kaydet → Gönder**. Politika URL'si değişmez (`https://ttuncaydemirr-beep.github.io/Arrowtile/privacy.html`); sayfa yeni metinle yayında olmalı.

Diğer sayfalarda değişen bir şey yok: Hedef kitle 13+ kalır (13 yaş altı sayılmaz), Reklam kimliği beyanı aynı kalır, "Uygulama erişimi/İçerik derecelendirme" etkilenmez.

## 6. CI / test notları
- `flutter` işi (analiz + test + deneme APK) `google-services.json` olmadan derler: Gradle eklentileri uygulanmaz, `Firebase.initializeApp()` istisna atar, `NoopTelemetry` devreye girer. `smoke`, `smoke-eea`, `smoke-ads` işleri bu Firebase'siz APK'larla çalışır (docs/16 ve docs/18 güvenceleri aynen geçerli).
- `firebase-apk` + `smoke-firebase`: sahte yapılandırmayla release APK. Emülatörde logcat'te `TELEMETRY: init ok` ve `TELEMETRY: consent: …` aranır; çökme yok ve `smoke-resume.sh` (arka plana git/dön) geçmeli. `ORG_GRADLE_PROJECT_arrowtileSkipMappingUpload=true` yalnızca bu işte R8 eşleme yüklemesini kapatır (sahte uygulama kimliğine ağ isteği olmasın).
- Gerçek `release.yml` bu oturumda **çalıştırılmadı** (kural). İlk gerçek AAB derlemesinde Crashlytics eşleme yükleme adımı ağa çıkar; başarısız olursa derleme hatasından anlaşılır.

## 7. Açık riskler
- Derleme yerelde doğrulanamadı (Flutter SDK yok); doğrulama yalnızca GitHub Actions'ta. Crashlytics Gradle eklentisi 3.0.8 + **AGP 9.3.1** birlikteliğine dair kamuya açık hata raporları var (3.0.6'da AGP 9'da sınıf bulunamadı hatası); `firebase-apk` işi bunu sahte yapılandırmayla yakalar. Gerçek release'e özgü tek fark, eşleme dosyası yükleme görevidir (burada devre dışı).
- Crashlytics onaya bağlı değil (§3). Veri güvenliği formundaki "paylaşılmıyor" yanıtı, §4 adım 2 yapılmazsa yanlış olur.
- Analytics yalnızca onay sonrası açıldığı için, açılıştan onay sonucuna (genelde saniyeler) kadar geçen olaylar atılır; çevrimdışı ilk açılışta onay durumu "bilinmiyor" kalırsa analiz o oturumda kapalıdır (güvenli yön).
- `level` parametresi yüksek kardinalitelidir (§2); standart GA4 raporlarında "(other)" görünür.
- `duration_s` duvar saatidir: arka planda geçen süre de sayılır (3600 sn ile kırpılır). Ortalama yerine medyan kullanın.
- Sürüm 1.1.2 AAB'si için `versionCode` 6; Play'e her yüklemede `+N` artırılmalıdır.
