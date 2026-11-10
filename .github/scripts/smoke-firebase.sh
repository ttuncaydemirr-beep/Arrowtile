#!/usr/bin/env bash
# Emülatörde Firebase etkin (SAHTE yapılandırmalı) release APK denemesi (docs/19).
# Kullanım: smoke-firebase.sh  (APK önceden kurulu olmalı)
# Doğrular: çökme yok; logcat'te "TELEMETRY: init ok" (Firebase başladı) ve "TELEMETRY: consent:" (onay sinyalleri hesaplandı);
# ardından aynı APK ile arka plana git/dön testi (smoke-resume.sh).
set -u
PKG=com.arrowtile.puzzle
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
for i in $(seq 1 60); do
  adb logcat -d -v brief flutter:V AndroidRuntime:E '*:S' > logcat-fb.txt || true
  if grep -q "TELEMETRY: init ok" logcat-fb.txt && grep -q "TELEMETRY: consent:" logcat-fb.txt; then break; fi
  sleep 1
done
echo "=== TELEMETRY / FATAL satırları ==="
grep -E "TELEMETRY|FATAL" logcat-fb.txt || echo "(yok)"
if grep -q "FATAL EXCEPTION" logcat-fb.txt; then echo "UYGULAMA ÇÖKTÜ"; exit 1; fi
grep -q "TELEMETRY: init ok" logcat-fb.txt || { echo "Firebase başlatılamadı (init ok satırı yok)"; exit 1; }
grep -q "TELEMETRY: consent:" logcat-fb.txt || { echo "Onay sinyalleri hesaplanmadı (consent satırı yok)"; exit 1; }
exec bash "$(cd "$(dirname "$0")" && pwd)/smoke-resume.sh" firebase 0
