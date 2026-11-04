#!/usr/bin/env bash
# Arrowtile — android/ klasörünü KENDİ Flutter sürümünüzün şablonuyla yeniden üretmeniz gerekirse (Gradle/AGP sürüm
# uyuşmazlığı vb.), bu betik uygulamaya özgü dosyaları (manifest, ikonlar, AdMob kimliği, MainActivity, R8 kuralları,
# yedek kuralları) yeni şablonun üstüne geri koyar.
#
# Adımlar (proje kökünden):
#   mv android android_backup
#   flutter create --platforms=android --org com.arrowtile --project-name arrowtile .
#   bash tool/restore_android_overlay.sh android_backup
# Sonra android/app/build.gradle(.kts) içine android_backup/app/build.gradle.kts dosyasındaki
# "signingConfigs" + "buildTypes.release" bölümlerini ve targetSdk = 36 / minSdk = 24 / applicationId ayarlarını ekleyin.
set -euo pipefail
SRC="${1:-android_backup}"
DST="android"
[ -d "$SRC/app/src/main" ] || { echo "HATA: $SRC/app/src/main yok (yedek klasörü yanlış)"; exit 1; }
[ -d "$DST/app/src/main" ] || { echo "HATA: $DST/app/src/main yok; önce 'flutter create --platforms=android .' çalıştırın"; exit 1; }

cp -R "$SRC/app/src/main/res/." "$DST/app/src/main/res/"
cp "$SRC/app/src/main/AndroidManifest.xml" "$DST/app/src/main/AndroidManifest.xml"
mkdir -p "$DST/app/src/debug/res/values"
cp "$SRC/app/src/debug/res/values/ads.xml" "$DST/app/src/debug/res/values/ads.xml"
cp "$SRC/app/src/debug/AndroidManifest.xml" "$DST/app/src/debug/AndroidManifest.xml"
[ -f "$SRC/app/src/profile/AndroidManifest.xml" ] && cp "$SRC/app/src/profile/AndroidManifest.xml" "$DST/app/src/profile/AndroidManifest.xml"

# MainActivity: şablonun ürettiği paket klasörünü kaldır, bizim com.arrowtile.puzzle sürümünü koy
rm -rf "$DST/app/src/main/kotlin" "$DST/app/src/main/java"
mkdir -p "$DST/app/src/main/kotlin"
cp -R "$SRC/app/src/main/kotlin/." "$DST/app/src/main/kotlin/"

cp "$SRC/app/proguard-rules.pro" "$DST/app/proguard-rules.pro"
cp "$SRC/key.properties.example" "$DST/key.properties.example"

# applicationId / namespace: şablon com.arrowtile.arrowtile üretir → com.arrowtile.puzzle
for f in "$DST/app/build.gradle.kts" "$DST/app/build.gradle"; do
  [ -f "$f" ] && sed -i 's/com\.arrowtile\.arrowtile/com.arrowtile.puzzle/g' "$f"
done
echo "Tamam. Şimdi $DST/app/build.gradle(.kts) içine imzalama (key.properties) ve targetSdk = 36 ayarlarını ekleyin:"
echo "  bkz. $SRC/app/build.gradle.kts"
