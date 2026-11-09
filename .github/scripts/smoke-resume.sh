#!/usr/bin/env bash
# Emülatörde "arka plana git → geri dön" duman testi (docs/16-geri-donus-donma.md).
# Kullanım: smoke-resume.sh <etiket> [form-bekleniyor]
#   etiket: çıktı klasörü adı (ör. release, eea); form-bekleniyor=1: UMP formu çıkabilir, "Consent" düğmesine dokunulur.
# Akış: aç → Play → oyun ekranı → HOME → yeniden aç → "Paused" penceresi ve 3 düğme var → Resume → pencere kayboldu,
# Pause düğmesi geri geldi, tahta çiziliyor → bir tur daha (pencere açıkken HOME) → logcat'te istisna yok.
# Dil: emülatör İngilizce (Play, Paused, Resume, Restart, Back to map, Pause).
set -u
TAG="${1:-release}"
EXPECT_FORM="${2:-0}"
PKG=com.arrowtile.puzzle
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$PWD/smoke-$TAG"
mkdir -p "$OUT"
UI="python3 $HERE/ui.py"
STEP=0

log() { echo "SMOKE[$TAG]: $*"; }

dump() { # $1 = dosya
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || true
  adb pull /sdcard/ui.xml "$1" >/dev/null 2>&1 || echo '<hierarchy/>' > "$1"
}

shot() { adb exec-out screencap -p > "$OUT/$1.png" 2>/dev/null || true; }

fail() {
  log "BAŞARISIZ: $*"
  dump "$OUT/fail.xml"; shot fail
  $UI texts "$OUT/fail.xml" | head -60 || true
  adb logcat -d -v brief > "$OUT/logcat-full.txt" 2>/dev/null || true
  echo "--- odak penceresi:"; adb shell dumpsys window 2>/dev/null | grep -E "mCurrentFocus|mFocusedApp" | head -3 || true
  echo "--- logcat (flutter/Ads/UMP/AndroidRuntime), son 60:"
  grep -E " (flutter|Ads|AndroidRuntime)|UMP|onsent" "$OUT/logcat-full.txt" | tail -60 | cut -c1-260 || true
  exit 1
}

# wait_for <regex> <saniye> : düğüm görünene kadar bekler, dökümü cur.xml'e yazar
wait_for() {
  local i
  for i in $(seq 1 "$2"); do
    dump "$OUT/cur.xml"
    if $UI has "$OUT/cur.xml" "$1"; then return 0; fi
    sleep 1
  done
  return 1
}

tap_label() { # <regex>
  local xy
  xy=$($UI find "$OUT/cur.xml" "$1") || fail "düğme bulunamadı: $1"
  log "dokun '$1' @ $xy"
  adb shell input tap $xy
}

launch() { adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; }

instances() {
  adb shell dumpsys activity activities | grep -o "ActivityRecord{[0-9a-f]* u0 $PKG/[A-Za-z.]*MainActivity" | sort -u | wc -l
}

adb logcat -c
launch
log "uygulama açıldı"

# ---- 1) menü (UMP formu çıkarsa onaylanır)
# form_dismiss: ekranda UMP onay formu varsa "Consent"e dokunur (dönüş 0 = dokunuldu)
form_dismiss() {
  local xy
  if xy=$($UI find "$OUT/cur.xml" '^(Consent|Accept all|I agree|Agree|Accept)$'); then
    FORM_SEEN=$((FORM_SEEN+1)); log "UMP onay formu görüldü, 'Consent' dokunuluyor @ $xy"; shot "ump-form-$FORM_SEEN"; adb shell input tap $xy
    return 0
  fi
  return 1
}
FORM_SEEN=0
for i in $(seq 1 90); do
  dump "$OUT/cur.xml"
  if form_dismiss; then sleep 2; continue; fi
  if $UI has "$OUT/cur.xml" '^(Play|Continue: Level [0-9]+)$'; then break; fi
  sleep 1
done
$UI has "$OUT/cur.xml" '^(Play|Continue: Level [0-9]+)$' || fail "ana menü (Play) görünmedi"
# EEA geçişinde form, menü görünür görünmez gelmeyebilir (ağdan yüklenir): kısa süre daha bekle
if [ "$EXPECT_FORM" = "1" ] && [ "$FORM_SEEN" = "0" ]; then
  for i in $(seq 1 30); do
    dump "$OUT/cur.xml"
    if form_dismiss; then sleep 3; break; fi
    sleep 1
  done
fi
shot menu
log "ana menü hazır (görülen UMP formu sayısı: $FORM_SEEN)"
if [ "$EXPECT_FORM" = "1" ] && [ "$FORM_SEEN" = "0" ]; then log "UYARI: EEA hata ayıklama coğrafyasında form beklenirdi ama görülmedi"; fi
echo "$FORM_SEEN" > "$OUT/ump-form-seen.txt"
sleep 2

# ---- 2) oyunu başlat
tap_label '^(Play|Continue: Level [0-9]+)$'
GAME_UP=0
for i in $(seq 1 30); do
  dump "$OUT/cur.xml"
  if form_dismiss; then log "UYARI: onay formu OYUN başlarken çıktı"; sleep 2; continue; fi
  if $UI has "$OUT/cur.xml" '^Pause$'; then GAME_UP=1; break; fi
  sleep 1
done
[ "$GAME_UP" = "1" ] || fail "oyun ekranı açılmadı (Pause düğmesi yok)"
sleep 2
shot game-before
adb exec-out screencap > "$OUT/game-before.raw" 2>/dev/null || true
C0=$($UI colors "$OUT/game-before.raw" 2>/dev/null || echo 0)
log "oyun ekranı açık; tahta renk sayısı=$C0"
PID0=$(adb shell pidof $PKG | tr -d '\r')

cycle() { # $1 = tur adı, $2 = 1: HOME'dan önce duraklatma penceresi zaten açık
  local name="$1"
  log "--- tur: $name"
  adb shell input keyevent KEYCODE_HOME
  sleep 4
  launch
  sleep 3
  wait_for '^Paused$' 15 || {
    if form_dismiss; then fail "[$name] geri dönünce OYUNUN ÜSTÜNDE UMP onay formu çıktı (form oyun sırasında gösterilmemeli)"; fi
    fail "[$name] geri dönünce 'Paused' penceresi yok"
  }
  shot "$name-sheet"
  for b in '^Resume$' '^Restart$' '^Back to map$'; do
    $UI has "$OUT/cur.xml" "$b" || fail "[$name] pencere düğmesi yok: $b"
  done
  local pid
  pid=$(adb shell pidof $PKG | tr -d '\r')
  [ "$pid" = "$PID0" ] || fail "[$name] süreç değişti ($PID0 -> $pid): uygulama yeniden başlatılmış"
  local n; n=$(instances)
  [ "$n" -le 1 ] || fail "[$name] birden çok MainActivity örneği: $n"
  tap_label '^Resume$'
  sleep 1
  wait_for '^Pause$' 10 || fail "[$name] Resume'dan sonra Pause düğmesi dönmedi"
  if $UI has "$OUT/cur.xml" '^Paused$'; then fail "[$name] Resume'dan sonra pencere kapanmadı (üst üste ikinci pencere?)"; fi
  sleep 1
  shot "$name-after"
  adb exec-out screencap > "$OUT/$name-after.raw" 2>/dev/null || true
  local c; c=$($UI colors "$OUT/$name-after.raw" 2>/dev/null || echo 0)
  log "[$name] pencere kapandı; tahta renk sayısı=$c"
  [ "$c" -ge 6 ] || fail "[$name] tahta çizilmiyor (renk sayısı $c < 6)"
}

cycle tur1
# ikinci tur: pencere zaten açıkken de olabilir; önce Pause'a dokunup pencereyi aç, sonra HOME
tap_label '^Pause$'
wait_for '^Paused$' 10 || fail "Pause düğmesi pencereyi açmadı"
log "pencere açıkken HOME"
adb shell input keyevent KEYCODE_HOME
sleep 4
launch
sleep 3
wait_for '^Paused$' 15 || fail "[tur2] pencere açıkken arka plana gidip dönünce pencere yok"
tap_label '^Resume$'
sleep 1
wait_for '^Pause$' 10 || fail "[tur2] Resume sonrası Pause yok"
if $UI has "$OUT/cur.xml" '^Paused$'; then fail "[tur2] pencere kapanmadı (yığılmış ikinci pencere)"; fi
cycle tur3

# ---- 3) logcat
adb logcat -d -v brief > "$OUT/logcat-full.txt" 2>/dev/null || true
if grep -q "FATAL EXCEPTION" "$OUT/logcat-full.txt" && grep -q "Process: $PKG" "$OUT/logcat-full.txt"; then fail "uygulama çöktü"; fi
if grep -E "EXCEPTION CAUGHT BY|Unhandled Exception|ANR in $PKG" "$OUT/logcat-full.txt" > "$OUT/exceptions.txt"; then
  cat "$OUT/exceptions.txt" | head -40
  fail "logcat'te Flutter istisnası / ANR var"
fi
grep -iE "UMP|consent|FormActivity|Ads:" "$OUT/logcat-full.txt" > "$OUT/consent-logcat.txt" || true
echo "=== UMP / onay satırları ==="; head -40 "$OUT/consent-logcat.txt" || true
log "TAMAM: geri dönüşte duraklatma penceresi tek, yanıt veriyor, tahta çiziliyor (görülen UMP formu: $FORM_SEEN)"
