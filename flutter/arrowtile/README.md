# Arrowtile (Flutter)

Süre yok, internetsiz ok bulmacası. Bu proje, web sürümünün (`../../game/`) **birebir aynı davranışlı** Flutter karşılığıdır:
aynı kurallar, aynı 200 hazır seviye (5.000 seviyeye kadar tasarlanmış, sonrası sonsuz), aynı belirlenimli seviye üretici (aynı tohum → aynı seviye), aynı günlük bulmaca, aynı ekonomi,
aynı reklam kuralları, dört dil (Türkçe, İngilizce, Almanca, Arapça/RTL). Android uygulama kimliği: `com.arrowtile.puzzle`.

> **Önemli — bu kod henüz hiç derlenmedi.** Teslimin hazırlandığı ortamda Flutter/Dart SDK yoktu ve indirilemiyordu.
> Kod, paketlerin GitHub kaynaklarındaki gerçek API'lerine bakılarak yazıldı; ancak ilk `flutter pub get / analyze / test`
> sizde çalışacak. Aşağıdaki "İlk derleme" adımlarını sırayla izleyin; hata çıkarsa hata metnini olduğu gibi iletin.

## 1. Kurulum

1. **Flutter stable** kurun (önerilen sürüm 3.41 veya üstü): <https://docs.flutter.dev/get-started/install>
   (Android Studio + Android SDK Platform 36 + JDK 17; Flutter, JDK'yı Android Studio ile birlikte bulur).
2. `flutter doctor` çalıştırın; kırmızı maddeleri giderin. Lisanslar için: `flutter doctor --android-licenses`.
3. Proje klasörüne girin ve bağımlılıkları alın:

```bash
cd flutter/arrowtile
flutter pub get          # paketleri indirir; android/local.properties'i de yazar
flutter gen-l10n         # lib/l10n/app_*.arb → lib/l10n/app_localizations*.dart (pub get / run da bunu otomatik yapar)
flutter analyze          # kaynak denetimi (ilk derlemede çıkan uyarıları bana iletin)
flutter test             # birim testleri + JS'ten üretilmiş altın testler (aşağıya bakın)
flutter run              # bağlı telefonda / emülatörde debug (test reklamları)
flutter build appbundle --release   # Play'e yüklenecek imzalı AAB (önce §2)
```

Çıktı: `build/app/outputs/bundle/release/app-release.aab`. Sürüm numarası `pubspec.yaml` içindeki `version: 1.1.2+6` satırındadır
(`1.1.2` = versionName, `+6` = versionCode). Play'e her yüklemede `+N` kısmını 1 artırın.

### Android klasörü
`android/` el ile hazırlandı (Flutter şablonuyla aynı yapı: AGP 9.3.1, Kotlin 2.4.20, Gradle 9.5.0, compileSdk/targetSdk 36,
minSdk 24, dikey yön, R8). Gradle sarmalayıcı dosyaları (`gradlew`, `gradle-wrapper.jar`) ve `local.properties` Flutter aracı
tarafından otomatik eklenir. Sizin Flutter sürümünüz farklı şablon üretiyorsa ve Gradle/AGP sürüm hatası alırsanız:

```bash
mv android android_backup
flutter create --platforms=android --org com.arrowtile --project-name arrowtile .
bash tool/restore_android_overlay.sh android_backup     # manifest, ikonlar, AdMob kimliği, R8 kurallarını geri koyar
# sonra android/app/build.gradle(.kts) içine imzalama + targetSdk 36 ayarlarını ekleyin (android_backup/app/build.gradle.kts'ye bakın)
```

## 2. İmzalama (key.properties)

Play'e yüklenecek AAB **yükleme anahtarıyla** imzalanmalıdır. Anahtarı bir kez oluşturun ve güvenli iki yerde yedekleyin:

```bash
keytool -genkey -v -keystore ~/arrowtile-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Sonra `android/key.properties.example` dosyasını `android/key.properties` olarak kopyalayıp doldurun:

```properties
storeFile=/TAM/YOL/arrowtile-upload.jks
storePassword=DEPO_SIFRESI
keyAlias=upload
keyPassword=ANAHTAR_SIFRESI
```

`key.properties` ve `.jks` dosyaları `.gitignore`'dadır; **asla paylaşmayın**. Dosya yoksa release derlemesi *debug anahtarıyla*
imzalanır (`flutter run --release` çalışır) ama Play bu paketi **reddeder**.

## 3. AdMob kimlikleri nerede değişir?

| Ne | Nerede | Not |
|---|---|---|
| AdMob **uygulama** kimliği (`ca-app-pub-…~…`) | `android/app/src/main/res/values/ads.xml` → `admob_app_id` | release için. Debug, `src/debug/res/values/ads.xml` içindeki **test** kimliğini kullanır (değiştirmeyin). |
| Geçiş + ödüllü + banner **reklam birimi** kimlikleri (`ca-app-pub-…/…`) | `lib/config/ads_config.dart` → `releaseInterstitialId`, `releaseRewardedId`, `releaseBannerId` | yalnız release derlemesinde kullanılır; debug/profile her zaman Google test birimleridir. |
| Satın alma ürünü | Play Console'da `remove_ads` (tüketilmeyen); kod: `AdsConfig.removeAdsProductId` | kimlik koddakiyle birebir aynı olmalı. |
| UMP (AB/BK onay formu) | AdMob > Gizlilik ve mesajlaşma'da GDPR mesajı oluşturup yayınlayın | emülatörde AEA'yı taklit için `ads_config.dart` → `umpDebugGeographyEea`, `umpTestDeviceId` (yalnız debug). |
| Gizlilik politikası adresi | `lib/config/ads_config.dart` → `AppInfo.privacyPolicyUrl` | Play Console'a girilen adresle aynı olmalı. |

Release derlemesinde Ayarlar'ın altında hâlâ test kimlikleri kullanılıyorsa küçük bir uyarı satırı görünür (gelir getirmez).
Ayrıntılı Play Console adımları: `../../docs/10-play-store-yukleme.md` ("Flutter ile derleme" bölümü).

## 4. Testler

`flutter test` şunları çalıştırır (`test/`):

| Dosya | Ne doğrular |
|---|---|
| `rng_test.dart` | RNG ve FNV özeti, **JS çıktısıyla bit bit aynı** (`test/golden/rng_golden.json`) |
| `levelgen_golden_test.dart` | v1.1: `specFor/seedFor/sizeOfChapter`; seviye **4, 7, 9, 38, 201, 204, 207, 209** ok listesi JS ile birebir; rastgele örneklenmiş + sabit seçilmiş seviyelerde (1, 200, 201, her kademe, 1619, 5000) **`levelHash` == `tools/level-hashes.json`**; 5001+ altın özet; paket (200) özetleri |
| `chapter_name_test.dart` | bölüm adları: 18 ad döngü + Roma rakamı, 4 dil (Arapça LRI/PDI) |
| `daily_test.dart` | **7 tarih** için günlük bulmaca JS ile birebir; seri/kupa kuralları |
| `engine_test.dart` | çözüm sırası, ipucu, renklendirme, dokunuş sonuçları (5 seviye × 5 oyun senaryosu) |
| `solvable_test.dart` | 200 hazır seviyenin hepsi: yapı + çözülebilirlik + par + kademe |
| `economy_test.dart` | jeton ödülü, bölüm bonusu, günlük ödül, ipucu harcama, **kayıt onarımı/göçü** (`freeUndos`), yedek kodu (JS ile birebir) |
| `ads_rules_test.dart` | reklam sıklığı, bölüm 1 reklamsız, 3 dk aralık, çevrimdışı, satın alma/geri yükleme, ödüllü, UMP (sahte saat + sahte platform); v1.1: **banner yalnızca menü/harita, adFree'de asla**, önceden yükleme (yinelenen yükleme yok), reklamda duraklatma dinleyicisi |
| `l10n_test.dart` | ARB anahtar ve yer tutucu eşitliği (4 dil) |

Altın dosyaları yeniden üretmek (web sürümü değişirse): proje kökünden `node tools/flutter/make-goldens.js`.
Diğer araçlar: `export-levels.js`, `export-arb.js`, `check-arb.js`, `render-sfx.js` (hepsi `tools/flutter/`).

**RNG/seviye altın testi başarısız olursa** (en olası ilk sorun): hangi test ve hangi `reason` metni (örn. "ok #17 hücreler …")
çıktığını iletin. Dart `int` 64 bit olduğundan `|0`, `>>>0`, `Math.imul` davranışları `lib/core/rng.dart` içinde her işlemin
yanında açıklamalı olarak taklit edilir; testler bunu kullanıcı tarafında doğrular.

## 5. Proje yapısı

```
lib/
  main.dart, app.dart          giriş, MaterialApp (dil, tema, RTL, toast)
  config/ads_config.dart       AdMob kimlikleri, destek e-postası, sürüm
  core/                        SAF DART (Flutter'a bağımlı değil; birim testlenir)
    rng.dart levelgen.dart engine.dart daily.dart
    economy.dart save_data.dart ads_rules.dart models.dart
  services/                    kayıt, ses, titreşim, AdMob+UMP, Play Billing
  state/                       AppController (ChangeNotifier), AppScope
  ui/                          tokens, board_painter (CustomPainter), widgets, screens/
  l10n/                        app_{tr,en,de,ar}.arb  (+ gen-l10n çıktısı)
  data/levels.json             200 hazır seviye
assets/sfx/*.wav               audio.js sentezinden render edilmiş sesler
assets/images/icon.png         menü logosu
android/                       Android projesi (com.arrowtile.puzzle)
test/ test/golden/             birim + altın testler
tool/restore_android_overlay.sh
```

## 6. Sık hatalar

| Belirti | Çözüm |
|---|---|
| `flutter.sdk not set in local.properties` | `flutter pub get` çalıştırın (dosyayı Flutter yazar). |
| `Version solving failed` / SDK sürümü uyuşmuyor | Flutter'ı güncelleyin (`flutter upgrade`); en az 3.38.1, önerilen ≥ 3.41. |
| `Target of URI doesn't exist: …/app_localizations.dart` | `flutter gen-l10n` çalıştırın. |
| Gradle/AGP/Kotlin sürüm hatası | §1 "Android klasörü" altındaki yeniden üretme adımları. |
| `SDK location not found` / lisans hatası | Android Studio > SDK Manager'dan Platform 36 kurun; `flutter doctor --android-licenses`. |
| Play "debug anahtarıyla imzalı" diyor | `android/key.properties` yok/yanlış; §2. |
| Release'te reklam gelmiyor / gelir yok | `ads_config.dart` ve `ads.xml` hâlâ Google test kimlikleri olabilir (§3). Yeni birimlerin dolması saatler sürebilir. |
| UMP formu görünmüyor | AdMob'da GDPR mesajı yayınlanmamış; AB dışındaysanız form zaten çıkmaz. |
| `remove_ads` bulunamadı (günlükte) | Ürün Play Console'da oluşturulup **etkinleştirilmeli**, AAB en az dahili testte yüklü olmalı, test hesabı lisans testçisi olmalı. |
| Ses yok | Cihaz sessiz modda olabilir; Ayarlar > Ses açık mı? Emülatörde ses çıkışını açın. |
| `Illegal argument in isolate message` | `AppController`'da `Isolate.run` kapanışları yalnızca üst düzey işlevlerde kurulmalı (kodda öyledir; değiştirirken dikkat). |
| `flutter test` yavaş | 22x31 aşırı zor seviye altın testleri JIT'te birkaç saniye sürer; normal. |

## 7. Web sürümüyle bilinçli farklar
Bkz. `../../docs/11-flutter-tasima.md` ("Web → Flutter bilinçli farklar"): Material simgeler, `Listener` tabanlı yakınlaştırma,
önceden render edilmiş WAV sesler.
