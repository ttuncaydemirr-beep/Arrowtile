#!/usr/bin/env bash
# 1.2.4: Emülatörde Android yedekleme kuralları testi (backup_rules.xml / data_extraction_rules.xml).
# Uygulama en az bir kez açılıp kayıt yazmış olmalı (smoke-resume.sh'den sonra çalışır). Yerel yedek taşıyıcısıyla
# (LocalTransport) yedek alınır ve şunlar denetlenir:
#   1) yedekte oyun kaydı (sp/FlutterSharedPreferences.xml) VAR,
#   2) yedekte başka hiçbir dosya YOK (yalnızca _manifest ve kayıt dosyası),
#   3) uygulama verisi silinip yedekten geri yüklenince kayıt dosyası AYNI içerikle geri geliyor,
#   4) geri yüklemeden sonra uygulama çökmeden açılıyor.
# Emülatör görüntüsü google_apis (adb root destekli) olmalı.
set -u
PKG=com.arrowtile.puzzle
OUT="$PWD/smoke-backup"
mkdir -p "$OUT"
PREFS="/data/data/$PKG/shared_prefs/FlutterSharedPreferences.xml"
log() { echo "BACKUP: $*"; }
fail() {
  log "BAŞARISIZ: $*"
  adb shell ls -la "/data/data/$PKG/shared_prefs" 2>&1 | head -40 || true
  adb logcat -d -v brief BackupManagerService:V BackupManager:V FullBackup:V LocalTransport:V AndroidRuntime:E '*:S' 2>/dev/null | tail -80 || true
  exit 1
}

adb root >/dev/null 2>&1 || true
sleep 3
adb wait-for-device
# force-stop KULLANILMAZ: Android "durdurulmuş" uygulamanın yedeğini almaz ("Backup is not allowed"). Ana ekrana gidilir.
adb shell input keyevent KEYCODE_HOME || true
sleep 3

log "yedek öncesi shared_prefs:"
adb shell ls "/data/data/$PKG/shared_prefs" | tee "$OUT/prefs-before.txt" || fail "shared_prefs okunamadı (adb root?)"
adb shell cat "$PREFS" | tr -d '\r' > "$OUT/prefs-before.xml"
grep -q "flutter.arrowtile." "$OUT/prefs-before.xml" || fail "yedek öncesi kayıt dosyasında oyun anahtarı yok ($PREFS)"
OTHERS=$(grep -v -x "FlutterSharedPreferences.xml" "$OUT/prefs-before.txt" | tr -d '\r' | grep -c . || true)
log "kayıt dışı tercih dosyası sayısı: $OTHERS (bunlar yedeğe GİRMEMELİ)"

adb shell bmgr enable true >/dev/null
adb shell bmgr list transports | tee "$OUT/transports.txt"
adb shell bmgr transport com.android.localtransport/.LocalTransport | tee -a "$OUT/transports.txt"
adb shell bmgr backupnow "$PKG" | tee "$OUT/backupnow.txt"
grep -q "Success" "$OUT/backupnow.txt" || fail "bmgr backupnow başarısız"

F=$(adb shell "find /data/cache/backup -path '*_full*' -name $PKG 2>/dev/null" | tr -d '\r' | head -1)
[ -n "$F" ] || fail "tam yedek dosyası bulunamadı (/data/cache/backup/*/_full/$PKG)"
log "yedek dosyası: $F"
adb shell "tar -tf $F" 2>/dev/null | tr -d '\r' | tee "$OUT/backup-list.txt"
[ -s "$OUT/backup-list.txt" ] || fail "yedek içeriği listelenemedi"
grep -q "apps/$PKG/sp/FlutterSharedPreferences.xml$" "$OUT/backup-list.txt" || fail "yedekte oyun kaydı YOK"
EXTRA=$(grep -v -E "^apps/$PKG/(_manifest|sp/FlutterSharedPreferences\.xml)$" "$OUT/backup-list.txt" | grep -v '/$' || true)
[ -z "$EXTRA" ] || fail "yedekte kayıt dışı dosya var: $EXTRA"
log "yedek içeriği doğru: yalnızca _manifest + sp/FlutterSharedPreferences.xml"

adb shell pm clear "$PKG" >/dev/null
adb shell "test -f $PREFS" && fail "pm clear sonrası kayıt hâlâ duruyor (test geçersiz)"
adb shell bmgr restore "$PKG" | tee "$OUT/restore.txt"
sleep 3
adb shell cat "$PREFS" 2>/dev/null | tr -d '\r' > "$OUT/prefs-after.xml"
[ -s "$OUT/prefs-after.xml" ] || fail "geri yüklemeden sonra kayıt GELMEDİ"
cmp -s "$OUT/prefs-before.xml" "$OUT/prefs-after.xml" || { diff "$OUT/prefs-before.xml" "$OUT/prefs-after.xml"; fail "geri yüklenen kayıt yedek öncesiyle aynı değil"; }
log "kayıt dosyası aynen geri geldi"
log "geri yükleme sonrası shared_prefs:"
adb shell ls "/data/data/$PKG/shared_prefs" | tee "$OUT/prefs-after.txt"

adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 25
adb logcat -d -v brief AndroidRuntime:E '*:S' > "$OUT/logcat-after.txt" || true
if grep -q "FATAL EXCEPTION" "$OUT/logcat-after.txt" && grep -q "Process: $PKG" "$OUT/logcat-after.txt"; then
  cat "$OUT/logcat-after.txt"; fail "geri yüklemeden sonra uygulama çöktü"
fi
adb shell pidof "$PKG" >/dev/null || fail "geri yüklemeden sonra uygulama çalışmıyor"
adb exec-out screencap -p > "$OUT/after-restore.png" 2>/dev/null || true
log "TAMAM"
