# Arrowtile

Süre sınırı olmayan, internetsiz oynanan ok bulmacası. Oklara dokun, yolu açık olanı tahtadan çıkar, tahtayı boşalt.

- 216 hazır seviye, ardından sonsuz bölümler (3 kolay → 3 orta → 2 zor → 1 aşırı zor döngüsü)
- Düz ve kıvrımlı oklar, günlük bulmaca, ok temaları, rahat mod
- 4 dil: Türkçe, English, Deutsch, العربية (sağdan sola)
- Reklam yalnızca seviye sonunda (en erken 3 seviyede bir, ilk 12 seviye reklamsız) + tek seferlik "reklamları kaldır"

Destek: nilkaren.tuncay.demir@gmail.com

## Klasörler

| Klasör | İçerik |
|---|---|
| `flutter/arrowtile/` | **Asıl uygulama** (Flutter). Play Store'a buradan derlenir. Ayrıntı: [README](flutter/arrowtile/README.md) |
| `game/` | Web önizleme / referans sürüm (HTML5). Kurallar önce burada denenir, sonra Flutter'a taşınır |
| `tools/` | Seviye üretici, doğrulayıcılar, testler, Flutter dönüştürme betikleri |
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
```

## Otomatik derleme (GitHub Actions)

Her `main` güncellemesinde `.github/workflows/ci.yml` çalışır: web doğrulamaları, `flutter analyze`, `flutter test` ve test amaçlı bir debug APK. APK, çalıştırmanın "Artifacts" bölümünden indirilebilir. İmzalı yayın paketi (AAB) bilerek CI'da üretilmez; imza anahtarı yalnızca geliştiricinin bilgisayarında durur.

## Güvenlik notu

Bu depo herkese açıktır. İmza anahtarları (`*.jks`, `key.properties`) `.gitignore` ile dışarıda tutulur; asla eklemeyin. Depodaki AdMob kimlikleri Google'ın test kimlikleridir.
