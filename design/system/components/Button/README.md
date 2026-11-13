# Button
Arrowtile'ın temel düğmesi: kabarık, 14 px köşeli, altında sert bir "kalınlık" gölgesi olan dokunma hedefi.

**Ne zaman:** her eylem için. Ekranda tek bir `primary` olur (menüde "Devam", modalda ana eylem). Yan eylemler `secondary`, üçüncül eylemler `ghost`.

**Tüketicinin sağladığı:** `<button class="at-btn …">` + etiket metni; isteğe bağlı başta bir simge (`.at-ic`), iki satırlı içerik için `.at-txt` içinde `<small>`.

| Sınıf | Görünüm |
|---|---|
| `primary` | `accent` dolgu, `accent-ink` yazı, gölge = dolgu %60 siyah |
| `secondary` | `card` dolgu, `ink` yazı, `raise-4` (modal içinde `cell` dolgu) |
| `ghost` | dolgusuz, `ink-soft` yazı, gölgesiz |
| `danger` | `danger` dolgu, `on-fill` yazı (açıkta beyaz, koyuda kömür) — yalnızca geri alınamaz eylemler |
| `equipped` | `success` dolgu, `on-fill` yazı — mağazada kuşanılmış tema |
| `big` / `tiny` / `block` / `lead` | 64 px · 36 px · tam genişlik · içerik başa hizalı |

**Kurallar**
- En az 52 px yükseklik, 18 px yatay dolgu. Uzun metin önce **2 satıra kayar**, sonra 1 px adımlarla en az **14 px**'e küçülür (`THEME.fitButton`). **Üç nokta ve kırpma yok**; gerekirse düğme uzar.
- Basınca `scale(.95) translateY(2px)`, gölge `raise-1`'e iner (90 ms, `ease-btn`).
- Odak: `star-ink` renginde 3 px çerçeve, 2 px öteleme (her yüzeyde ≥ 3:1).
- Devre dışı: %50 opaklık.
- Yazı: `button` stili (18/700); tümü büyük harf yok (Türkçe i/İ bozulmasın).
