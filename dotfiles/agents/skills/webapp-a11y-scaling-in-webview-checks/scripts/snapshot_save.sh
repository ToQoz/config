#!/usr/bin/env bash
# Save the running emulator's full state to a named snapshot. The
# emulator pauses briefly while QEMU dumps RAM + disk overlay; resume
# is automatic. Snapshot lives at
# `~/.android/avd/<avd>.avd/snapshots/<name>/`.
#
# Used by the parallel exploration workflow (see SKILL.md): the
# orchestrator saves an `agent-snap-<random>` after onboarding so
# read-only sub-agents can fork from the same authenticated state.
#
# Usage: snapshot_save.sh <serial> <name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sdkenv.sh
source "$SCRIPT_DIR/sdkenv.sh"

SERIAL="${1:?serial required (e.g. emulator-5554)}"
NAME="${2:?snapshot name required}"

# `adb emu` returns 0 even on internal failures — capture the console
# response and grep for "OK" to decide success.
out=$(adb -s "$SERIAL" emu avd snapshot save "$NAME" 2>&1)
if ! grep -q '^OK' <<<"$out"; then
  echo "snapshot_save: emulator console did not return OK: $out" >&2
  exit 1
fi

# Belt-and-braces: confirm the snapshot directory was actually created.
# Locate the AVD via the running emulator's reported avd name.
avd=$(adb -s "$SERIAL" emu avd name 2>/dev/null | head -1 | tr -d '\r\n')
snap_dir="$HOME/.android/avd/${avd}.avd/snapshots/${NAME}"
if [ ! -d "$snap_dir" ]; then
  echo "snapshot_save: console said OK but $snap_dir is missing" >&2
  exit 1
fi
echo "saved snapshot: $NAME (on $SERIAL, fs=$snap_dir)"
