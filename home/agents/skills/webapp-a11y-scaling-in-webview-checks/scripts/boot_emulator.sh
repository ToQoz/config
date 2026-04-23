#!/usr/bin/env bash
# Boot the dedicated Pixel 4a AVD (create it if missing) and print its
# adb serial (e.g. "emulator-5554"). Idempotent — if an emulator for
# this AVD is already attached, its serial is printed without rebooting.
#
# Default mode reuses an existing instance. The flags below opt into
# "fresh parallel instance" mode (consumer skills that use it document
# why; e.g. snapshot-based parallel exploration):
#
#   --port <N>         Boot to a specific adb port (serial = emulator-N).
#                      Required for --read-only so callers can predict
#                      the serial.
#   --snapshot <name>  Boot from the named snapshot (must exist on disk).
#   --read-only        Allow this instance to coexist with other
#                      emulators of the same AVD (each gets its own
#                      ephemeral overlay). Skips reuse detection.
#
# Usage:
#   boot_emulator.sh [AVD_NAME]
#   boot_emulator.sh [AVD_NAME] --port 5556 --snapshot agent-snap-xyz --read-only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sdkenv.sh
source "$SCRIPT_DIR/sdkenv.sh"

AVD_NAME=""
PORT=""
SNAPSHOT=""
READ_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --snapshot) SNAPSHOT="$2"; shift 2 ;;
    --read-only) READ_ONLY=1; shift ;;
    -h|--help) sed -n '1,/^set -/p' "$0" | grep '^#'; exit 0 ;;
    -*) echo "unknown flag: $1" >&2; exit 1 ;;
    *) AVD_NAME="$1"; shift ;;
  esac
done
AVD_NAME="${AVD_NAME:-webapp-a11y-pixel-4a}"

if [ "$READ_ONLY" = 1 ] && [ -z "$PORT" ]; then
  echo "boot_emulator: --read-only requires --port (sub-agent serial must be predictable)" >&2
  exit 1
fi

DEVICE_PROFILE="pixel_4a"
SYSTEM_IMAGE="${ANDROID_SYSTEM_IMAGE:-}"

# --- Create AVD if missing
if ! avdmanager list avd 2>/dev/null | grep -q "Name: ${AVD_NAME}$"; then
  if [ -z "$SYSTEM_IMAGE" ]; then
    cat >&2 <<MSG
boot_emulator: cannot create AVD '$AVD_NAME' — no installed system-image
matching host ABI '${ANDROID_HOST_ABI:-unknown}' was found in
$ANDROID_SDK_ROOT/system-images/. Install one via:
  sdkmanager 'system-images;android-36;google_apis_playstore;${ANDROID_HOST_ABI:-arm64-v8a}'
…or set ANDROID_SYSTEM_IMAGE to override.
MSG
    exit 1
  fi
  echo "Creating AVD: $AVD_NAME ($DEVICE_PROFILE, $SYSTEM_IMAGE)" >&2
  echo no | avdmanager create avd \
    -n "$AVD_NAME" \
    -k "$SYSTEM_IMAGE" \
    -d "$DEVICE_PROFILE" >&2
fi

running_serial_for_avd() {
  local avd="$1" serial name
  for serial in $(adb devices | awk '/emulator-.+\tdevice$/{print $1}'); do
    name=$(adb -s "$serial" emu avd name 2>/dev/null | head -1 | tr -d '\r\n')
    if [ "$name" = "$avd" ]; then
      echo "$serial"
      return 0
    fi
  done
  return 1
}

# Detect a running QEMU emulator process for $AVD that was NOT started
# with -read-only. The Android emulator refuses to launch a -read-only
# clone while a writable instance of the same AVD holds the AVD lock,
# and the resulting error in the emulator log is far from the call
# site. Catching this here lets us print a fix-up command at the call
# site instead.
running_writable_master_pid_for() {
  # Capture-then-filter (no pipe). Avoids `set -o pipefail` flagging the
  # pipeline as failed when awk's early `exit` makes the upstream `ps`
  # die with SIGPIPE (rc=141), which would silently disable preflight.
  local avd="$1" ps_out
  ps_out=$(ps -axo pid,command 2>/dev/null) || true
  awk -v avd="$avd" '
    $0 ~ "qemu-system" && $0 ~ ("-avd "avd"( |$)") && $0 !~ /-read-only/ {
      print $1; exit
    }' <<<"$ps_out"
}

# --- Default mode: reuse if any instance of this AVD is already up
if [ "$READ_ONLY" = 0 ] && [ -z "$PORT" ]; then
  if serial=$(running_serial_for_avd "$AVD_NAME"); then
    echo "$serial"
    exit 0
  fi
fi

# --- Read-only preflight: writable master would block clone boot
if [ "$READ_ONLY" = 1 ]; then
  if writable_pid=$(running_writable_master_pid_for "$AVD_NAME") \
     && [ -n "$writable_pid" ]; then
    master_serial=$(running_serial_for_avd "$AVD_NAME" || true)
    cat >&2 <<MSG
boot_emulator: a writable instance of '$AVD_NAME' is already running
  (qemu pid=$writable_pid${master_serial:+, serial=$master_serial}).
  Read-only clones cannot coexist with a non-read-only master. Either:
    - kill the master first:  adb -s ${master_serial:-<serial>} emu kill
    - or restart the master with --read-only on its own --port
MSG
    exit 1
  fi
fi

# --- Boot
LOG_TAG="$AVD_NAME${PORT:+-p$PORT}"
LOG="/tmp/webapp-a11y-emulator-${LOG_TAG}.log"
EMU_ARGS=( -avd "$AVD_NAME" -no-boot-anim )
[ "$READ_ONLY" = 1 ] && EMU_ARGS+=( -read-only -no-snapshot-save ) \
                      || EMU_ARGS+=( -no-snapshot-save )
[ -n "$PORT" ]      && EMU_ARGS+=( -port "$PORT" )
[ -n "$SNAPSHOT" ]  && EMU_ARGS+=( -snapshot "$SNAPSHOT" )

nohup emulator "${EMU_ARGS[@]}" >"$LOG" 2>&1 &

# --- Wait for ready
expected_serial=""
[ -n "$PORT" ] && expected_serial="emulator-$PORT"

for _ in $(seq 1 120); do
  if [ -n "$expected_serial" ]; then
    serial="$expected_serial"
    state=$(adb -s "$serial" get-state 2>/dev/null | tr -d '\r\n' || true)
    if [ "$state" = "device" ]; then
      bc=$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
      if [ "$bc" = "1" ]; then
        echo "$serial"
        exit 0
      fi
    fi
  else
    if serial=$(running_serial_for_avd "$AVD_NAME"); then
      bc=$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
      if [ "$bc" = "1" ]; then
        echo "$serial"
        exit 0
      fi
    fi
  fi
  sleep 2
done

echo "timeout waiting for emulator boot (see $LOG)" >&2
exit 1
