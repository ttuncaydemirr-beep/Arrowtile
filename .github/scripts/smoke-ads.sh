#!/usr/bin/env bash
# Emülatörde "reklam donması" duman testi (docs/18, sürüm 1.1.1).
# Kullanım: smoke-ads.sh <etiket> <nofill|fill|slow>
#   slow  : (1.1.4, docs/21) fill + --dart-define=ADS_PRESENT_DELAY_MS=8000: show() 8 sn geciktirilir (gerçek cihazdaki geç AdActivity).
#           Beklenen: seviye sonu reklam kapanana dek bekler; "show() çağrıldı" ile sonraki "level N opened" arasında mutlaka
#           dismissed / show failed / released satırı vardır ve seviye sırasında AdActivity hiç görülmez.
#   nofill: debug APK --dart-define=ADS_FORCE_INVALID=true (geçersiz reklam birimi → doldurulamadı; onaysız AdMob hesabını taklit eder)
#   fill  : debug APK, Google test reklam birimleri (gerçek reklam yüklenir/gösterilir; reklam penceresi kapatılır)
# 1.1.3: seviye sırasında AdActivity (geç gelen reklam) ve 'GEÇ gösterildi'/late_blocked satırları da başarısızlıktır.
# Her iki APK de --dart-define=AUTOPLAY_FROM=13 ile derlenir: kayıt seviye 13'e açılır, geçiş reklamı sayacı "bir sonraki tamamlamada
# reklam" olarak tohumlanır; uygulama seviye 13'ü kendiliğinden açıp çözer ve seviye sonunda "Sonraki"ne basar. Her seviye açılışında
# logcat'e `AUTOPLAY: level N opened` yazılır. 15 (ve 16) → 17 geçişi dahil, seviye 18'e kadar ilerlemesi beklenir; belirli bir süre
# yeni seviye açılmazsa (donma) ya da ANR/çökme olursa başarısız.
set -u
TAG="${1:-ads}"
MODE="${2:-nofill}"
PKG=com.arrowtile.puzzle
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$PWD/smoke-$TAG"
mkdir -p "$OUT"
UI="python3 $HERE/ui.py"
TARGET=18
STALL=90      # sn: yeni seviye bu sürede açılmazsa donma sayılır
TOTAL=480     # sn: toplam üst sınır

log() { echo "SMOKE[$TAG]: $*"; }
dump() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || true; adb pull /sdcard/ui.xml "$1" >/dev/null 2>&1 || echo '<hierarchy/>' > "$1"; }
shot() { adb exec-out screencap -p > "$OUT/$1.png" 2>/dev/null || true; }
fail() {
  log "BAŞARISIZ: $*"
  dump "$OUT/fail.xml"; shot fail
  $UI texts "$OUT/fail.xml" | head -40 || true
  adb logcat -d -v brief > "$OUT/logcat-full.txt" 2>/dev/null || true
  echo "--- odak penceresi:"; adb shell dumpsys window 2>/dev/null | grep -E "mCurrentFocus|mFocusedApp" | head -3 || true
  echo "--- logcat (flutter/Ads/AndroidRuntime), son 80:"
  grep -E " (flutter|Ads|AndroidRuntime)|ANR" "$OUT/logcat-full.txt" | tail -80 | cut -c1-240 || true
  exit 1
}

adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
log "uygulama açıldı (kip: $MODE, hedef: seviye $TARGET)"

START=$SECONDS
LAST_LVL=0
LAST_CHANGE=$SECONDS
AD_CLOSES=0
while [ $((SECONDS - START)) -lt "$TOTAL" ]; do
  adb logcat -d -v brief flutter:V '*:S' > "$OUT/flutter-cur.txt" 2>/dev/null || true
  LVL=$(grep -o "AUTOPLAY: level [0-9]* opened" "$OUT/flutter-cur.txt" | grep -o "[0-9]\+" | sort -n | tail -1)
  LVL=${LVL:-0}
  if [ "$LVL" -gt "$LAST_LVL" ]; then
    log "seviye $LVL açıldı (t=$((SECONDS - START)) sn)"
    LAST_LVL=$LVL; LAST_CHANGE=$SECONDS
  fi
  if [ "$LAST_LVL" -ge "$TARGET" ]; then break; fi
  if [ $((SECONDS - LAST_CHANGE)) -gt "$STALL" ]; then
    fail "DONMA: $STALL sn boyunca yeni seviye açılmadı (son açılan: $LAST_LVL)"
  fi
  # UMP formu çıkarsa onayla; tam ekran reklam ekrandaysa kapat (yalnızca fill kipi)
  FOCUS=$(adb shell dumpsys window 2>/dev/null | grep -E "mCurrentFocus" | head -1)
  if echo "$FOCUS" | grep -q "AdActivity"; then
    # 1.1.3 (docs/20): tam ekran reklam yalnızca seviye sonu geçişinde (show() çağrısından sonra, bir SONRAKİ seviye açılmadan) görünebilir.
    # Son işaret "level N opened" ise reklam seviye SIRASINDA belirmiştir (geç gelen reklam) → başarısız (fill ve nofill).
    LASTMARK=$(grep -nE "AUTOPLAY: level [0-9]+ opened|interstitial: show\(\) çağrıldı" "$OUT/flutter-cur.txt" | tail -1)
    if echo "$LASTMARK" | grep -q "opened"; then
      fail "GEÇ REKLAM: seviye sırasında tam ekran reklam penceresi açıldı (son işaret: $LASTMARK)"
    fi
    if [ "$MODE" = "fill" ] || [ "$MODE" = "slow" ]; then
      dump "$OUT/cur.xml"
      if xy=$($UI find "$OUT/cur.xml" '(?i)^(close|close ad|skip|kapat)$'); then
        log "reklam penceresi kapatılıyor (dokun @ $xy)"; adb shell input tap $xy
      else
        adb shell input keyevent KEYCODE_BACK
      fi
      AD_CLOSES=$((AD_CLOSES+1)); shot "ad-$AD_CLOSES"
    else
      fail "nofill kipinde tam ekran reklam penceresi açıldı (geçersiz birim doldurulmamalıydı)"
    fi
  else
    dump "$OUT/cur.xml"
    if xy=$($UI find "$OUT/cur.xml" '^(Consent|Accept all|I agree|Agree|Accept)$'); then log "UMP formu: onaylanıyor"; adb shell input tap $xy; fi
  fi
  sleep 3
done
[ "$LAST_LVL" -ge "$TARGET" ] || fail "süre doldu: seviye $TARGET açılmadı (son: $LAST_LVL)"
shot "reached-$TARGET"

adb logcat -d -v brief > "$OUT/logcat-full.txt" 2>/dev/null || true
grep -E "Ads:" "$OUT/logcat-full.txt" > "$OUT/ads-lines.txt" || true
echo "=== Ads satırları (son 40) ==="; tail -40 "$OUT/ads-lines.txt" || true
if grep -q "FATAL EXCEPTION" "$OUT/logcat-full.txt" && grep -q "Process: $PKG" "$OUT/logcat-full.txt"; then fail "uygulama çöktü"; fi
if grep -E "ANR in $PKG|EXCEPTION CAUGHT BY|Unhandled Exception" "$OUT/logcat-full.txt" > "$OUT/exceptions.txt"; then head -30 "$OUT/exceptions.txt"; fail "ANR / Flutter istisnası"; fi
if grep -qE "GEÇ gösterildi|late_blocked" "$OUT/logcat-full.txt"; then grep -E "GEÇ gösterildi|late_blocked" "$OUT/logcat-full.txt" | head; fail "geç gelen reklam olayı görüldü (bırakılmış reklam seviye sırasında belirdi)"; fi
if [ "$MODE" = "nofill" ]; then
  grep -q "onAdFailedToLoad" "$OUT/ads-lines.txt" || log "UYARI: geçersiz birim için onAdFailedToLoad satırı görülmedi (SDK hazır olmayabilir)"
fi
# 1.1.4 (docs/21): TUTMA sırası — show() çağrıldıktan sonra, reklam kapanmadan / gösterilemeden / bırakılmadan yeni seviye açılmamalı
grep -E "AUTOPLAY: level [0-9]+ opened|Ads: interstitial: (show\(\) çağrıldı|dismissed|released)|Ads: interstitial show failed" "$OUT/logcat-full.txt" > "$OUT/hold-order.txt" || true
echo "=== tutma sırası ==="; cut -c1-160 "$OUT/hold-order.txt" | tail -40
if ! awk '/show\(\) çağrıldı/{open=1; next} /dismissed|released|show failed/{open=0; next} /AUTOPLAY: level [0-9]+ opened/{ if (open) { print "İHLAL: " $0; bad=1 } } END { exit bad ? 1 : 0 }' "$OUT/hold-order.txt"; then
  fail "TUTMA İHLALİ: show() bitmeden yeni seviye açıldı"
fi
SHOWS=$(grep -c "show() çağrıldı" "$OUT/hold-order.txt" || true)
log "show() çağrısı: $SHOWS"
if [ "$MODE" = "slow" ] && [ "${SHOWS:-0}" -lt 1 ]; then log "UYARI: slow kipinde show() çağrısı görülmedi (test reklamı yüklenmemiş olabilir)"; fi
log "TAMAM: seviye 13 → $LAST_LVL arası geçişler takılmadan geçti (kip: $MODE, kapatılan reklam penceresi: $AD_CLOSES)"
