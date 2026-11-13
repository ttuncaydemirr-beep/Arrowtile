# LevelNode
Seviye haritasındaki 64 px yuvarlak düğüm; seviye numarası, durum, kademe ve kazanılan yıldızlar.

**Tüketicinin sağladığı:** seviye no (veya kilit simgesi), durum sınıfı, kademe sınıfı, isteğe bağlı `.at-node-stars` ve üstte `DifficultyTag`; hepsi `.at-node-wrap` içinde.

- Durum: varsayılan (oynanabilir) `accent`; `.done` `success`; `.locked` `cell` + iç `edge` halkası + kilit; `.current` 4 px `star` dış çerçeve.
- Kademe noktası sağ üst köşede, `board` çerçeveli 16 px: `tier-medium` yuvarlak kare, `tier-hard` baklava, `tier-extreme` daire + düğüm çevresinde 3 px `extreme` halka.
- Numara `node-num` stilinde (22/700).
