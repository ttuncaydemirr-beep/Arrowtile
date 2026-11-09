# Ok Kaçış — Oyun Tasarım Belgesi (v1)

Bağlayıcı kaynak: `docs/00-yonetici-brifi.md`. Seviye verisi: `game/js/levels.js`. Arayüz metinleri: `game/js/i18n.js`.

## 1. Temel döngü
1. Haritadan seviye seç → 2. Oklara doğru sırayla dokunup tahtayı boşalt → 3. Yıldız + jeton kazan → 4. Jetonları ipucu, geri alma ve ok temalarına harca → 5. Sonraki seviye.

Tek oturum hedefi: 1–3 dakikada bir seviye. Kayıp cezası hafif (seviye tekrarı), ilerleme hiç geri gitmez.

## 2. Kurallar ve kontroller
- **Dokun:** Bir oka dokununca ok kendi yönünde düz kayar.
  - Baş hücresinden tahta kenarına kadar olan tüm hücreler (diğer okların gövdeleri dahil) boşsa ok tahtadan çıkar.
  - Yolda bir ok varsa ok, engele kadar kayar, çarpar, sekip eski yerine döner (≈250 ms). **1 can gider**, kısa titreşim (açıksa) çalınır.
- Sürükleme ya da çift dokunma ile oynanmaz (iki parmakla yakınlaştırma/kaydırma serbesttir). **v1.2:** isabet okun gövde eksenine en yakın ok, eşik 0,5 hücre; iki ok neredeyse eşit yakınsa hiçbir ok hareket etmez. Tahta her zaman ekrana sığarak açılır; sığdırılmış hücre ≥ 22 px (15x22 tahta 360 px'te). Hücre 30 px'ten küçükse ilk büyük seviyede bir kez yakınlaştırma / "Önce seç, sonra fırlat" önerilir.
- Animasyon sürerken yeni dokunuşlar kuyruğa alınmaz, yok sayılır. Böylece yanlışlıkla iki dokunuş yapılmaz.
- **Bitiş:** Tüm oklar çıkınca seviye tamamlanır.

## 3. Can sistemi
- Her seviyede **3 can** vardır. Seviyeler arasında can taşınmaz ve bekleme süresi yoktur.
- Her çarpışma 1 can götürür ve **kalıcıdır** (v1.2: geri alma yok). Can 0 olunca "Canın bitti!" penceresi açılır: seviye **baştan** başlar (ücretsiz, bekleme yok) ya da isteğe bağlı ödüllü reklamla +1 can (seviye başına en fazla 1 kez).
- Canlar HUD'da 3 kalp olarak görünür.

## 4. Yıldız kuralı
| Yıldız | Koşul |
|---|---|
| ★★★ | Hiç çarpışma olmadan bitirmek |
| ★★ | 1 çarpışmayla bitirmek |
| ★ | Bitirmek (2 çarpışma; 3. çarpışmada can biter) |

- En iyi sonuç kaydedilir. Yıldız sayısı hiçbir zaman düşmez.
- v1.2: geri alma kaldırıldı (docs/08). Ödüllü +1 can çarpışma sayacını silmez; 3 yıldız satın alınamaz.

## 5. Yardımcılar
- **İpucu:** O anda çıkabilecek okların biri parlatılır (2 sn nabız efekti). Çıkabilen birden çok ok varsa en çok oku serbest bırakan seçilir. İpucunun yıldıza etkisi yoktur.
- **Geri alma:** v1.2'de kaldırıldı (docs/08 §1). Bu bulmacada başarılı çıkış hiçbir zaman kötü hamle olmadığından geri almanın tek işlevi canı iade etmekti; hata cezasız kalıyordu. Eski kayıtlardaki ücretsiz geri alma hakları hak başı 20 jeton olarak iade edilir.

## 6. Jeton ekonomisi
| Kalem | Değer |
|---|---|
| Başlangıç bakiyesi | 50 jeton + 2 ücretsiz ipucu (v1.2) |
| Seviye bitirme (ilk kez) | ★ 10 · ★★ 15 · ★★★ 20 jeton × seviye kademesi (v1.3 çarpanları: Kolay ×1, Orta ×1,5, Zor ×2, Aşırı zor ×3; v1.5'te kademe seviye bazında: bölümde 1-3 Kolay, 4-6 Orta, 7-8 Zor, 9-10 Aşırı zor) |
| Tekrar oynayıp yıldızı artırmak | Yalnızca aradaki fark (ör. ★→★★★ = +10) |
| Bölüm bonusu (10 seviyenin tamamı) | tek bonus: +150 jeton (v1.5, docs/15 §5; kademeye göre bonus kalktı) |
| İpucu | 50 jeton (v1.2; önce ücretsiz hak kullanılır) |

**Günlük ödül (7 günlük döngü):**

| Gün | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Ödül | 20 | 30 | 40 | 50 | 60 | 80 | 150 + 1 ipucu |

- Günde bir kez alınır; cihazın yerel tarihi esas alınır.
- Bir gün atlanırsa seri 1. güne döner. 7. günden sonra döngü yeniden 1. günden başlar.
- Saat geri alınırsa (kayıtlı son tarihten önce bir tarih görülürse) ödül verilmez, seri korunur.
- Tek döngü toplam 430 jeton + 1 ipucu eder.

**Ok temaları (mağaza):**

| Tema | Fiyat |
|---|---|
| Emaye | Ücretsiz (varsayılan) |
| Lokum | 300 |
| Çini | 500 |
| Bakır | 750 |
| Gece Lambası | 1000 |

**Denge kontrolü:**
- 36 seviyenin tamamı ★★★ ile bitirilirse 720 + 150 (bölüm bonusu) = 870 jeton kazanılır.
- Buna bir haftalık günlük ödül eklenince toplam yaklaşık 1300 jeton eder.
- Tüm temaların toplam fiyatı 2550 jetondur. Sadık bir oyuncu 2–3 hafta içinde hepsini açabilir.
- İpucu fiyatı, bir seviyeden kazanılan ortalama jetondan yüksek tutuldu. Böylece ipucu kullanmak cazip olur ama alışkanlık haline gelmez.
- Gerçek parayla satın alma ve reklam yoktur (v1).

## 7. Seviye haritası
- 36 seviye 3 bölüme ayrılır: **Çayır** (1–12), **Kanyon** (13–24), **Zirve** (25–36). Harita dikey ve kıvrımlı bir patika şeklindedir; aşağıdan yukarıya ilerlenir.
- Her düğümde seviye numarası ve kazanılan yıldızlar görünür. Kilitli düğüm gri ve kilit simgelidir.
- Bir seviyeyi bitirmek bir sonrakinin kilidini açar. İlerlemek için yıldız şartı yoktur.
- Harita açılınca oynanacak sıradaki seviyeye kaydırılır. Üst çubukta toplam yıldız (`{n}/108`) ve jeton bakiyesi gösterilir.

## 8. Ekran listesi
1. **Ana menü:**
   - Logo ve "Oyna" / "Devam: Seviye N" düğmesi.
   - Harita, Mağaza ve Ayarlar düğmeleri.
   - Günlük ödül rozeti (ödül hazırsa rozet titreşir).
2. **Harita:** Bölümler ve seviye düğümleri, geri düğmesi, jeton ve yıldız göstergesi.
3. **Oyun:**
   - Üst çubukta: seviye numarası, 3 kalp, duraklatma düğmesi.
   - Ortada tahta.
   - Alt çubukta: İpucu ve Baştan başla düğmeleri (v1.2). İpucu düğmesinde ücretsiz hak sayısı ya da jeton fiyatı yazar.
   - Duraklatma penceresinde: Devam et, Baştan başla, Haritaya dön.
4. **Seviye sonu:** Yıldız animasyonu, çarpışma sayısı, kazanılan jeton, "Yeni rekor!" etiketi; Sonraki seviye, Tekrar oyna ve Harita düğmeleri.
5. **Mağaza / temalar:**
   - Bakiye.
   - "Ok temaları" sekmesi: önizleme, fiyat ve Satın al / Kullan düğmesi.
   - "Yardımcılar" sekmesi: ipucu ve geri alma açıklamaları ile fiyatları.
6. **Günlük ödül penceresi:** 7 günlük kutular, bugünün kutusu vurgulu, "Al" düğmesi.
7. **Ayarlar:**
   - Ses (aç/kapat), Titreşim (aç/kapat).
   - **Dil** seçimi: Türkçe / English / Deutsch / العربية. Her dil kendi adıyla yazılır.
   - İlerlemeyi sıfırla (onay penceresiyle).
   - Destek e-postası: **nilkaren.tuncay.demir@gmail.com** (`mailto:` bağlantısı).
   - Gizlilik notu ve sürüm.

## 9. Dil ve RTL
- Desteklenen diller: tr, en, de, ar. Tüm metinler `game/js/i18n.js` içindedir ve dört dilde de anahtarlar aynıdır (`node tools/validate-i18n.js` ile doğrulanır).
- **Varsayılan dil:** `navigator.language` değerinin ilk iki harfi desteklenen dillerden biriyse o dil seçilir, değilse `en`. Ayarlardan değiştirilen dil localStorage'a kaydedilir ve sonraki açılışta önceliklidir. Dil değişince sayfa yeniden yüklenmez; bütün metinler yeniden çizilir.
- Yer tutucular (`{n}`, `{max}`, `{v}`) basit metin değişimiyle doldurulur. Rakamlar her dilde Batı rakamlarıyla (0–9) yazılır.
- **RTL (Arapça):**
  - `ar` seçilince `<html dir="rtl" lang="ar">` ayarlanır (sözlükte `meta.dir`).
  - Menüler, üst/alt çubuk sırası, geri oku, metin hizası ve harita yönü aynalanır. Mantıksal CSS (`margin-inline-start`, `text-align: start`) kullanılmalıdır.
  - **Oyun tahtası, okların yönleri ve koordinatlar AYNALANMAZ.** "R" her dilde ekranın sağı demektir.
  - Canvas'a metin yazılırken `ctx.direction = "rtl"` ayarlanmalıdır.
- **Almanca uzunluğu:** En uzun etiketler "Einstellungen", "Fortschritt löschen" ve "Sonnenuntergang"dır.
  - Düğmeler sabit genişlikli olmamalı; metin satır kaydırmalı ya da yazı boyutu en fazla %85'e kadar küçülmelidir.
  - Kırpma ve "…" ile kısaltma yasaktır.
  - 360 px genişlikte test edilmelidir.

## 10. Zorluk eğrisi (v1.2, docs/08)
Seviyeler `tools/generate-levels.js` ile üretilir (ortak üretici `game/js/levelgen.js`: yoğun yerleşim + kilit onarımı + başta serbest ok azaltma) ve `tools/validate-levels.js` ile doğrulanır. Seviye 1–3 öğretici olarak v1.1'deki haliyle korunur.
- **Doluluk:** oklarla kaplı hücre oranı. Bölüm 2'den itibaren ≥ %65, son bölümlerde %78–82.
- **Başta serbest:** başlangıçta yolu açık ok oranı. Bölüm 2+ ≤ %12, bölüm 9–10 ≤ %6.
- **Derinlik:** açgözlü çözümde tur sayısı (bağımlılık zinciri).
- **Puan:** derinlik + ok sayısı/6 + doluluk×12 − başta serbest oran×20. Etiket: Kolay ≤ 12 < Orta ≤ 26 < Zor ≤ 40 < Uzman. Doğrulayıcı her seviyenin etiketini yeniden hesaplar ve **bölüm ortalama puanının her bölümde arttığını** denetler.
- **v1.3 (docs/09):** Etiket artık seviyenin değil **bölümün kademesidir**: 3 Kolay → 3 Orta → 2 Zor → 1 Aşırı zor bölüm döngüsü ("Uzman" → "Aşırı zor"). Kademe bantları doluluk ve başta çıkabilen ok oranıyla tanımlıdır; puan döngü içi ve döngüler arası sıralamayı denetler. 216 hazır seviyeden sonra oyun sonsuz devam eder; oklar kıvrımlı olabilir (`{ cells, dir }`).

| Bölüm | Izgara | Ok (ort.) | Doluluk | Başta serbest | Derinlik (ort.) | Puan (ort.) |
|---|---|---|---|---|---|---|
| 1 | 3x3 → 7x10 | 8,5 | %60 | %22,5 | 5,3 | 9,3 |
| 2 | 8x10 → 9x11 | 18,5 | %70 | %9,9 | 9,0 | 18,5 |
| 3 | 9x12 → 10x13 | 26,3 | %71 | %8,8 | 10,7 | 21,8 |
| 4 | 10x13 → 11x14 | 31,8 | %73 | %8,9 | 13,8 | 26,0 |
| 5 | 11x15 → 12x16 | 43,2 | %75 | %7,7 | 15,8 | 30,5 |
| 6 | 12x16 → 13x17 | 52,9 | %76 | %7,6 | 16,4 | 32,9 |
| 7 | 12x17 → 13x18 | 56,3 | %78 | %7,4 | 18,0 | 35,3 |
| 8 | 13x18 → 14x19 | 64,1 | %79 | %6,1 | 20,7 | 39,6 |
| 9 | 13x19 → 14x20 | 71,8 | %81 | %5,1 | 24,8 | 45,4 |
| 10 | 14x20 → 15x22 | 86,4 | %82 | %5,5 | 24,0 | 47,2 |

- Ok uzunluğu 1–6; ortalama bölüm 2–8'de ≈ 3,1–3,4, bölüm 10'da ≈ 2,8 (yoğun tahtada boşlukları kısa oklar doldurur).
- `par` = ok sayısı, yani hiç çarpmadan optimal dokunma sayısıdır.

## 11. Öğretici (ilk 3 seviye, neredeyse metinsiz)
- **Seviye 1** (3x3, 2 ok):
  - Tek açık okun üstünde el simgesi belirir ve dokunma animasyonu oynar ("Oka dokun").
  - Bu ok çıkınca diğer okun yolu açılır ve el bu kez diğer oku gösterir.
- **Seviye 2** (3x3, 3 ok):
  - El, kapalı bir oku gösterir. Dokunulursa çarpma gösterilir ve kalp sallanır ("Çarpışma 1 can götürür").
  - Ardından açık ok vurgulanır ("Önce yolu açık olan ok").
  - Bu seviyede çarpışma can götürmez (öğretici muafiyeti).
- **Seviye 3** (4x4, 4 ok): Ücretsiz ipucu düğmesi nabız efektiyle gösterilir. Basılınca ipucunun nasıl çalıştığı görülür.
- Her öğretici balonda "Atla" düğmesi bulunur. Öğretici yalnızca ilk kez gösterilir.

## 12. Kayıt (localStorage, try/catch)
Anahtar: `arrowtile.save.v1` (eski `okKacis.save.v1` ilk açılışta taşınır). İçeriği:
```
{ lang, sound, vibration, coins, freeHints, stars: {id: 1..3}, unlocked, themesOwned: [], theme, daily: {lastDate, streakDay}, tutorialDone,
  chapterBonus, ads: {since, lastAt, adFree, test}, appearance, relaxed, aim, tips: [], dp: {done, streak, best, last, trophies} }
```
- v1.2: `freeUndos` alanı kaldırıldı; varsa hak başı 20 jeton eklenip silinir.
- Okuma başarısız olursa varsayılan değerlerle oynanır; oyun hiçbir zaman çökmemelidir.
- "İlerlemeyi sıfırla" bu anahtarı siler, dil seçimini korur.

## 13. Metin sözlüğü
Bütün arayüz metinleri dört dilde `game/js/i18n.js` dosyasındadır (`window.I18N`, 188 anahtar; güncel sayı `node tools/validate-i18n.js` çıktısındadır). Mağaza başlığı en fazla 30, kısa açıklama en fazla 80 karakterdir.

| Anahtar grubu | Ekran |
|---|---|
| `meta.*`, `lang.*` | Yazı yönü ve dil adları |
| `app.*`, `store.*` | Oyun adı ve mağaza başlığı/kısa açıklaması |
| `common.*` | Genel düğmeler |
| `menu.*` | Ana menü |
| `map.*` | Harita ve bölüm adları |
| `game.*` | Oyun ekranı, duraklatma ve can bitti penceresi |
| `tut.*` | Öğretici |
| `end.*` | Seviye sonu |
| `shop.*`, `theme.*` | Mağaza ve tema adları |
| `daily.*` | Günlük ödül |
| `settings.*` | Ayarlar (Dil dahil) |

Ürün adları:

| Dil | Ad |
|---|---|
| Türkçe | Ok Kaçış |
| İngilizce | Arrow Escape |
| Almanca | Pfeil-Flucht |
| Arapça | هروب الأسهم |
