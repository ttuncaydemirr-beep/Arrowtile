# Sheet
Modal pencere: duraklatma, seviye sonu, günlük ödül, onay.

**Tüketicinin sağladığı:** `.at-scrim` (tam ekran perde) içinde `.at-sheet`; `<h2>` başlık, `<p>` açıklama, isteğe bağlı yıldızlar / ödül, `.at-actions` içinde dikey düğme yığını.
- `board` dolgu, `radius-sheet` 22 px, `sheet` gölgesi (8 px kalın kenar + yumuşak gölge), en fazla 400 px, ortalı metin.
- Perde `scrim` (kömür, %55). Açılış 260 ms `ease-back` ile ölçek .9 → 1.
- Modal içindeki `secondary` düğme `cell` dolguya geçer (`board` üstünde ayrışsın diye).
- Yıldızlar 380 ms, 180 ms arayla patlar; ortadaki yıldız 10 px yukarıda.
