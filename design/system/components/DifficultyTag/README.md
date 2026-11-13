# DifficultyTag
Seviyenin zorluk kademesini gösteren küçük hap; harita düğümünün üstünde ve oyun ekranında tahtanın üst kenarında.

**Tüketicinin sağladığı:** kademe sınıfı (`easy`, `medium`, `hard`, `extreme`) + çevrilmiş ad. Oyun ekranında `.lg`.

| Kademe | Dolgu | Yazı | Düğüm noktası şekli |
|---|---|---|---|
| Kolay | `success` | `on-fill` | daire |
| Orta | `accent` | `on-fill` | yuvarlak kare |
| Zor | `coin` | `on-gold` | baklava |
| Aşırı zor | `extreme-deep` | beyaz | daire + düğüm halkası (`extreme`) |

Kademe her zaman **şekille de** ayrılır (docs/27 §B3); yalnızca renge güvenmeyin. `tag` stili 11/700.
