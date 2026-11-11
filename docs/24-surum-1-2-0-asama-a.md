# Arrowtile 1.2.0 — "Aşama A" (oynanış + görsel yenileme) — WEB ÖNİZLEME

Kaynak kararlar: `docs/17-sonraki-surum-notlari.md` ("Kesinleşen kararlar", "1.2.0 kapsam onayı", "Zorluk kararları", "Büyük güncelleme notları").
Süreç: **web önizleme (bu belge, `game/`) → sahip dener ve onaylar → Flutter'a taşınır.** Dal: `v1.2-web` (main'e birleştirilmedi).
Kapsam dışı (Aşama B): Play Games lider tablosu, WhatsApp daveti, mağaza görselleri, AdMob mağaza bağlantısı.
Değişmeyenler: reklam kuralları (seviye 1–12 reklamsız, ≥ 3 seviye, ≥ 3 dk; banner yalnızca menü/harita), süre sınırı yok, 3 can, günlük bulmaca (eski üretici, aynı bulmacalar).

## 1. Ne yapıldı

| # | İş | Durum |
|---|---|---|
| 1 | Bölüm = 20 seviye: 5 Kolay → 5 Orta → 5 Zor → 5 Aşırı zor; tahta bölümden bölüme büyür, 28x45'ten sonra en küçüğe döner | tamam |
| 2 | Yeni üretici: ince/uzun/çok kıvrımlı iç içe oklar, alanla artan ok sayısı, şekilli (maskeli) Aşırı zor tahtalar | tamam |
| 3 | Büyük tahta kaydırılır (sağa-sola, yukarı-aşağı), iki parmakla yakınlaştırılır; "Sığdır" düğmesi; hücre bazlı isabet | tamam |
| 4 | Ayarlar → Görünüm → "Ok rengi: Renkli / Tek renk" (kalıcı) | tamam |
| 5 | Çıkış animasyonu: ok kendi yolunu izleyerek sabit hızla tahta kenarına gider, kenarda kaybolur | tamam |
| 6 | Ok çıkış sesi: kendi üretimimiz yumuşak "rüzgâr esintisi" (WebAudio); titreşim tek kısa darbe | tamam |
| 7 | Seviye sonu kutlaması: meşale/alev + kademe × performans mesaj matrisi (4 dil), hız rozeti | tamam |
| 8 | "Çarptı! −1 can" bildirimi 2,5 sn (diğerleri 1,6 sn) | tamam |
| 9 | Harita: 20 seviyelik bölümler (tembel liste, mevcut bölümde açılır), kademe noktaları + kademe etiketleri, bölüm adı + Roma rakamı, bölüm sonu bonusu | tamam |

### 1.1 Bölüm ve tahta yapısı (`game/js/levelgen.js`, `specFor(id)`)
- Seviye 1–5 Kolay, 6–10 Orta, 11–15 Zor, 16–20 Aşırı zor; 21'de yeniden Kolay. 5.000 seviye = 250 bölüm, sonrası sonsuz (aynı kural).
- Tahta yalnızca bölüme bağlı; **büyüme uzunluğu tek sabit: `GROW_CHAPTERS = 9`**. Bölüm 1: 9x13 → 2: 11x17 → 3: 14x21 → 4: 16x25 → 5: 19x29 → 6: 21x33 → 7: 23x37 → 8: 26x41 → 9: **28x45** → bölüm 10 yine 9x13 … (doğrusal, tamsayı yuvarlama).
- Öğretici seviyeler 1–3 değişmedi (3x3 / 4x4, düz oklar).
- Her seviye numarasından türetilen sabit tohumla üretilir (`seedFor(id, tur)` = FNV("arrowtile-v20-id-tur")): herkes aynı seviyeyi görür. `LevelGen.VERSION = 'v20.0'` (eski sonsuz seviye önbelleği geçersiz olur).
- Pakette hazır seviye: ilk **100** (bölüm 1–5, `game/js/levels.js` 233 KB); sonrası oyunda arka planda önceden üretilir (mevcut mekanizma). Paket = üretici (özet karşılaştırması).
- Ekonomi: çarpanlar aynı (Kolay ×1, Orta ×1,5, Zor ×2, Aşırı zor ×3), bölüm bonusu 150 jeton artık 20. seviyede.

### 1.2 Yeni üretici (`build2`) — neden hep çözülebilir
Bir ok, başının baktığı doğru (ışın) üzerindeki tüm oklar çıkmadan çıkamaz → bağımlılık çizgesi. Üretici bu çizgeyi **artımlı olarak döngüsüz** tutar:
1. Boş bir hücre baş, bir yön seçilir. Işındaki oklardan başlanarak yeni okun bağımlı olacağı tüm oklar bulunur (genişlik öncelikli arama).
2. Bu okların ışınlarının geçtiği hücreler (ve yeni okun kendi ışını) gövdeye **yasaktır** — gövde oraya girerse döngü oluşurdu.
3. Gövde yasak olmayan boş hücrelerde baştan geriye büyür: uzunluk, dönüş sayısı, aynı yöne dönme (sarmal) ve dolu hücrelere yaslanma (sıkı kıvrım) eğilimi kademeye göre. Birkaç deneme yapılıp en uzun/en kıvrımlısı seçilir.
4. Işını boş ok (başta çıkabilen) yalnızca kademe bütçesi kadar yerleştirilir → başta çıkabilen ok sayısı kurgu gereği sınırlıdır; Kolay/Orta'da en az 3, Zor/Aşırı zor'da en az 2 ok başta çıkabilir kalır.
5. Sonra: orta boy oklar → **kuyruk uzatma** (tek hücrelik boşluklar komşu okun kuyruğuna eklenir, kısa dolgu oku yerine kıvrım) → doluluk bandın altındaysa kısa dolgu okları.
Sonuç ayrıca bağımsız çözücüyle (`tools/solver.js`) doğrulanır. Yalnızca tamsayı, `rand()`, + − × ÷ ve √ kullanılır (Dart'ta bit-bit aynı sonuç için).

Şekilli tahta (maske, `makeMask`): Aşırı zor seviyelerde ve tahta ≥ 14 sütunsa bölümdeki 5 Aşırı zor seviyenin 4'ü şekillidir: `organic` (düzensiz kenar + kesik köşe), `ring` (ortada büyük delik + içinde küçük ada), `ringOrganic` (ikisi). Seviye verisine `mask` (satır dizgileri, `1` = oynanabilir) eklendi; özet (`canon`) maskeyi de içerir.

Ölçülen değerler (5.000 seviye, `tools/verify-5000.js`):

| Kademe | Doluluk bandı (maske hücrelerine oranla) | Başta çıkabilen | Ok uzunluğu | Ort. dönüş/ok | 28x45'te ok sayısı |
|---|---|---|---|---|---|
| Kolay | %50–70 (hedef %60) | ≤ %24, en az 3 | 2–5 | ~0,2 | ~244 |
| Orta | %64–80 (hedef %72) | ≤ %14, en az 3 | 3–9 | ~1,4 | ~176 |
| Zor | %75–89 (hedef %82) | ≤ %8, en az 2 | 5–16 (+uzatma) | ~2,7 | ~126 |
| Aşırı zor | %83–96 (hedef %90) | ≤ %5, en az 2 | 8–28 (+uzatma, en uzun ort. 27) | ~3,8 (büyük tahtada 4+) | ~81 |

Bölüm içi sıra (ortalama puan) örneği, bölüm 9 (28x45): Kolay 49,9 < Orta 73,4 < Zor 100,7 < Aşırı zor 120,1.
Puan (`measure2`) = 40·doluluk + 8·ort. dönüş + 2·ort. uzunluk + 30·(1 − 5·başta çıkabilen oranı) + 0,1·derinlik.

### 1.3 Büyük tahta, kaydırma, isabet (`game/js/main.js`)
- Varsayılan yakınlıkta hücre **en az 20 px** (`MIN_CELL`). Sığan hücre ≥ 18 px ise (`FIT_OK`) tahta tam sığar ve kaydırma yoktur; daha küçükse tahta ekrandan büyük açılır.
  360 dp genişlikte: 9x13 → 35 px, 11x17 → 31 px, 14x21 → 24 px, 16x25 → 21 px (sığar); 19x29 ve üstü → 20 px, kaydırmalı.
- Tek parmak sürükleme = kaydırma (ataletli), iki parmak = yakınlaştırma; > 10 px hareket eden parmak **asla** dokunuş sayılmaz. Masaüstünde tekerlek = kaydırma, Ctrl/Alt + tekerlek = yakınlaştırma.
- Araç çubuğundaki üçüncü düğme: "Sığdır" (tüm tahta) ↔ "Yakınlaştır" (varsayılan). Kaydırmalı görünümde köşede küçük harita.
- İpucu ekranda olmayan bir oku gösterirse görünüm oka kayar.
- **İsabet hücre bazlı:** okun kapladığı hücrenin herhangi bir yerine dokunmak yeter (ince çizgiye değil). Boş hücrede en yakın ok (0,45 hücre içinde) seçilir; iki farklı ok neredeyse eşit uzaklıktaysa hiçbiri oynamaz (kısa vurgu). "Önce seç, sonra fırlat" ayarı duruyor; otomatik önerisi kaldırıldı.
- Çizim: ekran dışındaki oklar çizilmez; tepsi ve ızgara noktaları önbellekli.

### 1.4 Görünüm
- Oklar inceldi: gövde hücrenin %15'i (önce %18), baş %40. **Tek renk** kipinde gövde %8,5 (en az 1,6 px), gölge/şevron/nokta yok; renk tema mürekkebi (açık temada koyu lacivert-siyah, koyu temada açık).
- Oyun ekranı: üst çubuk alçaldı, araç çubuğu tek satır (56 px), tahta kalan yüksekliği doldurur; zorluk etiketi tahta üstündeki ayrılmış şeritte; şekilli tahtada tepsi tahtanın biçimini alır.
- Çıkış animasyonu: sabit hız (26 ms/hücre, en az 260 ms, en çok 1100 ms), gövdenin tamamı yol boyunca akar, tahta kenarında kırpılarak kaybolur (solma yok). Ok yola çıktıktan 110 ms sonra sıradaki oka dokunulabilir.
- Kutlama (`showEnd`): reklamla devam → küçük alev; can kaybı → orta; kusursuz → büyük + kıvılcım; Aşırı zor kusursuz → altın alev + havai fişek. Mesaj: `cel.<kademe>.<performans>` (flawless / l1 / l2 / ad), her hücrede 3 seçenek, 4 dilde ayrı yazıldı. Hız rozeti (`cel.fast`): ok başına ortalama ≤ 1,5 sn ve ≥ 8 ok; bekleme süresi sayılmaz; yavaşlık hiçbir yerde söylenmez.

### 1.5 Ses ve titreşim
- `SFX.slideOut`: iki katmanlı filtreli gürültü (bant geçiren süpürme + alçak geçiren), kazanç 90 ms'de doğrusal yükselir (tık yok), ~0,5 sn. Dosya yok, üçüncü taraf örnek yok. Ok hareketi başına tek ses (e2e ile doğrulanıyor).
- Titreşim: tüm olaylarda tek 16 ms darbe (`THEME.vibrate`).

## 2. Ayarlanabilir sabitler

| Sabit | Yer | Değer | Anlamı |
|---|---|---|---|
| `GROW_CHAPTERS` | levelgen.js | 9 | En küçükten en büyük tahtaya kaç bölümde varılır (**sahip onayı bekliyor**, öneri 8–10) |
| `MIN_W/MIN_H`, `MAX_W/MAX_H` | levelgen.js | 9x13, 28x45 | En küçük / en büyük tahta |
| `TIER2` | levelgen.js | tablo | Kademe başına doluluk, başta çıkabilen, uzunluk, dönüş, sarmal, deneme sayısı |
| `SHAPES`, `SHAPE_MIN_W` | levelgen.js | 5'li dizi, 14 | Aşırı zor tahta biçimleri ve en küçük şekilli tahta |
| `PREBUILT` | levelgen.js | 100 | Pakette hazır seviye sayısı |
| `MIN_CELL`, `FIT_OK`, `ZOOM_CELL` | main.js | 20, 18, 64 px | Varsayılan en küçük hücre, kaydırmasız kabul edilen hücre, en yakın hücre |
| `HIT_NEAR`, `AMBIG`, `PAN_SLOP` | main.js | 0,45 / 0,12 hücre, 10 px | İsabet ve kaydırma eşikleri |
| `exitPerCell/exitMin/exitMax/tapGap` | theme.js | 26 / 260 / 1100 / 110 ms | Çıkış animasyonu |
| `bodyWidth`, `monoBody` | theme.js | 0,15 / 0,085 | Ok kalınlığı (renkli / tek renk) |
| `CRASH_TOAST_MS` | main.js | 2500 | Çarpma bildirimi süresi |
| `FAST_MS_PER_ARROW`, `FAST_MIN_ARROWS` | main.js | 1500 ms, 8 | Hız rozeti eşiği |

`GROW_CHAPTERS` veya `TIER2` değişirse: `node tools/generate-levels.js && node tools/validate-levels.js && node tools/verify-5000.js` (özet dosyası yeniden yazılır).

## 3. Üretim süresi (Node 22, bu makine)

5.000 seviyenin tamamı: **15 sn** (2 işçi), CPU toplamı ~21 sn. Hata 0.

| | adet | ort (ms) | p50 | p95 | en çok |
|---|---|---|---|---|---|
| Kolay (tümü) | 1247 | 1,7 | 1,0 | 4,9 | 15 |
| Orta (tümü) | 1250 | 2,0 | 1,2 | 6,0 | 15 |
| Zor (tümü) | 1250 | 5,2 | 3,0 | 17,5 | 52 |
| Aşırı zor (tümü) | 1250 | 7,7 | 4,6 | 25,1 | 59 |
| Kolay 28x45 | 135 | 5,0 | 4,7 | 7,4 | 15 |
| Orta 28x45 | 135 | 5,4 | 5,3 | 7,7 | 13 |
| Zor 28x45 | 135 | 15,5 | 15,1 | 31,5 | 52 |
| **Aşırı zor 28x45** | 135 | **22,1** | 19,3 | **39,9** | 59 |

Hedef "p95 ≪ 1,5 sn" fazlasıyla sağlanıyor (eski üretici 22x31 Aşırı zor: ort. 562 ms, p95 1,7 sn). Kademe koşulları ilk turda sağlanıyor (ortalama 1,0–1,2 tur, en çok 8). Tarayıcı (Chromium) ölçümü için §5'e bakın.

## 4. Doğrulama
- `node tools/validate-i18n.js` — 239 anahtar × 4 dil.
- `node tools/validate-levels.js` — paket 100 + örnek 200 seviye: yapı (maske dahil), bağımsız çözücü, ızgara planı, tahta biçimi, kademe bandı, başta çıkabilen, paket == üretici, bölüm içi K < O < Z < A (puan ve dönüş), ok sayısı alanla artar, büyüme döngüsü.
- `node tools/verify-5000.js` — 5.000 seviye, aynı denetimler + süre + belirlenimlilik; `tools/level-hashes.json` yeniden yazıldı (üretici v20.0).
- `node tools/test-ads.js`, `node tools/test-daily.js` (günlük bulmaca değişmedi).
- `node tools/e2e.js`, `node tools/qa.js` (Playwright) — beklentiler 1.2.0'a uyarlandı; yeni testler: hücre bazlı isabet (4 seviyenin tüm hücreleri), büyük tahtada kaydırma dokunuş saymaz, kenarda durma, Sığdır/Yakınlaştır, kaydırma ipucu.
- Ekran görüntüleri: `node tools/shots-v12.js [klasör]`.

## 5. Sapmalar ve notlar
- **Bölüm içinde tahta sabit.** Kolay seviye de bölümün büyük tahtasında oynanır (bölüm 9'da Kolay = 28x45, ~244 kısa ok, ~30'u başta çıkabilir). "Kolay dostça kalsın" hedefi kısa/düz oklar, düşük doluluk ve çok sayıda başta çıkabilen okla sağlanıyor; istenirse Kolay/Orta tahtası bölüm içinde küçültülebilir (yeni sabit gerekir).
- Eski doğrulayıcıdaki "derinlik penceresi" ve "kıvrımlı oran" ölçütleri kalktı; yerine ok başına ortalama dönüş ve uzunluk geldi. Ort. uzunluk sırası %10 toleranslı, Aşırı zor ok sayısı artışı şekilli tahtada alan değiştiği için %15 toleranslı denetlenir (puan ve dönüş sırası kesin).
- Hazır paket 200 → 100 seviye (üretim artık milisaniyeler sürdüğü için paket küçültüldü).
- "Önce seç, sonra fırlat" otomatik önerisi kaldırıldı (hücre bazlı isabetle gerek kalmadı); ayar duruyor.
- Çıkış sırasında giriş kilidi kısaldı (ok tahtayı terk edene kadar değil, 110 ms): uzun yolda oyun ağırlaşmasın diye. Arka arkaya çıkan oklar kısa süre üst üste görünebilir.
- `VERSION` (main.js) ve ads.js / storage.js ipucu-reklam akışına dokunulmadı (1.1.6 düzeltmesiyle çakışmasın diye); storage.js'te yalnızca `PER_CHAPTER`, `CYCLE` ve `arrowColor` alanı değişti.
- main'de zaten kalan (bu dalla ilgisiz) e2e denetimleri: `core` "2 ücretsiz ipucu" (1.1.6 varsayılanı 0), `ads` Almanca gizlilik ekranında kelime bölünmesi, `v15` reklamda ses duraklatma (2 denetim).

## 6. Flutter'a taşırken
- `levelgen.dart`: `build2`, `makeMask`, `measure2`, `specFor`, `levelJob` birebir (aynı `rng`, `shuffle`, tamsayı bölmeler; `Math.floor(rand()*n)` sıraları korunmalı). Altın test: `tools/level-hashes.json` (maske özetin parçası).
- Seviye modeline `mask` alanı; tepsi çizimi maske birleşimi; `InteractiveViewer` yerine mevcut dönüşüm mantığı (sMin/sMax, kenarda durma, atalet).
- Kutlama metinleri `cel.*` ARB'ye; alev/kıvılcım/havai fişek `CustomPainter` ya da basit animasyon.

## 7. Görsel araştırma: renk paleti ve yazı tipi (sahip kuralı: hazır/varsayılan renk ve yazı tipi kullanılmaz)

### 7.1 Bulgular (web araştırması, 11.11.2026)
| Kaynak | Bulgu |
|---|---|
| Türün lideri **Arrows – Puzzle Escape** (Lessmore UG): 100 milyon+ indirme, 4,7★ / ~2,1 milyon oy — [AppGoblin](https://appgoblin.info/apps/com.ecffri.arrows), [inceleme sayfası](https://appireview.pages.dev/com.ecffri.arrows), [oyun tanıtımı](https://cceditorial-games.pages.dev/games/arrows-puzzle-escape) | Mağaza metni ve incelemeler aynı şeyi öne çıkarıyor: "bulmacaya odaklanmayı sağlayan temiz, minimalist tasarım", "görsel stil bilerek sade; dikkat efektlerde değil bulmacada", "süre yok, rahatlatıcı". Şikâyetler görsellikten değil reklamdan: 20. seviyeden sonra iki seviyede bir reklam ve 10 $'lık reklam kaldırma pahalı bulunuyor. |
| **Arrow Cube Escape** incelemesi — [Shacknews](https://www.shacknews.com/article/149355/arrow-cube-escape-review-score) | Beğenilen: "temiz cam" estetiği, kalın çizgilerle dengeli sade görünüm, rengin anlam taşıması (yanlış ok kırmızı, ipucu mavi). Beğenilmeyen: **kaydırma olmaması yüzünden yanlış dokunuşlar** ve ok yolunun önceden görülememesi. |
| Rahatlatıcı ("cosy") oyunların görsel dili — [UX Collective](https://uxdesign.cc/the-calm-and-charm-of-cosy-games-in-a-chaotic-world-7f29dbd8f4d9) | Pastel / yumuşak (doygunluğu düşük) paletler, yuvarlatılmış köşeler ve yuvarlak hatlı yazı tipleri sakinlik hissi veriyor. |
| **Readex Pro** — [GitHub (OFL 1.1)](https://github.com/ThomasJockin/readexpro) | Depo açıklamasına göre Lexend Latin ailesinden türetilmiş, Arapçası Nadine Chahine tarafından çizilmiş aile (Thomas Jockin ile). Tek ailede Latin + Arapça, değişken ağırlık (160–700), SIL OFL 1.1. |

Not: Kaynaklar rakiplerin kesin renk kodlarını vermiyor; aşağıdaki renkler bu bulgulardan çıkarılan ilkelere göre seçildi (birebir kopya değil). Sahibin paylaştığı referans ekran ("Süper Zor": açık zemin, ince siyah çizgi oklar) da aynı yönde.

### 7.2 Çıkarılan ilkeler
1. **Zemin sade ve nötr, kahraman oklar.** Arayüz süssüz; doygun renk yalnızca oklarda ve anlam taşıyan yerlerde.
2. **Renk anlam taşır.** Kırmızı yalnızca çarpma/can, altın yalnızca ipucu/yıldız; ok paletinde saf kırmızı ve altın sarısı yok (karışmasın).
3. **Yumuşak, sıcak, düşük doygunluk** (uzun oturumda göz yormayan "kâğıt ve mürekkep"); koyu temada saf siyah yerine kömür.
4. **Yuvarlak hatlı, okunaklı tek yazı tipi ailesi**; 4 dilde aynı karakter (Latin ve Arapça yan yana uyumlu).
5. **Yanlış dokunuşu azalt** (rakipteki en somut görsel-etkileşim şikâyeti): kaydırma + hücre bazlı isabet (§1.3) ve "önce seç" kipinde yol gösterimi.

### 7.3 Seçilen palet — "Kum ve Mürekkep" (`game/js/theme.js` `colors`, `game/css/style.css` `:root`)
| Rol | Açık tema | Koyu tema | Gerekçe |
|---|---|---|---|
| Zemin | `#EFEAE2` kum | `#14171C` kömür | Sıcak nötr; soğuk gri-mavi yerine kâğıt hissi (ilke 3) |
| Tahta / kart | `#FBF9F5` | `#1E2229` | Zeminden bir ton açık: tahta "kâğıt levha" gibi ayrışır |
| Kenar / gölge | `#D8D0C3` | `#0C0E12` | Yumuşak alt kalınlık |
| Hücre / ızgara noktası | `#EEE8DE` / `#CFC6B8` | `#272C35` / `#3A414D` | Çok hafif; okları bastırmaz (ilke 1) |
| Mürekkep (metin + tek renk oklar) | `#22252B` | `#F2EEE6` | Referanstaki siyah çizgi görünümü; saf siyah/beyaz değil (ilke 3) |
| İkincil metin | `#6A6760` | `#A19D94` | |
| Vurgu (birincil düğme) | `#1E7A78` derin çam yeşili-turkuaz | `#4DB6AC` | Sakin, kırmızı/altınla çakışmaz; beyaz metinle kontrast yaklaşık 5:1 |
| Yıldız / ipucu | `#E3A008` | `#F2B632` | Yalnızca ödül/ipucu (ilke 2) |
| Tehlike (can, çarpma) | `#D2453B` | `#F0685E` | Yalnızca hata/can (ilke 2) |
| Başarı | `#2F8F5B` | `#55C08A` | |

**Varsayılan ok paleti (Renkli kip, "Emaye" teması):** `#1F8A8A` turkuaz · `#E0703C` kiremit · `#D9A21B` hardal · `#4B5FC1` çivit · `#A0508F` erik. Beşi de orta doygunlukta, hem açık hem koyu tahtada okunur, birbirinden ton + parlaklıkla ayrışır (yön her zaman ok başı şekliyle de okunur → renk körlüğünde renk şart değil). Komşu oklar aynı rengi almaz (`OkEngine.colorize`).
**Tek renk kip:** oklar tema mürekkebiyle (`#22252B` / `#F2EEE6`), gövde hücrenin %8,5'i — referanstaki "ince siyah çizgi" görünümü; koyu temada kömür üstünde kırık beyaz.
Mağazadaki diğer ok temaları (Lokum, Çini, Bakır, Gece Lambası) satın alınabilir içerik olduğundan değiştirilmedi.

### 7.4 Yazı tipi — Readex Pro (pakette, `game/assets/fonts/ReadexPro-VF.ttf`, 272 KB; lisans `OFL.txt`)
- Tek dosya, tek aile: Türkçe (ğ ş İ ı), Almanca (ä ö ü ß ẞ) ve Arapça gliflerin tamamı doğrulandı (fontTools ile; 761 kod noktası). Rakamlar da aynı aileden.
- Lisans SIL OFL 1.1 → Flutter uygulamasına gömülebilir (`pubspec.yaml` `fonts:`; OFL.txt lisans sayfasına eklenir).
- Ağdan yüklenmez: `@font-face` yerel dosya; CSP `font-src 'self'` değişmedi. Sistem yazı tipleri yalnızca yedek.
- Neden bu aile: yuvarlak hatlı ve sakin (ilke 4), okunaklılık için tasarlanmış, Latin ile Arapça aynı çizgi kalınlığı ve x-yüksekliğinde; ağırlık ekseni 160–700 (başlıklar 700).
- Değerlendirilen diğerleri: Baloo Bhaijaan 2 (daha oyuncu/çocuksu, "premium ve sakin" hedefe uzak), Cairo (daha köşeli, Latin tarafı sıradan), Noto Sans + Noto Naskh (sistem varsayılanı hissi → kural gereği elendi).

### 7.5 Diğer görsel ayrıntılar
- Uygulama simgesi (mavi) bu aşamada değişmedi: mağaza kimliği ayrı karar; yeni paletle uyumlu simge Aşama B "yeni mağaza görselleri" işine bırakıldı.
- `theme-color` (durum çubuğu) yeni zemin renklerine güncellendi.
