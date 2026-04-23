#!/usr/bin/env bash
# Scaffold a TUI acceptance check session directory.
#
# Usage:
#   init-session.sh <base-dir> <title>
#
# Example:
#   init-session.sh ~/agents/testing/github-toqoz-sence "esc-interrupt"
#   # Creates: ~/agents/testing/github-toqoz-sence/20260420-esc-interrupt/
#
# Files created:
#   log.md       — per-step action log
#   summary.md   — final result table
#   panes/       — captured pane snapshots

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <base-dir> <title>" >&2
  exit 1
fi

BASE_DIR="$1"
TITLE="$2"
DATE=$(date +%Y%m%d)
SESSION_DIR="${BASE_DIR}/${DATE}-${TITLE}"

mkdir -p "$SESSION_DIR/panes"

cat > "$SESSION_DIR/log.md" << 'TMPL'
# TUI Acceptance Log

| Field | Value |
|---|---|
| Date | |
| Target | |
| Entry point | |
| Scenario | |

## Steps

<!--
Record each step as it happens:

## N. <short title>
- Action: `send-keys "..." Enter` / `sendl "..."` / `run "..."`
- Expected: <pane state / regex>
- Snapshot: panes/NN-<slug>.txt
- Result: **OK** / **FAIL** — <note>
-->
TMPL

cat > "$SESSION_DIR/summary.md" << 'TMPL'
# TUI Acceptance Summary

## Result

| # | Item | Result | Notes |
|---|---|---|---|

## Bugs Found

<!-- List any defects discovered, with repro steps -->

## Follow-ups

TMPL

echo "$SESSION_DIR"
