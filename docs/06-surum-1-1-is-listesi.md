# Arrowtile — İlk sürüm güncelleme iş listesi

Kaynaklar: 00-yonetici-brifi.md (ad, reklam kuralları), 04-test-raporu.md (hatalar), 05-rakip-analizi.md (G1–G9).

## A. Test hataları
04-test-raporu.md'deki kritik ve yüksek hataların tamamı, orta hataların mümkün olanları. Her düzeltmeye bir test.

## B. Yeniden adlandırma
- Oyun adı her yerde "Arrowtile" (i18n `app.name` 4 dilde aynı, Latin harf). Mağaza başlıkları brifteki gibi.
- İkon: mevcut ikon korunur; ana menüde başlık "Arrowtile".
- Kayıt anahtarı değişirse eski `okKacis.save.v1` verisi taşınır.

## C. Rakip analizinden (G1–G7, G9)
- G1 Dokunma koruması + "Önce seç, sonra fırlat" ayarı
- G2 Tahta ekrana sığar, iki parmakla yakınlaştırma/kaydırma, "sığdır" düğmesi, mini harita
- G3 Rahat mod (can yok, en fazla 2 yıldız, yarı jeton)
- G4 120 seviye (10 bölüm × 12), zorluk etiketi çözücü derinliğinden: Kolay/Orta/Zor/Uzman; üretici ve doğrulayıcı güncellenir
- G5 Günlük bulmaca (tarih tohumlu, çevrimdışı), seri sayacı, takvim
- G6 İlerlemeyi dışa/içe aktar (metin kodu)
- G7 Görünüm: Otomatik/Açık/Koyu
- G9 4 dilde mağaza metni: süre yok, internetsiz oynanır, geri alma var

## D. Reklam ve satın alma (brifteki kurallar, bağlayıcı)
- `game/js/ads.js` → `window.Monetization` + `AndroidBridge` arayüzü; köprü yoksa sessiz/test modu
- Geçiş reklamı yalnızca seviye sonu "Devam"da; seviye 1–12 reklamsız; ≥3 tamamlanan seviye ve ≥3 dk aralık; başarısız deneme sayılmaz; çevrimdışıysa atlanır
- Ödüllü reklam: can bitti (+1 can), ipucu (1 ipucu) — isteğe bağlı
- "Reklamları kaldır" ve "Satın alımları geri yükle": Mağaza + Ayarlar
- Süre sınırı yok
- "Veri toplamaz" metni kaldırılır, gizlilik metni sayfası eklenir (4 dil)
- Kurallar için birim testleri (sahte saat, sahte köprü)

## E. Tüm metinler 4 dilde (tr/en/de/ar), validate-i18n geçmeli. RTL ve 360 px taşma kontrolü.

## İlerleme
- 2026-10-25 · Aşama 1 (test hataları H1–H7) bitti. H1 çıkış animasyonunda ok tahtadan çıkana kadar girdi kilidi; H2 `window.__ok` yalnızca `?debug=1` ile, salt okunur kopya, debug kipi ayrı kum havuzu anahtarına yazar (gerçek kayda asla); H3 360 px'te 8 sütunda hücre 40 px; H4 `overflow-wrap:anywhere` kaldırıldı, `THEME.fitButton` kelime bölünmesini de taşma sayıyor (önce küçült, en son heceleme); H5 can götürmeyen çarpışma geri alma geçmişine girmez; H6 yatay telefonda "cihazı çevir" katmanı; H7 CSP meta etiketi. 02 tema fiyatları 0/300/500/750/1000, 01 anahtar sayısı düzeltildi. Testler: e2e 168/168, validate-i18n + validate-levels geçti, qa.js 160/162 (kalan 2: sahte saatli günlük ödül, makine yüklüyken sahte `Date` bazı yüklemelerde devreye girmiyor; blok tek başına 8/8 geçiyor). qa.js v1.1'e uyarlandı (debug URL, kum havuzu anahtarı, `debugPatch`, yatay uyarı kabulü).
- 2026-10-25 · Aşama 2 (ad değişikliği) bitti. Oyun adı her yerde "Arrowtile" (`app.title` → `app.name`, 4 dilde Latin harfle), mağaza başlıkları brifteki gibi; kayıt anahtarı `arrowtile.save.v1`, eski `okKacis.save.v1`/`okKacis.lang` ilk açılışta taşınıp silinir (yeni kayıt varsa üzerine yazılmaz, bozuk eski kayıt güvenli varsayılana). Testler: e2e 180/180, validate-i18n + validate-levels geçti, qa.js 156/162 → kalan 6'sı sahte-saat düzeneği; qa.js `setFakeDate` sahte saatin devreye girdiğini doğrulayıp gerekirse yeniden yükleyecek şekilde sağlamlaştırıldı, blok iki kez 8/8 geçti.
- 2026-10-25 · Aşama 3 (reklam/satın alma + gizlilik) bitti. `game/js/ads.js` → `window.Monetization` (kurallar: yalnızca seviye sonu "devam"da geçiş reklamı, sv 1–12 reklamsız, ≥3 tamamlanan seviye + ≥3 dk, başarısız deneme sayılmaz, çevrimdışı/köprüsüz atlanır, yerel yanıt gelmezse 90 sn zaman aşımı), `AndroidBridge` arayüzü (isAdFree, isOnline, isRewardedReady, showInterstitial, showRewarded, purchaseRemoveAds, restorePurchases; sonuçlar `Monetization.onNative`), ödüllü reklam: can bitti +1 can ve mağazada +1 ipucu (isteğe bağlı), "Reklamları kaldır" + "Satın alımları geri yükle" Mağaza ve Ayarlar'da, köprü yokken test modu. Gizlilik politikası oyun içi ekran + bağımsız `game/privacy.html` (4 dil, AdMob/UMP/Play Billing), "veri toplamaz" ifadesi kaldırıldı. Testler: test-ads 28/28 (sahte saat + sahte köprü), test-daily 13/13, e2e 227/227 (bir "One-time" kelime bölünmesi düzeltildi), validate-i18n (138 anahtar) + validate-levels geçti, qa.js 154/162 → kalan 8 (dil taraması) çalışma sırasında e-postaya eklenen `<wbr>` yüzündendi; geri alındı, e-posta 15 px tek satır.
- 2026-10-25 · Aşama 4 (G1, G2, G3, G7, G6) bitti. G1 isabet okun gövde eksenine uzaklıkla (genişletilmiş alan 0,75 hücre), iki ok arası belirsiz dokunuş hiçbir oku oynatmaz (titreşim + vurgu), Ayarlar'da "Önce seç, sonra fırlat" (seçili okun yolu noktalarla), hücre < 40 px ise bir kez önerilir; G2 tahta her zaman sığarak açılır, iki parmakla yakınlaştırma (≤3×) + kaydırma, "Sığdır" düğmesi, yakınken mini harita, oyun kendiliğinden kaydırmaz, dokunuş tap'te değil bırakışta; G3 Rahat mod (can yok, en fazla 2 yıldız, yarı jeton, HUD rozeti); G7 Görünüm Otomatik/Açık/Koyu (DOM + canvas); G6 dışa/içe aktarma `ARROWTILE1-…-sağlama` kodu (dil ve satın alma koda girmez), kopyala, bozuk kod reddi. Testler: e2e 247/247, test-ads 28/28, validate-i18n (164 anahtar) + validate-levels geçti, qa.js 162/162.
- 2026-10-25 · Aşama 5 (G4 + G5) bitti. G4: 120 seviye (10 bölüm × 12; yeni bölümler Göl, Orman, Çöl, Buzul, Volkan, Mercan, Yıldızlar), ilk 36 seviye birebir aynı (üretici tohumları korundu), ızgara ≤ 8x10; `tools/generate-levels.js` planı + 37+ için kademeli gevşetme, `--out`; zorluk etiketi (`diff`: Kolay ≤6 / Orta ≤10 / Zor ≤14 / Uzman >14 tur derinliği, `tools/solver.js difficulty()`), `validate-levels.js` etiketi yeniden hesaplayıp karşılaştırır; etiket harita düğümünde ve oyun ekranında. G5: `game/js/daily.js` tarih tohumlu çevrimdışı günlük bulmaca (hafta içi gününe göre zorluk), takvim, seri/en iyi seri/kupa, saat geri alınınca kupa yok, günlük bulmacada reklam yok. Testler: e2e 270/270, test-daily 13/13, test-ads 28/28, validate-i18n (187 anahtar) + validate-levels (120) geçti, qa.js 162/162 (qa'daki 36 seviyeye sabit beklenti seviye sayısına bağlandı).
- 2026-10-25 · Aşama 6 (G9) bitti. `docs/07-magaza-metinleri.md` (4 dil; başlık 21–23/30, kısa açıklama 63–72/80, uzun açıklama 1397–1837/4000; üç vaat: süre yok, internetsiz, geri alma; reklam kuralları ve satın alma dürüstçe yazıldı; "veri toplamaz" yok) ve i18n `store.title/short/long`; `validate-i18n` uzun açıklama sınırını da denetliyor, e2e docs/07 ↔ i18n eşleşmesini denetliyor. Testler: e2e 273/273, validate-i18n (188 anahtar) + validate-levels (120) + test-ads 28/28 + test-daily 13/13 geçti, qa.js 162/162. Ekran görüntüleri: tools/shots/v11/.
