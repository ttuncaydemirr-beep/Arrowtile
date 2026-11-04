# legacy/ — arşiv (artık güncellenmez)

Kullanıcı kararı (02.11.2026): Arrowtile'ın yayın sürümü **Flutter** projesidir (`../flutter/arrowtile/`).
Burada saklananlar yalnızca başvuru içindir:

- `android-native/` — WebView + Java köprüsü (AdMob/UMP/Billing) ile paketlenmiş ilk Android projesi (`com.arrowtile.puzzle`, 1.0.0).
  Gradle 8/9 ile ayrıca derlenmemiştir; Flutter sürümünde aynı davranış `lib/services/` içinde Dart ile yeniden yazılmıştır.
  Yol notu: `android-native/app/build.gradle.kts` oyun dosyalarını `../../game/` (proje kökü) klasöründen eşitler.
- `sync-android.sh` — `game/` klasörünü `android-native/app/src/main/assets/www/` altına kopyalar.

Web sürümü (`../game/`) **referans uygulama** olarak kalır: Flutter altın testleri onun çıktısından üretilir
(`node tools/flutter/make-goldens.js`).
