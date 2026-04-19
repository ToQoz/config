#!/usr/bin/env bash
# Initialize a verification session directory with required artifact files.
#
# Usage:
#   init-session.sh <base-dir> <title>
#
# Example:
#   init-session.sh ~/agents/verification/github-acme-app "user-login-handler"
#   # Creates: ~/agents/verification/github-acme-app/20260419-user-login-handler/
#
# Creates the directory and empty artifact files:
#   session.md, steps.md, events.jsonl, summary.md, screenshots/

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <base-dir> <title>" >&2
  exit 1
fi

BASE_DIR="$1"
TITLE="$2"
DATE=$(date +%Y%m%d)
SESSION_DIR="${BASE_DIR}/${DATE}-${TITLE}"

mkdir -p "$SESSION_DIR/screenshots"

# session.md — agent fills in target, scenario, envelope, breakpoints
cat > "$SESSION_DIR/session.md" << 'TMPL'
# Verification Session

| Field | Value |
|---|---|
| Date | |
| Target | |
| Entry point | |
| Trigger | |
| Type | CLI / WebApp |

## Verification Envelope

<!-- List the files and line ranges in scope -->

## Breakpoints

<!-- List each breakpoint with its reason -->

| # | File:Line | Reason |
|---|---|---|
TMPL

# steps.md — per-line verification log
cat > "$SESSION_DIR/steps.md" << 'TMPL'
# Step-Through Log

| Step | File:Line | Code | Expected | Actual | Match | Artifact |
|---|---|---|---|---|---|---|
TMPL

# events.jsonl — machine-readable, one JSON object per line
touch "$SESSION_DIR/events.jsonl"

# summary.md — filled at end
cat > "$SESSION_DIR/summary.md" << 'TMPL'
# Verification Summary

## Result

- [ ] All steps matched expectations
- [ ] Discrepancies found (see below)

## Discrepancies

<!-- List any expected vs actual mismatches -->

## Confidence

## Follow-ups

TMPL

echo "$SESSION_DIR"
