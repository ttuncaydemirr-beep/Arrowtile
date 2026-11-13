Arrowtile, oklara dokunup onları tahtadan kaçırdığın sakin bir mantık bulmacasıdır. Görsel dil **"Kum ve Mürekkep"**: sıcak, düşük doygunlukta nötr bir zemin; üstünde tek gösterişli unsur olarak emaye renkli oklar. Arayüz süssüz kalır, dikkat bulmacada olur. Bu belge web (`game/`) ve Flutter (`flutter/arrowtile/`) sürümlerinin ortak kaynağıdır; ikisi de aynı token değerlerini kullanır.

## İlkeler

1. **Zemin sade, kahraman oklar.** Doygun renk yalnızca oklarda ve anlam taşıyan yerlerde. Gradyan, parıltı, doku yok.
2. **Renk anlam taşır.** Kırmızı (`danger`) yalnızca can, çarpma ve hata; altın (`star`, `star-ink`) yalnızca ipucu, yıldız ve ödül. Ok paletlerinde saf kırmızı ve altın sarısı bulunmaz.
3. **Renk tek başına anlam taşımaz.** Okun yönü ok başı + şevron + noktayla, kaybedilen can içi boş kalple, boş yıldız çerçeveyle, zorluk kademesi şekille (daire, yuvarlak kare, baklava), seçili sekme alt çizgiyle okunur.
4. **Fiziksel nesneler.** Her dokunulabilir şey altında sert, bulanıksız bir "kalınlık" taşır (`raise-*`); basınca 2 px aşağı iner. Işık hep yukarıdan gelir.
5. **Uzun oturumda göz yormaz.** Kâğıt ve mürekkep: saf beyaz ve saf siyah yerine `board` #FBF9F5 ve `ink` #22252B; koyu temada kömür `bg` #14171C.

## İçerik ilkeleri

- **Ses:** sıcak, kısa, oyuncuya "sen" diye hitap eden. Örnekler: "Ödülün hazır!", "Bir oka dokun, tahtadan kaçsın.", "Kalan ok: 13".
- **Büyük harf:** başlıklar ve düğmeler cümle düzeninde. `text-transform: uppercase` kullanılmaz (Türkçe i/İ dönüşümü bozulur).
- **Düğmeler** olanı söyler: "Devam: Seviye 110", "Satın al", "Kuşan", "Haritaya dön". Bildirim sonucu söyler: "Tema kuşanıldı".
- **Rakamlar** her dilde Batı rakamı (0–9), eşit genişlikte (`hud`, `node-num`, `reward` stilleri).
- **Emoji** kullanılmaz; simgeler `Icon` setinden gelir.
- **Diller:** Türkçe, İngilizce, Almanca, Arapça. Almanca uzun metin düğmeyi büyütür, asla kırpılmaz. Arapça sağdan sola (aşağıya bakın).

## Renk

Kullanılacak token adları `tokens.json` ile aynıdır. Koddaki tek renk kaynağı `design/colors.json`'dır: `tools/gen-tokens.js` web (`style.css`, `theme.js`) ve Flutter (`tokens.dart`) renklerini oradan üretir. İki tema: **Kum (açık)** ve **Kömür (koyu)**. Tema `prefers-color-scheme` ile seçilir, Ayarlar › Görünüm (Otomatik / Açık / Koyu) ile değiştirilir (`data-theme`).

- Ekran zemini `bg`; tahta ve modal `board`; kabarık kontroller `card`; çukur izler (sekme, segment, takvim günü, kilitli düğüm) `cell`; her kabarık nesnenin alt kenarı `edge`.
- Metin `ink`, ikincil metin `ink-soft`. Her ikisi de `bg`, `card` ve `board` üstünde ≥ 4,5:1.
- Birincil eylem `accent` dolgu + `accent-ink` yazı. Ekranda bir tane.
- Diğer renkli dolguların (`success`, `danger`, Orta etiketinde `accent`) yazısı `on-fill`: açıkta beyaz, koyuda kömür. Altın dolguların (`star`, `coin`) yazısı her temada `on-gold`.
- Simgede, ipucu halkasında ve klavye odak halkasında altın için `star-ink`, jeton için `coin-ink` kullanın; `star` ve `coin` yalnızca rozet **dolgusu**dur (açık temada kart üstünde 3:1'in altında kalırlar).
- `success` tamamlanmış ve açık durumlar; `danger` can ve hata; `extreme` / `extreme-deep` yalnızca "Aşırı zor" kademesi.
- Bildirim ve yönlendirme balonu ters renklidir: `ink` dolgu, `bg` yazı.
- Modal perdesi `scrim`; yüzen katman gölgesi `shadow`.

### Ok temaları

Oklar temanın 5 rengini sırayla kullanır (`index mod 5`); komşu oklar aynı rengi almaz. Ok renkleri iki temada aynıdır ve açık/koyu `board` üstünde ≥ 3:1'dir (`tools/contrast.js`, CI'da çalışır).

| Tema | Fiyat | Tokenlar |
|---|---|---|
| Emaye (varsayılan) | ücretsiz | `arrow-emaye-1…5` turkuaz, kiremit, hardal, çivit, erik · `arrow-emaye-chevron` |
| Lokum | 300 | `arrow-lokum-1…5` |
| Çini | 500 | `arrow-cini-1…5` |
| Bakır | 750 | `arrow-bakir-1…5` |
| Gece Lambası | 1000 | `arrow-gece-1…5` · koyu şevron |

**Tek renk kipi:** oklar `ink` renginde ince çizgi (`arrow-mono-body`); gölge, şevron ve nokta yok.

### Kontrast

Her renk çifti `tools/contrast.js` ile CI'da denetlenir (100 çift; metin ≥ 4,5:1, simge, ok ve odak halkası ≥ 3:1). 1.2.2'de kapanan açıklar:

| Çift | Eski | Yeni | Çözüm |
|---|---|---|---|
| Odak halkası / `board` (açık) | 2,15 | 3,66 | halka `star` yerine `star-ink` |
| Dolgu yazısı / `success` (koyu) | 2,26 | 7,95 | beyaz yerine `on-fill` |
| Dolgu yazısı / `accent` (koyu) | 2,44 | 7,36 | beyaz yerine `on-fill` |
| Dolgu yazısı / `danger` (koyu) | 3,07 | 5,86 | beyaz yerine `on-fill` |
| Beyaz / `success` (açık) | 4,04 | 5,29 | `success` #2F8F5B → #267A4D |
| `success` metin / kart (açık) | 3,84 | 5,03 | aynı renk değişikliği |

### Yüksek kontrast

Ayarlar › Görünüm › **Yüksek kontrast** anahtarı, Otomatik / Açık / Koyu seçimiyle birlikte çalışan iki ek tema açar: **Yüksek kontrast (açık)** ve **Yüksek kontrast (koyu)**. Oyuncu anahtara dokunmadıysa cihazın ayarı izlenir (web `prefers-contrast: more`, Flutter `MediaQuery.highContrast`). Web'de kök öğeye `data-contrast="more"` konur; Flutter'da `Palette.lightHc` / `Palette.darkHc` seçilir (`pal.hc`).

- **Renkler:** aynı token adları, daha güçlü değerler (`design/colors.json` › `paletteHc`). Metin `ink` ve `ink-soft` her yüzeyde ≥ 7:1; dolgu yazıları (`accent-ink`, `on-fill`, `on-gold`) ≥ 7:1; `edge`, `star-ink`, `cell-dot` ≥ 3:1.
- **Kenarlık:** kabarık yüzeyler (ikincil düğme, simge düğmesi, araç, hap, kart, ayar grubu, modal, sekme ve segment izi, gün kutuları) gölge tonuyla değil 2 px `edge` kenarlıkla ayrılır. Web'de `outline` + negatif öteleme kullanılır, düzen kaymaz.
- **Odak:** 4 px `star-ink` halka.
- **Devre dışı:** saydamlık yok; `cell` zemin, `ink-soft` yazı, 2 px kesikli kenarlık.
- **Tahta:** oklar tema renklerini korur, çevrelerine 1,5 px `ink` kontur çizilir. Izgara noktaları tam opaktır.
- Ayırıcı çizgiler (`SettingsGroup`) `edge` renginde; seçili sekme alt çizgisi 4 px.

## Tipografi

- **Tek aile: Readex Pro** (değişken, ağırlık 160–700, SIL OFL 1.1; `fonts/ReadexPro-VF.ttf`, lisans `licenses/ReadexPro-OFL.txt`). Latin ve Arapça aynı çizgi kalınlığı ve x-yüksekliğinde. Ağdan yüklenmez, uygulamayla paketlenir. Flutter'da statik kesitler: Regular, Medium, SemiBold, Bold.
- Aileler: `sans` (Latin metin), `arabic`, `num` (rakamlar, `ui-rounded` yedekli), `mono` (yalnızca kayıt kodu kutusu).
- Ağırlıklar: 400 gövde, 600 açıklama, 700 başlık, düğme ve sayılar.
- Ölçek: `title` 30, `sheet-title` / `cel-msg` 24, `bar-title` 22, `chapter` 20, `item-name` / `button` 18, `body` / `label` 17, `tool-label` 15, `small` 14, `caption` 13, `tool-sub` 12, `tag` 11. Sayılar: `reward` 26, `node-num` 22, `hud` 17.
- Kalın başlık ve etiketler 700 (yazı tipinin üst sınırı). 1.2.2 öncesi kodda 800 yazıyordu, zaten 700 çiziliyordu.
- Gövde satır yüksekliği 1,3. **Arapça:** boyut ×1,08, satır yüksekliği 1,55 (`THEME.applyLang` → `--fs-scale`, `--lh`).
- Başlıklarda `text-wrap: balance` yerine kaydırma ve küçültme kuralı geçerlidir (Button'a bakın).

## Boşluk, köşe, gölge

- Boşluk adımları px cinsinden: `space-2 4 6 8 10 12 14 16 18 24`. Menü kenar boşluğu `space-24`, kaydırma alanları `space-16`, kart iç dolgusu `space-12`–`space-14`, ızgara aralığı `space-12`.
- Köşeler rol bazlıdır: `radius-sm` 10 (segment, takvim günü) · `radius-md` 12 (sekme) · `radius-btn` 14 (düğme, bildirim) · `radius-tool` 16 (araç, balon) · `radius-card` 18 (kart, ayar grubu) · `radius-sheet` 22 (modal) · `radius-logo` 30 · `radius-pill`.
- Gölge **sert ötelemedir**, bulanık değil: `raise-2` hap ve küçük düğme, `raise-3` simge düğmesi ve kart, `raise-4` düğme ve araç, `raise-6` uygulama simgesi; basılı hali `raise-1`. Dolgulu düğmelerde öteleme rengi dolgunun %60 siyahla karışımıdır. Bulanık gölge yalnızca `sheet` ve `float`.
- Kenarlık neredeyse hiç kullanılmaz; ayrım dolgu tonu + kalınlıkla yapılır. İstisnalar: reklam yuvasının kesikli `edge` çerçevesi, dil düğmesinin seçili `accent` kenarı, ayar satırları arasındaki 1 px `cell` çizgi.

## Düzen

- Dikey, tek sütun; geniş ekranda en fazla `app-max-width` 480 px, ortalı. Yatay telefonda "cihazı döndür" ekranı.
- Ekranlar üstte `TopBar`, ortada içerik (harita kaydırılır, oyun tahtası sığdırılır), altta araç çubuğu veya reklam yuvası (56 px, üstünde 16 px dokunulmaz boşluk; yalnızca menü ve haritada).
- Güvenli alanlar (`env(safe-area-inset-*)`) ekran dolgusuna eklenir.
- Dokunma hedefi en az `touch-min` 44 px, düğme `btn-height` 52 px.

## Sağdan sola (Arapça)

**Aynalanır:** metin hizası (`text-align: start`), satır ve menü sırası (yalnızca `margin-inline-*` / `padding-inline-*` / `inset-inline-*`; left/right yazılmaz), geri oku (`at-flip-rtl`), ilerleme yönü, anahtar topuzu.
**Aynalanmaz:** oyun tahtası, ızgara, okların yönü ve çizimi, sayılar, yıldız dizisi (1-2-3 soldan sağa), oynat simgesi, uygulama simgesi.

## Hareket

| Olay | Süre | Eğri |
|---|---|---|
| Düğme basma / bırakma | `dur-press` 90 / `dur-release` 160 | `ease-btn` |
| Ekran geçişi | `dur-screen` 200 opaklık | ease-out |
| Modal açılışı | `dur-sheet` 260, ölçek .9 → 1 | `ease-back` |
| Ok çıkışı | hücre başına `dur-exit-cell` 26 (260–1100) | sabit hız, ok kendi yolunu izler |
| Çarpma | 90 ileri → 220 geri; tahta 260 sarsılır (genlik 0,08·hücre, 3 salınım) | ileri ease-in, geri `ease-back` |
| Yıldızlar | her biri `dur-star` 380, 180 arayla; 0 → 1,15 → 1 | `ease-star` |
| İpucu halkası | `dur-hint` 900 nefes döngüsü | sinüs |

`prefers-reduced-motion` (Flutter: `MediaQuery.disableAnimations`): sarsıntı, atalet ve görünüm geçişleri kapanır, ok çıkışı en fazla 180 ms sürer, yıldızlar yalnızca belirir, sallanan/nabız animasyonları durur. Ses kapalıyken de her olayın görsel karşılığı vardır.

## Simgeler

- 23 satır içi SVG, 24 × 24 görünüm kutusu (`Icon` bileşeni; kaynak `game/js/main.js` `ICONS`). Çizgi simgeler `currentColor`, 2–3 px kontur, yuvarlak uç ve birleşim; renkli simgeler anlam token'larını kullanır (`coin-ink`, `star-ink`, `danger`, `success`, `ink-soft`).
- `assets/Icons/*.svg` aynı simgelerin açık temaya çözülmüş kopyalarıdır (`currentColor` → `ink` #22252B). Tema uyumlu kullanım için satır içi SVG'yi tercih edin.
- Emoji ve ikinci bir simge kütüphanesi kullanılmaz.

## Logo

- `assets/Logos/arrowtile-icon.svg`: yayındaki uygulama simgesi. Kobalt (#2456A6) zemin, beyaz 2 × 2 tahta, yukarı bakan kırmızı ok ve tahtadan sağa kaçan safran ok. Bu simge 1.2.0 öncesi "Emaye levha" paletinden kalmadır; mağaza kimliği ayrı bir karar olarak bekletiliyor.
- `assets/Logos/arrowtile-icon-candidate.svg`: "Kum ve Mürekkep" paletine uyumlu aday (mürekkep zemin, kum tahta, turkuaz ve kiremit oklar), Play mağaza denemesi için.
- Önemli öğeler merkezdeki %66'lık güvenli dairede kalır; zemin kenarlara taşar (uyarlanabilir simge maskesi).
- Yazı markası yoktur; uygulama adı `title` stilinde Readex Pro ile yazılır: "Arrowtile".

## Bileşenler

Bileşenler `components/bundle.css` içindeki `at-` önekli sınıflarla düz HTML olarak kullanılır (JavaScript paketi yok). Oyun tahtası ve oklar Canvas 2D ile çizilir: `Arrow` ve `Board` önizlemeleri `drawArrow` / `drawBoard` portunu içerir.

- **Eylemler:** Button, IconButton, Tool
- **Durum:** Pill, Tag, DifficultyTag
- **Gezinme:** TopBar, LevelNode, ChapterHeader, MapPath
- **Formlar:** Tabs, Switch, SettingsGroup, LanguagePicker
- **Katmanlar:** Sheet, Toast, CoachBubble
- **İçerik:** ShopItem, DailyReward, Calendar, Flame, AdBanner
- **Oyun:** Arrow, Board
- **Simgeler:** Icon

**Bu sistemde olmayanlar (kaynakta var, ayrı bileşen yapılmadı):** reklam yükleniyor kaplaması (`Sheet` + döner gösterge), kayıt kodu kutusu (`code` stili), yatay ekran uyarısı. Alevin renkleri illüstrasyon sabitidir (`flame-*`, `torch-*`, `spark`) ve `design/colors.json` dışında, doğrudan `style.css`'te durur.
