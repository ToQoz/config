---
name: ci-merge
description: >
  Watch CI on the current branch's PR, auto-fix any failures, get a Codex
  review once CI is green, then merge. Use this skill whenever the user says
  something like "CI が通ったらマージしといて", "wait for CI and merge",
  "CI を待ってマージ", "CI 通ったらレビューしてマージ", or any variant of
  "watch CI / fix CI / then merge". Trigger even if the user omits the Codex
  review step — it is included by default unless explicitly skipped.
---

# ci-merge

Watch CI on the current branch's PR, self-heal any failures, get a Codex
code review once CI is green, and merge.

## Prerequisites

- `gh` CLI authenticated
- `codex` CLI available (used for the review step)
- A PR already exists for the current branch (or will be created by the user
  before you start)

## Arguments

| Flag            | Effect                                          |
|-----------------|-------------------------------------------------|
| `--skip-review` | Merge immediately when CI passes; skip Codex review |
| `--no-delete`   | Keep the branch after merging (default: delete) |

## Workflow

### 1. Locate the PR

```bash
gh pr list --head "$(git branch --show-current)" --json number,url,title
```

If no PR exists, tell the user and stop. Do not create one automatically.

### 2. Watch CI

```bash
gh pr checks <PR_NUMBER> --watch
```

`gh pr checks --watch` blocks until all checks finish and exits non-zero if
any check failed. On success, proceed to step 4. On failure, proceed to step 3.

### 3. Diagnose and fix CI failures (loop)

**3a. Identify the failing run:**

```bash
gh pr checks <PR_NUMBER> --json name,state,detailsUrl
```

Pick the run(s) with `state: FAILURE`. Get the GitHub Actions run ID from the
URL (the number after `/runs/`), then pull the log:

```bash
gh run view <RUN_ID> --log-failed 2>&1 | tail -80
```

**3b. Diagnose.** Read the log carefully. Common causes and quick fixes:

| Symptom in log | Likely cause | Fix |
|---|---|---|
| `Prettier` / `Run Prettier to fix` | Formatter not run | `npx prettier --write '**/*.{js,ts,tsx}'` (or project's format script) |
| `ESLint` errors | Lint violations | `npm run fix` or `npm run lint -- --fix` |
| Type errors (`tsc`) | TypeScript compile error | Read the error, fix the source |
| Test failures | Broken test | Read the test output, fix code or test |
| Dependency missing | Lock file out of sync | Check project's package manager skill |

For formatter/linter issues, prefer running the project's own scripts (e.g.,
`npm run fix`, `npm run format`) over raw tool invocations — they capture the
project's exact configuration.

**3c. Apply the fix**, then commit and push:

```bash
# Stage and commit (use the commit skill if available)
git add <changed files>
git commit -m "style: fix CI — <short description>"
git push
```

**3d. Watch CI again.** Return to step 2. Repeat until CI is green or you
cannot figure out the fix (in that case, surface the log to the user and stop).

**Fix limit:** If you have made 3 fix attempts and CI still fails, stop and
report the remaining failure to the user rather than continuing to loop. Three
failed attempts usually mean the issue is outside the scope of automatic repair
(flaky infrastructure, a test asserting on new behavior, a breaking API change).

### 4. Codex review (unless `--skip-review`)

Once CI is fully green, ask Codex for a code review of the branch diff:

```bash
codex exec review --base <base-branch> --ephemeral
```

Determine the base branch from the PR:

```bash
gh pr view <PR_NUMBER> --json baseRefName --jq '.baseRefName'
```

Read the review output. Apply the following judgment:

- **Blocking issues** (security vulnerability, data loss risk, clear logic bug):
  surface to the user, fix, push, and restart from step 2.
- **Non-blocking suggestions** (style, minor improvements): note them in your
  response to the user but do not block the merge.
- **No issues**: proceed directly to merge.

Do not blindly accept every Codex suggestion. If a suggestion conflicts with
established project patterns (seen in CLAUDE.md or surrounding code), prefer
the project pattern.

### 5. Merge

```bash
gh pr merge <PR_NUMBER> --merge --delete-branch
```

Omit `--delete-branch` if `--no-delete` was passed.

After merging, confirm success to the user with the PR number and title.

## Error handling

- **PR not found**: Stop and tell the user. Do not guess or create a PR.
- **`gh` not authenticated**: Stop and tell the user to run `gh auth login`.
- **`codex` not found**: Skip the review step and note it was skipped.
- **CI still failing after 3 fix attempts**: Report the last failure log and
  stop. Do not merge a failing PR.
- **Codex review finds blocking issue**: Fix it, push, re-enter the CI watch
  loop from step 2.
