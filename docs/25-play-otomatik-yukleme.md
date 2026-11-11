# 25 - Play Store'a otomatik yükleme (bilgisayarsız yayın)

Amaç: **Release AAB (imzalı)** workflow'u imzalı AAB'yi derledikten sonra doğrudan Google Play'e (iç test ve/veya kapalı test) yüklesin; AAB'yi indirip Play Console'a elle yüklemeniz gerekmesin.
Bu özellik **isteğe bağlıdır**: `PLAY_SERVICE_ACCOUNT_JSON` secret'ı yoksa workflow eskisi gibi yalnızca AAB artifact'ı üretir (uyarı yazar, hata vermez).

Not: Google Cloud ve Play Console arayüzü sık değişir; aşağıdaki menü/düğme adları 2026 itibarıyla geçerlidir, sizde küçük farklar (ör. İngilizce/Türkçe etiket, menü yeri) olabilir. Mantık aynıdır.

## 1. Google Cloud projesi ve API (bir kez)

1. [console.cloud.google.com](https://console.cloud.google.com) adresine **Play Console'u kullandığınız Google hesabıyla** girin.
2. Üstteki proje seçiciden bir proje seçin veya oluşturun. Firebase projesini (`arrowtile-239be`) yeniden kullanabilirsiniz; ayrı bir proje de olur.
3. **APIs & Services → Library** (API'ler ve hizmetler → Kitaplık) içinde **Google Play Android Developer API**'yi arayın → **Enable** (Etkinleştir).

## 2. Servis hesabı ve JSON anahtarı (bir kez)

1. **IAM & Admin → Service accounts** (Hizmet hesapları) → **Create service account**.
2. Ad: `play-upload` → **Create and continue**. **Rol vermeyin** (Google Cloud tarafında rol gerekmez; yetkiyi 3. adımda Play Console verir) → **Done**.
3. Listede `play-upload@<proje>.iam.gserviceaccount.com` adresini kopyalayın (3. adımda lazım).
4. Servis hesabına tıklayın → **Keys** sekmesi → **Add key → Create new key → JSON → Create**. Bir `.json` dosyası inecek.
   - Kuruluş ilkesi anahtar oluşturmayı engelliyorsa (`iam.disableServiceAccountKeyCreation`) hata görürsünüz; proje kuruluşsuz (kişisel) bir projeyse bu olmaz.

## 3. Play Console'da yetki verme (bir kez)

1. [play.google.com/console](https://play.google.com/console) → sol altta **Users and permissions** (Kullanıcılar ve izinler) → **Invite new users** (Yeni kullanıcı davet et).
   - Eski arayüzde "Setup → API access" altında servis hesabı listelenip izin verilirdi; güncel arayüzde servis hesabı, normal bir kullanıcı gibi e-postasıyla davet edilir.
2. E-posta: 2. adımdaki `play-upload@...iam.gserviceaccount.com`.
3. **App permissions** (Uygulama izinleri) → **Add app** → **Arrowtile** seçin → şu izinleri verin:
   - **View app information (read-only)** (Uygulama bilgilerini görüntüleme)
   - **Release apps to testing tracks** (Uygulamaları test kanallarına yayınlama)
   - İleride üretime (production) de otomatik yüklemek isterseniz ayrıca **Release to production, exclude devices, and use Play App Signing** izni gerekir. Şimdilik vermeyin.
4. **Invite user → Send invite**. Servis hesabı için e-posta onayı gerekmez.

## 4. GitHub secret'ı ekleme (bir kez)

1. GitHub'da depo → **Settings → Secrets and variables → Actions → New repository secret**.
2. **Name:** `PLAY_SERVICE_ACCOUNT_JSON` (büyük harf, tam bu yazım).
3. **Secret:** indirdiğiniz JSON dosyasını bir metin düzenleyicide açın, **tüm içeriği** (`{` ile başlayıp `}` ile biten) kopyalayıp yapıştırın → **Add secret**.
4. JSON dosyasını telefondan/bilgisayardan **silin**; e-posta/sohbetle paylaşmayın.

Workflow secret'ı kullanmadan önce denetler: geçerli JSON mu, `type` alanı `service_account` mı, `client_email` ve `private_key` var mı? Değilse net bir hata mesajıyla **derlemeye başlamadan** durur. Secret'ın değeri günlüğe asla yazılmaz.

## 5. Çalıştırma

**Actions → Release AAB (imzalı) → Run workflow**. Alanlar:

| Alan | Seçenekler | Varsayılan | Anlamı |
|---|---|---|---|
| `track` | `none`, `internal`, `alpha`, `internal+alpha` | `internal+alpha` | `none`: yükleme yok (yalnızca AAB artifact). `internal`: İç test. `alpha`: **Kapalı test** (Play'deki varsayılan "Closed testing" kanalının API adı `alpha`). İkisi birden: önce iç, sonra kapalı test. |
| `status` | `completed`, `draft` | `completed` | `completed`: sürüm tamamlanmış olarak oluşur, test kullanıcılarına sunulur. `draft`: taslak oluşur; Play Console'da sürümü açıp **Start rollout** ile siz tamamlarsınız. |
| `hold_for_review` | evet/hayır | evet | Yalnızca `alpha` adımı için: değişiklikler Play'e **incelemeye gönderilmeden** hazırlanır (`changesNotSentForReview`). |
| `release_notes_tr/en/de/ar` | metin | boş | Boşsa `flutter/arrowtile/release-notes/<dil>.txt` dosyası kullanılır. En çok 500 karakter; tek satır alanında satır sonu için `\n` yazın. |

Önerilen akış (varsayılanlar): iç testte sürüm hemen hazır olur; kapalı testte sürüm oluşur ve değişiklik **Publishing overview** (Yayın genel bakışı) sayfasında "Changes ready to send" olarak bekler. Bu sayfada **Send changes for review** (İncelemeye gönder) düğmesine basarsınız. İnceleme bitince test kullanıcıları güncellemeyi alır.

### İncelemeye gönderme davranışı (önemli)
- **Managed publishing kapalıysa** (varsayılan) ve `hold_for_review` **kapalıysa**: Play, API ile yapılan değişikliği bazen **kendiliğinden incelemeye gönderir** ve inceleme bitince yayınlar. Yani siz bir şey yapmadan sürüm test kullanıcılarına ulaşabilir. Kontrolü elinizde tutmak için `hold_for_review` açık kalsın (varsayılan).
- `hold_for_review` açıkken bazı uygulamalarda Play şu hatayı verebilir: *"Changes cannot be sent for review automatically"* ya da tersi bir hata. Bu durumda `hold_for_review` değerini değiştirip tekrar çalıştırın (aynı AAB tekrar yüklenebilir, sürüm kodu yinelenme hatası vermez; bkz. sorun giderme).
- İç test (`internal`) sürümleri genellikle incelemeye girmez; yüklenince birkaç dakika içinde testçilere görünür.
- Bu davranış Play'in tarafında değişebilir; kesin durumu **Publishing overview** sayfasından görün.

### Sürüm notları
Her yüklemeden önce `flutter/arrowtile/release-notes/{tr,en,de,ar}.txt` dosyalarını yeni sürüme göre güncelleyin (şu an 1.1.6 notları var) ya da workflow çalıştırırken `release_notes_*` alanlarını doldurun. Diller Play'de sırasıyla `tr-TR`, `en-US`, `de-DE`, `ar` olarak gider. Mağaza girişinizde bu dillerin eklenmiş olması gerekir. Boş bırakılan dil için uyarı yazılır, o dilde not gönderilmez.

### Her yüklemeden önce
`flutter/arrowtile/pubspec.yaml` içinde `version: X.Y.Z+N` değerinde `N`'i (versionCode) artırın. Play aynı ya da daha düşük versionCode'u reddeder.

## Sorun giderme

| Belirti | Neden / çözüm |
|---|---|
| `The caller does not have permission` | Servis hesabı Play Console'da davet edilmemiş, **Arrowtile** için izin verilmemiş ya da izin eksik (3. adım). Yeni verilen izinlerin geçerli olması **birkaç dakikadan 24-36 saate kadar** sürebilir; bekleyip tekrar deneyin. Cloud'da API'nin etkin olduğunu (1. adım) ve JSON'un doğru servis hesabına ait olduğunu (`client_email`) kontrol edin. |
| `Google Play Android Developer API has not been used in project ... or it is disabled` | API, anahtarın ait olduğu projede etkin değil (1. adım); etkinleştirip birkaç dakika bekleyin. |
| `Package not found: com.arrowtile.puzzle` | Servis hesabı bu uygulamaya yetkili değil ya da izin henüz yayılmadı (yukarıdaki satır). |
| "PLAY_SERVICE_ACCOUNT_JSON geçersiz" / "servis hesabı anahtarı değil" | Secret'a JSON'un tamamı yapıştırılmamış ya da yanlış dosya yapıştırılmış (`google-services.json` değil, servis hesabı anahtarı olmalı). 4. adımı tekrarlayın. |
| `APK specifies a version code that has already been used` | Aynı versionCode daha önce yüklenmiş; `pubspec.yaml`'da `N`'i artırın. |
| `Only releases with status draft may be created on draft app` | Uygulama Play'de henüz taslak durumdaysa yalnızca `status=draft` kullanılabilir. |
| `Release notes ... too long` / sürüm notu hatası | Not 500 karakteri aşıyor ya da mağaza girişinde o dil ekli değil. |
| Yükleme atlandı uyarısı | `PLAY_SERVICE_ACCOUNT_JSON` tanımlı değil ya da `track=none`. AAB yine artifact olarak üretilir. |

İlk yükleme elle yapılmış olmalıdır (Play, uygulamanın ilk sürümünü API ile kabul etmez); Arrowtile için bu zaten yapıldı. Yükleme başarısız olsa bile AAB **artifact** olarak kayıtlıdır (**Artifacts → arrowtile-release-aab**), elle yüklemeye devam edebilirsiniz.

## Güvenlik
- JSON anahtarı bir **parola gibidir**: sahibi, Play Console'da verdiğiniz izin kadar işlem yapabilir. Yalnızca **GitHub secret** içinde tutun; depoya, sohbete, e-postaya koymayın.
- Yetkiyi dar tutun: yalnızca test kanalı izni (üretim izni vermeyin).
- Sızdığından şüphelenirseniz: Google Cloud → Service accounts → `play-upload` → Keys → anahtarı **Delete**; gerekirse Play Console → Users and permissions'tan kullanıcıyı kaldırın. Yeni anahtar üretip secret'ı güncelleyin. Anahtar iptal edildiği anda eski JSON işe yaramaz.
- Workflow secret değerini günlüğe yazmaz; Play adımları yalnızca elle (`workflow_dispatch`) çalışır.

## Teknik not
Yükleme için `r0adkll/upload-google-play@v1.1.5` (tam sürüme sabitli) kullanılır: paket `com.arrowtile.puzzle`, dosya imzalı AAB, varsa R8 `mapping.txt`, sürüm notları `whatsnew-<dil>` dosyalarından. İki kanal seçilirse aynı AAB iki ayrı adımda yüklenir. AAB artifact'ı, Play yüklemesinden **önce** kaydedilir.
