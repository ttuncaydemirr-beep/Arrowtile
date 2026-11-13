# AdBanner
Ana menü ve harita ekranının altındaki banner reklam yuvası; web önizlemede kesikli çerçeveli yer tutucu.

**Tüketicinin sağladığı:** ekranın en altında `.at-banner` (Flutter: `AdBannerSlot`); içeriği reklam SDK'sı doldurur. Web önizlemede metin "Reklam alanı" (i18n `ads.banner_placeholder`).

- Sabit 56 px yükseklik, tam genişlik; üstünde 16 px **dokunulmaz boşluk** (yanlış dokunuş önlemi). Reklam yüklenince düzen kaymaz.
- Yalnızca Ana menü ve Harita'da; oyun ekranında ve modallarda asla yok. "Reklamları kaldır" satın alındıysa gizlenir.
- Yer tutucu: 2 px kesikli `edge` çerçeve, `radius-sm`, `card` %60 dolgu, `ink-soft` yazı.
- Mağaza görsellerinde gösterilmez (`make-store-assets.py` örnek kayıtta `adFree`).
