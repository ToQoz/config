#!/usr/bin/env bash
# Build the bundled WebView tester APK (wvtest/) if it is missing or out
# of date. Produces `<skill>/wvtest/app.apk`.
#
# Tooling (adb / build-tools / javac / keytool) is resolved by
# scripts/sdkenv.sh — see that file for the lookup chain.
#
# Usage: build_apk.sh [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sdkenv.sh
source "$SCRIPT_DIR/sdkenv.sh"

WV="$(cd "$SCRIPT_DIR/.." && pwd)/wvtest"
SRC="$WV/src/com/example/wvtest/MainActivity.java"
MANIFEST="$WV/AndroidManifest.xml"
OUT="$WV/app.apk"

# Skip rebuild unless --force or APK is older than any source file
if [ "${1:-}" != "--force" ] && [ -f "$OUT" ]; then
  if [ "$OUT" -nt "$SRC" ] && [ "$OUT" -nt "$MANIFEST" ]; then
    echo "$OUT (up to date)"
    exit 0
  fi
fi

BT="${ANDROID_BUILD_TOOLS_DIR:-}"
PLATFORM="${ANDROID_PLATFORM_JAR:-}"
[ -n "$BT" ] && [ -d "$BT" ] || {
  echo "build_apk: no Android build-tools found under $ANDROID_SDK_ROOT/build-tools/." >&2
  echo "  Install one (e.g. sdkmanager 'build-tools;36.0.0') or set" >&2
  echo "  ANDROID_BUILD_TOOLS_DIR to an existing directory." >&2
  exit 1
}
[ -n "$PLATFORM" ] && [ -f "$PLATFORM" ] || {
  echo "build_apk: no Android platform jar found under $ANDROID_SDK_ROOT/platforms/." >&2
  echo "  Install one (e.g. sdkmanager 'platforms;android-36') or set" >&2
  echo "  ANDROID_PLATFORM_JAR to an existing android.jar." >&2
  exit 1
}
PATH="$BT:$PATH"

cd "$WV"
rm -rf classes gen classes.dex app.unaligned.apk app.aligned.apk "$OUT"
aapt2 link -I "$PLATFORM" --manifest AndroidManifest.xml -o app.unaligned.apk --java gen
mkdir -p classes
javac -classpath "$PLATFORM" -d classes "$SRC"
d8 --lib "$PLATFORM" --output . classes/com/example/wvtest/*.class
zip -j app.unaligned.apk classes.dex >/dev/null
if [ ! -f debug.keystore ]; then
  keytool -genkey -keystore debug.keystore -storepass android -keypass android \
    -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
    -dname 'CN=Android Debug,O=Android,C=US' >/dev/null 2>&1
fi
zipalign -f -p 4 app.unaligned.apk app.aligned.apk
apksigner sign --ks debug.keystore --ks-pass pass:android \
  --ks-key-alias androiddebugkey --key-pass pass:android \
  --out "$OUT" app.aligned.apk

echo "built: $OUT"
