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
