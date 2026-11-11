# Arrowtile 1.2.0 — Flutter sürümü (versionCode 11)

Kaynak: `docs/24-surum-1-2-0-asama-a.md` (web önizleme, sahip onaylı), `docs/17` kararları. Dal: **`v1.2`** (origin/main + origin/v1.2-web birleşimi).
main'e birleştirilmedi; yönetici inceleyip birleştirir. `release.yml` tetiklenmedi.

## 0. Sahip yanıtları (web önizleme sonrası)

| # | Konu | Karar | Uygulama |
|---|---|---|---|
| 1 | Büyüme uzunluğu | `GROW_CHAPTERS = 9` onaylandı | değişmedi |
| 2 | Kolay/Orta tahta | **DEĞİŞİKLİK**: Kolay ve Orta, bölüm tahtasından KÜÇÜK tahtada | §1 (web + Flutter, özetler yeniden üretildi) |
| 3 | Varsayılan ok rengi | Renkli | `arrowColor: 'color'` varsayılan |
| 4 | Palet + yazı tipi | "Kum ve Mürekkep" + Readex Pro | §3.6 |
| 5 | Çıkış sırasında giriş kilidi | 110 ms; otomatik "önce seç" önerisi kaldırıldı | §3.2 |

## 1. Karar #2 — kademe tahtası (web `game/js/levelgen.js`, Dart `lib/core/levelgen.dart`)

Kural: **seviye tahtası = bölüm tahtası × kademe kenar yüzdesi**, en-boy oranı korunur, hiçbir kenar en küçük tahtanın (9x13) altına inmez.
Ayar sabiti `TIER_SIZE_PCT` / `kTierSizePct` (yalnızca tamsayı, yarım yukarı yuvarlama → Dart'ta aynı sonuç):

| Kademe | Kenar | Alan (bölüm 9) | Bölüm 9 (28x45) | Bölüm 5 (19x29) | Bölüm 3 (14x21) |
|---|---|---|---|---|---|
| Kolay | %71 | ≈ %50 (%45–55 bandı) | 20x32 | 13x21 | 10x15 |
| Orta | %85 | ≈ %72 (%68–78) | 24x38 | 16x25 | 12x18 |
| Zor | %95 | ≈ %90 (%85–95) | 27x43 | 18x28 | 13x20 |
| Aşırı zor | %100 | %100 | 28x45 | 19x29 | 14x21 |

Bölüm 1 (9x13) dört kademede de 9x13; bölüm 2'de Kolay 9x13, Orta 9x14 (alt sınır). Şekilli tahta kuralı değişmedi (yalnızca Aşırı zor, tahta ≥ 14 sütun).
Yan etki ve düzeltme: kademe tahtaları değişince Zor seviyelerin tohumlarla ürettiği oklar da değişti; bölüm 52'de "Aşırı zor ort. dönüş > Zor" kesin
sırası 2,88 < 2,92 ile bozuldu → Aşırı zor kabul eşiği `minTurns` 2,2 → **2,6** (seviye en çok 8 tur içinde bunu sağlıyor; 5.000 seviyede yumuşak kısıt dışı 0).
`LevelGen.VERSION` / `kGenVersion` = **v20.1** (eski sonsuz seviye önbelleği geçersizleşir). Tohum dizgisi değişmedi (`arrowtile-v20-<id>-<tur>`).

Doğrulayıcılar: `validate-levels.js` bölüm başına kademe tahtası kuralı (kademe içinde sabit, Kolay ≤ Orta ≤ Zor ≤ Aşırı zor, Aşırı zor = bölüm tahtası,
alan bantları); "ok sayısı alanla artar" denetimi yalnızca o kademenin tahtası en az %10 büyüdüyse (9x13 → 9x14 gibi tek satırda ok sayısı dalgalanır).

5.000 seviye (`node tools/verify-5000.js`, 2 işçi, 10 sn): hata 0, sıra ihlali 0, büyüme ihlali 0, yumuşak kısıt dışı 0, şekilli 776.
28x45 bölümünde ok sayısı K / O / Z / A: **121 / 129 / 114 / 81** (önce Kolay 244 kısa ok idi). Puan sırası K 46,1 < O 73,0 < Z 100,8 < A 120,1.

| Node 22 üretim (ms) | adet | ort | p50 | p95 | en çok |
|---|---|---|---|---|---|
| Kolay 20x32 | 135 | 1,2 | 1,1 | 1,7 | 5 |
| Orta 24x38 | 135 | 2,7 | 2,5 | 4,6 | 8 |
| Zor 27x43 | 135 | 9,0 | 8,1 | 17,8 | 26 |
| Aşırı zor 28x45 | 135 | 20,0 | 18,0 | 39,3 | 122 |

## 2. Birleştirme (A)

`git merge origin/v1.2-web` çakışmasız (birleşme tabanı 993f57a; main yalnızca Flutter/belgeler, v1.2-web yalnızca game/tools/docs değiştirmişti).
Korunanlar: 1.1.6 (`resizeToAvoidBottomInset`, ipucu varsayılanı 0, `layout_shrunk`), 1.1.4/1.1.5 reklam TUTMA + ses servisi + banner/AdBannerSlot +
tek titreşim, Firebase telemetri, Release AAB otomatik yükleme (docs/25).
web e2e beklentileri main'e uyarlandı: yeni oyuncu 0 ücretsiz ipucu (ipucu 50 jeton düşer), reklamda ses yalnızca reklam ekrana gelince (`shown`) susar
(sahte köprü artık `shown` olayını yolluyor), Sığdır geçişi (280 ms) bitmeden yakınlaştırma yapılmıyor. `qa.js` harita kaydırması 20'lik bölüme göre.
Sonuç: `e2e.js` 375/375, `qa.js` (bkz. §6), `validate-levels`, `validate-i18n` (240 anahtar), `verify-5000`, `test-ads` (119), `test-daily` (14) GEÇTİ.

## 3. Flutter'a taşınanlar (B)

### 3.1 Üretici (`lib/core/levelgen.dart`)
`build2`, `makeMask` (organic / ring / ringOrganic), `measure2`, `specFor` (bölüm/kademe/tahta/biçim), `seedFor`, `LevelJob` (8 tur), `canon` (maske dahil) +
FNV-1a `levelHash` JS ile satır satır aynı (aynı `rand()` sırası, tamsayı bölmeler, kayan nokta işlem sırası; `Math.floor(rand()*n)` → `(rand()*n).floor()`).
Günlük bulmaca eski üreticiyle (`build`/`generate`/`kTiers`) değişmeden üretilir (daily_golden aynı).
`Level` modeline `mask` (satır dizgileri) ve `inMask(x, y)` eklendi; JSON gidiş-dönüşü maskeyi korur (önbellek, izolat).

Altın testler (`test/levelgen_golden_test.dart`, veri `tools/flutter/make-goldens.js`):
- bölüm yapısı, 16 bölüm için bölüm tahtası + 4 kademe tahtası, 33 seviye için `specFor` (w, h, kademe, bölüm, sıra, biçim, tohum 0/3);
- `makeMask`: 6 tohumlu maske satırı JS ile aynı;
- **tam ok listesi + maske + ölçüler** (doluluk, ort. dönüş, puan bit-bit): seviye 4, 9, 14, 18 (her kademe, 9x13), 56, 58 (şekilli 14x21), 177 (şekilli 28x45);
- **özet = tools/level-hashes.json**: 60 sabit seviye (1, 2, 3, 4, 5, 6, 10, 11, 15, 16, 19, 20, 21, 25, 26, 35, 36, 40, … 100, 101, … 160, 161, 166, 171, 176–181,
  200, 1619, 4999, 5000) + 20 örneklenmiş (tohum 20261111);
- 5.000 sonrası (sonsuz): 5001, 5002, 5006, 5011, 5016, 5020, 5177, 5180, 12345, 99999 özet + tahta + kademe;
- hazır paket (`lib/data/levels.json`, ilk **100** seviye, web'den `tools/flutter/export-levels.js`, maske dahil) == üretici.

### 3.2 Oyun ekranı (`lib/ui/screens/game_screen.dart`, `lib/ui/board_painter.dart`)
- Görünüm: varsayılan hücre ≥ 20 px (`_minCell`), sığan hücre ≥ 18 px ise tam sığar (`_fitOk`); sMin = tüm tahta, sMax = hücre ≈ 64 px; kenarda durma
  (x: 2/2 px, y: 36/8 px pay), tek parmak kaydırma + atalet (300 ms sönüm), iki parmak yakınlaştırma, fare tekerleği (Ctrl = yakınlaştırma).
  > 10 px hareket eden parmak asla dokunuş sayılmaz. Araç çubuğunda üçüncü düğme "Sığdır" ↔ "Yakınlaştır" (yalnızca gerektiğinde). İpucu oku ekranda
  değilse görünüm oka kayar. Kaydırılabilir tahtada köşede küçük harita. Ekran dışındaki oklar çizilmez.
- İsabet hücre bazlı (okun hücresinin her yeri), boş hücrede 3x3 komşulukta en yakın ok (0,45 hücre), belirsizlik 0,12.
- Çıkış: sabit hız 26 ms/hücre (260–1100 ms), ok kendi yolunu izler, tahta kenarında kırpılır (solma yok); **110 ms** sonra sıradaki oka dokunulabilir;
  kazanma son çıkış animasyonu bitince.
- Otomatik "önce seç" önerisi penceresi kaldırıldı (ayar duruyor); büyük tahtada bir kez "Tahta büyük: tek parmakla kaydır…" bildirimi (2,6 sn).
- "Çarptı! −1 can" bildirimi **2,5 sn** (`toast(ms:)`), diğerleri 1,6 sn.
- Tepsi: maskeli tahtada hücre birleşimi, yuvarlak köşe (önbellekli yol); ızgara noktaları yalnızca hücre ≥ 9 px'te.
- Tek renk kipi: gövde %8,5 (≥ 1,6 px), küçük ok başı, gölge/şevron/nokta yok, renk tema mürekkebi (açık temada koyu, koyu temada açık).
- 1.1.6 düzeltmeleri aynen: `resizeToAvoidBottomInset` kapalı, yazı ölçeği en çok 1,3, `layout_shrunk`; tahta kalan yüksekliği doldurur; araç çubuğu tek satır (56 px).

### 3.3 Seviye sonu (`lib/ui/celebration.dart`)
Meşale/alev: reklamla devam → küçük, can kaybı → orta, kusursuz → büyük + kıvılcım, Aşırı zor kusursuz → altın alev + havai fişek (CustomPainter,
web SVG yolları birebir). Mesaj `cel<Kademe><Performans>` (4 dil × 16 hücre × 3 seçenek, ARB `i18n.js`'ten yeniden üretildi), "Seviye tamamlandı!" alt
satırda (testler bu metni arıyor). Hız rozeti `celFast`: ok başına ≤ 1,5 sn ve ≥ 8 ok, dokunuşlar arası en çok 8 sn sayılır, reklamla devamda yok.
Animasyon **sonlu** (3,6 sn) — widget testlerinde `pumpAndSettle` takılmaz; azaltılmış harekette durağan.

### 3.4 Ses ve titreşim
- `slide_out_{0,1,2}.wav`: web'in kendi WebAudio "rüzgâr esintisi" sentezi (`audio.js breeze`) `tools/flutter/render-sfx.js` ile Chromium
  OfflineAudioContext'te sabit tohumlu gürültüyle WAV'a işlendi (537 ms, mono 44,1 kHz). Üçüncü taraf örnek yok — ses bizim.
- 1.1.4 ses servisi aynen (önceden kurulu oyuncular, kuyruk yok, susarken düşer); ok hareketi başına tek ses + tek titreşim (haptic_test).
- Titreşim: tüm olaylarda tek 16 ms darbe (`theme.js vibrate` ile aynı).

### 3.5 Harita (`lib/ui/screens/map_screen.dart`)
250 bölüm × 20 seviye (tembel liste aynı), düğüm köşesinde kademe noktası, her 5'li dilimin başında kademe etiketi, bölüm başlığında (bölümün sonu,
en üstte) bonus durumu ("Bölüm bonusu: 150" / "Bölüm tamamlandı"), açılışta oyuncunun düğümüne kaydırma. Banner yalnızca menü/harita (`AdBannerSlot`).

### 3.6 Görünüm
- Palet "Kum ve Mürekkep" (`lib/ui/tokens.dart`, açık + koyu), varsayılan ok paleti (turkuaz, kiremit, hardal, çivit, erik); Android açılış zemini
  (`values/colors.xml`, `values-night`) yeni zemin renkleri.
- Readex Pro (SIL OFL 1.1): değişken dosyadan sabit ağırlıklar (400/500/600/700, `tools/flutter/make-fonts.py`, her biri 98 KB; Türkçe, Almanca ve
  Arapça gliflerin tamamı doğrulandı) `assets/fonts/`, `pubspec.yaml fonts: ReadexPro`, `ThemeData.fontFamily`. Lisans `assets/fonts/OFL.txt`,
  `LicenseRegistry` (main.dart) + Ayarlar → "Açık kaynak lisansları" (`showLicensePage`; yeni i18n anahtarı `settings.licenses`, 4 dil).
- RTL: harita aynalanır, küçük harita karşı köşede, araç çubuğu `Row` (yön Directionality'den), kutlama ve rozet ortalı.
- Ayarlar → Görünüm → **Ok rengi: Renkli / Tek renk** (önizlemeli, kalıcı `arrowColor`, telemetri `setting_changed arrow_color`).

### 3.7 Arka plan üretimi (D)
Hazır paket sonrası (101+) seviyeler `Isolate.run` ile UI iş parçacığı dışında üretilir; oyuncu oynarken sıradaki **2** seviye sırayla önceden üretilir,
en yüksek numaralı 6 seviye önbellekte (`kGenVersion` değişince geçersiz).

### 3.8 Telemetri
`level_start` / `level_complete` / `level_fail`: `chapter` + `board` ("28x45") + `shaped` (0/1) eklendi (eski parametreler aynı; kişisel veri yok).

## 4. Kayıt göçü (C)

Seviye numaraları değişmediğinden yıldız/jeton/kilit olduğu gibi kalır. Sorun yalnızca `chapterBonus` (bölüm numarası listesi): 1.2.0 öncesi numaralar
10'luk bölümdür. Kural (`game/js/storage.js sanitize` ve `lib/core/save_data.dart migrateChapterBonus`, birebir):
- Kayıtta `cbv` yoksa/≠ 20: eski bölüm k → yeni bölüm ⌈k/2⌉ (tekrarsız). Eski k'nin 10 seviyesi yeni ⌈k/2⌉'nin yarısıdır ve 150 jeton zaten ödenmiştir →
  yeni bölüm ödenmiş sayılır: **çift ödeme yok**. Numaralar yeni bölümlere taşındığı için eski "bölüm 3" (seviye 21–30) yeni bölüm 3'ü (41–60) **kilitlemez**.
- Kayıt `cbv: 20` ile yazılır → göç bir kez. Yedek kodu (1.1.x kodları dahil) içe aktarmada da aynı kural.
- Test: `test/save_migration_test.dart` (8 durum) + economy_golden `sanitize` vakaları (JS ile aynı çıktı).
Not (sahip kararı, §8): eski bölümün yalnızca yarısının bonusunu almış oyuncu yeni bölümün kalan yarısı için ek bonus almaz.

## 5. Performans (D) — Dart, CI (`test/levelgen_bench_test.dart`, `flutter test` JIT, ubuntu-latest)

| Bölüm 9 tahtası | adet | ort | p50 | p95 | en çok |
|---|---|---|---|---|---|
| Kolay 20x32 | 10 | 1,3 | 1,2 | 1,6 | 1,6 |
| Orta 24x38 | 10 | 2,0 | 1,7 | 4,1 | 4,1 |
| Zor 27x43 | 20 | 4,6 | 4,4 | 12,0 | 12,0 |
| **Aşırı zor 28x45** | 40 | 10,6 | 9,5 | **22,9** | 33,4 |

Ölçüt p95 < 400 ms (test bunu doğrular) fazlasıyla sağlanıyor; Dart, Node'dan yaklaşık 2 kat hızlı. Ayrıca test, üretimin `Isolate.run` içinde aynı
seviyeyi verdiğini doğrular. (Değerler CI günlüğünde `LEVELGEN_BENCH` satırlarıdır; gerçek cihazda ölçülmedi.)

## 6. Testler ve CI

Yeni/yenilenen Dart testleri: `levelgen_golden_test` (yeniden yazıldı), `levelgen_bench_test`, `save_migration_test`, `board_view_test`
(28x45'te hücre ≥ 20 px, kaydırma dokunuş saymaz, hücre bazlı isabet — hücre merkezi ve köşeleri —, Sığdır ↔ Yakınlaştır, 110 ms kilit, küçük tahtada
Sığdır yok, ok rengi kalıcı), `solvable_test` (100 seviye, maske ve kademe tahtası), altın veriler (`economy`, `engine`, `levelgen`) web'den.
CI: `ci.yml` yalnızca main'e gönderim ve PR'da çalışır; dal için `workflow_dispatch` kullanıldı ve main'e PR açıldı (birleştirilmedi).
Çalıştırma kimlikleri ve sonuçlar rapordadır.

## 7. Web'den sapmalar

- Araç çubuğu düğmeleri Flutter'da simge + etiket yan yana (56 px); web'de CSS ile aynı yükseklik.
- Yazı tipi: web değişken dosyayı, Flutter 4 sabit ağırlığı kullanır (w800 istekleri 700'e düşer; web'de de dosya en çok 700).
- Kutlama animasyonu Flutter'da 3,6 sn sonra durur (web CSS sonsuz döngü) — test kararlılığı için.
- Fare tekerleğinde Alt/Ctrl = yakınlaştırma (web'de Meta da).
- Hız rozeti için süre ölçümü test saatine (`BoardModel.nowMs`) bağlı; web `performance.now()`.

## 8. Açık riskler / sahip kararı gerekenler

1. **Göç kuralı**: yarım bölüm bonusu almış eski oyuncu yeni bölümün kalan yarısı için bonus almaz (çift ödeme yok, gelir dostu). İstenirse
   "iki yarı da ödenmişse ödenmiş say" kuralına geçilebilir (oyuncuya en çok 150 jeton fazladan).
2. Küçük bölümlerde (1, 2, 10, 11, …) Kolay ve Orta en küçük tahtaya (9x13) dayanır: bu bölümlerde "nefes alma" yalnızca ok biçimiyle olur.
3. Gerçek cihazda ölçülmedi: 28x45 tahtada kare süresi, atalet hissi, büyük yazı + küçük ekran. Emülatör testleri yalnızca açılış/reklam akışını sınar.
4. Yeni rüzgâr sesi 537 ms (eskisi ~250 ms); hızlı art arda çıkışlarda oyuncu sayısı 3 → üst üste binme yerine düşme olabilir (tasarım gereği, kuyruk yok).
5. Uygulama simgesi (mavi) yeni paletle uyumlu değil — Aşama B "mağaza görselleri" işine bırakıldı.
