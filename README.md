# Arrowtile

Süre sınırı olmayan, internetsiz oynanan ok bulmacası. Oklara dokun, yolu açık olanı tahtadan çıkar, tahtayı boşalt.

- 5.000 seviye (500 bölüm × 10 seviye; ilk 200'ü pakette hazır, gerisi oyunda belirlenimli üretilir), ardından sonsuz devam; zorluk seviye bazında döner (bölümde 3 kolay → 3 orta → 2 zor → 2 aşırı zor)
- Düz ve kıvrımlı oklar, günlük bulmaca, ok temaları, rahat mod
- 4 dil: Türkçe, English, Deutsch, العربية (sağdan sola)
- Reklam: seviye sonunda geçiş reklamı (en erken 3 seviyede bir, ilk 12 seviye reklamsız) + yalnızca Ana menü ve Harita'da banner + tek seferlik "reklamları kaldır"

Destek: nilkaren.tuncay.demir@gmail.com

## Klasörler

| Klasör | İçerik |
|---|---|
| `flutter/arrowtile/` | **Asıl uygulama** (Flutter). Play Store'a buradan derlenir. Ayrıntı: [README](flutter/arrowtile/README.md) |
| `game/` | Web önizleme / referans sürüm (HTML5). Kurallar önce burada denenir, sonra Flutter'a taşınır |
| `tools/` | Seviye üretici, doğrulayıcılar, testler, Flutter dönüştürme betikleri |
| `design/` | Renk kaynağı `colors.json` (web ve Flutter renkleri buradan üretilir) ve tasarım sistemi `system/` (marka kitabı, token'lar, 25 bileşen). Ayrıntı: [design/README](design/README.md) |
| `docs/` | Tasarım belgeleri, test raporları, Play Store yükleme rehberi (`docs/10`) |
| `store/` | Mağaza ikonu, özellik grafikleri ve ekran görüntüleri (4 dil) |
| `dist/privacy-site/` | GitHub Pages için gizlilik politikası sayfası |
| `legacy/android-native/` | Eski WebView tabanlı Android projesi (arşiv, güncellenmez) |

## Hızlı başlangıç (Flutter)

```bash
cd flutter/arrowtile
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run
```

Yayın paketi: `android/key.properties` doldurulduktan sonra `flutter build appbundle --release`.

## Web önizleme testleri (Node 20+)

```bash
node tools/validate-levels.js
node tools/validate-i18n.js
node tools/test-ads.js
node tools/test-daily.js
node tools/gen-tokens.js --check
node tools/contrast.js
```

**Renkler:** bir rengi yalnızca `design/colors.json` içinde değiştirin, sonra `node tools/gen-tokens.js` çalıştırın. Betik `game/css/style.css`, `game/js/theme.js` ve `flutter/arrowtile/lib/ui/tokens.dart` içindeki `@tokens` bölgelerini yeniden yazar; `tools/contrast.js` kontrast eşiklerini denetler. Bu bölgeler elle düzenlenirse CI hata verir.

## Otomatik derleme (GitHub Actions)

| Workflow | Ne zaman çalışır | Ne yapar |
|---|---|---|
| `ci.yml` (**CI**) | `main`'e her gönderimde ve her PR'da | Web doğrulamaları → `flutter analyze` + `flutter test` → yayın modunda deneme APK → APK'yı Android emülatöründe açıp çökme denetimi |
| `release.yml` (**Release AAB (imzalı)**) | Yalnızca elle: Actions → Run workflow | Play Store'a yüklenecek imzalı `app-release.aab`. Anahtar, AdMob kimlikleri ve Firebase `google-services.json` GitHub secrets'tan okunur; eksikse veya test kimliği girilmişse açıklayıcı hatayla durur. İsteğe bağlı 10. secret `PLAY_SERVICE_ACCOUNT_JSON` varsa ve `track` ≠ none ise AAB'yi doğrudan Play'e (iç/kapalı test) yükler. Kurulum: [docs/14](docs/14-ci-imzali-derleme.md), Play yükleme: [docs/25](docs/25-play-otomatik-yukleme.md) |
| `pages.yml` (**Gizlilik sayfası**) | `dist/privacy-site/` değişince ve elle | Gizlilik politikasını GitHub Pages'e yayınlar |

### Deneme APK (telefonda denemek için)

Her başarılı `main` derlemesinden sonra **Releases → Deneme APK** altında `Arrowtile-deneme.apk` güncellenir; telefondan doğrudan indirilip kurulabilir. Debug anahtarıyla imzalıdır, reklamlar test reklamıdır, satın alma çalışmaz ve **Play Store'a yüklenemez**.

### Play Store paketi (imzalı AAB)

1. Yükleme anahtarını oluştur ve 9 zorunlu secret'ı gir (sonuncusu Firebase `GOOGLE_SERVICES_JSON`; 10. `PLAY_SERVICE_ACCOUNT_JSON` isteğe bağlı): [docs/14-ci-imzali-derleme.md](docs/14-ci-imzali-derleme.md)
2. Her yüklemeden önce `flutter/arrowtile/pubspec.yaml` içindeki `version: 1.1.3+N` değerinde `N`'i (versionCode) bir artır.
3. **Actions → Release AAB (imzalı) → Run workflow** → bitince **Artifacts → arrowtile-release-aab**. İsteğe bağlı: `track` seçerek doğrudan Play'e yükle (bilgisayarsız; kurulum: [docs/25](docs/25-play-otomatik-yukleme.md)).
4. Play Console'a yükleme adımları ve form yanıtları: [docs/10-play-store-yukleme.md](docs/10-play-store-yukleme.md)

### Gizlilik politikası adresi

`https://ttuncaydemirr-beep.github.io/Arrowtile/privacy.html` (uygulamadaki `AppInfo.privacyPolicyUrl` ile aynı; Play Console'a da bu girilir).
İlk kez yayınlamak için bir kez: **Settings → Pages → Build and deployment → Source: "GitHub Actions"**, ardından **Actions → Gizlilik sayfası → Run workflow**.

## Yayına kalan adımlar

- [ ] Settings → Pages kaynağını "GitHub Actions" yap ve gizlilik sayfası workflow'unu çalıştır
- [ ] AdMob'da uygulama + 2 reklam birimi (geçiş, ödüllü) oluştur
- [ ] Yükleme anahtarını oluştur, yedekle ve 9 secret'ı gir ([docs/14](docs/14-ci-imzali-derleme.md); Firebase konsol adımları ve Veri güvenliği formu: [docs/19](docs/19-firebase.md))
- [ ] İmzalı AAB'yi derle, Play Console'da uygulamayı oluştur, `remove_ads` ürününü tanımla
- [ ] Kapalı test: 12 test kullanıcısı, 14 gün; ardından üretime yayın

## Güvenlik notu

Bu depo herkese açıktır. İmza anahtarları (`*.jks`, `key.properties`) `.gitignore` ile dışarıda tutulur; asla eklemeyin. Gerçek AdMob kimlikleri, Firebase `google-services.json` içeriği ve imza şifreleri yalnızca GitHub secrets'ta durur (`google-services.json` `.gitignore`'dadır); depodaki kimlikler Google'ın test kimlikleridir.
