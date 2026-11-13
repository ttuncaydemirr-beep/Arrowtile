# Tabs
Sekmeler (`.at-tabs`, 2'li) ve segmentli seçici (`.at-seg`, 3'lü; `.two` ile 2'li).

**Tüketicinin sağladığı:** seçenek düğmeleri; seçili olana `.on` ve uygun ARIA (`aria-selected` / `aria-checked`).
- İz: `cell` dolgu, 4 px iç dolgu, 6 px aralık. Sekme izi `radius-tool`, segment izi `radius-btn`.
- Seçili seçenek üç yolla belli olur: `board` dolgu, `raise-2` ve **3 px `accent` alt çizgi** (docs/27 — yalnızca renk değil).
- Kullanım: mağaza sekmeleri, Görünüm (Otomatik/Açık/Koyu), ok rengi (Renkli/Tek renk).
