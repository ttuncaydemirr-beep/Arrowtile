# Ok Kaçış — Görsel & Ses Rehberi (v1)

Kaynak token'lar: `game/js/theme.js` (`window.THEME`, `drawArrow`, `drawBoard`). Bu belge ile kod çelişirse **kod geçerlidir**.
Önizleme: `tools/theme-preview.html` → `tools/theme-preview.png`.

## 1. Estetik yön: "Emaye levha"
Oklar, eski sokak tabelaları ve mutfak eşyalarındaki emaye kaplama gibi: dolgun, parlak, düz renkli parçalar; altlarında 1–2 px'lik koyu bir "kalınlık" var, yani tahtaya oturmuş ve itilebilir fiziksel nesneler gibi duruyorlar. Zemin porselen gri-mavi, tahta beyaz bir tepsi, hücreler hafif çukur. Kenarlarda gradyan, parıltı ya da doku yok. Tek "gösterişli" unsur okların kendisi. Arayüzün geri kalanı sakin ve kobalt-lacivert çizgide kalır. Okların yönü her zaman **şekille** okunur: üçgen ok başı, gövdede yönü gösteren beyaz şevronlar (›) ve ok başında beyaz bir nokta. Renk yalnızca okları birbirinden ayırmaya yarar, yön bilgisi taşımaz.

## 2. Renk paleti
| Token | Açık | Koyu | Kullanım |
|---|---|---|---|
| bg | `#E3E9EE` | `#0F1B27` | ekran zemini |
| board | `#F6F8FA` | `#172736` | tahta yüzü |
| boardEdge | `#C9D3DC` | `#0A131C` | tahta alt kalınlığı |
| cell | `#E6ECF1` | `#1E3245` | hücre çukuru |
| ink / inkSoft | `#1D2C3B` / `#5B6B7B` | `#E9EFF4` / `#93A5B6` | metin |
| accent | `#2456A6` | `#5B8DE0` | birincil buton (kobalt) |
| star | `#E8A317` | `#F2B632` | yıldız, ipucu halkası |
| coin | `#D99A1E` | `#F0B23A` | jeton |
| danger | `#C9372F` | `#EF5B52` | can, hata |
| success | `#2E8B57` | `#4DBB7F` | başarı |

Tema `prefers-color-scheme` ile seçilir, Ayarlar'dan değiştirilebilir: `THEME.palette('light'|'dark')`. Okların rengi iki temada da aynı kalır. Koyu zeminde de yeterli kontrastı sağlayan alt gölge sayesinde okunurlar.

## 3. Tipografi (yalnızca sistem fontları)
- Latin (tr/en/de): `system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans", Ubuntu, Arial, sans-serif`
- Arapça: `"Noto Naskh Arabic", "Noto Sans Arabic", "Geeza Pro", "Segoe UI", Tahoma, "Droid Arabic Naskh", sans-serif`. Arapça metinde boyut ×1,08, satır yüksekliği 1,55 (Latin: 1,3).
- Sayılar (seviye no, jeton, HUD): `ui-rounded, "SF Pro Rounded", system-ui, …`. Batı rakamları (0–9) her dilde kullanılır.
- Ölçek (px): başlık 30/800, h2 22/800, gövde 17/400, buton 18/800, küçük 14/600, HUD 18/800.
- Token'lar: `THEME.font.stacks`, `byLang`, `scaleByLang`, `lineHeightByLang`. `THEME.applyLang(lang)` çağrısı `<html lang dir>` niteliklerini ve `--font`, `--font-num`, `--lh`, `--fs-scale` CSS değişkenlerini ayarlar.
- Başlıklarda tümü büyük harf kullanılmaz. Türkçe "i/İ" dönüşümü bozulmasın diye `text-transform: uppercase` de kullanılmaz.

## 4. Çok dil ve RTL (ar)
**Aynalananlar** (`dir="rtl"` ile): metin hizası (`text-align: start`), menü ve satır düzeni (flex sırası, `margin-inline-*` / `padding-inline-*` kullanılır, left/right yazılmaz), geri ok ikonu (`transform: scaleX(-1)`), ilerleme çubuğu dolum yönü, seviye haritasında "sonraki" yönü, kaydırmalı listelerin başlangıcı, ayar anahtarlarının (toggle) yönü.
**Aynalanmayanlar**: oyun tahtası, ızgara koordinatları, okların yönü ve çizimi (Canvas'a dokunulmaz; `dir` Canvas'ı etkilemez), sayılar, yıldız dizilişi (soldan sağa 1-2-3 kalır), oynat ▶ ikonu, uygulama ikonu.

**Buton kuralı (uzun Almanca metin):**
1. `min-height: 52px`, yatay dolgu 18px, `white-space: normal; overflow-wrap: anywhere; hyphens: auto` (bunun çalışması için `<html lang>` doğru olmalı).
2. Metin önce **en fazla 2 satıra** kayar.
3. Hâlâ sığmıyorsa yazı 1px adımlarla en az **14px**'e küçülür: `THEME.fitButton(el)`.
4. **Ellipsis ve kırpma yok.** Buton yüksekliği gerekirse büyür.
5. Test: 360px genişlikte, 2 sütunlu düzende "Tagesbelohnung abholen" ve "احصل على المكافأة اليومية" taşmadan sığmalı (önizlemede doğrulandı).

## 5. Ok çizimi (Canvas 2D) — `drawArrow(ctx, {x,y,cell,dir,len,color,alpha,highlight,chevron})`
Oranlar hücre boyuna (`cell`) göredir (`THEME.shape`):
- **v1.2 (docs/08 §2) ince oklar:** kenar payı 0,12 · gövde kalınlığı 0,28 · ok başı genişliği 0,55 · ok başı uzunluğu 0,34 · ok başı yan köşe yarıçapı 0,05 · uç yarıçapı 0,04 · kuyruk tamamen yuvarlak (yarıçap = gövde/2) · alt kalınlık 0,045. (v1.1: 0,13 / 0,34 / 0,74 / 0,40 / 0,07 / 0,05 / 0,06.)
- Oklar 1–6 hücre uzunluğundadır; büyük tahtada uzun ince çizgiler gibi okunur. Küçük hücrede (22–26 px) yön ok başından okunur; şevron ve nokta en az ~1 px çizgiyle korunur.

Adımlar:
1. Kuyruk hücresinin merkezine `translate` edilir. Ardından yöne göre `rotate` yapılır: R 0, D 90°, L 180°, U −90°. Ok her zaman "sağa" çizilir.
2. Yerel x ekseninde kuyruk `-cell/2 + pay`, uç `(len − 0,5)·cell − pay`, ok başının tabanı `uç − başUzunluğu` noktasındadır.
3. 7 köşeli çokgen oluşturulur: kuyruk üst → taban üst → baş kanadı üst → uç → baş kanadı alt → taban alt → kuyruk alt. Köşeler `arcTo` ile yuvarlatılır.
4. Çizim sırası: (varsa) ipucu halkası (safran 0,20, beyaz 0,08), önce safran kalın, sonra beyaz ince kontur. Ardından **alt kalınlık**: aynı yol ekranın 0,045·cell aşağısında, renk %35 koyulaştırılmış. Sonra yüz dolgusu, en son %28 açılmış ince iç kontur.
5. Gövdenin her hücresine yönü gösteren bir beyaz şevron (›) çizilir (kalınlık 0,045 ama en az 0,9 px, yarı yükseklik 0,075). Ok başına beyaz bir nokta (r 0,04, en az 0,9 px) konur. Bu işaretler, renk körü oyuncular ve küçük ekranlar için yönün renkten bağımsız okunmasını sağlar.
6. Alt kalınlık her zaman ekranın aşağısına düşer (döndürmeden önce uygulanır), böylece ışık hep yukarıdan geliyormuş gibi görünür.
7. `alpha` çıkışta sönme için, `highlight` ipucu için kullanılır.

## 6. Izgara / tahta — `drawBoard(ctx, ox, oy, w, h, cell, mode)`
Tahta, köşe yarıçapı 0,30·cell ve iç dolgusu 0,30·cell olan bir tepsidir. Altında `boardEdge` renginde 0,1·cell'lik bir kalınlık bulunur. **v1.2 (docs/08 §2):** hücre kutuları (çukurlar) kaldırıldı; tahta tek düz yüzeydir ve yalnızca hücre köşelerinde çok hafif noktalar (`cellDot`, r 0,045·cell, en az 0,7 px; açıkta %75, koyuda %55 opaklık) bulunur. Noktalar köşededir, boş hücrenin ortası tahta rengindedir. Izgara çizgisi kullanılmaz. Hücre boyu: `min((ekranGenişliği − 8) / (w + 0,6), (kullanılabilirYükseklik − 16) / (h + 0,7))`, en fazla 72 px; tahta her zaman ekrana sığarak açılır, en büyük tahtada (15x22) 360 px ekranda ≥ 22 px. Daha rahat dokunmak için iki parmakla 4×'e kadar yakınlaştırılır. Oklar tahtadan çıkarken tahta kenarında kırpılmaz, ekran kenarına kadar uçarak kaybolur.

## 7. Animasyon (ms, `THEME.anim`)
| Olay | Süre | Easing |
|---|---|---|
| Ok kayışı (çıkış) | hücre başına 55, en az 160 | `cubic-bezier(.45,0,.85,.35)` (hızlanarak) + son 120 ms'de alpha→0 |
| Çarpışma | engele kadar 90 → geri sekme 220 | gidiş ease-in, geri `cubic-bezier(.34,1.56,.64,1)` |
| Tahta sarsıntısı | 260; genlik 0,08·cell, 3 salınım, sönümlü | sinüs × (1−t) |
| Yıldız kazanımı | her biri 380, aralarında 180 gecikme; ölçek 0→1,15→1 | `cubic-bezier(.34,1.7,.6,1)` |
| Buton basışı | 90'da scale .95, 160'ta geri | `cubic-bezier(.2,.8,.2,1)`; gölge 4px→1px |
| Ekran geçişi | 200 opaklık | ease-out |
| İpucu halkası | 900 döngülü nefes (alpha .5↔1) | sinüs |

`prefers-reduced-motion` açıksa sarsıntı kapatılır, kayış hücre başına 30 ms'ye iner ve yıldızlar ölçek animasyonu olmadan, yalnızca belirerek gelir.

## 8. Titreşim (`navigator.vibrate`, `THEME.vibrate`, `SFX.vibrate(ad)`)
tap `[8]` · slideOut `[12]` · bump `[30,40,30]` · levelWin `[20,60,20,60,40]` · error `[60]` · button `[6]`. Ayarlardan kapatılabilir (`SFX.setVibration(false)`). Destek yoksa sessizce geçilir.

## 9. Ses (`game/js/audio.js`, `window.SFX`)
Tüm sesler Web Audio ile kodla üretilir ve C majör pentatonik dizide kalır, böylece üst üste binince de uyumlu duyulur. Çıkışta bir compressor bulunur, ana ses seviyesi 0,55'tir. Sesler: `tap`, `slideOut(pitch)` (bant geçiren gürültü whoosh + yükselen sinüs; arka arkaya çıkışlarda `pitch` 0→1 artırılabilir), `bump`, `levelWin`, `star(i)`, `coin`, `button`, `error`, ayrıca `hint` ve `undo`. Kullanım: ilk dokunuşta `SFX.init()` çağrılır. `SFX.setEnabled(bool)`. Uygulama arka plana geçince bağlam askıya alınır. Her çağrı try/catch içinde çalışır ve aynı sesin art arda tetiklenmesi engellenir.

## 10. Ok temaları (`THEME.arrowThemes`, oklar renkleri sırayla kullanır)
| # | id | TR / EN / DE / AR | Renkler | Fiyat |
|---|---|---|---|---|
| 1 | emaye | Emaye / Enamel / Emaille / مينا | `#2456A6 #C9372F #E09A12 #2E8B57 #6B4C9A` | ücretsiz (varsayılan) |
| 2 | lokum | Lokum / Delight / Lokum / راحة الحلقوم | `#E2668E #D97511 #579C84 #A081D0 #AE8B19` | 300 |
| 3 | cini | Çini / Tile / Fliese / قيشاني | `#246EC2 #1C8C8C #C7382C #2F7A3D #5B8DE4` | 500 |
| 4 | bakir | Bakır / Copper / Kupfer / نحاس | `#B5652E #C76833 #B7722E #A5592F #C9773A` | 750 |
| 5 | gece | Gece Lambası / Night Light / Nachtlicht / ضوء الليل | `#1B9EAB #F155A0 #649F0D #BB8600 #9B78FF` (koyu şevron) | 1000 |

Fiyatlar yönetici kararıyla (24.10.2026) tasarım belgesindeki ekonomiye göre kesinleşti: 0 / 300 / 500 / 750 / 1000. Tema adları i18n.js'te `theme.emaye … theme.gece` anahtarlarıyla 4 dilde bulunur.

## 11. Erişilebilirlik
- Yön asla yalnızca renkle verilmez: ok başı + şevron + nokta kullanılır. Komşu oklar aynı renkte olsa bile ayırt edilebilirler, çünkü gövdeler arasında boşluk ve alt gölge vardır.
- Dokunma hedefleri en az 44px, butonlar 52px yüksekliktedir. Okun dokunma alanı kapladığı hücrelerin tamamıdır.
- Metin kontrastı: ink/bg açık temada ≈12:1, koyu temada ≈14:1. Beyaz metin kobalt (`#2456A6`) üzerinde ≈7:1.
- Ses kapalıyken de her olayın bir görsel karşılığı vardır (sarsıntı, sönme, yıldız).

## 12. Uygulama ikonu
`game/assets/icon.svg` (512, kaynak) ve `icon-512.png`. Kobalt zemin üzerinde beyaz 2×2 tahta, yukarı bakan kırmızı ok ve tahtadan sağa kaçan safran ok yer alır. Tüm öğeler merkezdeki %66'lık güvenli dairenin (r≈169px) içindedir. Zemin kenarlara kadar taşar, böylece maske hangi biçimde kesse de boşluk kalmaz. Adaptive ikonda ön plan için SVG'den zemin katmanı kaldırılarak ayrı bir katman üretilebilir.
