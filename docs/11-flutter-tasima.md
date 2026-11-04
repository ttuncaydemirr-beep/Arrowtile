# Arrowtile — Flutter'a taşıma (kullanıcı kararı, 02.11.2026)

Kural (tüm projeler): önce web önizleme ile kurallar oturur, sonra aynı tasarım Flutter'a çevrilir. Arrowtile'ın web sürümü (game/) **referans uygulamadır**: davranış, metin, ekonomi, reklam kuralları birebir aynı olacak.

## Ortam kısıtı
- Bu ortamda Flutter/Dart SDK ve pub.dev erişilemez → burada derleme/çalıştırma YOK. Kod kaynak olarak teslim edilir; kullanıcı Android Studio/VS Code + Flutter ile derler.
- Telafi: (1) referans JS'ten üretilmiş "altın" test verileri + `flutter test` birim testleri (kullanıcı tek komutla çalıştırır); (2) Dart kodu bağımsız bir gözden geçirici tarafından satır satır incelenir; (3) belirsiz API'ler için resmi pub.dev/Flutter belgeleri kaynak gösterilir.

## Hedef
- Proje: `/home/claude/ok-kacis/flutter/arrowtile/` — paket adı `arrowtile`, applicationId `com.arrowtile.puzzle` (Android projesiyle aynı → Play'de aynı uygulama), versionName 1.0.0, versionCode 2 (eski native proje 1 kullanılmış olabilir; Play'e hiç yüklenmediyse 1 de olur — rehberde not).
- Flutter stable (güncel), Dart 3, null safety. Yalnız Android hedefi zorunlu; iOS klasörü oluşturulabilir ama yapılandırma kapsam dışı.
- Android: compileSdk/targetSdk 36, minSdk 24 (google_mobile_ads ne istiyorsa), dikey, edge-to-edge, R8.

## Mimari
- `lib/core/` — saf Dart, Flutter'a bağımlı değil (birim testlenebilir):
  - `engine.dart` (engine.js birebir: yılan oklar `{cells, dir}`, hareket/çarpma, can, yıldız, ipucu seçimi)
  - `levelgen.dart` (levelgen.js birebir; **aynı tohum → aynı seviye**; JS'teki RNG ve sıra birebir korunur ki sonsuz seviyeler ve günlük bulmaca web sürümüyle aynı olsun)
  - `daily.dart`, `economy.dart` (storage.js içindeki ekonomi/ödül/göç kuralları), `ads_rules.dart` (ads.js'teki sıklık kuralları)
- `lib/data/levels.json` (assets) — 216 hazır seviye, levels.js'ten dönüştürülür (node betiği `tools/flutter/export-levels.js`).
- `lib/l10n/` — `app_tr.arb, app_en.arb, app_de.arb, app_ar.arb` i18n.js'ten üretilir (betik `tools/flutter/export-arb.js`); `flutter gen-l10n`; Arapça RTL otomatik (Directionality), tahta `Directionality(textDirection: ltr)` ile sabit.
- `lib/ui/` — ekranlar: Menü, Harita (sonsuz bölüm), Oyun, Seviye sonu, Can bitti, Mağaza (temalar + güçlendirici + reklamları kaldır), Günlük ödül, Günlük bulmaca + takvim, Ayarlar (dil, ses, titreşim, görünüm, rahat mod, önce seç sonra fırlat, gizlilik seçenekleri, dışa/içe aktar, sıfırla, destek e-postası, gizlilik politikası, sürüm), Gizlilik politikası.
- Tahta: `CustomPainter` (theme.js drawArrow/drawBoard birebir oranlar: gövde %18, baş %42 / min 7 px, şevron hücre ≥22 px), `InteractiveViewer` yakınlaştırma ≤5×, mini harita, polyline isabet (eşik 0,5, belirsizlik 0,18), yılan animasyonu (AnimationController), çarpma sarsıntısı, reduced-motion (MediaQuery.disableAnimations).
- Kayıt: `shared_preferences`, anahtar `arrowtile.save.v1` ile aynı JSON şeması; bozuk veri → güvenli varsayılan.
- Ses: web'deki Web Audio sesleri kısa WAV dosyalarına render edilir (`tools/flutter/render-sfx` — Chromium OfflineAudioContext ile audio.js'teki sentezden) → `assets/sfx/*.wav`; çalma `audioplayers` veya `just_audio` (düşük gecikme). Titreşim `HapticFeedback` + gerekiyorsa `vibration` paketi.
- Reklam: `google_mobile_ads` (geçiş + ödüllü, UMP `ConsentInformation`/`ConsentForm`), kimlikler `lib/config/ads_config.dart` + AndroidManifest meta-data; debug'da daima test kimlikleri.
- Satın alma: `in_app_purchase` (remove_ads, tüketilmeyen; pending, restore, acknowledge/completePurchase).
- Bağımlılıklar yalnızca yaygın, bakımlı paketler; sürümler pubspec'te sabitlenir ve docs'ta kaynakla gösterilir.

## Kalite
- `test/` : engine, levelgen (altın: JS'ten üretilmiş seviye 217, 229, 300, 313 ve 5 günlük tarih için beklenen ok listesi JSON), çözülebilirlik (216 seviyenin hepsi), ekonomi, reklam kuralları (sahte saat), kayıt göçü, l10n anahtar eşitliği.
- `tools/flutter/make-goldens.js` altın dosyaları üretir.
- Bağımsız kod incelemesi (ayrı ajan) → `docs/12-flutter-inceleme.md`.

## Teslim
- `dist/Arrowtile-flutter-v1.0.0.zip` (build/.dart_tool hariç), `docs/10` yerine Flutter'a göre güncellenmiş yükleme rehberi bölümü (`flutter build appbundle`), mağaza görselleri aynı (store/).
- Native Android projesi (android/) arşivlenir: `legacy/`; artık güncellenmez.

## İlerleme
- [x] 1. Node araçları (`tools/flutter/`): `export-levels.js` (216 seviye → `lib/data/levels.json`), `export-arb.js` + `check-arb.js` (192 anahtar × 4 dil, `store.*`/`meta.dir`/`app.rotate` hariç; tipografik kesme), `render-sfx.js` (audio.js → 13 WAV, Chromium OfflineAudioContext, 276 KB), `make-goldens.js` (RNG/hash, seviye 217-229-300-313, 5 günlük tarih, motor senaryoları, ekonomi, yedek kodu, reklam kuralı). Hepsi çalıştırıldı.
- [x] 2. `lib/core/` saf Dart: `rng.dart`, `models.dart`, `engine.dart`, `levelgen.dart`, `daily.dart`, `save_data.dart`, `economy.dart`, `ads_rules.dart` yazıldı (DERLENMEDİ — Dart SDK yok). Sonraki: testler, proje iskeleti, servisler, arayüz.
- [x] 3. Proje iskeleti: `pubspec.yaml`, `l10n.yaml`, `analysis_options.yaml`, `android/` (Flutter şablonu AGP 9.3.1/Kotlin 2.4.20/Gradle 9.5.0 + com.arrowtile.puzzle, compile/targetSdk 36, minSdk 24, imzalama key.properties, manifest izinleri, AdMob uygulama kimliği, mipmap ikonları eski projeden taşındı). Birim testleri yazıldı: rng, levelgen (altın), daily, engine, solvable (216), economy/sanitize/yedek, ads_rules, l10n. Sonraki: servisler (kayıt, ses, titreşim, reklam/UMP, satın alma), arayüz.
- [x] 4. Servisler + arayüz yazıldı (DERLENMEDİ): `lib/services/` (kayıt, ses, titreşim, AdMob+UMP, Play Billing), `lib/state/` (AppController, AppScope), `lib/ui/` (tokens, board_painter = theme.js drawArrow/drawBoard, widgets, menü, harita, oyun, mağaza, ayarlar, gizlilik, günlük ödül, takvim), `lib/app.dart`, `lib/main.dart`, `lib/l10n/l10n_lookup.dart`. Sonraki: README, docs/10 "Flutter ile derleme", legacy taşıma, zip.

## Bağımlılıklar

Kaynak: bu ortamda pub.dev/storage.googleapis.com erişilemediğinden sürümler ve API'ler **GitHub kaynak depolarından** (31.10–02.11.2026 tarihli `main` dalı) okundu; kullanılan her API çağrısı o kaynakta doğrulandı. `pubspec.yaml` aralıkları (`^`) bu sürümleri kapsar; `flutter pub get` Flutter sürümünüzle uyumlu en yeni sürümü seçer ve `pubspec.lock` oluşturur.

| Paket | pubspec | Kaynakta okunan sürüm | Kaynak | Not |
|---|---|---|---|---|
| Flutter SDK | `flutter: ">=3.38.1"`, Dart `>=3.10.0` | şablon: AGP 9.3.1, Kotlin 2.4.20, Gradle 9.5.0, compile/targetSdk 36, minSdk 24 | github.com/flutter/flutter (`packages/flutter_tools/lib/src/android/gradle_utils.dart`, `templates/app/`) | önerilen: stable ≥ 3.41 |
| `google_mobile_ads` | `^9.1.0` | 9.2.0 (Android GMA SDK 25.5.0, UMP 4.0.0) | github.com/googleads/googleads-mobile-flutter `packages/google_mobile_ads` (`pubspec.yaml`, `CHANGELOG.md`, `lib/src/…`) | `InterstitialAd.load`, `RewardedAd.load`, `FullScreenContentCallback`, `ConsentInformation`, `ConsentForm.loadAndShowConsentFormIfRequired/showPrivacyOptionsForm`, `MobileAds.updateRequestConfiguration/initialize` |
| `in_app_purchase` | `^3.2.0` | 3.3.1 | github.com/flutter/packages `packages/in_app_purchase/in_app_purchase` | `purchaseStream`, `queryProductDetails`, `buyNonConsumable`, `completePurchase`, `restorePurchases` |
| `in_app_purchase_android` | `>=0.4.0 <1.0.0` | 0.5.5 (Play Billing Library 9.1.0) | github.com/flutter/packages `packages/in_app_purchase/in_app_purchase_android` | yalnız `GooglePlayPurchaseDetails.billingClientPurchase.purchaseState` (bekleyen ayrımı) için |
| `shared_preferences` | `^2.5.0` | 2.5.6 | github.com/flutter/packages `packages/shared_preferences/shared_preferences` | `getInstance/getString/setString/remove` |
| `url_launcher` | `^6.3.0` | 6.3.3 | github.com/flutter/packages `packages/url_launcher/url_launcher` | `launchUrl(Uri, mode: LaunchMode.externalApplication)` (mailto) |
| `audioplayers` | `^6.5.0` | 6.8.1 | github.com/bluefireteam/audioplayers `packages/audioplayers` | `AudioPool.create`, `PlayerMode.lowLatency`, `AudioContextConfig(focus: mixWithOthers)` |
| `vibration` | `^3.1.0` | 3.2.1 | github.com/benjamindean/flutter_vibration `vibration` | `Vibration.hasVibrator/vibrate(duration|pattern)` |
| `flutter_localizations`, `intl` | SDK / `any` | — | Flutter SDK | `flutter gen-l10n` (l10n.yaml; `synthetic-package` artık yok: çıktı `lib/l10n/`) |
| `flutter_lints` (dev) | `^6.0.0` | 6.0.0 | google_mobile_ads `pubspec.yaml` | — |

Bilinen belirsizlik: bu sürümler `main` dalından okundu; pub.dev'de yayımlanmış en yeni sürüm bundan eski olabilir (aralıklar bu yüzden geniştir). Bir API adı uyuşmazsa `flutter analyze` ilk derlemede gösterir.

## Web → Flutter bilinçli farklar
- Simgeler: web'deki satır içi SVG yerine Material simgeleri (jeton `monetization_on`, yıldız `star`, kalp `favorite`, el `touch_app` …).
- Yakınlaştırma/kaydırma: `InteractiveViewer` yerine ham işaretçi olayları (`Listener`) — web'deki pinch/pan/kenetleme ve isabet kuralları birebir korunur.
- Ses: aynı sentez, `OfflineAudioContext` ile WAV'a önceden render edildi (13 dosya); ardışık çıkış perdesi 3 kademe (0 / 0,5 / 1).
- İpucu halkası: web'de `globalAlpha` nabzı `drawArrow` tarafından sıfırlandığı için etkisizdi; Flutter'da da etkisizdir (davranış korunmuştur).
- Yedek kodu: JSON/base64/FNV biçimi aynı; `ARROWTILE1-…` kodları web ↔ Flutter arasında taşınır (altın testle sınanır).
- Sayfa yönü uyarısı (`app.rotate`) ve `?debug=1` kancası taşınmadı (Flutter'da dikey kilit var; hata ayıklama kancası yok).

- [x] 5. Belgeler ve taşıma: `flutter/arrowtile/README.md` (kurulum, imzalama, AdMob kimlikleri, sık hatalar), `docs/10` §3b "Flutter ile derleme", `tool/restore_android_overlay.sh` (Gradle şablonu uyuşmazsa yedek yol), native `android/` → `legacy/android-native/`, `tools/sync-android.sh` → `legacy/sync-android.sh` (+ `legacy/README.md`; `make-icons.py` artık Flutter `res/` klasörüne yazar). Sonraki: dist zip.
- [x] 6. `dist/Arrowtile-flutter-v1.0.0.zip` (build/.dart_tool/.gradle hariç; `flutter/`, `tools/flutter/`, `game/`, `docs/`, `legacy/README.md`).

## Doğrulama durumu (02.11.2026)

**Çalıştırılan (Node/Python, bu ortamda):** `export-levels.js` (216 seviye), `export-arb.js` + `check-arb.js` (192 anahtar × 4 dil; i18n.js ile değer eşitliği; Dart kaynağındaki 184 `loc.xxx` kullanımının ARB'de var olduğu), `render-sfx.js` (13 WAV, 276 KB), `make-goldens.js` (RNG/hash; seviye 217/229/300/313; 5 günlük tarih; 5 seviye × 5 motor senaryosu; ekonomi/sanitize/yedek kodu; 5 reklam senaryosu), mevcut JS testleri (`validate-i18n` 197 anahtar, `test-ads` 32/32, `test-daily` 14/14). Dart kaynaklarının parantez/tırnak dengesi betikle denendi (39 dosya temiz; bu tarama sırasında bir test dosyasındaki eksik `)` bulunup düzeltildi). RNG/FNV aritmetik mantığı Dart `int` (64 bit) anlamını `BigInt.asIntN(64)` ile taklit eden bağımsız bir Node yoklamasıyla JS'e karşı denendi (8 tohum × 5000 değer + 4 özet: birebir) — bu Dart derlemesinin yerine GEÇMEZ.

**Doğrulanamayan (Dart SDK yok):** derleme, `flutter analyze`, `flutter test` (özellikle `levelgen_golden_test`, `daily_test`, `engine_test`), cihazda çalışma, AdMob/UMP/Billing gerçek akışları, ses çalma, Gradle/AGP birleşimi.

**Riskli noktalar:** (1) paket API'leri GitHub `main` kaynağından doğrulandı ama yayımlanmış sürümlerle farklı olabilir; (2) `lib/core/levelgen.dart` JS'ten satır satır taşındı, 456 satırlık algoritmada tek bir `rand()` sırası farkı seviyeyi değiştirir — altın testler ilk koşuda bunu gösterir; (3) `android/` Flutter `main` şablonundan elle yazıldı (AGP 9.3.1 / Gradle 9.5.0); kullanıcının Flutter sürümü farklıysa README'deki yeniden üretme adımı; (4) `build()` içinde Dart `sort` kararlı olmadığından adım 7 için eşitlikte indeks kıyaslaması eklendi, `Math.pow` yerine V8 çıktısından üretilmiş tablo kullanıldı (son basamak farkı riski kapatıldı); (5) Dart-web hedefi desteklenmez (RNG 64-bit int ister).

- [x] 7. Bağımsız kod incelemesi (02.11.2026): `docs/12-flutter-inceleme.md` — derleme engelleyici/çalışma/davranış hatası 0; 5 küçük sertleştirme uygulandı; `check-arb.js` geçti; zip yeniden üretildi.
