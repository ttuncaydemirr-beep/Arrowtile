#!/usr/bin/env bash
# Android köprüsünün mantık denetimi (Android SDK GEREKMEZ):
#  1) app/src/main/java/** sahte (stub) Android/AdMob/UMP/Billing sınıflarıyla javac ile derlenir
#     (sözdizimi + iç tutarlılık; GERÇEK SDK API'si ile uyum Android Studio derlemesinde doğrulanır).
#  2) AndroidBridge sahte Host/Ads/Billing/Consent ile çalıştırılır, ürettiği JS betikleri yazdırılır.
#  3) Bu betikler GERÇEK game/js/ads.js'e verilir ve sonuçlar denetlenir.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../../.."
OUT="$(mktemp -d)"
javac -nowarn -d "$OUT" $(find "$HERE/stubs" -name '*.java') "$ROOT"/legacy/android-native/app/src/main/java/com/arrowtile/puzzle/*.java "$HERE/BridgeHarness.java"
java -cp "$OUT" com.arrowtile.puzzle.BridgeHarness > "$OUT/scripts.txt"
node "$HERE/feed.js" "$OUT/scripts.txt"
rm -rf "$OUT"
