# Arrowtile — Bölüm döngüsü revizyonu (kullanıcı kararı, 25.10.2026)

Geri bildirim: 9 yaşında bir çocuk 22. seviyeye zorlanmadan geldi. Kullanıcı istekleri:
1. Zorluk döngüsü: 3 bölüm KOLAY → 3 bölüm ORTA → 2 bölüm ZOR → 1 bölüm AŞIRI ZOR, sonra aynı döngü tekrar (ve böyle devam).
2. Oklar daha ince.
3. Tahta (alan) her bölümde biraz daha büyür.

## Yönetici kararları

### Yapı
- Döngü = 9 bölüm × 12 seviye = 108 seviye. İlk sürümde **2 tam döngü hazır üretilmiş ve doğrulanmış: 18 bölüm, 216 seviye**.
- 216'dan sonra oyun **sonsuz devam eder**: aynı 9'lu döngü, oyunun içindeki üreticiyle seviye numarasından türetilen sabit tohumla üretilir (aynı seviye herkes için aynı). Harita sonsuz bölüm listesini gösterir (görünür bölüm + bir sonraki kilitli).
- Seviye 1–3 öğretici aynen kalır (bölüm 1'in içinde, kolay).

### Tahta boyutu: her bölüm büyür, zorluktan bağımsız
- Bölüm 1: 7x9'dan başlar (öğretici hariç). Her bölümde yaklaşık +1 sütun / +1 satır (en-boy oranı telefona uygun ~0,7).
- Bölüm 18 sonu ≈ 20x28. Sonsuz bölümlerde 22x31'de sabitlenir.
- Bölüm içindeki 12 seviye de hafifçe büyür (ilk seviye bölümün en küçüğü).

### Zorluk kademeleri (tahta büyüklüğünden ayrı olarak)
Mevcut ölçümlere göre çocuk "doluluk %70, başta çıkabilen %10" seviyesini kolay buldu; bu yüzden kademeler buna göre yukarı çekildi:

| Kademe | Doluluk | Başta çıkabilen ok | Derinlik | Not |
|---|---|---|---|---|
| Kolay | %65–70 | ≤ %12 | düşük | Rahatlatıcı ama düşündürür |
| Orta | %75–80 | ≤ %7 | orta | |
| Zor | %82–86 | ≤ %4 | yüksek | Uzun bağımlılık zincirleri |
| Aşırı zor | %88–93 | ≤ %2 (en az 1) | en yüksek | Üretici çok deneme yapıp en derin adayı seçer |

- İkinci döngüdeki her kademe, birinci döngüdeki aynı kademeden ölçülebilir şekilde zor olmalı (tahta büyüdüğü için doğal olarak).
- Doğrulayıcı denetler: her bölümün ölçülen puanı kendi kademe bandında; döngü içinde Kolay < Orta < Zor < Aşırı zor; aynı kademe döngüden döngüye artar.
- Etiket: bölümün kademesi (Kolay / Orta / Zor / Aşırı zor) — haritada bölüm başlığında ve oyun ekranında. "Uzman" etiketi kalkar, yerine "Aşırı zor" (4 dilde).
- Aşırı zor bölümler haritada farklı görünür (ör. koyu/kırmızı rozet) ki oyuncu hazırlıklı girsin.

### Ödüller kademeye göre
- Seviye jetonu: Kolay ×1, Orta ×1,5, Zor ×2, Aşırı zor ×3 (taban: 10/15/20 jeton = 1/2/3 yıldız).
- Bölüm bonusu: Kolay 50, Orta 75, Zor 100, Aşırı zor 200.
- Reklam kuralları değişmez (bölüm 1 reklamsız).

### İnce oklar
- Gövde kalınlığı hücrenin %28'i → **%18**. Ok başı %55 → %42 genişlik.
- Hücre küçükse (< 22 px) gövdedeki şevronlar çizilmez; yönü ok başı verir. Ok başı en az 7 px genişlikte kalır.
- Renk körlüğü: ok başı şekli yönü her zaman gösterir.

### Kıvrımlı oklar (kullanıcı isteği, 25.10.2026 23:31)
- Oklar artık düz olmak zorunda değil: gövde, birbirine komşu hücrelerden geçen bir yol (yılan gibi). Şekiller: L, S/Z, U, merdiven, uzunlarda kıvrılan spiral benzeri. Uzunluk 1–8.
- Kural (rakiplerle aynı, öğrenmesi kolay): okun yönü BAŞININ baktığı yöndür. Dokununca ok başı o yönde düz ilerler, gövde başın geçtiği yoldan tren gibi takip eder. Çıkış koşulu değişmez: başın önündeki doğru (tahta kenarına kadar) boşsa ok çıkar; değilse baş engele kadar ilerler, çarpar, ok geri döner, 1 can gider. Gövdenin kendisi bu doğrunun üzerinde olamaz (üretici bunu garanti eder).
- Veri formatı: `{ cells: [[x,y], ...], dir }` — kuyruktan başa sıralı hücreler, her biri bir öncekine komşu; dir = baş yönü (son adımın yönüyle aynı olmak zorunda değil ama baş geriye, kendi gövdesine bakamaz). Düz ok bu formatın özel durumu. Eski `{x,y,dir,len}` okuma desteği kalır.
- Kademeye göre kıvrımlı ok oranı: Kolay ~%30, Orta ~%45, Zor ~%55, Aşırı zor ~%65. Öğretici 1–3 düz; ilk kıvrımlı ok seviye 4'te tek cümlelik ipucu baloncuğuyla tanıtılır (4 dil).
- Çizim: köşeleri yuvarlatılmış ince çizgi, ok başı sonda; şevronlar (hücre ≥ 22 px ise) her düz parçada akış yönünde. Animasyon: yılan gibi kayma (gövde yolu takip eder).
- Dokunma: okun çizgisine (polyline) en yakın mesafe ile isabet; belirsizlik kuralı aynen.
- Görsel çeşitlilik için renk ataması komşu oklar aynı renk olmayacak şekilde.

### Dokunma (daha küçük hücreler)
- Sığdırılmış hücre en az 16 px. Hücre < 26 px ise "önce seç, sonra fırlat" önerisi ilk kez gösterilir; yakınlaştırma üst sınırı 5×. Belirsiz dokunuş kuralı aynen.

### Bölüm adları
- 18 bölüm için 4 dilde ad (mevcut 10 ad korunur + 8 yeni). Sonsuz bölümler: "Bölüm 19" vb.

### Günlük bulmaca
- Haftanın günlerine kademe: Pzt–Çar Kolay, Per–Cum Orta, Cmt Zor, Paz Aşırı zor; tahta boyu orta (≈12x16).

## İlerleme
- **Aşama 1 (ince ok + kıvrımlı biçim) — tamam.** Gövde %18, baş %42 (en az 7 px), hücre < 22 px'te şevron yok; sığdırılmış hücre ≥ 16 px, geniş tahtada (≥ 21 sütun) tepsi dolgusu 0,1; "önce seç, sonra fırlat" önerisi hücre < 26 px'te; yakınlaştırma 5×. Yeni ok biçimi `{ cells, dir }` motor (`engine.js`), çözücü (`tools/solver.js`: komşuluk, uzunluk 1–8, kendi üstünden geçme, baş kendi gövdesine bakmaz, ızgara ≤ 22x31) ve üreticide (`levelgen.js`: baştan geriye büyüyen yılan gövdesi, kıvrımlı oran için ucu ucuna birleştirme — derinlik en çok %10 düşebilir); eski `{x,y,dir,len}` okunmaya devam ediyor. Çizim polyline (yuvarlak köşeli ince çizgi, sonda ok başı, düz parçalarda akış yönünde şevron); çıkış/çarpma animasyonu iz boyunca yılan gibi kayma; isabet okun çizgisine en yakın mesafe (eşik 0,5, belirsizlik 0,18 aynen); komşu oklar farklı renk (`OkEngine.colorize`). e2e alt kümesi (core, fix, feat, shots12) 69/69.
- **Aşama 2 (kademe bantları + kıvrımlı oran + 216 seviye) — tamam.** Bölüm/kademe/boyut kuralı oyunla ortak: `levelgen.js` `specFor(id)` (döngü K-K-K-O-O-O-Z-Z-A; tahta bölüm 1 başı 7x9 → bölüm 18 sonu 20x28, sonsuzda 22x31'de sabit; bölüm içinde hafif büyüme). Kademe bantları doluluk %65–70 / 75–80 / 82–86 / 88–93, başta çıkabilen ≤ %12 / 7 / 4 / 2 (en az 1); bandın üstüne taşma engellendi; fazla serbest okları silen son adım eklendi. `tools/generate-levels.js` 216 seviyeyi 18 sn'de yeniden üretir (aşırı zor: 4+ tur, en derin aday); `tools/validate-levels.js` yeniden yazıldı (yapı, bağımsız çözücü, ızgara planı, bant, başta çıkabilen, seviye 4'te kıvrımlı ok, bölüm kıvrımlı oranı, döngü içi K<O<Z<A ve döngüler arası artış) → 216/216 GEÇTİ. Döngü 1: Kolay 21,8 < Orta 34,2 < Zor 46,6 < Aşırı zor 57,2; döngü 2: 45,0 < 63,5 < 79,6 < 101,3. Kıvrımlı oran gerçekleşen: Kolay ~%42, Orta ~%48, Zor ~%52, Aşırı zor ~%55 (yüksek dolulukta 1–2 hücrelik dolgu okları oranı sınırlıyor; Kolay hedefin üstünde, Aşırı zor ~%65 hedefinin 10 puan altında — doğrulayıcı sınırı hedef −12). `analyze()` ara dizileri yeniden kullanacak şekilde hızlandırıldı (~3,5×, aynı sonuç). Günlük bulmaca 12x16, haftanın gününe göre kademe (`test-daily` 14/14). Bölüm raporu: `node tools/validate-levels.js --md`.
- **Aşama 3 (sonsuz devam + harita) — tamam.** 216'dan sonrası oyunda `LevelGen.levelJob(id)` ile üretilir: tohum = seviye no (`seedFor(id, tur)`), kısıtları sağlayan ilk tur (en çok 8), zaman sınırı yok → her cihazda aynı seviye. İş adım adım (tek build) arka planda çalışır; animasyon/dokunuş varken bekler; sıradaki seviye oyun başlarken, "Devam" seviyesi menüde önceden üretilir; son 4 seviye kayıt anahtarı + `.endless` önbelleğinde (debug'da kum havuzu anahtarı). Önceden üretilmemişse kısa "Seviye hazırlanıyor…" penceresi. Ölçüm (Node, bölüm 19–54, 108 seviye): Kolay/Orta/Zor tüm iş ≤ 0,14 sn; Aşırı zor 22x31 ortalama 0,78 sn, en kötü tüm iş 2,65 sn (4 tur), en uzun tek adım 0,92 sn — oyuncu önceden üretim sayesinde beklemez; tarayıcıda soğuk başlangıç 313 (aşırı zor 22x31) 0,36 sn. Harita: hazır 18 bölüm + sonsuzda oyuncunun bölümü ve bir sonraki (kilitli); bölüm başlığında kademe rozeti, Aşırı zor koyu kırmızı rozet + kırmızı kenar şeridi; düğüm etiketleri kaldırıldı; bölüm bonusu kademeye göre. Kayıt seviye no 99999'a kadar kabul eder; 216 bitince "sonsuz bölümler başlıyor" mesajı.
- **Aşama 4 (etiketler, ödüller, bölüm adları, mağaza metni) — tamam.** 4 dilde `diff.extreme` ("Aşırı zor" / "Very hard" / "Sehr schwer" / "صعب جدًا"; `diff.expert` kaldırıldı), 8 yeni bölüm adı (11–18: Mağara, Şelale, Bozkır, Fırtına, Ada, Kale, Kutup Işığı, Ay ve karşılıkları), sonsuz bölümler `map.chapter_n` ("Bölüm {n}"), `game.preparing`, seviye 4'te bir kez gösterilen kıvrımlı ok baloncuğu `tut.curve`, 216 bitince `end.all_done` "sonsuz bölümler başlıyor". Ödüller `storage.js`: seviye jetonu 10/15/20 × (1 / 1,5 / 2 / 3), bölüm bonusu 50/75/100/200 (haritada kademeye göre gösterilir). Mağaza kısa/uzun metinleri 216 seviye + sonsuz bölümler, 20x28, kıvrımlı oklar ve yeni etiketlerle güncellendi (kısa açıklama 78/77/79/70 ≤ 80); `docs/07` i18n'den yeniden üretildi; `docs/01` ödül tablosu güncellendi. `validate-i18n` GEÇTİ (195 anahtar × 4 dil).
- **Aşama 5 (sıralı tam test turu + görüntüler) — tamam.** Tek tek, sırayla: `validate-i18n` GEÇTİ (195 anahtar × 4 dil), `validate-levels` 216/216 GEÇTİ, `test-ads` 28/28, `test-daily` 14/14, `e2e` 315/315 (216 seviyenin tamamı oyunun kendi yoluyla kazanıldı; kademe çarpanlı ekonomi; harita kademe rozetleri; sonsuz bölüm 19; v13 görüntüleri), `qa` 157/157 (ilk koşuda 5 test-düzeneği varsayımı v1.3'e uyarlandı: kuyruk koordinatı, şevron dışında renk örneği, en büyük tahta ≥ 16 px; oyun kodu değişmedi). Test sırasında bulunan tek oyun hatası düzeltildi: kıvrımlı ok baloncuğu büyük tahtada üst satırlardaki dokunuşları yutuyordu → baloncuk dokunuşu tahtaya geçirir (yalnızca "Atla" tıklanır). Görüntüler `tools/shots/v13/`: tr bölüm 1 (sv4), 4, 7, 9, 10, 18 ilk seviyeleri, bölüm 19 (sv217, sonsuz), harita (bölüm 19 ve aşırı zor bölüm 18 başlığı); ar sv97 ve de sv205 (aşırı zor).
