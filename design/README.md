# design/

Arrowtile'ın görsel dili **"Kum ve Mürekkep"** için kaynak klasör.

| Yol | Ne |
|---|---|
| `colors.json` | **Renklerin tek kaynağı.** `node tools/gen-tokens.js` bu dosyadan `game/css/style.css`, `game/js/theme.js` ve `flutter/arrowtile/lib/ui/tokens.dart` içindeki `@tokens` bölgelerini üretir. |
| `system/README.md` | Marka kitabı: ilkeler, metin dili, renk, tipografi, boşluk, köşe, gölge, düzen, RTL, hareket, simgeler, logo. |
| `system/tokens.json` | Tüm tokenlar (renk, yazı stilleri, boşluk, köşe, gölge, boyut, süre, eğri, ok geometrisi). Renk değerleri `colors.json` ile aynı olmalıdır; `tools/gen-tokens.js --check` bunu denetler. |
| `system/components/` | 21 bileşenin yönergesi (`README.md`) ve önizlemesi (`preview.html`); ortak stiller `bundle.css` (`at-` önekli sınıflar). |
| `system/assets/` | Uygulama simgesi (yayındaki + aday) ve 23 arayüz simgesi (açık temaya çözülmüş SVG kopyaları). |

Canlı, gezilebilir sürüm: Claude'daki "Arrowtile" Design System artifact'ı (önizlemeler orada `tokens.css` ile birlikte çizilir; buradaki `preview.html` dosyaları o sayfanın ürettiği `tokens.css`'e dayanır, tek başına açıldığında renksiz görünür). Yazı tipi: `game/assets/fonts/ReadexPro-VF.ttf` (SIL OFL 1.1).

**Bir rengi değiştirmek:** `colors.json`'u düzenleyin → `node tools/gen-tokens.js` → `system/tokens.json`'daki aynı tokenı güncelleyin → `node tools/gen-tokens.js --check && node tools/contrast.js`.
