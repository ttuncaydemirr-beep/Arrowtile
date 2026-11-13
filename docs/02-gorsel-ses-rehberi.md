# Arrowtile — Görsel & Ses Rehberi (v2, 1.2.2)

Kaynaklar: renkler `design/colors.json` (tek kaynak; `tools/gen-tokens.js` web ve Flutter'a üretir), diğer token'lar `game/js/theme.js` (`window.THEME`) ve `flutter/arrowtile/lib/ui/tokens.dart`. Tasarım sistemi (marka kitabı, tüm token'lar, 21 bileşen): `design/system/`. Bu belge ile kod çelişirse **kod geçerlidir**.
Geçmiş: v1 "Emaye levha" (porselen gri-mavi zemin, kobalt vurgu) 1.2.0'da "Kum ve Mürekkep" ile değişti (docs/24 §7); kontrast düzeltmeleri 1.2.1 (docs/27 §B) ve 1.2.2.

## 1. Estetik yön: "Kum ve Mürekkep"
Sıcak, düşük doygunlukta kum zemin; tahta zeminden bir ton açık bir "kâğıt levha"; tek gösterişli unsur emaye renkli oklar. Oklar dolgun, düz renkli parçalardır ve altlarında ince koyu bir "kalınlık" taşır; tahtaya oturmuş, itilebilir nesneler gibi durur. Gradyan, parıltı ya da doku yok. Okun yönü her zaman **şekille** okunur: ok başı, gövdedeki şevronlar (›) ve ok başındaki nokta. Renk yalnızca okları birbirinden ayırır. Kırmızı yalnızca can/çarpma/hata, altın yalnızca ipucu/yıldız/ödül için kullanılır; ok paletlerinde bu iki anlam rengi bulunmaz.

## 2. Renk paleti
| Token (theme.js / CSS) | Açık (Kum) | Koyu (Kömür) | Kullanım |
|---|---|---|---|
| `bg` | `#EFEAE2` | `#14171C` | ekran zemini |
| `board` / `--board`, `--card` | `#FBF9F5` | `#1E2229` | tahta yüzü, modal, kabarık kontroller |
| `boardEdge` / `--edge` | `#D8D0C3` | `#0C0E12` | tahta ve kontrollerin alt kalınlığı |
| `cell` | `#EEE8DE` | `#272C35` | çukur yüzeyler (sekme izi, takvim günü, kilitli düğüm) |
| `cellDot` | `#CFC6B8` | `#3A414D` | tahtadaki hücre köşe noktası |
| `ink` / `inkSoft` | `#22252B` / `#6A6760` | `#F2EEE6` / `#A19D94` | metin; `ink` tek renk kipinde oklar |
| `accent` / `accentInk` | `#1E7A78` / `#FFFFFF` | `#4DB6AC` / `#14171C` | birincil düğme (derin çam yeşili-turkuaz) |
| `onFill` | `#FFFFFF` | `#14171C` | success/accent/danger dolgusu üstündeki yazı (1.2.2) |
| `star` / `starInk` | `#E3A008` / `#AD7800` | `#F2B632` / `#F2B632` | `star` rozet dolgusu; `starInk` yıldız simgesi, ipucu ve odak halkası |
| `coin` / `coinInk` | `#D4951A` / `#A86F0C` | `#F0B23A` / `#F0B23A` | jeton rozeti / jeton simgesi ve ödül yazısı |
| `danger` | `#D2453B` | `#F0685E` | can, çarpma, hata |
| `success` | `#267A4D` | `#55C08A` | tamamlanan, açık, ücretsiz (açık değer 1.2.2'de #2F8F5B'den) |
| `highlightRing` | `#AD7800` | `#F2B632` | ipucu halkası dış konturu |
| `shadow` | `rgba(34,37,43,.16)` | `rgba(0,0,0,.45)` | yalnızca yüzen katmanlar |

Temadan bağımsız (`THEME.fixed`): `onGold #22252B` (altın dolgu üstündeki yazı), `extreme #B3263A` ve `extremeDeep #7A1420` ("Aşırı zor"), `scrim #14171C` %55 (modal perdesi).
Tema `prefers-color-scheme` ile seçilir, Ayarlar › Görünüm (Otomatik / Açık / Koyu) ile değiştirilir (`data-theme`). Ok renkleri iki temada aynıdır.

## 3. Tipografi — Readex Pro
- Tek aile: **Readex Pro** (SIL OFL 1.1), uygulamayla paketlenir, ağdan yüklenmez. Web: değişken yazı tipi `game/assets/fonts/ReadexPro-VF.ttf` (160–700). Flutter: Regular 400, Medium 500, SemiBold 600, Bold 700. Latin ve Arapça aynı ailede; sistem yazı tipleri yalnızca yedek.
- Yığınlar (`THEME.font.stacks`): `latin`, `arabic`, `numeric` (rakamlar, `ui-rounded` yedekli). Arapça metinde boyut ×1,08, satır yüksekliği 1,55 (Latin: 1,3).
- Ölçek (px/ağırlık): başlık 30/700, modal başlığı 24/700, çubuk başlığı 22/700, gövde 17/400, düğme 18/700, küçük 14/600, açıklama 13/600, HUD 17–18/700. Kalın değer 700'dür (yazı tipinin üst sınırı; 1.2.2 öncesi kodda 800 yazıyordu, 700 çiziliyordu).
- Batı rakamları (0–9) her dilde kullanılır. Başlıklarda tümü büyük harf ve `text-transform: uppercase` kullanılmaz (Türkçe i/İ).

## 4. Çok dil ve RTL (ar)
**Aynalananlar** (`dir="rtl"` ile): metin hizası (`text-align: start`), menü ve satır düzeni (flex sırası, `margin-inline-*` / `padding-inline-*` kullanılır, left/right yazılmaz), geri ok ikonu (`transform: scaleX(-1)`), ilerleme çubuğu dolum yönü, seviye haritasında "sonraki" yönü, kaydırmalı listelerin başlangıcı, ayar anahtarlarının (toggle) yönü.
**Aynalanmayanlar**: oyun tahtası, ızgara koordinatları, okların yönü ve çizimi (Canvas'a dokunulmaz; `dir` Canvas'ı etkilemez), sayılar, yıldız dizilişi (soldan sağa 1-2-3 kalır), oynat ▶ ikonu, uygulama ikonu.

**Buton kuralı (uzun Almanca metin):**
1. `min-height: 52px`, yatay dolgu 18px, `white-space: normal; overflow-wrap: anywhere; hyphens: auto` (bunun çalışması için `<html lang>` doğru olmalı).
2. Metin önce **en fazla 2 satıra** kayar.
3. Hâlâ sığmıyorsa yazı 1px adımlarla en az **14px**'e küçülür: `THEME.fitButton(el)`.
4. **Ellipsis ve kırpma yok.** Buton yüksekliği gerekirse büyür.
5. Test: 360px genişlikte, 2 sütunlu düzende "Tagesbelohnung abholen" ve "احصل على المكافأة اليومية" taşmadan sığmalı (önizlemede doğrulandı).

## 5. Ok çizimi (Canvas 2D) — `drawArrow(ctx, opts)`
Oranlar hücre boyuna (`cell`) göredir (`THEME.shape`, Flutter `Shape`). 1.2.0 değerleri:
- kenar payı 0,12 · gövde kalınlığı 0,15 (en az 2 px) · ok başı genişliği 0,40 (en az 7 px) · ok başı uzunluğu 0,30 · baş köşe yarıçapı 0,05 · uç yarıçapı 0,04 · alt kalınlık 0,045 · şevron yarı yüksekliği 0,075, çizgi 0,045 · baş noktası 0,04.
- Oklar kıvrımlı olabilir (`cells`: kuyruktan başa hücre listesi). Gövde yuvarlak uçlu ve köşeli bir çizgidir; sonda köşeleri yuvarlatılmış üçgen ok başı bulunur.
- Çizim sırası: (varsa) ipucu halkası (`highlightRing` 0,20 + beyaz 0,08), **alt kalınlık** (aynı yol 0,045·cell aşağıda, renk %35 koyu; ışık hep yukarıdan), yüz, düz gövde hücrelerinde şevronlar (hücre ≥ 22 px ise) ve ok başında nokta (temanın `chevron` rengi).
- **Tek renk kipi** (Ayarlar › Ok rengi): `ink` renginde ince çizgi (gövde 0,085, en az 1,6 px; baş 0,34); gölge, şevron ve nokta yok.

## 6. Izgara / tahta — `drawBoard(ctx, ox, oy, w, h, cell, mode)`
Tahta, köşe yarıçapı 0,30·cell ve iç dolgusu 0,30·cell olan bir tepsidir. Altında `boardEdge` renginde 0,1·cell'lik bir kalınlık bulunur. **v1.2 (docs/08 §2):** hücre kutuları (çukurlar) kaldırıldı; tahta tek düz yüzeydir ve yalnızca hücre köşelerinde çok hafif noktalar (`cellDot`, r 0,045·cell, en az 0,7 px; açıkta %75, koyuda %55 opaklık) bulunur. Noktalar köşededir, boş hücrenin ortası tahta rengindedir. Izgara çizgisi kullanılmaz. Hücre boyu: `min((ekranGenişliği − 8) / (w + 0,6), (kullanılabilirYükseklik − 16) / (h + 0,7))`, en fazla 72 px; tahta her zaman ekrana sığarak açılır, en büyük tahtada (15x22) 360 px ekranda ≥ 22 px. Daha rahat dokunmak için iki parmakla 4×'e kadar yakınlaştırılır. Oklar tahtadan çıkarken tahta kenarında kırpılmaz, ekran kenarına kadar uçarak kaybolur.

## 7. Animasyon (ms, `THEME.anim`)
| Olay | Süre | Easing |
|---|---|---|
| Ok çıkışı | hücre başına 26, en az 260, en fazla 1100; ok kendi yolunu izleyerek tahta kenarına dek gider | sabit hız |
| Sıradaki dokunuş | çıkış başladıktan sonra en az 110 | |
| Çarpışma | engele kadar 90 → geri sekme 220 | gidiş ease-in, geri `cubic-bezier(.34,1.56,.64,1)` |
| Tahta sarsıntısı | 260; genlik 0,08·cell, 3 salınım, sönümlü | sinüs × (1−t) |
| Yıldız kazanımı | her biri 380, aralarında 180; ölçek 0→1,15→1 | `cubic-bezier(.34,1.7,.6,1)` |
| Buton basışı | 90'da scale .95 + 2 px aşağı, 160'ta geri | `cubic-bezier(.2,.8,.2,1)`; gölge 4px→1px |
| Ekran geçişi | 200 opaklık | ease-out |
| Modal açılışı | 260, ölçek .9→1 | `cubic-bezier(.34,1.56,.64,1)` |
| İpucu halkası | 900 döngülü nefes (alpha .5↔1) | sinüs |

`prefers-reduced-motion` (Flutter: `MediaQuery.disableAnimations`) açıksa sarsıntı, atalet ve görünüm geçişleri kapanır, ok çıkışı en fazla 180 ms sürer, yıldızlar ölçeklenmeden yalnızca belirir.

## 8. Titreşim (`THEME.vibrate`, `SFX.vibrate(ad)`, Flutter `HapticsService`)
1.2.0'dan beri tüm olaylarda (tap, slideOut, bump, levelWin, error, button) **tek kısa darbe: 16 ms**; ok hareketi başına bir titreşim. Ayarlardan kapatılabilir. Destek yoksa sessizce geçilir.

## 9. Ses (`game/js/audio.js`, `window.SFX`)
Tüm sesler Web Audio ile kodla üretilir ve C majör pentatonik dizide kalır, böylece üst üste binince de uyumlu duyulur. Çıkışta bir compressor bulunur, ana ses seviyesi 0,55'tir. Sesler: `tap`, `slideOut(pitch)` (bant geçiren gürültü whoosh + yükselen sinüs; arka arkaya çıkışlarda `pitch` 0→1 artırılabilir), `bump`, `levelWin`, `star(i)`, `coin`, `button`, `error`, ayrıca `hint` ve `undo`. Kullanım: ilk dokunuşta `SFX.init()` çağrılır. `SFX.setEnabled(bool)`. Uygulama arka plana geçince bağlam askıya alınır. Her çağrı try/catch içinde çalışır ve aynı sesin art arda tetiklenmesi engellenir.

## 10. Ok temaları (`THEME.arrowThemes`, `kArrowThemes`; kaynak `design/colors.json`)
Oklar temanın 5 rengini sırayla kullanır (`index % 5`); komşu oklar aynı rengi almaz.
| # | id | TR / EN / DE / AR | Renkler | Şevron | Fiyat |
|---|---|---|---|---|---|
| 1 | emaye | Emaye / Enamel / Emaille / مينا | `#1F8A8A #E0703C #B8850E #5468CC #A0508F` (turkuaz, kiremit, hardal, çivit, erik) | beyaz %78 | ücretsiz (varsayılan) |
| 2 | lokum | Lokum / Delight / Lokum / راحة الحلقوم | `#E2668E #D97511 #579C84 #A081D0 #AE8B19` | beyaz %85 | 300 |
| 3 | cini | Çini / Tile / Fliese / قيشاني | `#246EC2 #1C8C8C #C7382C #2F7A3D #5B8DE4` | beyaz %80 | 500 |
| 4 | bakir | Bakır / Copper / Kupfer / نحاس | `#B5652E #C76833 #B7722E #A5592F #C9773A` | krem %80 | 750 |
| 5 | gece | Gece Lambası / Night Light / Nachtlicht / ضوء الليل | `#1B9EAB #F155A0 #649F0D #BB8600 #9B78FF` | koyu %70 | 1000 |

Tüm ok renkleri açık ve koyu tahtada ≥ 3:1 (docs/27 §B1). Tema adları i18n'de `theme.emaye … theme.gece` anahtarlarıyla 4 dilde bulunur.

## 11. Erişilebilirlik
- Yön asla yalnızca renkle verilmez: ok başı + şevron + nokta. Kaybedilen can içi boş kalp, boş yıldız çerçeve, zorluk kademesi şekil (daire / yuvarlak kare / baklava / halka), seçili sekme alt çizgi ile de ayrılır (docs/27 §B3).
- Dokunma hedefleri en az 44 px, butonlar 52 px. Okun dokunma alanı kapladığı hücrelerin tamamıdır.
- Kontrast `tools/contrast.js` ile CI'da denetlenir (100 çift): metin ≥ 4,5:1, ok, simge ve odak halkası ≥ 3:1, her iki temada; web ve Flutter renklerinin özdeşliği de denetlenir. Örnekler: `ink`/`bg` açıkta 12,8:1, koyuda 15,5:1; beyaz/`accent` 5,1:1; odak halkası `starInk`/`board` 3,66:1.
- Ses kapalıyken de her olayın görsel karşılığı vardır (sarsıntı, sönme, yıldız).

## 12. Uygulama ikonu
`game/assets/icon.svg` (512, kaynak) ve `icon-512.png`: kobalt zemin üzerinde beyaz 2×2 tahta, yukarı bakan kırmızı ok ve tahtadan sağa kaçan safran ok. Bu simge v1 paletindendir ve 1.2.x'te bilerek değiştirilmedi (mağaza kimliği ayrı karar). "Kum ve Mürekkep" uyumlu aday: `store/icon-candidates/` (mürekkep zemin, kum tahta, turkuaz ve kiremit oklar), Play mağaza denemesi bekliyor. Tüm öğeler merkezdeki %66'lık güvenli dairede (r≈169 px); zemin kenarlara taşar.
