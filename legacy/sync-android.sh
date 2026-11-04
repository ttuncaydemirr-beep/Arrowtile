#!/usr/bin/env bash
# Arrowtile — oyun dosyalarını (game/) Android projesinin assets/www klasörüne eşitler.
# Gradle bunu her derlemede zaten yapar (app/build.gradle.kts: syncGameAssets); bu betik elle eşitleme içindir.
# Kullanım (proje kökünden): bash legacy/sync-android.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"  # legacy/ klasöründen proje kökü
SRC="$ROOT/game/"
DST="$ROOT/legacy/android-native/app/src/main/assets/www/"
[ -f "$SRC/index.html" ] || { echo "HATA: $SRC/index.html yok"; exit 1; }
mkdir -p "$DST"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude '.DS_Store' --exclude 'Thumbs.db' "$SRC" "$DST"
else
  rm -rf "$DST"; mkdir -p "$DST"; cp -R "$SRC". "$DST"
fi
echo "Eşitlendi: $(find "$DST" -type f | wc -l) dosya → legacy/android-native/app/src/main/assets/www/"
