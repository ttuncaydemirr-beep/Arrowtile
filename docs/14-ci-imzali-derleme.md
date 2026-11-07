# İmzalı AAB'yi GitHub Actions'ta derleme

Bilgisayara Flutter kurmadan, Play Store'a yüklenecek imzalı `app-release.aab` dosyasını GitHub üzerinden alırsınız.
Workflow: `.github/workflows/release.yml` (yalnızca elle çalışır). Depo herkese açıktır: anahtar ve şifreler **asla** depoya
yazılmaz, yalnızca GitHub **secrets** içinde durur.

## 1. Yükleme anahtarını oluşturun (bir kez)

Java (JDK 17) olan herhangi bir bilgisayarda (Android Studio'nun JDK'sı da olur):

```bash
keytool -genkeypair -v -keystore arrowtile-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

İstenen depo şifresini ve anahtar şifresini belirleyin. Şifrelerde `\` (ters eğik çizgi) kullanmayın; harf ve rakam yeterlidir.

## 2. Base64'e çevirin

- Linux/Mac: `base64 -w0 arrowtile-upload.jks` (Mac: `base64 -i arrowtile-upload.jks`)
- Windows (PowerShell): `[Convert]::ToBase64String([IO.File]::ReadAllBytes("arrowtile-upload.jks"))`

Çıkan tek satırlık uzun metin `ANDROID_KEYSTORE_BASE64` değeridir.

## 3. GitHub secrets

Depoda **Settings > Secrets and variables > Actions > New repository secret**:

| Secret | Değer |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | 2. adımdaki base64 metni |
| `ANDROID_KEYSTORE_PASSWORD` | depo (keystore) şifresi |
| `ANDROID_KEY_ALIAS` | `upload` (1. adımdaki alias) |
| `ANDROID_KEY_PASSWORD` | anahtar şifresi |
| `ADMOB_APP_ID` | AdMob uygulama kimliği, `ca-app-pub-…~…` |
| `ADMOB_INTERSTITIAL_ID` | geçiş reklamı birimi, `ca-app-pub-…/…` |
| `ADMOB_REWARDED_ID` | ödüllü reklam birimi, `ca-app-pub-…/…` |

Herhangi biri eksikse veya Google test kimliği (`3940256099942544`) girilmişse workflow açıklayıcı bir hatayla durur.

## 4. Çalıştırma

**Actions > "Release AAB (imzalı)" > Run workflow**. Bitince çalıştırmanın sayfasında **Artifacts > arrowtile-release-aab**
indirilir (içinde `app-release.aab` olan zip). Play Console'a yüklemeden önce `pubspec.yaml` içindeki `+N` (versionCode) her
yüklemede artmalıdır.

## Yedekleme ve kayıp uyarısı

- `arrowtile-upload.jks` dosyasını ve iki şifreyi en az **iki ayrı güvenli yerde** saklayın (parola yöneticisi, şifreli bulut). Depoya, e-postaya veya sohbete koymayın.
- İlk yüklemede Play Console'da **Play App Signing**'i kabul edin. Uygulamayı Google'ın tuttuğu asıl imza anahtarı imzalar; sizdeki anahtar yalnızca **yükleme anahtarıdır**.
- Yükleme anahtarı kaybolursa uygulama kaybolmaz: Play Console > **Uygulama bütünlüğü > Uygulama imzalama > Yükleme anahtarını sıfırla** ile yeni bir yükleme anahtarı kaydettirebilirsiniz (Google onayı birkaç gün sürebilir). Yeni bir anahtar oluşturup sertifikasını (PEM) Google'a göndermeniz yeterlidir. Play App Signing'i kabul etmeden yüklenen uygulamalarda böyle bir kurtarma yoktur.
