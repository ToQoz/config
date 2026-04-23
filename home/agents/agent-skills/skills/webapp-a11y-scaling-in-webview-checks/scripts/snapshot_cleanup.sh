#!/usr/bin/env bash
# Delete a saved emulator snapshot. Used at the end of the parallel
# exploration workflow, ideally from a `trap` so leftovers don't
# accumulate when the orchestrator dies mid-run.
#
# Two-step fallback:
#   1. If a serial is given AND that emulator is up, ask it via
#      `adb emu avd snapshot delete` (clean, lets QEMU release locks).
#   2. Otherwise nuke the snapshot directory directly under
#      `~/.android/avd/<avd>.avd/snapshots/<name>`.
#
# Usage:
#   snapshot_cleanup.sh <avd> <name>             # fs-only delete
#   snapshot_cleanup.sh <avd> <name> <serial>    # try adb first

set -euo pipefail

AVD="${1:?avd name required}"
NAME="${2:?snapshot name required}"
SERIAL="${3:-}"

if [ -n "$SERIAL" ] && adb -s "$SERIAL" get-state >/dev/null 2>&1; then
  out=$(adb -s "$SERIAL" emu avd snapshot delete "$NAME" 2>&1) || true
  if grep -q '^OK' <<<"$out"; then
    echo "deleted snapshot via adb: $NAME"
    exit 0
  fi
  echo "snapshot_cleanup: adb path failed ($out), falling back to fs delete" >&2
fi

DIR="$HOME/.android/avd/${AVD}.avd/snapshots/${NAME}"
if [ -d "$DIR" ]; then
  rm -rf "$DIR"
  echo "deleted snapshot via fs: $DIR"
else
  echo "snapshot_cleanup: no snapshot named $NAME for AVD $AVD (already gone?)" >&2
fi
