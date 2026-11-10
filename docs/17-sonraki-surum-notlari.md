# Sonraki sürüm (1.2.0) — kullanıcı istekleri

Zamanlama: Arrowtile Play Store'da üretime (herkese açık) yayınlandıktan sonraki ilk güncelleme. O zamana kadar yalnızca acil düzeltmeler ayrı sürümle yapılır.
Süreç: önce web önizleme → kullanıcı onayı → Flutter → CI → kapalı test/üretim. Yeni metinler 4 dilde (tr/en/de/ar, Arapça RTL).

## İstekler (09.11.2026)
1. Ok gidiş (slideOut) sesi rüzgâr esintisi gibi olsun.
2. Oyuncular arası lider tablosu.
3. "Arkadaşını davet et".
4. Zor ve Aşırı zor seviyelerde okların kıvrımları daha uzun ve daha karışık olsun.
5. Oklar daha küçük/ince, oyun alanı daha büyük (kullanıcı daha önce de istemişti).
6. Alan büyüdükçe ok sayısı da artsın.
7. Titreşim tek kısa "bip" şeklinde olsun.
8. Kullanıcı bunlara ekleme yapacak; liste güncellenecek.

## Kapalı test geri bildirimleri (09.11.2026 akşam)
9. **Oklara dokunmada temas sorunu** — testçiler dokunuşun bazen algılanmadığını / yanlış algılandığını söylüyor. Ayrıntı (hangi sürüm, ne oluyor: tepki yok mu, komşu ok mu seçiliyor, yakınlaştırmada mı) kullanıcıdan istenecek. İncelenecek: dokunma toleransı/isabet alanı (ince oklar + büyük tahta), kaydırma/yakınlaştırma jestiyle çakışma, "dokunma koruması" eşiği, "önce seç sonra fırlat" ayarı. §5 (daha ince ok, daha büyük alan) bu sorunu büyütebilir → isabet alanı ok çizgisinden bağımsız ve hücre boyutuna göre olmalı. Ciddi çıkarsa 1.2.0'ı beklemeden acil düzeltme.
10. **Reklamlarda donma** — sebep biliniyor: AdMob uygulaması henüz onaylı değil (sınırlı reklam sunumu), reklam isteği dolmuyor ve bekleme süresince oyun duraklıyor. AdMob onayı + mağaza bağlantısından sonra yeniden değerlendirilecek. Yine de: dolmayan reklamda bekleme süresi kısaltılmalı (ör. ≤3 sn) ve geçiş reklamı hiç yoksa sessizce atlanmalı; ödüllü reklam yoksa kullanıcıya net "şu an reklam yok" mesajı.

## Kararlar (09.11.2026)
- §3 davet: yalnızca WhatsApp (Android paylaşım sayfası) ile mağaza bağlantılı davet mesajı, 4 dilde. Ödül YOK.
- §2 lider tablosu: kullanıcı "seviye için puan" önerdi veya rakiplerde en beğenileni. Yönetici önerisi — kullanıcı ONAYLADI (09.11.2026):
  - Altyapı: Google Play Games Services lider tablosu (kendi sunucumuz yok, ücretsiz; günlük/haftalık/tüm zamanlar sürümlerini otomatik üretir; Android'de hileli skor gizleme var; arkadaşlar ve herkese açık görünüm).
  - Ana tablo "Puan": her tamamlanan seviye puan verir = kademe tabanı (Kolay 100, Orta 150, Zor 200, Aşırı zor 300) × yıldız (1–3). Haftalık görünüm varsayılan (her pazar sıfırlanır, yeni başlayan da zirveye çıkabilir); tüm zamanlar da görülebilir. Rakiplerde (Royal Match vb.) ilerleme bazlı sıralama + süreli sıfırlanan tablolar yaygın.
  - İkinci tablo: "En yüksek seviye" (tüm zamanlar).
  - Oyun internetsiz oynanmaya devam eder; puanlar bağlantı gelince gönderilir. Giriş isteğe bağlı.

## Planlama notları (yönetici)
- §2 lider tablosu internet ve hesap gerektirir (ör. Google Play Games Services). Oyunun "internetsiz oynanır" vaadi, gizlilik politikası ve Play veri güvenliği formu buna göre güncellenmeli; oyun internetsiz oynanmaya devam etmeli, tablo yalnızca bağlantı varken çalışmalı. Hangi skor (seviye, yıldız, günlük bulmaca serisi) kullanıcıyla netleştirilecek.
- §3 davet: Android paylaşım sayfasıyla mağaza bağlantısı paylaşımı (basit, sunucusuz). Davet ödülü istenirse doğrulama için sunucu/Play kurulum yönlendirmesi gerekir; kullanıcıyla netleştirilecek.
- §4–6 üretici değişikliği: 5.000 seviye içeriği değişir → level-hashes.json, verify-5000, Flutter altın testleri yeniden üretilir. Büyük tahtada üretim süresi (düşük telefon) yeniden ölçülmeli. Hücre ≥ 16 px kuralı ve yakınlaştırma kontrol edilmeli.
- §1 ve §7: ses dosyası yenisiyle değişir (lisansı uygun/kendi üretimimiz); titreşim tek kısa darbe (ör. 15–20 ms), tüm olaylarda aynı.

## Büyük güncelleme notları (10.11.2026)
Kullanıcı 1.1.1'i telefonda denedi: reklam gelmeyince uyarı verip devam ediyor (donma çözüldü).

11. **Ok hareketi daha simetrik/düzgün:** ok çıkarken kendi yolunu izleyerek sabit hızla tahtanın sonuna kadar gitsin ve kenardan çıkıp kaybolsun (yarıda solup kaybolmasın). Kıvrımlı okların tamamı (kuyruk dahil) yol boyunca akmalı.
12. **Aşırı zor = referans oyundaki "Süper Zor" görünümü** (kullanıcının oynadığı benzer bir oyundan ekran görüntüsü, 10.11.2026; görsel depoya konmadı, rakip ekranı). Görülenler:
    - Çok ince siyah çizgi oklar, açık zemin, renk yok; küçük ok uçları. Tahta ekranı neredeyse tamamen dolduruyor (tahminen ~28×45 hücre; ekran dışına taşan, kaydırma/yakınlaştırmayla gezilen alan).
    - Okların çoğu uzun, çok kıvrımlı dik açılı yollar: spiral, S/U/G şekilleri, kancalar, 4–8 dönüşlü yılanlar; düz kısa oklar azınlıkta.
    - Tahta dikdörtgen değil, organik/kesik bir şekil: ortada büyük boş bir delik ve içinde küçük bir ok kümesi, kenarlar düzensiz → maske/şekilli tahtalar.
    - Doluluk çok yüksek, oklar iç içe geçmiş; çözüm derinliği büyük.
    - Arayüz: üstte geri + yeniden başlat, zorluk adı, 3 kalp; "İpucu" (reklamla) düğmesi; altta ızgara (#) aç/kapa düğmesi.
    → Bizde: Aşırı zor (ve daha hafif hâliyle Zor) için daha büyük alan, daha küçük/ince oklar, çok daha uzun ve karmaşık kıvrımlar, isteğe bağlı şekilli tahta maskeleri (delikli/organik). §4, §5, §6 ile birlikte tek iş olarak ele alınacak. Dokunma isabeti hücre bazlı kalmalı (bkz. §9); ızgara aç/kapa düğmesi düşünülebilir.

## Zorluk kararları (10.11.2026, kullanıcı)
Testçiler: 1.1.1'de takılma/donma yok. Ancak oyun kolay bulunuyor ("bölümler basit geçiliyor, hiç takılmıyoruz").
Yönetici analizi: asıl sebep küçük alan (seviye 10–30'da tahta 7x9–9x11 ≈ 60–100 hücre; 22x31'e ancak seviye 201'de ulaşılıyor; küçük tahtada maxLen ≤ 5 → kısa oklar). Renk ikincil (uzun iç içe oklarda takibi kolaylaştırır).
Kullanıcı kararı (deneme önizlemesi istemedi):
13. **Ayarlar'a "Ok rengi: Renkli / Tek renk" seçimi.** Tek renk: referans oyundaki gibi tema zeminine uygun tek renk ince çizgi (açık temada siyah, koyu temada açık). Varsayılan şimdilik Renkli (kararı yayında netleştir). 4 dil.
14. **Ekranı (tahtayı) büyüt, okları incelt.** Tahta ekrana tek seferde sığmak zorunda değil: sağa-sola ve yukarı-aşağı kaydırılabilir (mevcut yakınlaştırma/kaydırma altyapısı; "sığdır" düğmesi kalır). Hücre en az ~16–20 px dokunulabilir kalmalı; isabet alanı hücre bazlı (§9). Tahta büyümesi çok daha hızlı olmalı (en büyük boyuta çok daha erken ulaşılsın) ve en büyük boyut referans oyuna yaklaşsın (≈28x45 civarı, doğrulayıcı/üretim süresiyle birlikte ayarlanacak). §4–§6 ve §12 ile tek iş.

## 1.1.2 cihaz denemesi (10.11.2026, kullanıcı)
- 1.1.2 telefonda sorunsuz açıldı. Bir geçiş reklamı geldi; reklam açılırken oyun "birazcık takılır gibi oldu ama ilerledi". → Reklam gösterimi öncesi/sonrası kısa takılma incelenecek (ör. reklam açılmadan önce ticker/ses duraklatma ve geri dönüşte yeniden çizim maliyeti; Crashlytics/ANR ve Firebase `interstitial` olay süreleriyle doğrulanacak).

## 1.2.0 kapsam onayı (10.11.2026, kullanıcı)
Kullanıcı 1.2.0 listesinin tamamını onayladı (büyük kaydırılabilir tahta ≈28x45, ince/küçük oklar ve alanla artan ok sayısı, uzun karmaşık kıvrımlar, şekilli "Süper Zor" tahtalar, ok rengi seçimi, oku sonuna kadar götürüp kaybetme, rüzgâr sesi, tek bip titreşim, Play Games lider tablosu, WhatsApp davet (ödülsüz), dokunma ve reklam takılması düzeltmeleri, yeni mağaza görselleri, AdMob mağaza bağlantısı).
**DEĞİŞİKLİK — zorluk döngüsü (docs/15 §5'in yerine geçer):**
- 20 seviyelik sabit çark, sonsuza kadar: 5 Kolay → 5 Orta → 5 Zor → 5 Aşırı zor, sonra baştan. (Seviye 1–5 Kolay, 6–10 Orta, 11–15 Zor, 16–20 Aşırı zor, 21–25 Kolay …)
- Amaç (kullanıcı): oyuncu her 20 seviyede bir "baştan başlıyor" hissiyle oynasın.
- Tahta büyüklüğü artık uzun vadeli bölüm ilerlemesine değil çarkın içindeki konuma bağlı ("sürekli değişken"): Kolay küçük, Aşırı zor en büyük (≈28x45, kaydırmalı). Her çarkta yeniden küçükten başlar.
- Açık sorular (kullanıcıya soruldu): bölüm = 20 seviyelik çark mı; ilk çark(lar) yeni oyuncu için daha yumuşak mı.

## Kesinleşen kararlar (10.11.2026 akşam, kullanıcı)
- **Bölüm = 20 seviye** (bir çark). Haritada her bölüm Kolay→Aşırı zor tam bir tur; bölüm bonusu tur sonunda. 5.000 seviye = 250 bölüm.
- **Tahta büyümesi (önceki "tahta çarka bağlı" notunun yerine):** bölümler arası kademeli büyüme — her yeni 20'lik bölümde tahta bir önceki bölümden büyür ve ok sayısı artar; en büyük boyuta (≈28x45) ulaşınca bir sonraki bölümde yine en küçük boyuta dönülür ve döngü tekrar eder. Bölüm içindeki zorluk sırası 5 Kolay / 5 Orta / 5 Zor / 5 Aşırı zor (doluluk, kıvrım, derinlik buna göre). Küçükten en büyüğe kaç bölümde varılacağı web önizlemede ayarlanacak (öneri: 8–10 bölüm) ve kullanıcıya onaylatılacak.
- **Seviye sonu kutlaması (YENİ, onaylandı):** küçük meşale/alev görseli, büyüklüğü performansa göre (reklamla devam → küçük; can kaybı → orta; kusursuz → büyük + kıvılcım; Aşırı zor kusursuz → altın alev + havai fişek). Mesajlar kademe × performans matrisi (Kolay kusursuz "Sıradaki gelsin!", Aşırı zor kusursuz "Harikasın..!" vb.), her hücrede 3–4 rastgele seçenek, 4 dil (kültüre uygun yazım). Hız yalnızca bonus rozeti ("Şimşek gibi!"); yavaşlık asla olumsuz söylenmez (süre sınırı yok vaadi). Reklamla devam eden oyuncu cesaretlendirilir.
