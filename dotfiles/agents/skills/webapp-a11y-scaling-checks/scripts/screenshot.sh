#!/usr/bin/env bash
# One-shot: boot emulator if needed, apply max a11y settings, open URL in
# Chrome, capture a device screenshot, and print the output path.
#
# Usage: screenshot.sh <url> [out.png]

set -euo pipefail

URL="${1:?url required}"
OUT="${2:-/tmp/webapp-a11y-screenshot.png}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=sdkenv.sh
source "$SCRIPT_DIR/sdkenv.sh"

mkdir -p "$(dirname "$OUT")"

# Default Chrome app-locale for this one-shot path. The launcher does
# not pick a default — wrappers do. Override by exporting CHROME_LOCALE
# before invoking this script (set to '' to opt out of the override).
export CHROME_LOCALE="${CHROME_LOCALE-ja-JP}"

SERIAL=$("$SCRIPT_DIR/boot_emulator.sh")
# Clear any stale density override so FRE dialogs remain easy to dismiss.
"$SCRIPT_DIR/apply_a11y.sh" "$SERIAL" --reset >&2
"$SCRIPT_DIR/launch_chrome.sh" "$SERIAL" "$URL"
# Apply a11y after FRE is cleared, then re-launch so the page picks up
# the new density/font scale.
"$SCRIPT_DIR/apply_a11y.sh" "$SERIAL" >&2
"$SCRIPT_DIR/launch_chrome.sh" "$SERIAL" "$URL"

# `adb shell screencap` captures what a user actually sees — unlike the
# CDP full-page screenshot, which tiles pathologically on Android Chrome
# (`Page.captureScreenshot` with `captureBeyondViewport`).
adb -s "$SERIAL" shell screencap -p > "$OUT"

# Sidecar with the inputs needed to re-derive this shot. Cheap
# reproducibility / audit trail: paired by filename so callers can do
# `for png in *.png; do jq . "${png}.json"; done`.
density=$(adb -s "$SERIAL" shell wm density 2>/dev/null \
          | awk -F': ' '
              /Override density/{o=$2}
              /Physical density/{p=$2}
              END{print (o!="") ? o : p}' \
          | tr -d '\r')
font_scale=$(adb -s "$SERIAL" shell settings get system font_scale 2>/dev/null | tr -d '\r')
jq -n \
  --arg url           "$URL" \
  --arg out           "$OUT" \
  --arg ts            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg serial        "$SERIAL" \
  --arg density       "${density:-unknown}" \
  --arg font_scale    "${font_scale:-unknown}" \
  --arg chrome_locale "${CHROME_LOCALE-<unset>}" \
  --arg system_image  "${ANDROID_SYSTEM_IMAGE:-<unset>}" \
  '{url: $url, out: $out, ts: $ts, serial: $serial,
    density: $density, font_scale: $font_scale,
    chrome_locale: $chrome_locale, system_image: $system_image}' \
  > "${OUT}.json"

echo "$OUT"
