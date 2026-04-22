#!/usr/bin/env bash
# Apply (or reset) the Android accessibility scaling knobs that the
# Display + Font settings UI exposes: system font_scale (→ Font Size)
# and wm density (→ Display Size). Default is stock max: 1.30x on both.
# Both Chrome and WebView pick these up.
#
# Usage:
#   apply_a11y.sh <serial>
#   apply_a11y.sh <serial> --font-scale 2.0 --density-multiplier 1.5
#   apply_a11y.sh <serial> --reset

set -euo pipefail

SERIAL="${1:?serial required (e.g. emulator-5554)}"; shift || true
FONT_SCALE="1.30"
DENSITY_MULT="1.30"
RESET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --reset) RESET=1; shift ;;
    --font-scale) FONT_SCALE="$2"; shift 2 ;;
    --density-multiplier) DENSITY_MULT="$2"; shift 2 ;;
    -h|--help)
      sed -n '1,/^set -/p' "$0" | grep '^#'
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ "$RESET" = 1 ]; then
  adb -s "$SERIAL" shell settings put system font_scale 1.0
  adb -s "$SERIAL" shell wm density reset
  echo "reset: font_scale=1.0 density=physical"
  exit 0
fi

# Read physical density, compute override
phys=$(adb -s "$SERIAL" shell wm density \
       | awk -F': ' '/Physical density/{print $2}' | tr -d '\r')
override=$(awk -v p="$phys" -v m="$DENSITY_MULT" 'BEGIN{printf "%d", p*m+0.5}')

adb -s "$SERIAL" shell wm density "$override"
adb -s "$SERIAL" shell settings put system font_scale "$FONT_SCALE"

echo "applied: font_scale=$FONT_SCALE density=$override (physical=$phys × $DENSITY_MULT)"
