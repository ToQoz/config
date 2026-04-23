#!/usr/bin/env bash
# Print a recommended sub-agent count for the parallel exploration
# workflow, based on free RAM. Hard-capped at 8.
#
# Per-emulator budget note (measured 2026-04-22 on a 64 GB M-series Mac
# with 3 read-only clones booted from a fresh snapshot):
#   - Steady-state added pressure on free+inactive: ~0.4 GB / clone
#   - QEMU process RSS reported ~5 GB but most is shared (system image
#     mmap'd across instances, qemu binary)
#   - Boot-time peak transiently larger; concurrent boots stack
# 1 GB / clone is the per-clone budget. The host reservation is half
# the total RAM (rather than a fixed 4 GB) so heavily multitasked
# workstations don't get starved.
#
# Sample outputs:
#    8 GB host →  4    (tight; consider stagger)
#   16 GB host →  8    (cap)
#   24/32/64 GB host →  8 (cap)
#
# Usage: parallelism_hint.sh
# Output: a single integer on stdout (1..8).

set -euo pipefail

GB=1073741824
PER_EMU_GB=1   # matches observed steady-state with margin
HARD_CAP=8

bytes=""
case "$(uname -s)" in
  Darwin) bytes=$(sysctl -n hw.memsize 2>/dev/null) ;;
  Linux)
    kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null)
    [ -n "$kb" ] && bytes=$((kb * 1024))
    ;;
esac

if [ -z "$bytes" ] || [ "$bytes" -le 0 ]; then
  # Detection failed — fall back to a safe default; SKILL.md's manual
  # guideline takes over from here.
  echo 4
  exit 0
fi

total_gb=$((bytes / GB))
budget_gb=$((total_gb / 2))   # half for host, half for emulators
[ "$budget_gb" -lt "$PER_EMU_GB" ] && { echo 1; exit 0; }

n=$((budget_gb / PER_EMU_GB))
[ "$n" -gt "$HARD_CAP" ] && n="$HARD_CAP"
[ "$n" -lt 1 ] && n=1
echo "$n"
