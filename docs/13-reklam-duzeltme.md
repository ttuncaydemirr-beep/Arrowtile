# 13 - Reklam düzeltmesi (Samsung A53 denemesi)

Sorunlar: (A) 3 can bitince "reklam izle: +1 can" düğmesi çoğunlukla görünmüyor, görününce reklam açılmıyor; (B) jeton bitince reklamla jeton kazanma yolu yok.

Neden: ödüllü düğmeler yalnızca reklam ÖNCEDEN yüklenmişse ve DNS ölçümü (`_online`) başarılıysa çiziliyordu; hazır reklam çizim ile dokunuş arasında tükenirse `showRewarded` sessizce `false` dönüyordu.

Çözüm (web referansı ile aynı kurallar):
- Düğmeler reklam SDK'sı varsa her zaman görünür (`rewardedOffered`). Dokunuşta hazır değilse "Reklam yükleniyor…" penceresi, `ensureRewardedLoaded` (10 sn, bekleme süresi yok sayılır), sonra reklam. Olmazsa "Şu an reklam yok, biraz sonra tekrar dene." (test/debug derlemede AdMob hata kodu parantez içinde).
- `_showing` her yolda sıfırlanır (kapanış, hata, istisna, 5 dk bekçi zamanlayıcısı); Completer'lar hep tamamlanır.
- Reklamdan jeton: +50 jeton (= ipucu fiyatı), takvim günü başına en çok 10; kayıt alanları `ads.coinDate` (yyyy-aa-gg) ve `ads.coinCount`. Mağazada "Reklam izle: +50 jeton" kartı; oyunda jetonsuz ipucu isteğinde "Jetonun yetmiyor" penceresi (Reklam izle / Mağaza / Kapat). Saat geri alınırsa ya da ilerleme sıfırlanırsa hak yenilenmez.
- CI emülatör testi logcat'te `Ads:V` + `flutter:V` toplar, "Ad failed to load / onAdFailedToLoad / rewarded / interstitial" satırlarını yazdırır (başarısızlık işi düşürmez).

## İlerleme günlüğü
- Push 1 (a2f95e0): kod + testler + CI. Sonuç: web yeşil, analyze 0 sorun, flutter test 147 geçti / 1 kaldı (yedek kodu altın verisinde ads alanları eksikti); düzeltiliyor.
- Push 2 (476cf82): altın veri düzeltildi. CI yeşil: web, flutter (analyze 0 sorun, 148 test geçti), emülatör (çökme yok; logcat: MobileAds initialized, interstitial loaded, rewarded loaded).
