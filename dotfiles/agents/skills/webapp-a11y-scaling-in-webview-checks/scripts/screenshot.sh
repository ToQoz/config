#!/usr/bin/env bash
# One-shot: boot emulator if needed, build/install wvtest APK if needed,
# apply the default preset (LINE MiniApp: density × 1.1, textZoom 200 —
# see SKILL.md for the preset list and how to switch), open URL, capture
# device screenshot, print path.
#
# Usage: screenshot.sh <url> [out.png]

set -euo pipefail

URL="${1:?url required}"
OUT="${2:-/tmp/webapp-a11y-scaling-in-webview-screenshot.png}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$(dirname "$OUT")"

SERIAL=$("$SCRIPT_DIR/boot_emulator.sh")
"$SCRIPT_DIR/apply_a11y.sh" "$SERIAL" --font-scale 1.0 --density-multiplier 1.1 >&2
"$SCRIPT_DIR/launch_webview.sh" "$SERIAL" "$URL" 200 >&2

adb -s "$SERIAL" shell screencap -p > "$OUT"
echo "$OUT"
