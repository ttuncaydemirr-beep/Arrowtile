# Board
Okların durduğu tepsi: düz `board` yüzeyi, altında `edge` kalınlığı, yalnızca hücre köşelerinde `cell-dot` noktaları.

**Tüketicinin sağladığı:** tahta boyutu (w × h hücre) ve ok listesi; hücre boyu ekrandan hesaplanır.
- Köşe yarıçapı `board-radius` 0,30·hücre (en fazla 10 px), iç dolgu `board-pad` 0,30 (21+ sütunda 0,1), alt kalınlık 0,1·hücre.
- Izgara çizgisi ve hücre kutusu **yok**; köşe noktaları açıkta %75, koyuda %55 opaklık.
- Hücre boyu: `min((genişlik − 8) / (w + 0,6), (yükseklik − 16) / (h + 0,7))`, en fazla 72 px. Tahta her zaman ekrana sığarak açılır (15 × 22'de 360 px ekranda ≥ 22 px), iki parmakla 4×'e kadar yakınlaşır.
- Oklar tahtadan çıkarken kenarda kırpılmaz, ekran kenarına kadar uçar.
- Oyun ekranında üst kenarın ortasında `DifficultyTag.lg`.
