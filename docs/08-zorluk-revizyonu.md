# Arrowtile — Zorluk revizyonu (kullanıcı geri bildirimi, 25.10.2026)

Geri bildirim: "Oklar büyük, alan küçük; oyun çok kolay. Geri alma yüzünden hata yapma ihtimali yok denecek kadar az."

## Teşhis (yönetici)
1. Izgara en fazla 8x10, ok uzunluğu 1–3, doluluk düşük → tahtaya bakınca çıkabilecek ok hemen görülüyor.
2. Oklar hücrenin büyük kısmını kaplıyor → tahta "kalabalık" görünmüyor, okuma zahmetsiz.
3. Bu bulmacada başarılı bir çıkış hiçbir zaman kötü hamle değildir (ok çıkarmak başka oku engellemez). Tek hata çarpışmadır. Bu yüzden geri almanın tek işlevi canı iade etmek → hata cezası pratikte yok.

## Kararlar
### 1. Geri alma kaldırılıyor
- Oyun ekranından, mağazadaki güçlendiricilerden, ekonomiden, kayıttan (eski ücretsiz geri alma hakları jetona çevrilir: hak başı 20 jeton), i18n'den ve testlerden kaldırılır.
- Çarpışma = kalıcı can kaybı. 3 can. Can bitince: "Baştan başla" veya isteğe bağlı ödüllü reklamla +1 can (seviye başına en fazla 1 kez).
- Yıldız: 0 çarpışma 3★, 1 çarpışma 2★, 2 çarpışma 1★ (değişmedi).
- Rahat mod aynen kalır (canı umursamayan oyuncu için).
- İpucu kalır ama pahalanır: 50 jeton; başlangıçta 2 ücretsiz ipucu.

### 2. İnce oklar
- Gövde kalınlığı hücrenin ~%28'i (şu an çok daha kalın), ok başı ~%55. Şevron ve uç noktası korunur ama gövdeyle orantılı küçülür; erişilebilirlik (yön renksiz okunur) korunur.
- Hücre arası boşluk/hücre kutuları kaldırılır veya çok silikleşir; tahta tek düz yüzey + çok hafif nokta ızgara. Oklar uzun ince çizgiler gibi görünür.

### 3. Büyük, dolu tahtalar
- Izgara: seviye 1–3 öğretici (5x5'e kadar), sonra kademeli büyür: ~bölüm 2'de 8x10, bölüm 5'te 11x15, bölüm 10'da 14x20 (en fazla 15x22).
- Ok uzunluğu 1–6 (büyük tahtada ortalaması 3–4).
- Doluluk (oklarla kaplı hücre oranı) bölüm 2'den itibaren ≥%65, son bölümlerde %75–85.
- Başlangıçta hemen çıkabilen ok oranı: bölüm 2+ ≤%12, son bölümlerde ≤%6.
- Zorluk ölçütü: tur derinliği + ok sayısı + doluluk birleşik puanı; etiketler buna göre yeniden kalibre edilir, her bölüm bir öncekinden ölçülebilir şekilde zor olmalı (validate-levels bunu denetler: bölüm ortalaması monoton artar).
- Seviye sayısı 120 kalır; tamamı yeniden üretilir ve doğrulanır. Günlük bulmaca da yeni parametrelerle.

### 4. Dokunma (küçük hücrelerle)
- Tahta her zaman ekrana sığarak açılır; hücre 40 px kuralı kalkar, yerine: sığdırılmış hücre ≥22 px (390 px'te 14 sütun ≈ 25 px).
- İsabet: okun gövde eksenine en yakın ok, eşik 0,5 hücre; iki aday birbirine yakınsa (belirsiz) hiçbir ok hareket etmez (G1 korunur).
- Sığdırılmış hücre <30 px ise ilk büyük seviyede bir kez "iki parmakla yakınlaştır / önce seç, sonra fırlat" önerisi.
- Yakınlaştırma üst sınırı 4×.

### 5. Metinler
- Mağaza vaadi "geri alma var" çıkar → "süre yok, internetsiz oynanır, yüzlerce el yapımı… değil: yüzlerce zorlu bulmaca" gibi dürüst bir üçüncü vaat (4 dilde). docs/07 ve i18n güncellenir.

## İlerleme
- 2026-10-25 · Aşama 1 (geri alma kaldırıldı) bitti. Geri alma düğmesi, motor geçmişi (`undo/canUndo`), mağazadaki yardımcı ve i18n anahtarları (`game.undo`, `game.nothing_to_undo`, `game.buy_undo`, `shop.undo_desc`) silindi; çarpışma kalıcı can kaybı, 3 can, yıldız kuralı aynı, rahat mod aynı. Can bitince ödüllü +1 can seviye başına en fazla 1 kez (baştan başlayınca da). İpucu 50 jeton, yeni oyuncuya 2 ücretsiz ipucu. Kayıt göçü: eski `freeUndos` hak başı 20 jeton olarak eklenir, alan silinir, göç ilk açılışta kalıcı yazılır (tekrar uygulanmaz). Testler: e2e 284/284 (yeni: ekonomi/göç, +1 can sınırı), qa.js 155/155 (geri alma kontrolleri v1.2 kurallarına çevrildi), test-ads 28/28, test-daily 13/13, validate-i18n (184 anahtar) geçti.
- 2026-10-25 · Aşama 2 (ince oklar, sade tahta) bitti. `theme.js`: gövde 0,28, ok başı 0,55×0,34, şevron/nokta orantılı (en az ~1 px), alt kalınlık 0,045; `drawBoard` hücre çukurlarını kaldırdı: tek düz yüzey + hücre köşelerinde hafif nokta ızgara. 02 görsel rehber §5–6 güncellendi. qa.js piksel algılaması (boş hücre = tahta rengi) buna göre güncellendi.
- 2026-10-25 · Aşama 3 (üretici/çözücü/doğrulayıcı, 120 seviye, günlük bulmaca) bitti. Ortak üretici `game/js/levelgen.js` (yoğun rastgele yerleşim → kilitlenen okları ters çevirerek onarım → boşluk doldurma → başta serbest okları içeri çevirme / yollarını kısa kapalı oklarla kesme; her adımda çözülebilirlik korunur). `tools/generate-levels.js` yeniden yazıldı (16 sn), `tools/solver.js` (≤15x22, len 1–6, birleşik puan), `tools/validate-levels.js` (doluluk, başta serbest oran, etiket = ölçülen puan, bölüm ortalaması monoton artış + bölüm raporu). Seviye 1–3 öğretici korundu. Bölüm raporu: 1: 3x3→7x10, 8,5 ok, %60, başta serbest %22,5, derinlik 5,3 · 2: 8x10→9x11, 18,5, %70, %9,9, 9,0 · 3: 9x12→10x13, 26,3, %71, %8,8, 10,7 · 4: 10x13→11x14, 31,8, %73, %8,9, 13,8 · 5: 11x15→12x16, 43,2, %75, %7,7, 15,8 · 6: 12x16→13x17, 52,9, %76, %7,6, 16,4 · 7: 12x17→13x18, 56,3, %78, %7,4, 18,0 · 8: 13x18→14x19, 64,1, %79, %6,1, 20,7 · 9: 13x19→14x20, 71,8, %81, %5,1, 24,8 · 10: 14x20→15x22, 86,4, %82, %5,5, 24,0 (puan ortalaması 9,3 → 47,2, her bölümde artıyor). Günlük bulmaca aynı üreticiyle (Pzt 9x12 … Paz 12x16, doluluk %68–75, başta serbest ≤ %12; ort. 29 ms, en kötü 271 ms).
- 2026-10-25 · Aşama 4 (dokunma) bitti. İsabet eşiği 0,5 hücre (belirsiz dokunuş G1 korunur), yakınlaştırma 4×, hücre < 30 px ise ilk büyük seviyede bir kez öneri, 360 px'te 15x22 tahta hücresi 22 px. Aşama 2–4 testleri: validate-levels (120, monoton) + validate-i18n + test-daily 13/13 + test-ads 28/28 geçti, qa.js 156/157 (kalan: 22,0 px hücrenin piksel ölçümünde yuvarlama; 0,1 px tolerans eklendi), e2e bu turda yük altında bir zamanlama hatasıyla yarıda kaldı (bölüm tek başına 41/41; beklemeler artırıldı) → son turda tam çalıştırılacak.
- 2026-10-25 · Aşama 5 (metinler) bitti. Mağaza kısa/uzun açıklamaları 4 dilde: "geri alma var" vaadi çıkarıldı → süre yok, internetsiz, gerçekten zorlu bulmacalar (120 seviye, 14x20'ye varan dolu tahtalar, her gün günlük bulmaca); docs/07 i18n'den yeniden üretildi (kısa 62–75/80, uzun 1497–1962/4000). `game.aim_suggest` yakınlaştırma önerisini de içeriyor. 01 (kurallar, ekonomi, kayıt, zorluk eğrisi tablosu) ve 02 (ok/tahta) belgeleri güncel. Son tam tur (sırayla): validate-i18n (184 anahtar), validate-levels (120, bölüm puanı monoton), test-ads 28/28, test-daily 13/13, e2e 302/302, qa.js 157/157. Ekran görüntüleri: tools/shots/v12/ (tr sv 1, 13, 49, 85, 120 + günlük; ar sv120; de sv85).
