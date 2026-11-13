# Flame
Seviye sonu penceresinin üstündeki meşale: alevin boyu oyuncunun performansını, rengi kademesini anlatır.

**Tüketicinin sağladığı:** `.at-flame` + boy sınıfı (`f-s`, `f-m`, `f-l`) + isteğe bağlı `sparks` ve `gold`; içinde meşale SVG'si (64 × 100), kıvılcımlar için 7 `<i class="spark">` (`--dx`, `--d`), havai fişek için 3 `.fw` (her biri 10 `<i>`, `--a` açısı). `aria-hidden="true"`: anlam metindedir (`cel-msg`).

| Performans | Boy | Ek |
|---|---|---|
| Reklamla devam | `f-s` 52 px | — |
| 1–2 can kaybı | `f-m` 78 px | — |
| Kusursuz | `f-l` 108 px | `sparks` |
| Aşırı zor + kusursuz | `f-l` | `gold` + `sparks` + havai fişek (`star`, `danger`, `accent`) |

- Renkler illüstrasyon sabitleridir (`flame-*`, `torch-*`, `spark`), iki temada aynıdır; altın alevin dış katmanı `star`.
- Alev 900 ms ileri-geri titrer; kıvılcımlar 1500 ms, havai fişek 1700 ms döngüde. Azaltılmış harekette animasyon durur, kıvılcımlar sabit konumda görünür.
- Yavaşlık asla söylenmez: alev hiçbir durumda "kötü" görünmez, en küçük boy bile yanar.
