# Arrowtile – Claude çalışma kuralları

Arrowtile, Google Play Store'da yayımlanan bir Android oyunudur (Flutter).
Sahibi Tuncay programlama bilmiyor; geliştirmeler onun yönlendirmesiyle yapılır.
Tüm açıklamalar sade Türkçe olmalıdır.

## Her oturumda
1. Önce bu dosyayı ve docs/00-DURUM.md'yi oku. Yalnızca işle ilgili dosyaları incele.
2. İş bitince docs/00-DURUM.md'yi güncelle: ne yapıldı, ne kaldı, sırada ne var.

## Geliştirme kuralları
3. Çalışan özellikleri ve oyun mekaniklerini koru.
4. Her geliştirme için ayrı bir dal aç; bir dalda tek iş olsun.
5. Değişiklikten sonra mümkün olan testleri çalıştır ve derleme hatalarını kontrol et.
6. Gereksiz dosya veya kod değişikliği yapma.
7. Tuncay onay vermeden ana dala birleştirme.
   Yalnızca docs/00-DURUM.md güncellemeleri onay beklemeden ana dala gidebilir. Oyun kodu, CLAUDE.md ve diğer tüm dosyalar için onay şart.

## İş bölümü: Sohbet ve Code

**Code'un işleri:** oyun kodu, derleme, test, paket güncellemeleri, sürüm numarası,
depodaki teknik dosyalar.
**Sohbetin işleri:** kararlar ve planlama, araştırma, mağaza metinleri ve görseller,
gizlilik politikası, web önizlemesi, Code'un yaptığı işi kontrol edip raporlamak.

- Kendi alanına girmeyen bir iş istenirse yapma. "Bu iş [Code / Sohbet] tarafının işi"
  de ve Tuncay'ın oraya aynen yapıştırabileceği hazır bir mesaj yaz.
- Bir iş başka bir işe bağlıysa (ör. karar → kod) önce kendi kısmını bitir,
  sonra diğer taraf için hazır mesajı ver.
- İki taraf da işe başlamadan önce docs/00-DURUM.md'ye bakar; orada diğer tarafa
  verilmiş bir iş varsa ona dokunmaz.
- Acil durum: Tuncay açıkça "bunu sen yap" derse kural esner. Yine de
  DURUM.md'ye not düşülür.

## Raporlama
8. Değişiklikleri sade Türkçeyle açıkla.
9. Her maddeyi şöyle işaretle: "test edildi" / "derlendi, test edilemedi" / "telefonda denenmeli".
10. Test edilmemiş bir özelliği çalışıyor olarak raporlama.

## Riskler (önceden bildir)
11. Yayındaki sürümü etkileyebilecek her riski önceden söyle.
12. Paket adına, imza anahtarına/keystore'a dokunma; versionCode her yayında artar, asla düşmez.
13. AdMob, satın alma (reklamları kaldır), Firebase/Crashlytics veya toplanan veri değişirse
    önceden bildir; gerekirse Play veri güvenliği formu ve gizlilik politikası güncellenmeli.

## Oyunun kalıcı kararları
- Seviye ortasında asla reklam yok; reklam en erken her 3 seviyede bir.
- Süre sınırı hiçbir zaman eklenmez.
- Geliştirici adı: Demir Games Studio.
- Gizlilik politikası: https://ttuncaydemirr-beep.github.io/privacy/arrowtile/
