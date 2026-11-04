# Ok Kaçış — Test Raporu (v1)

Hazırlayan: Test Sorumlusu (bağımsız) · Tarih: 2026-10-25
Kapsam: `game/` (file:// ile), Chromium (Playwright 1.63, /opt/pw-browsers), dokunmatik mobil bağlam, 390x844 ve 360x740, DPR 2.
Test aracı: `tools/qa.js`. Geliştiricinin `e2e.js` ve `solver.js` dosyalarından bağımsızdır: kendi kural modeli ve çözücüsü vardır. Tahta yerleşimi oyunun iç değişkenlerinden değil, canvas piksellerinden okunur. Dokunuşlar gerçek `touchscreen.tap` ile yapılır. Kod düzeltilmedi.

## 1. Özet

| Çalıştırma | Geçti | Kaldı |
|---|---|---|
| Geliştiricinin `node tools/e2e.js` testi | 118 | 0 |
| `node tools/validate-i18n.js` / `validate-levels.js` | geçti | — |
| Bağımsız QA (`tools/qa.js`), geçerli kontroller | **163** | **17** |

**Bağımsız QA ile bulunan hatalar:** 0 kritik, 1 yüksek, 3 orta, 3 düşük. Bunlara ek olarak 1 şüpheli bulgu var (aşağıda ayrı başlıkta).

Notlar:
- Geliştiricinin "her şey geçti" sonucu doğru ama eksik. `e2e.js` animasyon sırasında dokunuşu, 360 px'te hücre boyunu, kelime bölünmesini ve `window.__ok` kancasını test etmiyor.
- `qa.js`'in son tam çalıştırması 128 geçti / 17 kaldı (toplam 145) verdi. Bu sonuçları şöyle düzelttim:
  - Diller bölümü, test scriptimdeki bir değişken sırası hatası yüzünden ilk çalıştırmada hiç çalışmadı. Hatayı düzelttikten sonra bölümü tek başına çalıştırdım: 34 geçti / 4 kaldı.
  - İki "KALDI" sonucu test hatasıydı ve listeden çıkarıldı:
    - Tema fiyatı kontrolünün regex'i yanlıştı. Ekrandaki gerçek fiyatlar (Ücretsiz/300/500/750/1000) belgeyle aynı, bu yüzden kontrol "geçti" sayıldı.
    - "Sonraki seviye" kontrolünde test, yeni seviyedeki bir oka kendisi dokunmuştu. Sonuç geçersiz sayıldı.
  - Bu iki test ve değişken sırası hatası `qa.js`'te düzeltildi. Tam script bu düzeltmelerden sonra yeniden çalıştırılmadı; zaman sınırı nedeniyle yalnızca Diller bölümü tekrar çalıştırıldı.
- Satır numaraları: `main.js` için dosyanın kendi satır numarası verildi.

## 2. Hata listesi (önem sırasıyla)

### H1 — YÜKSEK: Çıkış animasyonu sürerken dokunuşlar kabul ediliyor; oklar birbirinin içinden geçiyor
- **Belge:** 01 §2: "Animasyon sürerken yeni dokunuşlar kuyruğa alınmaz, yok sayılır."
- **Adımlar** (390 ve 360 px'te tekrar üretildi):
  1. Seviye 22'yi aç.
  2. Açık bir oka dokun.
  3. Ok kayarken (≈30–40 ms sonra) başka bir oka dokun. Bu ikinci ok, yolu az önce kayan ok tarafından kapatılmış bir ok olabilir.
- **Beklenen:** İkinci dokunuş yok sayılır.
- **Gerçekleşen:** İkinci ok da hemen çıkıyor. Yolunu kapatan ok hâlâ ekranda kayarken ikinci ok onun içinden geçerek tahtadan çıkıyor (`ok1 kayarken ok0 içinden geçip çıktı`).
- **Neden:** Mantıkta ilk ok dokunulduğu anda siliniyor. Girdi kilidi (`busy`) yalnızca son okta açılıyor.
- **İlgili:** `game/js/main.js:548` (`busy = G.isWon();`), `main.js:525`.
- Çarpışma animasyonu sırasında girdi doğru şekilde engelleniyor (bkz. geçen testler).

### H2 — ORTA: `window.__ok` hata ayıklama kancası sürüm yapısında açık; hile yapılabiliyor ve duraklatma atlanabiliyor
- **Adımlar:**
  1. Konsolda (WebView'da da erişilebilir) `__ok.state().coins = 999999; __ok.state().themesOwned.push('gece')` çalıştır.
  2. Ayarlar'da sesi aç/kapat (kayıt tetiklenir).
  3. Sayfayı yenile.
- **Gerçekleşen:** 999999 jeton ve Gece Lambası teması kalıcı oluyor. Ayrıca duraklatma penceresi açıkken `__ok.tapArrow(i)` hamle yapıyor (ok çıktı), çünkü `tapArrow` pencere kontrolü yapmıyor.
- **Beklenen:** Kanca sürüm yapısında olmamalı ya da salt okunur olmalı (yorumdaki "kullanıcıya görünmez" ifadesi doğru değil).
- **İlgili:** `game/js/main.js:756-768`, `main.js:532` (`tapArrow` içinde `modalOpen()` kontrolü yok).

### H3 — ORTA: 360 px ekranda 8 sütunlu seviyelerde hücre 40 px'in altında
- **Belge:** 01 §2: "hücre en az 40 px olmalıdır (8 sütunda 360 px ekrana sığar)".
- **Adımlar:** 360x740 ekranda seviye 22'yi (8x10) aç.
- **Gerçekleşen:** Hücre boyu canvas piksellerinden 37,9 px ölçüldü (390 px'te 41).
- **Neden:** Hesaba tahta dolgusu (0,6 hücre) da ekleniyor: `(W−32)/(w+0.6)`.
- **Etki:** 21–36. seviyelerde dokunma hedefi belgedeki sınırın altında.
- **İlgili:** `game/js/main.js:421`.

### H4 — ORTA: Uzun kelimeler ortasından, tire olmadan bölünüyor (DE, TR, AR)
- **Belge:** 01 §9: "kırpma yasak; metin satır kaydırmalı ya da yazı %85'e kadar küçülmeli". 02 §4.
- **Adımlar:** 360 px'te Harita ve Mağaza ekranlarını aç. Ekran görüntüsüyle doğrulandı.
- **Gerçekleşen:**
  - de-360 ve de-390: harita başlığı "Levelkar / te", öğretici balonu "Tipp-Knopf", mağaza "Nachtlicht".
  - tr-360: "Haritası", tema adı "Emay / e", buton "Kullanılıy / or".
  - ar-360: "المستويات", "الحلقوم".
- Yatay taşma ve ellipsis yok. Sorun, `overflow-wrap: anywhere` küçültme denenmeden önce kelimeyi bölmesi. `fitButton` bölünmeyi taşma saymıyor, `.bar-title` ve `.item-name` ise hiç sığdırılmıyor.
- **İlgili:** `game/css/style.css:50` (`.bar-title`), `:76` (`.btn`), `:201` (`.item-name`), `:140`, `:195`. Ayrıca `game/js/theme.js` `fitButton`.

### H5 — DÜŞÜK: Öğretici seviye 2'de geri alma, geri alınacak bir şey yokken jeton/hak harcıyor
- **Adımlar:**
  1. Seviye 2'yi öğretici modda aç (ücretsiz geri alma 0, jeton 100).
  2. Kapalı oka dokun. Öğretici muafiyeti nedeniyle can düşmez.
  3. Geri al'a bas.
- **Gerçekleşen:** 20 jeton düşüyor (100 → 80) ama can ve oklar değişmiyor.
- **Beklenen:** "Geri alınacak hamle yok" uyarısı gösterilmeli ve ücret alınmamalı.
- **İlgili:** `game/js/engine.js:112` (`canUndo`, can düşmeyen çarpışmaları da sayıyor), `main.js:670-678`.

### H6 — DÜŞÜK: Yatay ekranda tahta çok küçülüyor, yönlendirme uyarısı yok
- **Adımlar:** Oyun sırasında ekranı 844x390 (veya 844x360) boyutuna döndür.
- **Gerçekleşen:**
  - Hücre boyu 20,9 px (360 yüksekliğinde 17,9 px), canvas 480x229.
  - Tahta görünür alanda kalıyor ve dikeye dönünce eski ölçeğe dönüyor; ölçekleme mantığı doğru.
  - Ancak bu boyutta oynanamaz durumda.
- Brif "Dikey ekran" diyor. Android paketinde yönlendirme kilidi ya da "cihazı çevirin" mesajı gerekli.
- **İlgili:** `game/js/main.js:414-428`.

### H7 — DÜŞÜK: Content-Security-Policy yok
- **Durum:** `index.html` içinde CSP meta etiketi yok. Dış istek olmadığı için şu an bir risk görülmedi.
- **Öneri:** WebView paketi için `default-src 'self'; img-src 'self' data:` gibi bir politika eklenmeli (savunma derinliği).
- **İlgili:** `game/index.html:4-11`.

## 3. Şüpheli (tekrar üretilemedi ya da doğrulanamadı)

- **Uygulama açıkken gece yarısı geçince günlük ödül rozeti:**
  - Sahte saatle 23:59:50'de ödül alındı, 11 sn beklendi, menü yeniden çizildi. Rozet "hazır" olmadı (1 kez KALDI).
  - Sahte `Date` sayfa yüklemesinde sabitlenen bir ofsetle çalışıyor. Hatanın oyunda mı yoksa test düzeneğinde mi olduğu doğrulanamadı.
  - Gece yarısı geçişi sayfa yenilenerek test edildiğinde doğru çalışıyor (bkz. geçenler).
- **Belge tutarsızlıkları (kod hatası değil):**
  - 02 §10'da tema fiyatları 600/900/1500 yazıyor. Kod 01 §6 ile uyumlu (500/750/1000).
  - 01 §13'te "106 anahtar" yazıyor; sözlükte 107 anahtar var.

## 4. Geçen testler (kısa)

**1. Kurallar** (390 ve 360 px):
- Açık ok çıkıyor; ekranda da tamamen kayboluyor.
- Kapalı ok engelin önündeki hücreye kadar kayıyor, engelin ötesine geçmiyor ve eski yerine dönüyor.
- Çarpışmada 1 can gidiyor (motor ve HUD birlikte).
- 3 çarpışmada "Canın bitti" penceresi açılıyor. Tekrar dene ile 3 can geri geliyor ve oklar yerine dönüyor.
- Geri alma:
  - Çıkan ok aynı hücrelerine dönüyor (piksellerle doğrulandı).
  - Kaybedilen can iade ediliyor, çarpışma sayacı korunuyor.
  - Seviye yeniden başladıktan sonra geri alma yapılamıyor ve ücret alınmıyor.
- İpucu (20 rastgele durumda, canvas farkından okunarak): her seferinde çıkabilir bir ok gösterdi (20/20) ve her seferinde en çok oku serbest bırakanı seçti (20/20).
- Yıldızlar: 2/1/0 çarpışma → 1/2/3 yıldız. 3 çarpışma + geri alma ile bitirmek 1 yıldız veriyor. Daha kötü bir tekrar yıldızı düşürmüyor.

**2. Ekonomi:**
- Başlangıç: 50 jeton + 3 ücretsiz ipucu + 3 ücretsiz geri alma.
- İlk bitirme +20. Tekrar oynamada yalnızca fark (+10, +5, +5) veriliyor; daha kötü tekrar 0.
- Bölüm bonusu +50 bir kez veriliyor; bölüm eksikken verilmiyor.
- Önce ücretsiz hak kullanılıyor, sonra ipucu 30 ve geri alma 20 jeton düşüyor.
- Yetersiz jetonda işlem yapılmıyor, jeton düşmüyor ve uyarı gösteriliyor. Düğme metinleri hak sayısını ya da fiyatı gösteriyor.
- Temalar:
  - Fiyatlar 0/300/500/750/1000.
  - Yetersiz jetonla satın alınamıyor. Onay iptal edilince jeton düşmüyor.
  - Satın alma: −300 jeton, tema sahiplenilip seçiliyor ve yenilemeden sonra kalıcı.
  - Oyunda seçili temanın rengi kullanılıyor. Temalar arası geçiş kalıcı.
- Günlük ödül (sahte tarihle):
  - 20/30/40/50/60/80/150 + 1 ipucu; 8. gün yeniden 20. Döngü toplamı 430.
  - Aynı gün ikinci kez alınamıyor. Gece yarısında yerel tarih esas alınıyor.
  - Bir gün atlanınca seri 1. güne dönüyor.
  - Saat geri alınınca ödül verilmiyor, seri korunuyor; saat düzelince seri kaldığı yerden devam ediyor.

**3. Kayıt:**
- Yenilemeden sonra yıldız, jeton, kilit ve öğretici durumu korunuyor; menüde "Devam: Seviye 2" görünüyor.
- localStorage SecurityError atınca, `null` dönünce, setItem kota hatası verince ve getItem hata atınca oyun açılıyor, seviye oynanıyor ve konsol hatası çıkmıyor.
- Bozuk JSON, `null`, dizi, sayı, negatif/NaN/dev değerler ve yanlış tipte alanlar güvenle onarılıyor.

**4. Diller:**
- 4 dil × 2 genişlik × 20 ekran durumu tarandı (menü, günlük ödül, harita, kilit uyarısı, oyun, öğretici 1–3, duraklat, uyarılar, seviye sonu, can bitti, mağaza, onay, ayarlar, sıfırla). DOM metinleri, aria-label'lar ve uyarılar sözlükle karşılaştırıldı: sözlük dışı sabit metin yok.
- `lang`/`dir` doğru. Konsol hatası yok.
- Arapça (RTL):
  - Tahta İngilizce ile birebir aynı yerleşimde ve aynalanmamış; ok başları doğru yönde çiziliyor.
  - Ekranın sağındaki oka dokununca o ok hareket ediyor; kapalı oka dokununca doğru şekilde çarpışma oluyor.
  - Üst çubuk ve araç çubuğu aynalı; geri ikonu ve harita patikası aynalı.
  - Canvas `ctx.direction` = rtl. Rakamlar Batı rakamı.
- Taşma: tr-390, en-390, en-360 ve ar-390'da hiçbir kusur yok. Diğer ekranlarda yatay taşma ve ellipsis yok (kelime bölünmesi için bkz. H4).

**5. Sağlamlık:**
- Kapalı oka 25 ms arayla 5 dokunuş yalnızca 1 can götürüyor.
- Çarpışma animasyonu sırasında gelen dokunuş yok sayılıyor.
- Çıkış animasyonu sırasında duraklatma penceresi açılıyor ve durum tutarlı kalıyor; duraklat → haritaya dön çalışıyor.
- Animasyon sırasında boyut değişince tahta yeniden ölçekleniyor, ortalanıyor, DPR 2 korunuyor ve dokunuş doğru oka gidiyor. Yataydan dikeye dönüşte eski ölçeğe dönüyor.
- Son ok çıkarken geri al, duraklat ve baştan başla yok sayılıyor; bitiş ekranı geliyor.
- Arka plana geçince oyun otomatik duraklıyor.
- Hiçbir oturumda konsol ya da sayfa hatası yok.

**6. Güvenlik/gizlilik:**
- Tüm oturumlarda izlenen isteklerin hepsi file:// veya data:; dış ağ isteği yok.
- Kaynakta eval, `new Function` veya string `setTimeout` yok. fetch, XHR, WebSocket ve beacon yok. index.html içinde dış kaynak yok.
- Kayıt alanlarına konan HTML/JS enjeksiyonu çalışmadı. `innerHTML` yalnızca sabit sözlük metinleri, sayılar ve `esc()` ile kaçışlanmış değerlerle kullanılıyor.

## 5. Tekrar çalıştırma

```
node tools/e2e.js     # geliştirici testi (118 kontrol)
node tools/qa.js      # bağımsız QA (~10 dk); sonuçlar tools/shots/qa-results.json
```
