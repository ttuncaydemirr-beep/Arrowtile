# Arrowtile Flutter — bağımsız kod incelemesi (02.11.2026)

Gözden geçiren: kodu yazmayan, bağımsız bir inceleme oturumu. Bu ortamda Dart/Flutter SDK yoktur; bu yüzden "derleyici" görevi
satır satır okuma, JS referansıyla yan yana karşılaştırma, küçük Node yoklamaları ve paketlerin GitHub kaynağının okunmasıyla yapıldı.
**Hiçbir şey derlenmedi ve çalıştırılmadı**; aşağıdaki "kesin" ifadeler okumaya dayanır (bkz. §4 sınırlar).

## 1. Özet sayılar

| Konu | Sayı |
|---|---|
| İncelenen Dart dosyası | 39 (lib 30 + test 9; ~7 600 satır lib, ~850 satır test) |
| İncelenen diğer dosya | 4 ARB (192 anahtar × 4 dil), pubspec, l10n.yaml, analysis_options, Android (gradle ×4, manifest ×3, XML kaynakları, 25 PNG), 6 altın JSON |
| JS ile satır satır karşılaştırılan modül | rng, levelgen (456 satır JS), engine, daily, storage (ekonomi/sanitize/yedek kodu), ads, theme.drawArrow/drawBoard, main.js'in oyun/harita/mağaza/takvim bölümleri |
| Kaynağıyla doğrulanan paket API çağrısı | 45'ten fazla (aşağıda §3) |
| Derleme engelleyici hata | **0** |
| Çalışma hatası | **0** |
| Davranış farkı (web'e göre, istenmeyen) | **0** |
| Küçük sertleştirme (düzeltildi) | **5** |
| Yanlış alarm olarak elenen şüphe | 9 (§2.2) |
| Düzeltilemeyen / doğrulanamayan nokta | 8 (§4) |

Beklenenden temiz çıktı. Bu, kodun derleneceği anlamına gelmez; yalnızca okunarak bulunabilecek bir hatanın kalmadığı anlamına gelir.

## 2. Düzeltilenler ve elenen şüpheler

### 2.1 Düzeltilenler

| # | Önem | Dosya:satır | Ne idi | Ne yapıldı | Kaynak |
|---|---|---|---|---|---|
| 1 | küçük (çalışma sağlamlığı) | `lib/services/audio_service.dart:74` | `AudioPool.start()` bir `Future<StopFunction>` döndürür; `_play` içindeki `try/catch` yalnızca eşzamanlı hatayı yakalıyordu. Platform kanalı hatası "yakalanmamış asenkron hata" olurdu. | `.then<void>((_) {}, onError: …)` ile asenkron hata yutuldu (oyun sessiz devam eder, web'deki `safe()` ile aynı). | `bluefireteam/audioplayers` `audio_pool.dart` (`Future<StopFunction> start`) |
| 2 | küçük (bellek) | `lib/ui/widgets.dart:31,38` | `FitText._fits` her kurulumda en çok ~20 deneme × (1 + kelime sayısı) `TextPainter` üretiyor, hiçbiri `dispose` edilmiyordu (yerel paragraf nesneleri GC'ye kalıyordu). | Her `TextPainter` ölçümden hemen sonra `dispose()` edilir; sonuç aynı. | Flutter `TextPainter.dispose` |
| 3 | küçük (savunma) | `lib/ui/widgets.dart:76,79` | `Pressable` işaretçi kalkış/iptal olaylarında `setState` çağırıyor; öğe işaretçi basılıyken ağaçtan kalkarsa "setState after dispose" olurdu. | `&& mounted` koruması eklendi. (Normal dokunuşta sıra zaten güvenli: Listener kalkışı, `onTap` hakem süpürmesinden önce işlenir.) | Flutter `GestureBinding` sırası |
| 4 | küçük (analiz uyarısı) | `test/levelgen_golden_test.dart:4` | `models.dart` içe aktarması kullanılmıyordu → `flutter analyze` "unused_import" uyarısı. | İçe aktarma kaldırıldı. | — |
| 5 | küçük (yanıltıcı yorum) | `lib/core/ads_rules.dart:4` | Üstteki açıklama olmayan `services/ads_platform.dart` dosyasına gönderme yapıyordu (`AdsPlatform` aynı dosyada, uygulaması `services/ads_service.dart`'ta). | Yorum düzeltildi. | — |

Ayrıca `tools/flutter/check-arb.js` yeniden çalıştırıldı: **GEÇTİ** (192 anahtar × 4 dil, yer tutucu eşitliği, i18n.js ile değer eşitliği, Dart'taki 184 `loc.xxx` kullanımı ARB'de var). Zip yeniden üretildi (§5).

### 2.2 Şüphelendim, kaynakla doğrulayıp elemedim (yanlış alarm)

| Şüphe | Sonuç |
|---|---|
| `final double t = x.clamp(0.0, 1.0)` — `num.clamp` `num` döner, `double`'a atanamaz mı? | Dart, `a.clamp(b, c)` doğrudan çağrısında a, b, c aynı türdeyse (int/double) sonuç türünü o türe daraltır (Flutter'ın `no_double_clamp` kuralının yorumları da bunu doğrular: doğrudan çağrı `int`, tear-off `num`). Kodda yalnızca doğrudan çağrılar var → hata yok. |
| `map_screen.dart` zor/aşırı bölüm başlığı: `BorderDirectional(start: …)` + `borderRadius` → debug'da "borderRadius can only be given for uniform borders" onayı? | Flutter `box_border.dart` (`paintNonUniformBorder` yolu): görünen renk tek ise (`visibleColors.length == 1`) düzgün olmayan kenar + yarıçap izinli. Hata yok. |
| `app.dart` builder'ında `Theme.of(c)` tema üstünde mi, yoksa açık tema mı dönüyor (koyu kip paleti hiç uygulanmaz)? | `MaterialApp._materialBuilder` `widget.builder`'ı `AnimatedTheme` altında, ayrı bir `Builder` bağlamıyla çağırır (kaynakta açık yorum var). Doğru. |
| `Navigator.pop()` programatik çıkışı `PopScope(canPop: false)` ile engellenir mi (oyun ekranı, sonuç/ölüm pencereleri)? | Hayır; `PopScope` yalnızca sistem geri hareketini/`maybePop`'u keser. `goToMap`/`popUntil`/`pop` çalışır. |
| `levelgen.dart` `_pow16` tablosu `Math.pow(m+0.5, 1.6)` ile birebir mi? | Node ile 41 değerin tamamı `!==` karşılaştırmasıyla denendi: 0 fark. Tablo indeks aralığı (0..30) tahta ölçülerini (≤ 22×31) kapsıyor. |
| `rng.dart` / `fnv32` 64-bit `int` ile 32-bit JS davranışını veriyor mu? | Dart kaynağındaki işlemler satır satır BigInt (`asIntN(64)`) ile yeniden uygulanıp `rng_golden.json`'a karşı denendi: 9 tohum × 64 değer + 8 özet, 0 fark (yazarın yoklamasından bağımsız ikinci yoklama). |
| Android `build.gradle.kts` Kotlin eklentisiz `kotlin { compilerOptions … }` bloğu ve `android.builtInKotlin=false` hatalı mı? | Flutter `main` şablonu (`android-kotlin.tmpl`, `android.tmpl/gradle.properties.tmpl`) ile birebir aynı; Flutter Gradle eklentisi Kotlin'i bağlar. Şablon sürümleri (Gradle 9.5.0, AGP 9.3.1, KGP 2.4.20, compile/targetSdk 36, minSdk 24) `gradle_utils.dart` ile eşleşiyor. |
| `l10n.yaml`'da `synthetic-package` yok → çıktı nereye gider, `import 'l10n/app_localizations.dart'` bulunur mu? | `flutter_tools` kaynağında `synthetic-package` kaldırılmış (verilirse uyarı/hata); çıktı `arb-dir` (= `lib/l10n`). Doğru. |
| Aynı `admob_app_id` hem `main/res/values` hem `debug/res/values` içinde → "Duplicate resources"? | Hayır; kaynak kümeleri öncelikle birleşir, debug ana kümeyi geçersiz kılar. |

## 3. Alan alan sonuçlar

### 3.1 Derleme engelleyiciler (öncelik 1)
- Tüm 39 Dart dosyasında içe aktarma çözümlemesi betikle denendi (her proje simgesi, bildirildiği dosyayı içe aktaran dosyalarda kullanılıyor); üretilen `app_localizations.dart` hariç eksik yok. Kullanılmayan tek içe aktarma `levelgen_golden_test.dart`'taydı (düzeltildi).
- Üye kullanımı betikle denendi (`app.*`, `pal.*`, `g.*`, `th.*`, `res.*`, `eco.*`, `dl.*`, `Shape.*`, `Anim.*`, `AdsConfig.*`, `AppInfo.*`): tanımsız üye yok. Tüm `Icons.*` (20 simge) Flutter `icons.dart` içinde var. `Palette` alanları (int) yalnızca `rgba(...)` ile Color'a çevriliyor; Color beklenen yerde int geçen çağrı yok.
- Yapıcı çağrıları: zorunlu adlandırılmış parametreler, konumlu parametre sayıları ve sırası (ör. `LevelResult` 9, `GenResult` 5, `Tier` 6, `StreakInfo` 4) tüm çağrı yerlerinde eşleşiyor.
- Boş değer güvenliği, `late`, `switch` kapsamı (`BtnKind` 6, `PurchaseStatus` 5, `PurchaseOutcome` 5 değer — hepsi kapsanmış), kayıtlar (`(int, List<int>?)`), `Isolate.run` kapanışlarının yalnızca basit parametre yakalaması, `async` sonrası `context` kullanımı (`mounted`/`ctx.mounted`/yakalanmış `nav`) incelendi: hata yok.
- l10n: ARB anahtarlarının hepsi geçerli Dart tanımlayıcısı, ayrılmış sözcük/`Object` üyesi çakışması yok; 21 yer tutuculu metnin hepsi fonksiyon olarak doğru sırada ve doğru türle (`int`/`String`) çağrılıyor; hiçbir yer tutuculu anahtar getter olarak kullanılmıyor; ARB'lerde sahipsiz `{`, `}` veya `'` yok (ICU ayrıştırma hatası çıkmaz). `nullable-getter: false` ile `AppLocalizations.of(context)` `!` olmadan kullanılıyor — tutarlı.
- Proje simgeleri Flutter/paket simgeleriyle çakışmıyor (`Shape`, `Level`, `Game`, `Tier`, `Palette`, `Monetization`, `PurchaseResult` … hiçbiri `material`, `google_mobile_ads` veya `in_app_purchase` dışa aktarımlarında yok).

### 3.2 Paket API'leri (öncelik 2) — GitHub kaynağıyla
Kaynak okuma: `googleads/googleads-mobile-flutter` (etiket `v9.2.0`; `main` ile `lib/` arasında tek satır fark var), `flutter/packages` (`in_app_purchase_android-v0.5.5` etiketi `main` ile aynı, `in_app_purchase` 3.3.1), `bluefireteam/audioplayers` (6.8.1; `AudioPool.create(audioContext:)` 6.5.1 etiketinde de var), `benjamindean/flutter_vibration` (3.2.1), `flutter/flutter` (şablonlar, `MediaQuery`, `PopScope`, `box_border`, `app.dart`).

| Paket | Doğrulanan çağrılar (hepsi doğru) |
|---|---|
| google_mobile_ads | `MobileAds.instance.initialize()`, `updateRequestConfiguration(RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg))`; `InterstitialAd.load(adUnitId, request, adLoadCallback)`, `RewardedAd.load(adUnitId, request, rewardedAdLoadCallback)`; `InterstitialAdLoadCallback/RewardedAdLoadCallback(onAdLoaded, onAdFailedToLoad(LoadAdError))`; `FullScreenContentCallback<T>(onAdDismissedFullScreenContent, onAdFailedToShowFullScreenContent(T, AdError))`; `ad.show()` / `RewardedAd.show(onUserEarnedReward: (AdWithoutView, RewardItem))`; `LoadAdError.code/message`; `ConsentInformation.instance.requestConsentInfoUpdate(params, onSuccess, onFailure(FormError))`, `getPrivacyOptionsRequirementStatus()` (Future) + `PrivacyOptionsRequirementStatus.required`, `canRequestAds()`; `ConsentForm.loadAndShowConsentFormIfRequired(cb(FormError?))`, `ConsentForm.showPrivacyOptionsForm(cb)`; `ConsentRequestParameters(tagForUnderAgeOfConsent, consentDebugSettings)`, `ConsentDebugSettings(debugGeography, testIdentifiers)`, `DebugGeography.debugGeographyEea`. `pubspec` `^9.1.0` aralığı: `v9.1.0` ve `v9.2.0` etiketleri var. |
| in_app_purchase (+android) | `InAppPurchase.instance.isAvailable/purchaseStream/queryProductDetails(Set<String>)/buyNonConsumable(purchaseParam:)/completePurchase/restorePurchases`; `PurchaseParam(productDetails:)`; `PurchaseStatus.{pending,purchased,error,restored,canceled}`; `PurchaseDetails.pendingCompletePurchase`; `GooglePlayPurchaseDetails.billingClientPurchase.purchaseState` + `PurchaseStateWrapper.purchased` (içe aktarımlar `billing_client_wrappers.dart` ve `in_app_purchase_android.dart` doğru). Android `restorePurchases` boş liste de yayınlar → `BillingService`'in "boş liste = geri yükleme yanıtı" varsayımı doğru; hata durumunda istisna atar → kodun `catch`'i doğru. |
| audioplayers | `AudioPool.create(source, maxPlayers, playerMode, audioContext)`, `pool.start()`, `pool.dispose()`, `AssetSource('sfx/x.wav')` (`assets/` önekini önbellek ekler), `AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build()`, `PlayerMode.lowLatency`. |
| vibration | `Vibration.hasVibrator()` (`Future<bool>`), `Vibration.vibrate(duration:)`, `Vibration.vibrate(pattern:)`. Not: 3.2.0'dan itibaren Dart ≥ 3.11 / Flutter ≥ 3.41 ister; daha eski Flutter'da pub 3.1.x'i seçer (hata değil). |
| shared_preferences / url_launcher | `SharedPreferences.getInstance/getString/setString/remove`, `launchUrl(Uri, mode: LaunchMode.externalApplication)`; etiketler `shared_preferences-v2.5.x`, `url_launcher-v6.3.x` mevcut. Manifest'te `mailto`/`https` `<queries>` var. |

### 3.3 Birebirlik (öncelik 3)
- **rng.dart / fnv32**: JS ile aynı; bağımsız 64-bit yoklaması 0 fark.
- **levelgen.dart**: `rand()` çağrı sırası ve sayısı, kısa devre (`k > 1 && curvy && rand() < turnP`), `pickLen` (önce `rand()`, sonra toplam), `pickDir` (tablo), `snake`, `flip`, `shuffle`, adım 1–7, `genJob`/`levelJob`, `specFor`, `seedFor` JS ile satır satır karşılaştırıldı: fark yok. Kritik noktalar: (a) `reduce()` içinde `i2` ve `snapshot` takma adı doğru (anlık görüntü `old` ile geri yazılıyor, `where` kapanışı döngü başı değeri yakalıyor); (b) 4b'de `saved` kopyası ve `L.arrows = saved`; (c) adım 7'deki kararsız `sort` eşitlikte indeksle karşılaştırılarak JS'in kararlı sıralamasına eşitlenmiş (`free` zaten artan indeksli); (d) `analyze()`'ın JS'teki paylaşımlı arabellek/EPOCH optimizasyonu yerine her çağrıda yeni dizi + `i+1` damgası kullanması sonucu değiştirmez (damga her çağrıda sıfırdan başlar); (e) `HashSet` kullanılmıyor — `Set<int> own` yalnızca üyelik sorgusu, yineleme yok; (f) `curvedRatio()` 0 ok için JS gibi `NaN` (Dart `0/0` istisna atmaz); (g) `Math.round` yalnızca pozitif değerlerde, Dart `round()` ile aynı.
- **engine.dart** (`colorize` yedek dalı dahil), **daily.dart** (UTC gün farkı, `weekday-1`, `recordSolve` saat-geri dalı), **economy.dart** (`levelReward` `floor(x+0.5)`; yedek kodu alan sırası `JSON.stringify(state)` ile aynı), **save_data.dart** (`jsInt` = `Math.floor(Number(v))` + `isFinite` + kırpma; `stars` anahtarı kırpma çakışması dahil 26 `sanitize` vakası elle izlendi), **ads_rules.dart**: JS ile eşdeğer. Bilinçli fark: `continueAfterLevel` önce `platform.interstitialReady` bakar (JS'te köprü "reklam hazır mı" bilmez); hazır değilse sayaç sıfırlanmaz — docs/11'deki tasarımla uyumlu.
- **Testler altın verileri doğru yüklüyor mu?** `golden()` yolu proje köküne göre (flutter test CWD'si) doğru; JSON şekilleri (`engine_golden.json` bir dizi, `levels[].level/measure`, `specs[].spec/seed0/seed3`, `puzzles[].puzzle`, `steps[].r/dp`, `bad[].code/parsed`, `ads_golden` `ops/log`) test kodunun beklediği anahtarlarla eşleşiyor. `make-goldens.js`'teki `run()` ile `engine_test.dart`'taki `run()` aynı politikaları uyguluyor. 216 hazır seviye `levels.js` ile `levels.json` arasında alan alan eşit (0 fark).
- **theme.js ↔ board_painter.dart**: gövde/baş/şevron/nokta geometrisi, `arcTo` taklidi (teğet uzaklığı `r/tan(θ/2)`, dönüş yönü), tepsi/nokta ızgarası, alt kalınlık gölgesi aynı. İpucu halkası nabzının web'de etkisiz olduğu not edilmiş ve korunmuş.

### 3.4 Android (öncelik 4)
`applicationId`/`namespace` `com.arrowtile.puzzle` = `MainActivity.kt` paketi; `minSdk 24`, `compileSdk`/`targetSdk 36`; `key.properties` okuma (`rootProject.file`, dört alan dolu değilse debug imzası), R8 + kaynak küçültme, `proguard-rules.pro` mevcut; manifest: `INTERNET`, `ACCESS_NETWORK_STATE`, `AD_ID`, `VIBRATE`, AdMob `APPLICATION_ID` (`@string/admob_app_id`, debug'da test kimliği), `flutterEmbedding=2`, `enableOnBackInvokedCallback=true` (PopScope için gerekli), `screenOrientation=portrait`, `queries` (PROCESS_TEXT, mailto, https). İkon kaynakları: 5 yoğunluk × (ic_launcher, _round, _foreground, _background, _monochrome) PNG ve `mipmap-anydpi-v26` adaptif XML'leri mevcut; `launch_background` → `@color/app_bg` (açık/koyu) var. Billing izni eklentiden birleşir.

### 3.5 Arayüz (öncelik 5)
- **RTL**: yön `Locale(app.lang)` ile `MaterialApp`'ten gelir; tahta `Listener`+`CustomPainter` ile mutlak koordinatta çizilir (yönden etkilenmez, yani "LTR sabit"); sayısal rozetler/yıldızlar/jetonlar ve yedek kodu alanı açıkça `TextDirection.ltr`; harita yolu RTL'de aynalanır; mini harita RTL'de karşı köşede; ileri/geri okları `Icons.arrow_*` ile otomatik aynalanır.
- **Güvenli alan**: her ekran `SafeArea`; ekran dışı katman `MediaQuery.paddingOf` ile alt boşluğu ekler; `edgeToEdge` + şeffaf çubuklar.
- **Yaşam döngüsü**: `GameScreen` `_ticker`, `_heartCtl`, `_repaint`, tüm `Timer`'lar ve gözlemci `dispose`'ta temizleniyor; `_hud()` `mounted` korumalı; `_later` oturum+`mounted` korumalı; `_ToolButton`/`_BouncingHand`/`StarsBig` denetleyicileri `dispose` ediliyor; `AdsCard` zaman uyumsuz sonuçlarda `mounted` bakıyor; `MapScreen` kaydırıcısı `dispose` ediliyor; `purchaseStream` aboneliği `BillingService.dispose`'ta iptal.
- **async sonrası context**: `flow.dart` yalnızca önceden yakalanmış `nav` kullanır; sonuç pencereleri `ctx.mounted`/`mounted` bakar.

## 4. Düzeltilemeyen / doğrulanamayan noktalar

1. **Gerçek derleme yok.** Dart tip çıkarımı, kullanım dışı (deprecated) API bilgisi ve analiz lint'leri okumayla %100 doğrulanamaz. Özellikle `flutter_lints` bilgi düzeyi uyarıları (`prefer_const_constructors`, `prefer_const_literals_to_create_immutables`, bazı `deprecated_member_use`) kaynakta çok sayıda olabilir; hata değildir.
2. **Cihazda davranış**: AdMob/UMP formu, Play Billing (`remove_ads`), `AudioPool` `lowLatency` modu, `vibration` desenleri, kenardan kenara + dikey kilit, tahta dokunuş/yakınlaştırma hissi yalnızca cihazda sınanabilir.
3. **Paketlerin pub.dev'deki yayımlanmış hali**: API'ler yukarıdaki etiketli sürümlerin GitHub kaynağında doğrulandı; pub.dev arşivinin bu kaynakla bayt bayt aynı olduğuna dair bağımsız kanıt yok (etiketler mevcut ve `main` ile aynı/yakın olduğundan risk düşük).
4. **Gradle/AGP**: `android/` Flutter `main` şablonuna (AGP 9.3.1, Gradle 9.5.0, KGP 2.4.20) eşittir. Kullanıcının kurduğu Flutter sürümünün şablonu farklıysa Flutter aracı sürüm uyarısı verebilir; çözüm README §1 "Android klasörü" (yeniden üretme + `tool/restore_android_overlay.sh`).
5. **`AppInfo.privacyPolicyUrl`** hâlâ yer tutucu (`https://KULLANICI.github.io/…`) ve kodda hiçbir yerde kullanılmıyor (oyun içi politika ekranı ayrı). Play Console'a girilecek gerçek adres için yalnızca belge amaçlı; yayından önce değiştirilmeli veya sabit kaldırılmalı. Davranış değişikliği olmasın diye dokunulmadı.
6. **Ayarlar → Dışa/İçe aktar**: `TextEditingController`'lar `dispose` edilmiyor (iki küçük nesne). Pencere kapanış animasyonu sırasında alan hâlâ ekranda olduğundan `dispose` etmek "kullanılmış denetleyici" hatası riski taşır; bilerek bırakıldı.
7. **Web'e göre bilinçli ama belgelenmesi gereken fark**: Flutter'da `AdsPlatform.available` her zaman `true` (web'deki "köprü yok → test modu" yalnızca birim testlerinde). Play Store'suz emülatörde "Reklamları kaldır" `unavailable → failed/offline` sonucu verir, test modu gibi taklit edilmez.
8. **Karakter ölçümü**: `FitText` ölçümü `TextPainter` ile yapılır; CSS'in hecelemesiyle (`hyphens: auto`) birebir aynı satır kırılması garanti edilemez (kelime ortadan bölünmez; sığmazsa yazı küçülür).

## 5. Kullanıcı ilk `flutter pub get / analyze / test` çalıştırdığında en olası kalan hatalar (olasılık sırasıyla)

1. **`flutter analyze` ilk anda onlarca "Target of URI doesn't exist: …/app_localizations.dart"** — üretilen dosya yok. Çözüm: önce `flutter gen-l10n` (README'de var). Bu hata geçince analiz çıktısı kısalır.
2. **Analiz bilgi/uyarı seviyesi**: `prefer_const_constructors` / `prefer_const_literals_to_create_immutables` (çok sayıda), olası `deprecated_member_use` (Flutter 3.41'de eskiyen bir üye), `unused_*`. Hata değildir; tek tek düzeltilebilir.
3. **Sürüm çözümü**: `Flutter < 3.38.1` ise `google_mobile_ads 9.x` yüzünden "Version solving failed" (Flutter'ı yükseltin). `Flutter 3.38–3.40` ise `vibration` 3.1.x seçilir (sorun değil).
4. **Gradle**: ilk `flutter run`'da AGP/Gradle/KGP sürüm uyarısı veya JDK 17 gereksinimi; `android/local.properties` yoksa `flutter pub get` yazar. Uyuşmazlıkta README yedek yolu.
5. **`flutter test`**: kodun mantığı yukarıdaki karşılaştırmaya göre altın verilerle uyumlu olmalı. Başarısız olursa en olası yer `levelgen_golden_test` / `daily_test` (156 satırlık algoritmada tek `rand()` farkı); hata metni "ok #N hücreler …" gibi ilk farkı gösterir — o metni iletin. Testler JIT'te yavaş olabilir (zaman aşımları 5–10 dk).
6. **Çalışma anı (debug)**: UMP/Billing/AdMob günlük satırları (`remove_ads bulunamadı`, `UMP update: …`) — Play Console'da ürün/ileti yapılandırması bitene dek normal.

## 6. Dosya değişiklik özeti

`lib/services/audio_service.dart`, `lib/ui/widgets.dart`, `lib/core/ads_rules.dart` (yalnızca yorum), `test/levelgen_golden_test.dart` (içe aktarma). Başka dosyaya dokunulmadı; JS referansıyla farklılaştıran hiçbir değişiklik yapılmadı.
