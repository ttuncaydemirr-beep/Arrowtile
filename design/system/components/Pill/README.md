# Pill
HUD sayacı: jeton bakiyesi gibi tek bir sayıyı simgesiyle gösteren hap; can ve yıldız dizileri de burada.

**Tüketicinin sağladığı:** `<span class="at-pill">` + `.at-ic` + `<span class="at-num">`.

- `card` dolgu, `radius-pill`, `raise-2`, 700 ağırlık. Sayılar `hud` stilinde, eşit genişlikte; her dilde `direction: ltr`.
- Can: dolu kalp `danger`, kaybedilen can **içi boş kalp** (`ink-soft` çerçeve) — renk tek başına anlam taşımaz.
- Yıldız: dolu `star-ink`, boş **çerçeve** `ink-soft`. Yıldız dizisi RTL'de de soldan sağa kalır.
- 400 px'den dar ekranda harita çubuğunda jeton hapı gizlenir.
