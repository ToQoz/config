---
name: release-pr
description: Create a release PR between two branches, wait for CI, run Codex review, and append the review result to the PR description. Use this skill whenever the user says /release-pr or wants to open a release pull request from one branch to another.
---

# release-pr

Create a release PR using the `release-pr` script, wait for CI to pass, run a Codex review, and append the review as `## Agent Review` at the end of the PR description.

Usage:

```
/release-pr [env]
```

**SKILL Bundled Scripts**: `./scripts/create-release-pr <base branch> <head branch>`

| Argument | Description |
|---|---|
| `base branch` | The target branch (e.g. `main`, `production`) |
| `head branch` | The source branch being merged (e.g. `develop`, `feature/x`) |

## Branch Resolution

When `env` is provided, use it to determine the base and head branches according to the project's branching convention.

When `env` is **omitted**, resolve the branch pair interactively:

### Step 1 — Fetch and list remote branches

```bash
git fetch origin
git branch -r --list 'origin/*' --sort=-committerdate | sed 's|origin/||' | grep -vE 'HEAD|dependabot/|renovate/'
```

### Step 2 — Detect the branching model

Normalize remote branch names using this alias table:

| Canonical | Matches |
|---|---|
| `main` | `main`, `master` |
| `develop` | `develop`, `development` |
| `dev` | `dev` |
| `staging` | `staging`, `stg` |
| `production` | `production`, `prod` |

Use the **first matching** model below (ordered by specificity):

#### GitLab Flow (environment promotion from main)

**Condition:** `main` exists AND at least two of {`dev`, `staging`, `production`} exist.

Promotion chain (skip any missing link): `main` → `dev` → `staging` → `production`

Example pairs: `main` → `dev`, `dev` → `staging`, `staging` → `production`

#### Environment promotion (without main as source)

**Condition:** `develop` exists AND at least one of {`staging`, `production`} exists.

Promotion chain (skip any missing link): `develop` → `staging` → `production`

#### Git Flow

**Condition:** `main` exists AND (`develop` or `dev`) exists AND none of {`staging`, `production`} exist as separate environment branches.

Promotion chain: `develop` (or `dev`) → `main`

#### Fallback

No pattern matched — skip to step 4.

**Important:** When generating pairs from the matched chain, always use the **actual remote branch name** (e.g. `stg` not `staging`) in all git commands and PR creation.

### Step 3 — Present candidates

From the matched chain, generate candidate pairs for adjacent branches. A valid pair `(head → base)` must satisfy:
- Both branches exist on the remote.
- `head` has commits ahead of `base` (`git rev-list --count origin/<base>..origin/<head>` > 0).

Present valid candidates with commit counts:

```
Release PR の対象ブランチを選んでください:

1. main → dev (3 commits ahead)
2. dev → stg (7 commits ahead)
```

### Step 4 — Manual fallback

If no valid candidate pairs are found, list all remote branches and ask the user to specify `<base>` and `<head>` manually.

Proceed to the workflow below once the base and head branches are determined.

## Workflow

### 1. Create the PR

Run the bundled script to create the PR:

```bash
pr="$(./scripts/create-release-pr <base> <head>)"
pr_number="$(echo "$pr" | jq -r '.number')"
pr_url="$(echo "$pr" | jq -r '.url')"
```

The script outputs JSON with `number` and `url`. The title follows the format `Main Release 2025/06/01` and the body lists merge commits between the two branches.

### 2. Wait for CI

Watch CI checks until they reach a terminal state:

```bash
gh pr checks <PR_NUMBER> --watch
```

- Terminal-passing states: `SUCCESS`, `SKIPPED`, `NEUTRAL`
- Terminal-failing states: `FAILURE`, `ERROR`, `CANCELLED`, `TIMED_OUT`

If checks are unavailable or still pending after a long time, inspect PR status directly:

```bash
gh pr view <PR_NUMBER> --json mergeStateStatus,statusCheckRollup
```

Do not proceed to review until CI reaches a terminal state. If CI fails, report the failure summary and stop — this skill does not auto-fix CI.

### 3. Run Codex Review

After CI passes, run a Codex code review against the base branch:

```bash
codex exec review --base <base> --ephemeral --sandbox read-only
```

Capture the full review output. If `codex` is unavailable, note that review was skipped and stop.

### 4. Append Review to PR Description

Fetch the current PR body and append the Codex review as a new section:

```bash
CURRENT_BODY="$(gh pr view <PR_NUMBER> --json body --jq '.body')"
```

Then update the PR body with the review appended:

```bash
gh pr edit <PR_NUMBER> --body "$(printf '%s\n\n## Agent Review\n\n%s' "$CURRENT_BODY" "<codex review output>")"
```

**Language:** Match the language of the PR body. The `release-pr` script writes the PR body in the repository's convention — use the same language for the `## Agent Review` section. If the body is in Japanese, write the section header and any framing text in Japanese. The Codex output itself can be quoted as-is.

### 5. Open and Report

Open the PR in the browser:

```bash
gh pr view --web <PR_NUMBER>
```

Report the PR URL, CI status, and a brief summary of the Codex review findings.

## Stop Conditions

- `release-pr` script is not found or exits with an error
- PR creation fails (e.g. PR already exists for this head/base pair)
- CI fails — report failure, do not proceed to review
- `codex` CLI is unavailable
