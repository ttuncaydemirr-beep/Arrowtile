# Arrow
Oyunun kahramanı: hücre ızgarasında kuyruktan başa giden, ok başlı kalın çizgi. Canvas 2D ile çizilir (`drawArrow`), DOM bileşeni değildir.

**Tüketicinin sağladığı:** `{ ox, oy, cell, cells: [[x,y]…] (kuyruk→baş), dir: 'R'|'D'|'L'|'U', color, chevron, highlight, mono }`.

**Anatomi** (oranlar hücre boyuna göre, `shape` tokenları)
1. Gövde: `arrow-body` 0,15 kalınlıkta, yuvarlak uçlu ve köşeli çizgi; kuyruk ve uç hücre kenarından `arrow-margin` 0,12 içeride.
2. Ok başı: genişlik `arrow-head-width` 0,40 (en az 7 px), uzunluk 0,30, köşeleri yuvarlatılmış üçgen.
3. Alt kalınlık: aynı yol `arrow-depth` 0,045 aşağıda, renk %35 koyu — ışık hep yukarıdan.
4. Yön işaretleri: her düz gövde hücresinde bir şevron (›) ve ok başında nokta, temanın `chevron` renginde. Hücre 22 px'den küçükse şevron çizilmez.
5. İpucu: `highlight-ring` (0,20) + `highlight` beyaz (0,08) iki kontur, 900 ms nefes.
6. Tek renk kipi: `ink` renginde `arrow-mono-body` 0,085 ince çizgi; gölge, şevron ve nokta yok.

**Kurallar**
- Yön **asla yalnızca renkle** verilmez: ok başı + şevron + nokta.
- Renk okları birbirinden ayırır; tema rengi `index mod 5` ile atanır, komşu oklar aynı rengi almaz.
- Tahta ve oklar RTL'de **aynalanmaz**.
- Çıkış: ok kendi yolunu izleyerek sabit hızla kaçar (hücre başına 26 ms, 260–1100 ms). Çarpma: 90 ms ileri, 220 ms `ease-back` geri, tahta 260 ms sarsılır.
