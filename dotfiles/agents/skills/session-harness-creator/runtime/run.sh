#!/usr/bin/env bash
set -uo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Session Harness Runtime v1
#
# This is a STABLE script — not generated per task.
# Task-specific content lives in harness.env, prompt.md, and verifier.sh.
#
# Usage: bash .session-harness/<task>/run.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Load config ───────────────────────────────────────────────
if [[ ! -f "$HARNESS_DIR/harness.env" ]]; then
  echo "ERROR: $HARNESS_DIR/harness.env not found" >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$HARNESS_DIR/harness.env"

# Defaults
: "${REPO_ROOT:?REPO_ROOT must be set in harness.env}"
: "${TASK_SLUG:?TASK_SLUG must be set in harness.env}"
: "${MODE:=bounded-loop}"
: "${MAX_ITERATIONS:=3}"
: "${AGENT_ALLOWED_TOOLS:=Read,Edit,Write,Glob,Grep}"
: "${AGENT_PERMISSION_MODE:=acceptEdits}"
: "${AGENT_MAX_TURNS:=30}"

cd "$REPO_ROOT" || exit 1
mkdir -p "$HARNESS_DIR/state"

# ── Logging ───────────────────────────────────────────────────
log() {
  printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "$HARNESS_DIR/state/transcript.log"
}

# ── Verification ──────────────────────────────────────────────
run_verifier() {
  if [[ ! -f "$HARNESS_DIR/verifier.sh" ]]; then
    echo '{"status":"skip","checks":[]}'
    return 0
  fi
  bash "$HARNESS_DIR/verifier.sh" 2>&1
}

verifier_status() {
  echo "$1" | tail -1 | jq -r '.status' 2>/dev/null || echo "unknown"
}

verifier_fail_signature() {
  echo "$1" | tail -1 | jq -r '[.checks[] | select(.status == "fail") | .check] | sort | join(",")' 2>/dev/null || echo "unknown"
}

verifier_fail_summary() {
  echo "$1" | tail -1 | jq -r '.checks[] | select(.status == "fail") | "FAIL: \(.check)\n  Evidence: \(.evidence // "none" | .[0:500])"' 2>/dev/null || echo "$1"
}

# ── Agent invocation ──────────────────────────────────────────
run_agent() {
  local prompt="$1"
  local flags=(
    --print
    --allowedTools "$AGENT_ALLOWED_TOOLS"
    --permission-mode "$AGENT_PERMISSION_MODE"
    --max-turns "$AGENT_MAX_TURNS"
  )

  claude "${flags[@]}" "$prompt" 2>&1
  return $?
}

# ── Manifest update ───────────────────────────────────────────
set_status() {
  local status="$1"
  if command -v jq &>/dev/null && [[ -f "$HARNESS_DIR/manifest.json" ]]; then
    jq --arg s "$status" '.status = $s' "$HARNESS_DIR/manifest.json" \
      > "$HARNESS_DIR/manifest.json.tmp" \
      && mv "$HARNESS_DIR/manifest.json.tmp" "$HARNESS_DIR/manifest.json"
  fi
}

# ── Retro generation ──────────────────────────────────────────
write_retro() {
  local final_status="$1"
  local iterations="$2"
  cat > "$HARNESS_DIR/retro.md" <<RETRO
## Summary
Task: $TASK_SLUG
Mode: $MODE
Status: $final_status
Iterations: $iterations

## Harness Effectiveness
- verifier.sh present: $([ -f "$HARNESS_DIR/verifier.sh" ] && echo yes || echo no)
- Mode used: $MODE
- Iterations needed: $iterations
- Review state/ directory for per-iteration logs and verifier outputs

## Notes
- (fill in after reviewing results)
RETRO
}

# ── Prompt loading ────────────────────────────────────────────
TASK_PROMPT="$(cat "$HARNESS_DIR/prompt.md" 2>/dev/null || echo "ERROR: prompt.md not found")"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Mode dispatch
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

case "$MODE" in

# ── one-shot ──────────────────────────────────────────────────
one-shot)
  log "Mode: one-shot"
  log "Running agent..."
  run_agent "$TASK_PROMPT" > "$HARNESS_DIR/state/agent-1.log" 2>&1
  agent_exit=$?

  if (( agent_exit != 0 )); then
    log "Agent exited with code $agent_exit"
    set_status "failed"
    write_retro "failed" 1
    exit 1
  fi

  log "Running verifier..."
  VOUT=$(run_verifier)
  echo "$VOUT" > "$HARNESS_DIR/state/verifier-1.json"
  VSTATUS=$(verifier_status "$VOUT")
  log "Verifier: $VSTATUS"

  if [[ "$VSTATUS" == "pass" || "$VSTATUS" == "skip" ]]; then
    set_status "verified"
    write_retro "verified" 1
    log "Done (one-shot)"
    exit 0
  else
    set_status "failed"
    write_retro "failed" 1
    log "Verifier failed. Check state/verifier-1.json"
    exit 1
  fi
  ;;

# ── verify-only ───────────────────────────────────────────────
verify-only)
  log "Mode: verify-only (no agent invocation)"
  log "Running verifier..."
  VOUT=$(run_verifier)
  echo "$VOUT" > "$HARNESS_DIR/state/verifier-1.json"
  VSTATUS=$(verifier_status "$VOUT")
  log "Verifier: $VSTATUS"

  if [[ "$VSTATUS" == "pass" ]]; then
    set_status "verified"
    write_retro "verified" 0
  else
    set_status "failed"
    write_retro "failed" 0
  fi
  log "Review verifier.md for manual checks"
  exit 0
  ;;

# ── bounded-loop ──────────────────────────────────────────────
bounded-loop)
  log "Mode: bounded-loop (max $MAX_ITERATIONS iterations)"
  PREV_FAIL_SIG=""
  iteration=0

  while (( iteration < MAX_ITERATIONS )); do
    iteration=$((iteration + 1))
    log "── Iteration $iteration/$MAX_ITERATIONS ──"

    # Build prompt
    if (( iteration == 1 )); then
      PROMPT="$TASK_PROMPT"
    else
      DIFF_STAT=$(git diff --stat 2>/dev/null | tail -5)
      FAILED=$(verifier_fail_summary "$VOUT")
      PROMPT="## Task (reminder)
$(cat "$HARNESS_DIR/prompt.md")

## Current state
Files changed:
$DIFF_STAT

## Verifier failures (iteration $((iteration - 1)))
$FAILED

Fix the failing checks above. Do not modify verifier.sh unless a check is
demonstrably wrong. When done, stop."
    fi

    # Run agent
    log "Running agent..."
    run_agent "$PROMPT" > "$HARNESS_DIR/state/agent-$iteration.log" 2>&1
    agent_exit=$?

    if (( agent_exit != 0 )); then
      log "Agent exited with code $agent_exit — stopping"
      set_status "failed"
      write_retro "failed (agent error)" "$iteration"
      exit 1
    fi

    # Run verifier
    log "Running verifier..."
    VOUT=$(run_verifier)
    echo "$VOUT" > "$HARNESS_DIR/state/verifier-$iteration.json"
    VSTATUS=$(verifier_status "$VOUT")
    log "Verifier: $VSTATUS"

    if [[ "$VSTATUS" == "pass" || "$VSTATUS" == "skip" ]]; then
      log "All checks passed on iteration $iteration"
      set_status "verified"
      write_retro "verified" "$iteration"
      exit 0
    fi

    # Convergence detection
    FAIL_SIG=$(verifier_fail_signature "$VOUT")
    if [[ "$FAIL_SIG" == "$PREV_FAIL_SIG" && -n "$FAIL_SIG" ]]; then
      log "Same failures repeating ($FAIL_SIG) — non-convergent, stopping"
      set_status "failed"
      write_retro "failed (non-convergent)" "$iteration"
      exit 1
    fi
    PREV_FAIL_SIG="$FAIL_SIG"

    # No-diff detection
    if [[ -z "$(git diff --name-only 2>/dev/null)" && iteration -gt 1 ]]; then
      log "No files changed — agent may be stuck, stopping"
      set_status "failed"
      write_retro "failed (no changes)" "$iteration"
      exit 1
    fi

    log "Feeding back failures..."
  done

  log "Max iterations ($MAX_ITERATIONS) reached"
  set_status "failed"
  write_retro "failed (max iterations)" "$MAX_ITERATIONS"
  exit 1
  ;;

*)
  echo "ERROR: Unknown MODE=$MODE in harness.env (expected: one-shot, verify-only, bounded-loop)" >&2
  exit 1
  ;;
esac
