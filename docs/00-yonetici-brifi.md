# Ok Kaçış — Yönetici Brifi (v1)

## Ad (yönetici kararı 25.10.2026, rakip analizine göre)
- Marka: **Arrowtile** — tüm dillerde Latin harfle aynı yazılır (çalışma adı "Ok Kaçış" kullanımdan kalkar).
- Mağaza başlıkları (≤30): tr "Arrowtile: Ok Bulmacası" · en "Arrowtile: Arrow Puzzle" · de "Arrowtile: Pfeil-Rätsel" · ar "Arrowtile: لغز الأسهم"
- Paket adı önerisi: `com.arrowtile.puzzle` (Play'de yayından önce doğrulanacak).

## Ürün
- Tür: Hibrit casual "ok kaçış" bulmacası (Play Store'da 2026'nın yükselen trendi: Arrow Puzzle, Arrows – Puzzle Escape benzeri).
- Temel kural: Izgarada oklar var. Bir oka dokununca ok, gösterdiği yönde düz kayar. Yolu açıksa tahtadan çıkar; yolunda başka ok varsa çarpar, geri döner ve 1 can gider. Tüm oklar çıkınca seviye biter.
- Kitle: Genel kitle (her yaş).
- Diller (ZORUNLU, ilk sürümden itibaren): Türkçe (tr), İngilizce (en), Almanca (de), Arapça (ar). Tüm metinler `game/js/i18n.js` içinde `window.I18N = { tr:{...}, en:{...}, de:{...}, ar:{...} }` sözlüğünde, aynı anahtarlarla. Varsayılan dil cihaz dilinden seçilir (navigator.language), bulunamazsa İngilizce; Ayarlar'dan değiştirilebilir ve kaydedilir.
- Arapça sağdan sola (RTL): `ar` seçilince `<html dir="rtl" lang="ar">`; menüler, butonlar, metin hizası aynalanır. Oyun tahtası ve okların yönleri AYNALANMAZ (bulmaca mantığı aynı kalır). Sayılar Batı rakamıyla (0-9) gösterilebilir. Uzun Almanca kelimeler butonlara sığmalı (taşma/kırpma testi).
- Hibrit katman (hafif): seviye haritası, 3 yıldız puanlama, günlük ödül, ipucu ve geri alma jetonları, açılabilir ok/tema görünümleri.

## Reklam ve satın alma (ilk sürümde, kullanıcı kararı 25.10.2026)
- Tür: yalnızca geçiş reklamı (interstitial), seviye SONU ekranından sonra, oyuncu "Devam" dediğinde. Banner yok.
- Seviye ortasında, duraklatma menüsünde, öğreticide ASLA reklam yok.
- Sıklık: en erken her 3 tamamlanan seviyede bir (sayaç kayıtta tutulur, başarısız deneme sayılmaz); ilk bölüm (seviye 1-12) tamamen reklamsız; iki reklam arası en az 3 dakika.
- İsteğe bağlı ödüllü reklam: "can bitti" ve ipucu/jeton ekranında, oyuncu kendi seçerse (ör. +1 can veya 1 ipucu). Zorunlu değil.
- "Reklamları kaldır": tek seferlik, tüketilmeyen Google Play ürünü (ürün kimliği: `remove_ads`). Satın alınınca geçiş reklamları kalıcı kapanır; ödüllü reklamlar isteğe bağlı kalır. Mağaza ve Ayarlar'da "Satın alımları geri yükle".
- Süre sınırı oyunun hiçbir modunda hiçbir zaman eklenmez.
- İnternet yoksa reklam gösterilmez, oyun normal devam eder (çevrimdışı oynanabilirlik korunur).
- Uygulama mimarisi: oyun reklam/satın alma SDK'sını doğrudan çağırmaz; `game/js/ads.js` içindeki `window.Monetization` katmanı, Android'de `window.AndroidBridge` (showInterstitial, showRewarded, purchaseRemoveAds, restorePurchases, isAdFree) çağırır; köprü yoksa (web önizleme) reklam yerine hiçbir şey göstermez ve satın almayı test modunda taklit eder. Kurallar (sıklık, bölüm, süre) JS katmanında uygulanır ve test edilir.
- Android tarafı (paketleme aşamasında): Google AdMob + Google Play Billing + AB/İngiltere için onay formu (UMP). Gizlilik metni ve Play "Veri güvenliği" formu reklam kimliğine göre güncellenir. "Veri toplamaz" ifadesi kaldırılır.

## Teknik sınırlar
- Tek klasörlük HTML5 oyun: `game/index.html` + `game/js/*.js` + `game/assets/`. Çerçeve yok, saf JS + Canvas 2D (veya SVG/DOM).
- Tamamen çevrimdışı çalışmalı, dış CDN yok. Dikey ekran, 360–430 px genişlikte kusursuz, dokunmatik öncelikli.
- Kayıt: localStorage (try/catch ile). Oyun kodu internet istemez; reklam ve satın alma yalnızca Android köprüsü üzerinden.
- Sesler Web Audio API ile kodla üretilecek (dosya gerekmez).
- Daha sonra Android WebView içinde paketlenecek; bu yüzden performans ve küçük boyut önemli.
- Destek e-postası (ayarlar/hakkında ekranı ve mağaza): nilkaren.tuncay.demir@gmail.com

## Ekip ve teslimler
| Rol | Teslim |
|---|---|
| Oyun Tasarımcısı | `docs/01-oyun-tasarim-belgesi.md` + `game/js/levels.js` (en az 30 çözülebilir seviye) |
| Görsel & Ses Sorumlusu | `docs/02-gorsel-ses-rehberi.md` + `game/js/theme.js` (renk/şekil token'ları) + `game/js/audio.js` + `game/assets/icon.svg` |
| Geliştirici | Çalışan oyun (`game/`) |
| Test Sorumlusu | `docs/04-test-raporu.md` |
| Yönetici (Claude) | Koordinasyon, kalite kapısı, kullanıcıya rapor |

## Ortak seviye veri formatı (herkes bunu kullanır)
```js
// game/js/levels.js
window.LEVELS = [
  { id: 1, w: 4, h: 4, arrows: [ {x:0, y:1, dir:"R", len:2}, ... ], par: 0 }
];
// x,y = okun KUYRUK hücresi (0 tabanlı, sol üst köşe 0,0)
// dir: "U" | "D" | "L" | "R" — ok başının baktığı yön
// len: okun kapladığı hücre sayısı (1-3); gövde kuyruktan dir yönünde uzanır
// Oklar üst üste binemez. Her seviyenin en az bir çözüm sırası olmalı.
```
