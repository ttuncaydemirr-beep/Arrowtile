# Ok Kaçış — Rakip Analizi ve Güncelleme Listesi (v1)

Tarih: 25.10.2026 · Hazırlayan: Yönetici

## İncelenen rakipler
| Oyun | Yayıncı | İndirme | Puan | Gelir modeli |
|---|---|---|---|---|
| Arrows – Puzzle Escape | Lessmore | 100M+ | 4,7 (≈2,2M yorum) | Reklam + uygulama içi satın alma |
| Arrow Puzzle: Tap Puzzle Games | Easybrain | 50M+ (≈99M kurulum) | 4,84 (≈1,55M) | Reklam; günlük/aylık görev, kupa |
| Arrow Maze – Tap Away | — | 1M+ | 4,8 (≈99K) | Reklam |
| Tap Away: Tap Puzzle Game | PlayZ | 1M+ | 4,3 (≈6K) | Reklam + satın alma |
| Arrow Fever: Tap Out (iOS) | — | — | 4,6 (≈24K) | Reklam kaldırma 7,99 $, jeton paketleri |
| Arrows Puzzle: Escape Out! (iOS) | — | — | 4,5 (≈3K) | Reklam kaldırma, paketler, kumbara |

## Yorumlardaki tekrar eden şikâyetler
1. **Reklam yoğunluğu** (en sık): her seviye sonrası reklam, ilerledikçe uzayan reklamlar, kapanması zor reklamlar, başka oyunlara yönlendirme.
2. **Yanlış dokunma**: komşu oka basılıyor, can gidiyor. Büyük tahtada yakınlaştırınca tahtanın tamamı görünmüyor; iPad'de tahta kayıyor.
3. **Geri alma yok**: tek hatayı geri alma isteniyor (reklam karşılığı bile olsa).
4. **Zorluk etiketleri yalan**: "Kabus" seviyeler kolay bulunuyor.
5. **İlerleme kaybı / takılma**: seviye geçmiyor, aynı bulmaca tekrarlıyor, yeniden kurunca ilerleme siliniyor, oyun kapanıyor.
6. **"Çevrimdışı" ama internet istiyor.**
7. **Destek yok**: oyun içinde destek bağlantısı bulunamıyor.
8. **Sonradan eklenen süre sınırı** ve reklamla ek süre alma baskısı.
9. İstekler: 3'ten fazla can, ok rengi değiştirme, karanlık mod, okun yolunu önizleme (bazıları) / anında fırlatma (bazıları).

## Övülenler (korunacak)
Süre sınırı yok, sakin/minimal görünüm, karanlık mod, çevrimdışı oynanabilme, ipucu, çok seviye, günlük görevler.

## Bizim durumumuz
Zaten var: süre yok, çevrimdışı ve veri toplamıyor, geri alma, ipucu, ok temaları, oyun içi destek e-postası, reklam yok.

## Güncelleme listesi (geliştiriciye)
| # | Değişiklik | Neden |
|---|---|---|
| G1 | **Dokunma koruması**: isabet alanı okun gövdesine göre genişletilir, iki okun arasındaki belirsiz dokunuş hiçbir oku oynatmaz (titreşim + kısa vurgu). Ayarlarda "Önce seç, sonra fırlat" seçeneği: ilk dokunuş oku ve yolunu gösterir, ikinci dokunuş fırlatır. Hücre 40 px'ten küçükse bu seçenek ilk kez önerilir. | 2. şikâyet |
| G2 | **Tahta her zaman ekrana sığar**; iki parmakla yakınlaştırma + kaydırma, köşede "sığdır" düğmesi, yakınken küçük bir harita. Oyun sırasında tahta kendiliğinden kaymaz. | 2 |
| G3 | **Rahat mod** (Ayarlar): can yok, yıldız en fazla 2, jeton yarı. | 9, erişilebilirlik |
| G4 | **Seviye sayısı 36 → 120** (4 bölüm daha), zorluk etiketi çözücünün ölçtüğü bağımlılık derinliğine göre gerçekçi: Kolay / Orta / Zor / Uzman. | 4, içerik miktarı |
| G5 | **Günlük bulmaca**: tarihten üretilen tohumla çevrimdışı üretilen tek bulmaca, takvim ve seri sayacı; tamamlayana küçük kupa. | övülen özellik |
| G6 | **Kayıt yedeği**: Ayarlar'da "İlerlemeyi dışa aktar / içe aktar" (kısa metin kodu, panoya kopyala). | 5 |
| G7 | **Karanlık mod seçimi**: Otomatik / Açık / Koyu. | 9 |
| G8 | **Reklam + reklamları kaldır İLK SÜRÜMDE** (kullanıcı kararı, 25.10.2026). Kurallar brifte "Reklam ve satın alma" bölümünde. | 1, 6, 8 |
| G9 | Mağaza açıklaması 4 dilde şu üç vaadi öne çıkarır: süre yok, internetsiz oynanır, geri alma var. ("Veri toplamaz" ifadesi reklam nedeniyle kaldırılır.) | farklılaşma |

Kaynaklar: Google Play ve App Store mağaza sayfaları ile AppBrain (Ekim 2026).
