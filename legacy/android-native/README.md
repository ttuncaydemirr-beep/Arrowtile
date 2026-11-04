# Arrowtile — Android projesi

HTML5 oyunu (`../game/`) tam ekran bir WebView içinde çalıştıran Android Studio projesi.
Reklam: Google AdMob (geçiş + ödüllü) · Onay: UMP · Satın alma: Google Play Billing (`remove_ads`).

| Ayar | Değer |
|---|---|
| applicationId | `com.arrowtile.puzzle` |
| versionCode / versionName | 1 / 1.0.0 |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 |
| Android Gradle Plugin / Gradle | 9.5.0 / 9.6.0 (wrapper) |
| Dil | Java 17 |
| Kütüphaneler | androidx.activity 1.13.0, androidx.webkit 1.18.0, play-services-ads 25.5.0, UMP 4.0.0, Play Billing 9.1.0 |

> Bu proje Android SDK'nın ve Google Maven deposunun olmadığı bir ortamda hazırlandı, bu yüzden orada **derlenmedi**.
> İlk derleme Android Studio'da yapılacak. Studio bir sürüm uyarısı verirse (örneğin "AGP sürümünü yükselt" ya da
> "bir kütüphane daha yüksek compileSdk istiyor") önerilen düzeltmeyi kabul edin. `targetSdk 36` olarak kalmalı.

## Klasörler

```
android/
  app/src/main/java/com/arrowtile/puzzle/
    MainActivity.java     WebView, güvenli alan, geri tuşu, dış bağlantılar
    AndroidBridge.java    window.AndroidBridge (game/js/ads.js'in beklediği metodlar)
    AdsManager.java       AdMob geçiş + ödüllü reklam (önceden yükleme)
    ConsentManager.java   UMP onay formu + "Gizlilik seçenekleri"
    BillingManager.java   Play Billing: remove_ads, acknowledge, pending
    WwwPathHandler.java   https://appassets.androidplatform.net/ → assets/www/
  app/src/main/assets/www/   oyun dosyaları (derlemede ../game/ klasöründen otomatik kopyalanır)
  app/src/main/res/values/ads.xml    AdMob kimlikleri (YAYINDAN ÖNCE DEĞİŞTİR)
  app/src/debug/res/values/ads.xml   debug derlemesi: her zaman Google test kimlikleri
  keystore.properties.example        imza ayarları şablonu
```

## Oyun dosyaları tek kaynaktan gelir

Oyunun kendisini yalnızca `../game/` klasöründe düzenleyin. Her derlemede `syncGameAssets` görevi bu klasörü
`app/src/main/assets/www/` içine eşitler. Elle eşitlemek isterseniz proje kökünden `bash tools/sync-android.sh` çalıştırın.
`android/` klasörü tek başına açılırsa (yanında `game/` yoksa) içindeki `assets/www` olduğu gibi kullanılır.

## Android Studio'da açma ve deneme

1. Android Studio'nun güncel kararlı sürümünü kurun.
2. **File > Open** ile bu `android/` klasörünü seçin. Gradle eşitlemesi (sync) bitene kadar bekleyin. SDK Platform 36 ister, kurun.
3. Telefonu USB hata ayıklama açıkken bağlayın (ya da bir emülatör açın) ve ▶ **Run** düğmesine basın.
   Debug derlemesi her zaman **test reklamları** gösterir ("Test Ad" etiketli). Bu normaldir.
4. Debug derlemesinde Chrome'da `chrome://inspect` adresinden WebView konsolunu görebilirsiniz.

## Yayından önce AdMob kimlikleri

`app/src/main/res/values/ads.xml` içinde üç değer var: uygulama kimliği (`~` içerir), geçiş reklamı birimi ve ödüllü
reklam birimi. Bu değerleri AdMob hesabınızda oluşturduğunuz kimliklerle değiştirin (docs/10 §2).
`src/debug/...` dosyasına dokunmayın: geliştirme sırasında gerçek reklama tıklamak AdMob hesabını riske atar.

## İmzalı AAB üretme (Google Play'e yüklenen dosya)

Play'e APK değil **AAB** (Android App Bundle) yüklenir. İki yol var, birini seçin.

### Yol A: Android Studio sihirbazı (en kolayı)
1. **Build > Generate Signed App Bundle or APK…** menüsüne gidin, **Android App Bundle** seçeneğini seçip **Next** deyin.
2. **Key store path** altında **Create new…** deyin (ilk sefer):
   - Dosya yeri: projenin DIŞINDA güvenli bir klasör, örneğin `Belgeler/anahtarlar/arrowtile-upload.jks`
   - Şifre: güçlü bir şifre seçip parola yöneticinize kaydedin
   - Alias: `upload`, geçerlilik süresi: 25 yıl ya da daha uzun, ad soyad / ülke (TR) alanlarını doldurun
3. **Next** deyip **release** seçeneğini seçin, **Create** deyin.
4. Dosya `app/release/app-release.aab` konumunda oluşur.

### Yol B: keystore.properties ile (komut satırı / sürekli kullanım)
1. `keystore.properties.example` dosyasını `keystore.properties` adıyla kopyalayın ve dosya yolu ile şifreleri yazın.
2. Android Studio'da **Build > Generate App Bundles or APKs > Generate Bundle(s)** menüsünü kullanın
   ya da terminalde `./gradlew bundleRelease` komutunu çalıştırın.
3. Çıktı `app/build/outputs/bundle/release/app-release.aab` konumunda olur.

`keystore.properties` ve `.jks` dosyaları `.gitignore` içinde. **Bu dosyaları asla paylaşmayın.** Yedeğini iki ayrı güvenli yerde tutun.

### Play App Signing (Play uygulama imzalama)
Play Console'da ilk AAB'yi yüklerken **Play App Signing** varsayılan olarak açıktır. Asıl uygulama imzalama anahtarını
Google saklar. Sizin oluşturduğunuz `.jks` yalnızca **yükleme anahtarıdır** (upload key). Bu anahtarı kaybederseniz
Play Console > Kurulum > Uygulama imzalama sayfasından yükleme anahtarı sıfırlama talebinde bulunabilirsiniz.
Uygulama yine de yayında kalır.

## Kod küçültme (R8)
Release derlemesinde `isMinifyEnabled` ve `isShrinkResources` açık. `proguard-rules.pro` dosyası
`@JavascriptInterface` metodlarını korur. Bu kural olmazsa oyun reklam ve satın alma köprüsünü bulamaz.
Release derlemesini yayından önce gerçek cihazda mutlaka deneyin (docs/10 "Yayın öncesi kontrol listesi").

## Köprü denetimi (SDK gerekmez)
`bash ../tools/android/verify-bridge/run.sh` komutu Java kodunu sahte Android sınıflarıyla derler, köprünün ürettiği
yanıtları gerçek `game/js/ads.js` dosyasına verir ve sonucu denetler. Bu denetim gerçek SDK ile derlemenin yerini tutmaz.
