#!/usr/bin/env bash
# Launch Chrome at the given URL on the given emulator serial, advancing
# through the First Run Experience (ToS, sign-in, notifications prompt)
# until no known FRE button is on screen. Idempotent on already-configured
# emulators — the FRE loop is a no-op when it's not present.
#
# Usage: launch_chrome.sh <serial> <url>

set -euo pipefail

SERIAL="${1:?serial required}"
URL="${2:?url required}"

# Optionally set Chrome's per-app locale so the browser's accept-
# languages matches the target-content language. Without it, Chrome
# shows a "Translate this page?" infobar on foreign-language content
# that overlays the page UI and corrupts a11y screenshots.
#
# Policy: this launcher does NOT pick a default. The caller — wrapper
# script (e.g. `screenshot.sh`) or the user driving the interactive
# flow — must set CHROME_LOCALE to the target language (e.g. "ja-JP").
# Pass an empty string to opt out explicitly. If unset, we warn and
# skip the locale override; you may see a translate banner.
if [ -z "${CHROME_LOCALE+set}" ]; then
  echo "launch_chrome: CHROME_LOCALE is unset — skipping Chrome app-locale override." >&2
  echo "  If the target page's language differs from the device default, the" >&2
  echo "  Translate banner may overlay the screen in captures. Set CHROME_LOCALE" >&2
  echo "  (e.g. 'ja-JP') or set it to '' to silence this warning." >&2
elif [ -n "$CHROME_LOCALE" ]; then
  if ! adb -s "$SERIAL" shell cmd locale set-app-locales com.android.chrome \
         --locales "$CHROME_LOCALE" >/dev/null 2>&1; then
    echo "launch_chrome: warning — failed to set Chrome app locale to $CHROME_LOCALE." >&2
    echo "  If the target page's language differs from the device default, the" >&2
    echo "  Translate banner may overlay the screen in captures." >&2
  fi
fi

chrome_start() {
  adb -s "$SERIAL" shell am start -a android.intent.action.VIEW \
    -d "$URL" \
    -n com.android.chrome/com.google.android.apps.chrome.Main >/dev/null
}

# Tap the first node whose resource-id matches the supplied extended
# regex. Restricted to resource-ids (not arbitrary text) to avoid
# clicking matching content on the actual web page. Returns 0 if a tap
# happened, 1 otherwise.
tap_first_id() {
  local regex="$1" dump node bounds nums cx cy
  adb -s "$SERIAL" shell uiautomator dump /sdcard/fre.xml >/dev/null 2>&1 || return 1
  dump=$(adb -s "$SERIAL" shell cat /sdcard/fre.xml 2>/dev/null || true)
  node=$(grep -oE "<node[^>]*resource-id=\"[^\"]*(${regex})[^\"]*\"[^/]*/>" \
         <<<"$dump" | head -1 || true)
  [ -n "$node" ] || return 1
  bounds=$(grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' <<<"$node" | head -1)
  [ -n "$bounds" ] || return 1
  # shellcheck disable=SC2207
  nums=($(grep -oE '[0-9]+' <<<"$bounds"))
  cx=$(( (${nums[0]}+${nums[2]})/2 ))
  cy=$(( (${nums[1]}+${nums[3]})/2 ))
  adb -s "$SERIAL" shell input tap "$cx" "$cy" >/dev/null
  return 0
}

chrome_start

# Best-effort FRE dismissal: repeatedly tap known close-dialog buttons
# until a scan finds nothing to tap. Covers ToS → sign-in →
# notifications, regardless of whether the prompt owns focus or rides
# inside ChromeTabbedActivity.
#
# Priority order:
#   1. terms_accept           — accept ToS (positive, required to proceed)
#   2. signin_fre_dismiss_*   — skip sign-in
#   3. negative_button        — generic modal "No thanks"
#   4. ack_button             — privacy-sandbox "Got it"
#   5. more_button            — privacy-sandbox "More" (reveals ack_button)
for _ in $(seq 1 30); do
  sleep 1.5
  tap_first_id 'terms_accept'              && continue
  tap_first_id 'signin_fre_dismiss_button' && continue
  tap_first_id 'negative_button'           && continue
  tap_first_id 'ack_button'                && continue
  tap_first_id 'more_button'               && continue
  break
done

# Re-issue the VIEW intent in case a first-run dialog ate it.
chrome_start
sleep 3

focus=$(adb -s "$SERIAL" shell dumpsys window 2>/dev/null \
        | awk '/mCurrentFocus/{print; exit}')
case "$focus" in
  *com.android.chrome*firstrun.FirstRunActivity*)
    echo "Chrome still on FirstRunActivity: $focus" >&2
    exit 1 ;;
  *com.android.chrome*) ;;
  *)
    echo "Chrome not in focus: $focus" >&2
    exit 1 ;;
esac
