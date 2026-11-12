# Arrowtile — Google Play'e yükleme rehberi

Hazırlayan: Android/Yayın Geliştiricisi · Tarih: 31.10.2026 (Flutter bölümü §3b: 02.11.2026) · Uygulama: `com.arrowtile.puzzle` 1.0.0

> **02.11.2026:** Native `android/` projesi `legacy/android-native/` altına arşivlendi, `tools/sync-android.sh` → `legacy/sync-android.sh`. Güncel derleme yolu **§3b (Flutter)**; §3 ve metindeki `android/…` yolları eski projeyi anlatır.

Bu belge, oyunu Google Play'de yayına almak için **sizin** yapacağınız adımları sırasıyla anlatır. Teknik ayrıntılar
`android/README.md` dosyasında. Hazır dosyalar:

| Dosya | Ne işe yarar |
|---|---|
| `dist/Arrowtile-android-v1.0.0.zip` | Android Studio projesi (oyun dosyaları içinde) |
| `dist/Arrowtile-store-assets.zip` | Play ikonu, özellik grafikleri, ekran görüntüleri (4 dil) |
| `dist/privacy-site/` | Gizlilik politikası sayfası, herkese açık bir adrese yüklenmeye hazır |
| `docs/07-magaza-metinleri.md` | Mağaza başlığı, kısa ve uzun açıklama (4 dil) |

> **Önemli:** Proje bu ortamda derlenemedi, çünkü Android SDK yok ve Google'ın kütüphane deposuna erişim yok.
> İlk derlemeyi Android Studio'da siz yapacaksınız (§3). Java kodu sahte Android sınıflarıyla derlendi ve köprü mantığı
> oyunun gerçek `ads.js` dosyasıyla test edildi. Gerçek SDK'larla uyum ise ilk Android Studio derlemesinde doğrulanacak.

## Güncel Google Play kuralları (Ekim 2026'da kontrol edildi)

- **Hedef API:** 31.08.2026'dan beri yeni uygulamalar ve güncellemeler **Android 16'yı (API 36)** hedeflemek zorunda.
  Gerekirse 01.11.2026'ya kadar uzatma istenebiliyordu. Projede `targetSdk = 36` ayarlı. (Brifte API 35 yazıyordu, ancak artık yetmiyor.)
- **Billing:** 31.08.2026'dan beri Play Billing Library **8 ya da üstü** zorunlu. Projede 9.1.0 kullanılıyor.
- **Kapalı test:** 13.11.2023'ten sonra açılmış **kişisel** geliştirici hesaplarında, üretime çıkmadan önce **en az 12 test kullanıcısı**
  kapalı teste katılmalı ve **14 gün kesintisiz** testte kalmalı. Kuruluş (şirket) hesapları bu kuraldan muaf.
- **AdMob:** Klasik Google Mobile Ads SDK (25.5.0, minSdk 24) artık "Legacy / bakım modu" olarak anılıyor. Google yeni projelere
  "GMA Next-Gen SDK" öneriyor. Klasik SDK destekleniyor ve kararlı. Next-Gen'e geçişi ilerideki bir sürüme bırakmayı öneriyorum.

Kaynaklar sayfanın sonunda.

---

## 1. Play Console geliştirici hesabı

1. <https://play.google.com/console> adresine gidin ve Google hesabınızla giriş yapın.
2. **Kişisel** hesap türünü seçin. (Şirketiniz yoksa kişisel hesap uygundur. Kuruluş hesabı D-U-N-S numarası ister.)
3. Tek seferlik kayıt ücretini (25 $) ödeyin.
4. Kimlik doğrulamasını tamamlayın: kimlik belgesi, adres ve telefon. Onay birkaç gün sürebilir.
5. **Geliştirici adı** mağazada görünür: **Demir Games Studio** (sahip kararı; "Demir Games" Play'de alınmış — tüm projelerde aynı ad). İletişim e-postası olarak `nilkaren.tuncay.demir@gmail.com` adresini kullanın.

## 2. AdMob hesabı, uygulama ve 3 reklam birimi

1. <https://admob.google.com> adresinde aynı Google hesabıyla kaydolun. Ödeme ve vergi bilgilerini girin.
2. **Uygulamalar > Uygulama ekle**: Platform **Android**. "Uygulama mağazada listeleniyor mu?" sorusuna şimdilik **Hayır** deyin
   (yayından sonra mağaza kaydına bağlarsınız). Uygulama adı: **Arrowtile**.
3. Oluşan **Uygulama kimliği** `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` biçimindedir (`~` içerir). Not alın.
4. **Reklam birimleri > Reklam birimi ekle**:
   - **Geçiş reklamı (Interstitial)**, ad: `seviye_sonu`. Kimliği (`/` içerir) not alın.
   - **Ödüllü (Rewarded)**, ad: `odul_can_ipucu`. Ödül: 1 adet, "odul". Kimliği not alın.
   - **Banner**, ad: `menu_harita_banner` (v1.1; yalnızca ana menü ve haritada, uyarlanabilir boyut). Kimliği not alın.
5. `android/app/src/main/res/values/ads.xml` dosyasını açın ve üç test kimliğini kendi kimliklerinizle değiştirin:
   `admob_app_id`, `admob_interstitial_id`, `admob_rewarded_id`. (`src/debug/...` dosyasına dokunmayın.)
6. **Gizlilik ve mesajlaşma > Avrupa düzenlemeleri (GDPR)**: bir **GDPR mesajı** oluşturun, uygulamaya bağlayın ve yayınlayın.
   Mesaj dilleri: Türkçe, İngilizce, Almanca, Arapça. Bu mesaj olmadan UMP onay formu görünmez ve AEA/BK'da reklam geliri düşer.
   İsterseniz **ABD eyalet düzenlemeleri** mesajını da açın.
7. Oyunun Ayarlar > Reklamlar bölümündeki **Gizlilik seçenekleri** düğmesi yalnızca bu formun gerekli olduğu bölgelerde görünür.

### app-ads.txt (önerilir, zorunlu değil)
AdMob, reklam sahteciliğini önlemek için geliştirici web sitenizin kökünde bir `app-ads.txt` dosyası ister. Bu dosya yoksa
reklamlar yine gösterilir, ancak bazı reklamverenler teklif vermeyebilir.
1. AdMob > Uygulamalar > **app-ads.txt** bölümündeki satırı kopyalayın (`google.com, pub-…, DIRECT, f08c47fec0942fa0`).
2. Satırı, Play Console'daki **geliştirici web sitesi** alanına yazdığınız alan adının KÖKÜNDE `app-ads.txt` dosyası olarak yayınlayın.
   GitHub Pages kullanıyorsanız bu adres `https://KULLANICI.github.io/app-ads.txt` olmalıdır. Bunun için depo adı
   `KULLANICI.github.io` olmalıdır (§7'deki gizlilik sitesini de bu depoya koyabilirsiniz). Örnek dosya: `dist/privacy-site/app-ads.txt.ornek`.

## 3. Android Studio'da projeyi açma ve imzalı AAB üretme

1. `dist/Arrowtile-android-v1.0.0.zip` dosyasını açın (ya da doğrudan `android/` klasörünü kullanın).
2. Android Studio > **File > Open** ile `android/` klasörünü açın. Gradle sync bitene kadar bekleyin.
   İstenirse "Android SDK Platform 36" ve önerilen güncellemeleri kurun.
3. Oyunda değişiklik yaptıysanız eşitleme kendiliğinden olur (`game/` klasörü `assets/www` içine kopyalanır).
   Elle eşitlemek için proje kökünde `bash tools/sync-android.sh` çalıştırın.
4. Telefonda **debug** sürümünü çalıştırın (▶ Run). Test reklamlarının ve satın alma düğmelerinin göründüğünü kontrol edin.
5. `versionCode` değerini kontrol edin (`android/app/build.gradle.kts`). İlk yüklemede 1 olmalı, sonraki her yüklemede 1 artırın.
6. **Build > Generate Signed App Bundle or APK… > Android App Bundle** adımlarını izleyin. Yükleme anahtarını oluştururken
   `android/README.md` dosyasındaki "İmzalı AAB" bölümüne bakın. Anahtar dosyası (`.jks`) ve şifrelerin yedeğini mutlaka alın.
7. Çıktı dosyası `app-release.aab` olarak oluşur.

## 3b. Flutter ile derleme (güncel yol — Android Studio adımlarının Flutter karşılığı)

**Karar (02.11.2026):** yayın sürümü Flutter projesidir (`flutter/arrowtile/`, `docs/11-flutter-tasima.md`). Yukarıdaki §3 eski
WebView projesi (`legacy/android-native/`, artık güncellenmez) içindir; Play Console, AdMob, `remove_ads`, form yanıtları
(§4–§11) **aynı kalır** çünkü uygulama kimliği aynıdır (`com.arrowtile.puzzle`). Ayrıntılı kurulum ve sık hatalar:
`flutter/arrowtile/README.md`.

| Android Studio (WebView projesi) | Flutter karşılığı |
|---|---|
| `android/` klasörünü Android Studio'da aç, Gradle sync | Flutter kur → `cd flutter/arrowtile` → `flutter pub get` (+ `flutter gen-l10n`) |
| Debug sürümünü telefonda çalıştır (▶) | `flutter run` (debug/profile **her zaman Google test reklamları**) |
| `android/app/src/main/res/values/ads.xml` içinde 3 AdMob kimliği | **Uygulama** kimliği: `android/app/src/main/res/values/ads.xml` (`admob_app_id`). **Reklam birimi** kimlikleri: `lib/config/ads_config.dart` (`releaseInterstitialId`, `releaseRewardedId`, `releaseBannerId`). Debug test kimliği: `src/debug/res/values/ads.xml` (değiştirmeyin). |
| `versionCode` → `android/app/build.gradle.kts` | `flutter/arrowtile/pubspec.yaml` → `version: 1.0.0+2` (`+2` = versionCode; ilk Play yüklemesi için 1 de olabilir — native proje Play'e hiç yüklenmediyse `+1` kullanabilirsiniz; sonraki her yüklemede 1 artırın) |
| `targetSdk = 36` | aynı (`android/app/build.gradle.kts`: compileSdk/targetSdk 36, minSdk 24) |
| Build > Generate Signed App Bundle (`keystore.properties`) | `android/key.properties` (örnek: `key.properties.example`) + `flutter build appbundle --release` |
| Çıktı `app-release.aab` | `build/app/outputs/bundle/release/app-release.aab` |
| `tools/sync-android.sh` (oyun dosyası eşitleme) | gerekmez: oyun mantığı Dart'tadır; `legacy/sync-android.sh` yalnızca eski proje içindir |
| Gizlilik URL'si → `ads.xml privacy_policy_url` | `lib/config/ads_config.dart` → `AppInfo.privacyPolicyUrl` |
| UMP test: `src/debug/.../ads.xml` | `lib/config/ads_config.dart` → `umpDebugGeographyEea`, `umpTestDeviceId` (yalnız debug) |

Adım adım:
1. `cd flutter/arrowtile && flutter pub get && flutter gen-l10n && flutter test` (testler hata verirse yayına çıkmayın; ilk fark metnini iletin).
2. Telefonda `flutter run` — menü, harita, seviye 1–3 öğretici, günlük bulmaca, Ayarlar (dil/RTL), mağaza görünüyor mu.
3. AdMob'da uygulama + 3 reklam birimi (geçiş, ödüllü, banner) + GDPR mesajı (§2); kimlikleri `ads.xml` ve `ads_config.dart` içine yazın.
4. Yükleme anahtarını oluşturup `android/key.properties` doldurun (README §2).
5. `flutter build appbundle --release` → `app-release.aab` → Play Console dahili test (§4) → `remove_ads` (§5) → kapalı test (§6).
6. Release (dahili test parçasından kurulu) sürümde §11 kontrol listesini uygulayın; "WebView/`?debug=1`" maddeleri Flutter'da geçerli değildir
   (hata ayıklama kancası yoktur), onun yerine **Ayarlar'da test kimliği uyarısının görünmediğini** doğrulayın.

> Bu belgedeki "Burada derlenemedi" uyarısı Flutter için de geçerlidir: kod hazırlandığı ortamda Flutter SDK yoktu; ilk
> `flutter pub get / analyze / test / run` sizde yapılacak.

---

## 4. Play Console'da uygulama oluşturma

1. **Tüm uygulamalar > Uygulama oluştur**.
2. Uygulama adı: **Arrowtile: Ok Bulmacası** (varsayılan dil Türkçe). Diğer dillerin başlıkları docs/07'de.
3. Varsayılan dil: **Türkçe – tr-TR**. Uygulama mı oyun mu: **Oyun**. Ücretsiz mi ücretli mi: **Ücretsiz**.
4. Beyanları onaylayın (Geliştirici Program Politikaları, ABD ihracat yasaları).
5. **Kontrol paneli > Uygulamanızı ayarlayın** bölümündeki görevleri §6'daki hazır yanıtlarla doldurun.
6. **Test > Dahili test** bölümünde yeni bir sürüm oluşturun ve `app-release.aab` dosyasını yükleyin. Play App Signing'i kabul edin.
   Dahili test, uygulamayı birkaç dakika içinde kendi telefonunuza kurmanın en hızlı yoludur.

## 5. "remove_ads" ürünü ve fiyat

Ürün, en az bir AAB yüklendikten sonra (dahili test yeterli) oluşturulabilir.
1. **Para kazanma > Ürünler > Tek seferlik ürünler** (eski adı "Uygulama içi ürünler") > **Ürün oluştur**.
2. Ürün kimliği: **`remove_ads`**. Bu kimlik koddakiyle birebir aynı olmalı ve sonradan değiştirilemez.
3. Ad / açıklama (4 dilde):
   - tr: "Reklamları kaldır" / "Seviye aralarındaki reklamlar kalıcı olarak kapanır. Tek seferlik satın alma."
   - en: "Remove ads" / "Ads between levels are switched off for good. A single purchase."
   - de: "Werbung entfernen" / "Werbung zwischen den Levels wird dauerhaft abgeschaltet. Einmaliger Kauf."
   - ar: "إزالة الإعلانات" / "تتوقف الإعلانات بين المستويات نهائيًا. شراء لمرة واحدة."
4. Satın alma seçeneği: **Satın al (buy)**, tüketilmeyen (non-consumable). Bu ürün tekrar satın alınamaz.
5. **Fiyat önerisi: 2,99 USD** taban fiyat. Diğer ülkelerin fiyatlarını Play'in otomatik çevirmesine bırakın ve Türkiye fiyatını gözden geçirin.
   Gerekçe:
   - Rakiplerde reklam kaldırma **7,99 $** (docs/05: Arrow Fever vb.). Bizim reklam yükümüz zaten hafif: ilk bölüm reklamsız,
     en erken 3 seviyede bir reklam ve en az 3 dakika ara var. Bu yüzden kullanıcı için "kaldırma" değeri rakiplerden düşük. Fiyat da öyle olmalı.
   - 2,99 $ dürtüsel satın alma aralığındadır ve rakip fiyatının yarısından azdır. Bunu "adil oyun" vaadiyle birlikte
     mağaza açıklamasında öne çıkarabiliriz.
   - Tek seferlik bir ürün olduğu için fiyat çok düşük tutulursa (0,99 $) toplam gelir azalır. 1,99–3,99 $ makul aralıktır.
     İlk 2–3 ay satın alma oranına bakıp gerekirse ayarlayın. (Play'de fiyat sonradan değiştirilebilir.)
6. Ürünü **Etkinleştir**.

## 6. Kapalı test (12 kişi × 14 gün) ve üretime yayın

1. **Test > Kapalı test > Parça oluştur** (ör. "Kapalı test"). Test kullanıcılarını bir **Google Grubu** ya da e-posta listesi olarak ekleyin.
2. Sürüm oluşturun, AAB'yi yükleyin ve incelemeye gönderin. Onaydan sonra **katılım bağlantısını** test kullanıcılarına gönderin.
   Her kişi bağlantıyı açıp "Test kullanıcısı ol" demeli ve uygulamayı Play'den kurmalı.
3. **En az 12 kişi 14 gün boyunca kesintisiz** testte kalmalı. Testten çıkıp yeniden giren kişinin süresi baştan başlar.
   Önlem olarak 14–15 kişi ekleyin. Test kullanıcılarından gerçekten oynamalarını ve geri bildirim vermelerini isteyin, çünkü Google bunu soruyor.
4. 14 gün dolunca **Kontrol paneli > Üretim erişimi başvurusu** formunu doldurun. Form, test nasıl yapıldı, ne öğrenildi ve
   uygulama yayına hazır mı sorularını sorar. İnceleme genelde birkaç gün sürer.
5. Erişim açılınca **Üretim > Yeni sürüm** bölümünde aynı (ya da versionCode'u artırılmış) AAB'yi yükleyin.
   **Kademeli dağıtım** önerilir: önce %20, sorun yoksa %100. Ülkeler: tümü (en azından TR, DE, AT, CH ve Arap ülkeleri).
6. **Lisans test kullanıcıları:** Play Console > **Ayarlar > Lisans testi** bölümüne kendi Gmail adresinizi ve test kullanıcılarını ekleyin.
   Bu hesaplar `remove_ads` ürününü gerçek ödeme yapmadan test kartıyla satın alabilir. "Yavaş test kartı" seçeneğiyle
   bekleyen (pending) ödemeyi de deneyebilirsiniz.

---

## 7. Play Console formlarının hazır yanıtları

### Uygulama erişimi
**Tüm işlevler özel erişim olmadan kullanılabilir.** Giriş, hesap ya da şifre yok.

### Reklamlar
**Evet, uygulamam reklam içeriyor.** (AdMob: seviye sonu geçiş reklamı ve isteğe bağlı ödüllü reklam.)

### Reklam kimliği (Advertising ID) beyanı
- Uygulama reklam kimliğini kullanıyor mu: **Evet**. (Manifestte `com.google.android.gms.permission.AD_ID` izni var.)
- Amaç: **Reklam veya pazarlama** ve **Analiz**. (AdMob ayrıca **dolandırıcılığı önleme** amacıyla da kullanır.)

### İçerik derecelendirmesi (IARC anketi)
- E-posta: nilkaren.tuncay.demir@gmail.com · Kategori: **Oyun** (Bulmaca).
- Şiddet: **Hayır** (oklar soyut şekillerdir, karakter ya da kan yok). Korku: **Hayır**. Cinsellik/çıplaklık: **Hayır**.
- Küfür veya kaba dil: **Hayır**. Uyuşturucu, alkol, tütün: **Hayır**.
- Kumar: gerçek parayla kumar **Hayır**, simüle kumar **Hayır** (ganimet kutusu ya da rastgele ödül satışı yok).
- Kullanıcı etkileşimi: kullanıcılar birbiriyle iletişim kurabiliyor mu **Hayır**, kullanıcı içeriği paylaşımı **Hayır**,
  konum paylaşımı **Hayır**.
- Dijital ürün satın alma: **Evet** (uygulama içi satın alma: "Reklamları kaldır").
- Sınırsız internet erişimi / tarayıcı: **Hayır**.
- Beklenen sonuç: PEGI 3 / USK 0 / ESRB Everyone, "Uygulama İçi Satın Alma" etiketiyle.

### Hedef kitle ve içerik
- Hedef yaş grupları: **13–15, 16–17, 18+** (13 yaş altını seçmeyin).
- **Neden 13+?** Oyun her yaşa uygun, ancak 13 yaş altı seçilirse uygulama Google Play **Aile Politikası** kapsamına girer.
  Bu durumda AdMob'da çocuklara yönelik işleme (`tagForChildDirectedTreatment`), kişiselleştirilmemiş reklam,
  reklam kimliğinin toplanmaması ve yalnızca "Aileler için sertifikalı" reklam kaynakları gerekir. Ek inceleme ve gelir kaybı da olur.
  Oyunu çocuklara yönelik olarak pazarlamıyoruz ve reklam içeriğini koddan genel izleyiciye uygun (PG) seviyeyle sınırladık.
- "Uygulamanız çocukların ilgisini çekebilir mi?" sorusu çıkarsa dürüst yanıt verin: renkli bir bulmaca olduğu için **Evet**
  denebilir. Bu durumda mağaza görsellerinde ve metinlerinde çocuklara hitap etmediğimizi açıklayın.
- **Kullanıcı çocuklara yönelik yayın isterse ne değişir (kısaca):** hedef kitleye 13 yaş altı eklenir; Aile Politikası şartları
  geçerli olur; koda `RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_TRUE` ve `MAX_AD_CONTENT_RATING_G` eklenir;
  `AD_ID` izni kaldırılır; Veri güvenliği formu güncellenir. Bu ayrı bir sürüm işidir ve bana söylemeniz yeterli.

### Veri güvenliği (Data safety)
> **Sürüm 1.1.2'den itibaren Firebase Analytics + Crashlytics eklendi: bu bölümdeki tablo eskidir, güncel form yanıtları [docs/19-firebase.md](19-firebase.md) §5'tedir.**

Genel sorular:
- Uygulama kullanıcı verisi topluyor ya da paylaşıyor mu: **Evet** (reklam SDK'sı nedeniyle).
- Aktarım sırasında tüm veriler şifreleniyor mu: **Evet** (AdMob ve Play Billing TLS kullanır).
- Kullanıcılar verilerinin silinmesini isteyebiliyor mu: **Evet**. Hesap yok ve oyun verisi yalnızca cihazda tutuluyor.
  Kullanıcı Ayarlar > İlerlemeyi sıfırla ile ya da uygulamayı kaldırarak silebilir. Reklam kimliği cihaz ayarlarından sıfırlanabilir veya silinebilir.
  Sorular için e-posta adresi gizlilik politikasında var.
- Hesap oluşturma: **Yok** (bu yüzden silme bağlantısı URL'si gerekmez).

Veri türleri (AdMob'un resmi açıklamasına göre, SDK 25.5.0):

| Veri türü (Play kategorisi) | Toplanıyor | Paylaşılıyor | Amaç | İsteğe bağlı mı |
|---|---|---|---|---|
| Konum > **Yaklaşık konum** (IP adresinden) | Evet | Evet (Google/AdMob) | Reklam, Analiz, Dolandırıcılık önleme | Zorunlu |
| Uygulama etkinliği > **Uygulama etkileşimleri** (açılış, dokunma, reklam görüntüleme) | Evet | Evet | Reklam, Analiz, Dolandırıcılık önleme | Zorunlu |
| Uygulama bilgileri ve performansı > **Tanılama** (performans, kilitlenme) | Evet | Evet | Analiz, Dolandırıcılık önleme | Zorunlu |
| Cihaz veya diğer kimlikler > **Cihaz veya diğer kimlikler** (reklam kimliği, uygulama seti kimliği) | Evet | Evet | Reklam, Analiz, Dolandırıcılık önleme | Zorunlu |
| Finansal bilgiler > **Satın alma geçmişi** ("Reklamları kaldır" satın alımı, Google Play Billing) | Evet | Hayır | Uygulama işlevleri | Zorunlu |

Notlar:
- Oyunun kendisi (ilerleme, yıldız, jeton, ayarlar) **cihazdan çıkmaz**. Sunucumuz yok ve bu veriler "toplanan veri" sayılmaz.
- Ödeme bilgileri (kart vb.) Google Play'de kalır, bize ulaşmaz. "Satın alma geçmişi" satırı temkinli bir beyandır.
- Bölgesel onay: AEA/BK/İsviçre'de kişiselleştirilmiş reklamdan önce UMP formuyla onay alınır.

### Diğer beyanlar
- Haber uygulaması: **Hayır** · COVID-19 temaslı takip/durum uygulaması: **Hayır** · Devlet uygulaması: **Hayır**
- Finansal özellikler: **Yok** · Sağlık: **Yok** · Kullanıcı kaynaklı içerik: **Yok**
- Ön kayıt (pre-registration): isteğe bağlı, gerek yok.

---

## 8. Gizlilik politikası URL'si

Play herkese açık, giriş istemeyen ve PDF olmayan bir web adresi ister. Gizlilik sayfası hazır: `dist/privacy-site/`
(`privacy.html` 4 dilde; dil `?lang=tr|en|de|ar` ile seçilir).

### Seçenek A: GitHub Pages (önerilen, ücretsiz)
1. <https://github.com> adresinde ücretsiz hesap açın.
2. **New repository**: adını `KULLANICI.github.io` koyun (KULLANICI = GitHub kullanıcı adınız). **Public** seçin.
   (Bu ad sayesinde ileride `app-ads.txt` dosyası da kök adreste çalışır.)
3. **Add file > Upload files**: `dist/privacy-site/` klasörünün **içindekileri** (privacy.html, index.html, css/, js/, assets/)
   sürükleyip bırakın ve **Commit changes** deyin.
4. **Settings > Pages**: Source **Deploy from a branch**, Branch **main / (root)** seçip **Save** deyin. 1–2 dakika bekleyin.
5. Adres: `https://KULLANICI.github.io/privacy.html`. Tarayıcıda açıp 4 dili deneyin.
6. Bu adresi Play Console > **Uygulama içeriği > Gizlilik politikası** alanına yazın.
7. Aynı adresi `android/app/src/main/res/values/ads.xml` içindeki `privacy_policy_url` alanına da yazın
   (uygulama içinden açılmasına izin verilen tek dış web adresi budur).

### Seçenek B: Google Sites
<https://sites.google.com> adresinde yeni bir site açın, "Arrowtile Gizlilik Politikası" sayfası ekleyin, oyundaki gizlilik metnini
(4 dil alt alta) yapıştırın ve **Yayınla** deyin. Kolaydır, ancak metin değişince elle güncellemeniz gerekir. app-ads.txt için uygun değildir.

### Not: Artifact olarak yayın
Gizlilik sayfasını ben bir claude.ai Artifact sayfası olarak da yayınlayabilirim. Ancak Artifact sayfaları varsayılan olarak
**gizlidir** ve oturum isteyebilir. Play'in istediği "herkese açık, giriş istemeyen" şartını güvenilir biçimde karşılamaz.
Bu yüzden Play'e GitHub Pages ya da Google Sites adresini verin.

## 9. Destek e-postası
**nilkaren.tuncay.demir@gmail.com**. Play Console > Mağaza ayarları > İletişim bilgileri alanına yazın.
Bu adres oyunun Ayarlar > Destek bölümünde ve gizlilik politikasında zaten var.

## 10. Mağaza girişi

- **Metinler:** başlık, kısa açıklama ve uzun açıklama 4 dilde `docs/07-magaza-metinleri.md` dosyasında
  (karakter sınırları denetlendi). Play Console > **Ana mağaza girişi** bölümüne Türkçe metni girin, ardından
  **Çeviri ekle** ile en-US, de-DE ve ar dillerini ekleyip ilgili metinleri yapıştırın.
- **Grafikler** (`dist/Arrowtile-store-assets.zip`):
  - Uygulama simgesi: `play-icon-512.png` (512×512, 32-bit PNG)
  - Özellik grafiği: `feature-graphic-<dil>.png` (1024×500). Her dilin girişine kendi dilindeki grafiği yükleyin.
  - Telefon ekran görüntüleri: `screenshots/<dil>/01…06.png` (1080×1920, 9:16), her dilde 6 adet.
    Sıra: ana menü, kolay seviye, aşırı zor seviye, harita, günlük bulmaca takvimi, günlük tahta.
- **Kategori:** Oyunlar › **Bulmaca**.
- **Etiketler** (Play en fazla 5 etiket seçtirir): *Bulmaca*, *Mantık*, *Beyin oyunları*, *Çevrimdışı*, *Tek oyunculu*
  (listede bunların karşılığını seçin; bulunamayanların yerine *Gündelik* ya da *Minimalist* seçilebilir).
- **İletişim:** e-posta (yukarıda). Web sitesi alanına GitHub Pages adresi (`https://KULLANICI.github.io`) yazılabilir.

---

## 11. Yayın öncesi kontrol listesi

- [ ] `res/values/ads.xml`: üç AdMob kimliği **kendi** kimliklerinizle değiştirildi. (Release'te hâlâ `ca-app-pub-3940256099942544` varsa gelir gelmez.)
- [ ] `privacy_policy_url` gerçek, herkese açık adres; Play Console'daki adresle aynı.
- [ ] AdMob'da GDPR mesajı oluşturuldu ve yayınlandı.
- [ ] Hata ayıklama kancası kapalı: uygulama `index.html` adresini `?debug=1` OLMADAN açıyor (MainActivity `START_URL`). Değiştirmeyin.
- [ ] `versionCode` her yüklemede artırıldı. `versionName` doğru (1.0.0). Oyundaki "Sürüm" yazısı da 1.0.0.
- [ ] `targetSdk = 36` (Play şartı). AAB **release** derlemesi ve yükleme anahtarıyla imzalı.
- [ ] Yükleme anahtarı (`.jks`) ve şifreler iki ayrı güvenli yerde yedekli.
- [ ] Gerçek cihazda **release** sürümüyle (dahili test parçasından kurup) şunlar denendi:
  - [ ] Bölüm 1'de (seviye 1–12) hiç reklam yok. 13+ seviyelerde seviye sonu "Devam" sonrası reklam geliyor, kapanınca oyun sürüyor.
  - [ ] "Can bitti" penceresinde ödüllü reklam +1 can veriyor. Mağazada ödüllü reklam +1 ipucu veriyor. Reklam yarıda kapanınca ödül yok.
  - [ ] Uçak modunda oyun normal açılıyor ve oynanıyor, reklam ve satın alma "İnternet yok" diyor.
  - [ ] **Lisans test kullanıcısıyla** "Reklamları kaldır" satın alındı, geçiş reklamları kalktı. Uygulama silinip kurulunca
        "Satın alımları geri yükle" düğmesi sahipliği geri getirdi. Yavaş test kartıyla bekleyen ödeme "ödeme bekleniyor" mesajı verdi.
  - [ ] AB'de olmayan bir cihazda UMP testi için: `src/debug/res/values/ads.xml` içinde `ump_debug_geography_eea=true` ve
        Logcat'teki test cihazı kimliğiyle debug sürümünde form ve Ayarlar'daki **Gizlilik seçenekleri** düğmesi görüldü.
  - [ ] Geri tuşu: oyunda duraklatma menüsünü açıyor, menülerde bir önceki ekrana dönüyor, ana menüde uygulamadan çıkıyor.
  - [ ] Destek e-postası bağlantısı e-posta uygulamasını açıyor. Durum çubuğu ve çentik oyunun üstünü kapatmıyor.
  - [ ] Arapça seçilince arayüz sağdan sola, tahta aynalanmıyor.

## Bilinen notlar
- Tabletlerde (en kısa kenarı 600 dp ve üstü) Android 16 yön kilidini yok sayabilir. Manifestte geçici muafiyet var.
  Oyunun CSS'i yatay ekrana da uyum sağlıyor.
- 360 px genişlikte harita ekranının başlığı ("Seviye Haritası" / Arapça karşılığı) yıldız sayacı büyüyünce iki-üç satıra
  bölünüyor (ekran görüntüsü 04'te görülüyor). Oyun kodunda küçük bir düzeltme önerisi: harita başlığında yıldız hapı daralınca başlığı kısaltmak.
- Arapça ekran görüntüleri bu ortamdaki tek Arapça yazı tipi (DejaVu Sans) ile alındı. Cihazda Noto Naskh/Sans Arabic ile daha güzel görünür.
  İsterseniz Arapça görüntüleri emülatörden yeniden alabilirsiniz.
- Satın alma doğrulaması cihazda yapılıyor, sunucu yok. Bu ölçekteki bir oyun için yaygın bir yöntem.
- Sahiplik iade edilirse (refund) yerel taraf bunu bir sonraki açılışta görür. Oyunun kendi kaydındaki reklamsızlık bayrağı ise kalır.

## Kaynaklar
- Hedef API şartı: <https://developer.android.com/google/play/requirements/target-sdk>
- Yeni kişisel hesaplar için test şartı (12 kişi, 14 gün): <https://support.google.com/googleplay/android-developer/answer/14151465>
- Play Billing sürüm notları ve zorunlu sürüm: <https://developer.android.com/google/play/billing/release-notes>
- Play Billing entegrasyonu (pending, acknowledge): <https://developer.android.com/google/play/billing/integrate>
- AdMob test reklam birimleri: <https://developers.google.com/admob/android/test-ads>
- AdMob Android SDK sürüm notları: <https://developers.google.com/admob/android/rel-notes>
- UMP SDK kurulumu: <https://developers.google.com/admob/android/privacy>
- UMP sürüm notları: <https://developers.google.com/ad-manager/dynamic-ad-insertion/sdk/android/privacy/release-notes>
- AdMob için Play Veri güvenliği açıklaması: <https://developers.google.com/admob/android/privacy/play-data-disclosure>
- AGP 9.5.0 sürüm notları: <https://developer.android.com/studio/releases/gradle-plugin>
- AGP 9.0 davranış değişiklikleri: <https://developer.android.com/build/releases/agp-9-0-0-release-notes>
- AndroidX kararlı sürümler: <https://developer.android.com/jetpack/androidx/versions/stable-channel>

## İlerleme
- [x] 1. Gradle projesi (android/, Kotlin DSL, AGP 9.5.0 + Gradle wrapper 9.6.0, compileSdk/targetSdk 36, minSdk 24, com.arrowtile.puzzle 1/1.0.0, 4 dilde "Arrowtile", dikey, RTL). Burada derlenemedi: Google Maven erişimi ve Android SDK yok (eklenti çözümlenemedi); oyun dosyası eşitleme görevi Gradle 8.14.3 ile ayrı denendi, çalışıyor.
- [x] 2. MainActivity (WebViewAssetLoader https://appassets.androidplatform.net/, dış adres engeli, mailto + gizlilik URL dışarıda, geri tuşu → JS, edge-to-edge güvenli alan, izinler). Sahte Android sınıflarıyla javac derlemesi geçti.
- [x] 3. AndroidBridge (ads.js'teki 7 metod + privacyOptionsRequired/showPrivacyOptions + vibrate/setSystemBarsDark). Java köprüsünün ürettiği betikler gerçek ads.js'e verildi: 9/9 geçti.
- [x] 4. AdMob (play-services-ads 25.5.0): geçiş + ödüllü, önceden yükleme; kimlikler res/values/ads.xml (Google test kimlikleri), debug her zaman test (src/debug).
- [x] 5. UMP 4.0.0 onay akışı + Ayarlar'da 4 dilde "Gizlilik seçenekleri" düğmesi (yalnızca köprü varsa ve gerekliyse). validate-i18n geçti (197 anahtar), test-ads 32/32.
- [x] 6. Play Billing 9.1.0: remove_ads, acknowledge, açılış/onResume/geri yükle sorgusu, SharedPreferences, bekleyen (pending) satın alma.
- [x] 7. İmzalama: keystore.properties'ten okuyan signingConfig + keystore.properties.example; R8 açık + JS arayüzü keep kuralları (README ayrıntıları 10. maddeyle).
- [x] 8. İkonlar: adaptive (foreground/background/monochrome) 5 yoğunlukta + eski tip ic_launcher/ic_launcher_round (API 24-25) + store/play-icon-512.png (512x512 RGBA, 16 KB). Üretici: tools/android/make-icons.py.
- [x] 9. Mağaza görselleri: store/feature-graphic-{tr,en,de,ar}.png (1024x500, Arapça RTL) + store/screenshots/<dil>/ 6'şar adet 1080x1920 (ana menü, kolay seviye 5, aşırı zor seviye 100, harita, günlük bulmaca takvimi, günlük tahta). Gerçek oyun, ?debug olmadan (kanca yok, denetlendi). Üretici: tools/android/make-store-assets.py. Not: bu ortamda Arapça yazı tipi yalnızca DejaVu Sans.
- [x] 10. Bu belge (adım adım yükleme, form yanıtları, gizlilik URL, fiyat önerisi, kontrol listesi) + android/README.md + dist/privacy-site/ (yüklemeye hazır gizlilik sayfası).
- [x] 11. dist/Arrowtile-android-v1.0.0.zip (android/, build ve .gradle hariç, assets/www dolu; 358 KB) + dist/Arrowtile-store-assets.zip (35 dosya, 5,2 MB).
- [x] Doğrulama: e2e 315/315, qa 157/157, test-ads 32/32, validate-i18n geçti, Java köprü → ads.js 9/9 (tools/android/verify-bridge/run.sh). Gradle/AAB derlemesi YAPILAMADI (SDK ve Google Maven yok).
- [x] 12. (08.11.2026) CI ile imzalı AAB ve gizlilik sayfası: `.github/workflows/release.yml` (elle çalışır, secrets: `docs/14-ci-imzali-derleme.md`), `.github/workflows/pages.yml` (GitHub Pages → `https://ttuncaydemirr-beep.github.io/Arrowtile/privacy.html`; Ayarlar > Pages kaynağı "GitHub Actions" olmalı), `AppInfo.privacyPolicyUrl` güncellendi. Henüz çalıştırılıp doğrulanmadı; anahtar ve secrets kullanıcıdadır.
