# Session Harness Templates

All paths are under `.session-harness/<task-slug>/`.

## harness.env

```bash
REPO_ROOT="<absolute path to repo>"
TASK_SLUG="<task-slug>"

# Mode: one-shot | verify-only | bounded-loop
MODE="bounded-loop"

# bounded-loop settings
# 1-2 for trivial edits, 3 for normal, 4-5 only with fast checks + narrow scope
MAX_ITERATIONS=3

# Agent settings
# IMPORTANT: Restrict to minimum needed. Broad Bash is a blast-radius multiplier.
AGENT_ALLOWED_TOOLS="Read,Edit,Write,Glob,Grep,Bash(make:*),Bash(git diff:*),Bash(git status:*)"
AGENT_PERMISSION_MODE="acceptEdits"
AGENT_MAX_TURNS=30
```

## prompt.md

```markdown
# Task: <one-sentence description>

## Goal
<what needs to be done and why>

## Context
<key files, patterns to follow, relevant architecture>

## Requirements
<specific constraints, patterns to mirror, files to touch>

## Done criteria
<what "done" means — should match verifier.sh checks>
- [ ] <criterion 1>
- [ ] <criterion 2>

When you believe you are done, stop.
```

## failure-modes.md

```markdown
# Failure Modes

| # | Failure mode | Manifestation | Detection | Type | Existing tooling? |
|---|---|---|---|---|---|
| 1 | <specific failure> | <observable symptom> | <check command or procedure> | automated/manual | tsc/lint/no |
```

## verifier.sh

```bash
#!/usr/bin/env bash
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(jq -r '.repo_root' "$HARNESS_DIR/manifest.json")"
cd "$REPO_ROOT" || exit 1

results=()
overall="pass"

json_string() { jq -Rs .; }

check() {
  local name="$1"; shift
  local tmp
  tmp="$(mktemp)"
  if "$@" >"$tmp" 2>&1; then
    results+=("{\"check\":$(printf '%s' "$name" | json_string),\"status\":\"pass\"}")
  else
    results+=("{\"check\":$(printf '%s' "$name" | json_string),\"status\":\"fail\",\"evidence\":$(json_string <"$tmp")}")
    overall="fail"
  fi
  rm -f "$tmp"
}

# ── Layer 1: Project-native checks ────────────────────────────
# Uncomment and adapt. These are the highest-signal checks.

# check "typecheck" bash -lc 'make tsc'
# check "lint" bash -lc 'make lint'
# check "tests" bash -lc 'make test'
# check "generation fresh" bash -lc 'make gen && git diff --exit-code gen/'

# ── Layer 2: Reusable project patterns ────────────────────────
# Import from references/patterns/ if available.
# Examples:

# check "migration roundtrip" bash -lc 'make db/mig/down TO=<prev> && make db/mig/up'
# check "no console.log" bash -lc '! grep -r "console\.log" apps/api/services/'

# ── Layer 3: Task-specific probes ─────────────────────────────
# Generated for this task. This is where the LLM adds value.
# Examples:

# check "domain field exists" bash -lc 'grep -q "newField" apps/api/domain/entity.ts'
# check "proto rpc exists" bash -lc 'grep -q "NewRpc" gen/proto/services/v1/service_pb.ts'
# check "guard in layout" bash -lc 'grep -q "NewGuard" apps/web/app/layout.tsx'
# check "admin display" bash -lc 'grep -q "newField" apps/web/app/admin/detail.tsx'

# ── Output ────────────────────────────────────────────────────
printf '{"status":"%s","checks":[%s]}\n' "$overall" "$(IFS=,; echo "${results[*]}")"
[[ "$overall" == "pass" ]]
```

## verifier.md

```markdown
# Manual Verification Checklist

## Unverified risks
These failure modes are NOT mechanically verified by verifier.sh:
- <risk 1 — why it can't be scripted>
- <risk 2>

## Manual checks
1. [ ] <check requiring human judgment>
2. [ ] <check requiring a running browser>
```

## manifest.json

```json
{
  "task_slug": "<task-slug>",
  "repo_root": "<absolute path>",
  "created_at": "YYYY-MM-DDTHH:MM:SSZ",
  "status": "created"
}
```

## .gitignore

```gitignore
state/
*.tmp
*.secret
```
