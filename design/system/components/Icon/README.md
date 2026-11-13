# Icon
Uygulamanın 23 satır içi SVG simgesi (`game/js/main.js` `ICONS`), 24 × 24 görünüm kutusu.

**Tüketicinin sağladığı:** `<span class="at-ic">` içinde SVG; boyut kapsayıcıdan gelir (varsayılan 24 px).
- **Çizgi simgeler** (map, shop, gear, back, restart, calendar, fit, zoomin, rotate, check, noads, pause, lock): `currentColor`, 2–3 px kontur, yuvarlak uç ve birleşim. Üstündeki metnin rengini alır.
- **Renkli simgeler** anlam renklerini token'dan alır: coin → `coin-ink`, star/bulb/trophy → `star-ink`, heart/gift → `danger`, leaf → `success`, boş yıldız/kalp → `ink-soft` çerçeve.
- Emoji kullanılmaz. Geri oku RTL'de aynalanır (`at-flip-rtl`).
- `assets/Icons` altındaki dosyalar açık temaya çözülmüş renklerle kopyalardır; tema uyumlu kullanım için satır içi SVG'yi tercih edin.
