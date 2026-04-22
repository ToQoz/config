#!/usr/bin/env bash
# Install (if missing) and launch the bundled wvtest WebView harness with
# the given URL and text-zoom value. Idempotent — re-launching re-navigates
# the WebView to the new URL.
#
# Usage: launch_webview.sh <serial> <url> [text_zoom]
# Default text_zoom: 200

set -euo pipefail

SERIAL="${1:?serial required}"
URL="${2:?url required}"
ZOOM="${3:-200}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK="$(cd "$SCRIPT_DIR/.." && pwd)/wvtest/app.apk"

# Ensure APK exists
if [ ! -f "$APK" ]; then
  "$SCRIPT_DIR/build_apk.sh" >&2
fi

# Install if not already installed, or if the APK on disk is newer than what's installed
if ! adb -s "$SERIAL" shell pm path com.example.wvtest >/dev/null 2>&1; then
  adb -s "$SERIAL" install -r "$APK" >&2
fi

adb -s "$SERIAL" shell am force-stop com.example.wvtest
sleep 1
adb -s "$SERIAL" shell am start -n com.example.wvtest/.MainActivity \
  --es url "$URL" --ei zoom "$ZOOM" >/dev/null

# Wait for WebView's DevTools socket to appear (Chromium attaches on first
# paint). Match the socket name with a word-boundary so stale sockets from
# previous runs don't prematurely satisfy the check.
for _ in $(seq 1 20); do
  pid=$(adb -s "$SERIAL" shell pidof com.example.wvtest 2>/dev/null | tr -d '\r\n')
  if [ -n "$pid" ] && adb -s "$SERIAL" shell \
       "cat /proc/net/unix 2>/dev/null | grep -qE 'webview_devtools_remote_${pid}$'"; then
    exit 0
  fi
  sleep 1
done

echo "launch_webview: CDP socket did not appear for com.example.wvtest" >&2
exit 1
