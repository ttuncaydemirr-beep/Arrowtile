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

## Kararlar (09.11.2026)
- §3 davet: yalnızca WhatsApp (Android paylaşım sayfası) ile mağaza bağlantılı davet mesajı, 4 dilde. Ödül YOK.
- §2 lider tablosu: kullanıcı "seviye için puan" önerdi veya rakiplerde en beğenileni. Yönetici önerisi (kullanıcı onayı bekliyor):
  - Altyapı: Google Play Games Services lider tablosu (kendi sunucumuz yok, ücretsiz; günlük/haftalık/tüm zamanlar sürümlerini otomatik üretir; Android'de hileli skor gizleme var; arkadaşlar ve herkese açık görünüm).
  - Ana tablo "Puan": her tamamlanan seviye puan verir = kademe tabanı (Kolay 100, Orta 150, Zor 200, Aşırı zor 300) × yıldız (1–3). Haftalık görünüm varsayılan (her pazar sıfırlanır, yeni başlayan da zirveye çıkabilir); tüm zamanlar da görülebilir. Rakiplerde (Royal Match vb.) ilerleme bazlı sıralama + süreli sıfırlanan tablolar yaygın.
  - İkinci tablo: "En yüksek seviye" (tüm zamanlar).
  - Oyun internetsiz oynanmaya devam eder; puanlar bağlantı gelince gönderilir. Giriş isteğe bağlı.

## Planlama notları (yönetici)
- §2 lider tablosu internet ve hesap gerektirir (ör. Google Play Games Services). Oyunun "internetsiz oynanır" vaadi, gizlilik politikası ve Play veri güvenliği formu buna göre güncellenmeli; oyun internetsiz oynanmaya devam etmeli, tablo yalnızca bağlantı varken çalışmalı. Hangi skor (seviye, yıldız, günlük bulmaca serisi) kullanıcıyla netleştirilecek.
- §3 davet: Android paylaşım sayfasıyla mağaza bağlantısı paylaşımı (basit, sunucusuz). Davet ödülü istenirse doğrulama için sunucu/Play kurulum yönlendirmesi gerekir; kullanıcıyla netleştirilecek.
- §4–6 üretici değişikliği: 5.000 seviye içeriği değişir → level-hashes.json, verify-5000, Flutter altın testleri yeniden üretilir. Büyük tahtada üretim süresi (düşük telefon) yeniden ölçülmeli. Hücre ≥ 16 px kuralı ve yakınlaştırma kontrol edilmeli.
- §1 ve §7: ses dosyası yenisiyle değişir (lisansı uygun/kendi üretimimiz); titreşim tek kısa darbe (ör. 15–20 ms), tüm olaylarda aynı.
