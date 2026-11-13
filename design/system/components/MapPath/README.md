# MapPath
Seviye haritasında bir bölümün 20 seviyesini birleştiren kıvrımlı yol; düğümler (`LevelNode`) yolun üstüne oturur.

**Tüketicinin sağladığı:** `.at-path` (yükseklik = bölümdeki seviye sayısı × adım), içinde bir `svg.trail` (iki `path`) ve mutlak konumlu `LevelNode`'lar; her 5 seviyede bir `.at-tier-label`.

- Yol: x = 50 + 30·sin(i·π/3) (yüzde), y alttan yukarı 96 px adımla (kaynak `MAP.STEP`); ilk seviye en altta. RTL'de x aynalanır (100 − x).
- Çizim: alta `edge` renginde 14 px yuvarlak uçlu şerit, üstüne `board` renginde 4 px kesik çizgi (2/12). `vector-effect: non-scaling-stroke` ile kalınlık ölçekten bağımsız.
- Kademe etiketi her kademe diliminin başında, düğümün 30 % yanında: Kolay `success`, Orta `accent` (yazı `on-fill`), Zor `coin` (yazı `on-gold`), Aşırı zor `extreme-deep`.
- Harita sanal listelenir: yalnızca görünen bölümler ± 1 DOM'dadır; açılışta mevcut seviye ekranın ortasına kaydırılır.
