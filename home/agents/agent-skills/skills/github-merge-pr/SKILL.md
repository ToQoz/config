---
name: github-merge-pr
description: Watch CI, fix failures, review, and merge the current branch's PR.
---

# github-merge-pr

Watch the current branch's PR, self-heal CI failures, review the final diff,
and merge only when the PR is safe to merge.

## Prerequisites

- The user explicitly requested this skill (do not invoke autonomously)
- `gh` CLI authenticated
- A PR exists for the current branch
- `codex` CLI available for review, unless `--skip-review` is passed

## Arguments

| Flag | Effect |
|---|---|
| `--skip-review` | Skip Codex review after CI passes |
| `--no-delete` | Keep the branch after merge |
| `--merge` | Use a merge commit |
| `--squash` | Squash merge |
| `--rebase` | Rebase merge |

Default merge strategy: use the repository's preferred/default strategy when
clear from project conventions; otherwise use `--merge`. If multiple strategy
flags are passed, stop and ask the user to choose one.

## Workflow

### 1. Preflight

Check the branch and worktree:

```bash
git branch --show-current
git status --short
```

Do not overwrite unrelated user changes. If the worktree has unrelated
uncommitted changes, stop and ask before modifying files.

Locate the PR:

```bash
gh pr list --head "$(git branch --show-current)" --json number,url,title,state,isDraft,baseRefName,headRefName
```

Stop if no PR is found, more than one PR is found, the PR is closed, or the PR
is draft. If the PR is already merged, report that and stop.

### 2. Wait For CI

```bash
gh pr checks <PR_NUMBER> --watch
```

Treat `SUCCESS`, `SKIPPED`, and `NEUTRAL` as non-failing terminal states.
Treat `FAILURE`, `ERROR`, `CANCELLED`, `TIMED_OUT`, and action-required states
as failures.

If required checks are missing or GitHub reports checks are unavailable, inspect
the PR status with:

```bash
gh pr view <PR_NUMBER> --json mergeStateStatus,statusCheckRollup
```

Do not merge until required checks are green or the repository clearly has no
required checks.

### 3. Fix CI Failures

For each failed attempt, identify failing checks:

```bash
gh pr checks <PR_NUMBER> --json name,state,detailsUrl
```

For GitHub Actions failures, extract the run ID from `detailsUrl` and inspect:

```bash
gh run view <RUN_ID> --log-failed
```

Fix the smallest clear cause. Prefer project scripts over raw tools, for
example `npm run format`, `npm run lint -- --fix`, `npm test`, or the local
equivalent. For type or test failures, read the relevant source and fix the
actual issue.

After each fix:

```bash
git status --short
git add <changed files>
git commit -m "<type>: fix CI failure"
git push
```

Return to CI waiting. Stop after 3 failed fix attempts and report the latest
failure summary. Never merge a failing PR.

### 4. Review

Unless `--skip-review` was passed, run Codex review after CI is green:

```bash
BASE_BRANCH="$(gh pr view <PR_NUMBER> --json baseRefName --jq '.baseRefName')"
codex exec review --base "$BASE_BRANCH" --ephemeral --sandbox read-only
```

If `codex` is unavailable, report that review was skipped and continue only if
the user did not explicitly require review.

Handle review results:

- Blocking issue: fix it, commit, push, and return to CI waiting.
- Non-blocking suggestion: note it, but do not block merge.
- No issue: continue.

Use judgment. Do not apply suggestions that conflict with established project
patterns.

### 5. Merge

Refresh PR state before merging:

```bash
gh pr view <PR_NUMBER> --json state,isDraft,mergeStateStatus,baseRefName,title
gh pr checks <PR_NUMBER>
```

Stop if the PR became closed, draft, blocked, conflicted, or failing.

Merge with the selected strategy:

```bash
gh pr merge <PR_NUMBER> --merge --delete-branch
```

Use `--squash` or `--rebase` instead when selected. Omit `--delete-branch` when
`--no-delete` was passed.

After merging, report the PR number, title, merge strategy, and whether the
branch was deleted.

## Stop Conditions

- PR not found, ambiguous, closed, draft, or already merged
- `gh` is missing or unauthenticated
- Worktree has unrelated uncommitted changes
- CI remains failing after 3 fix attempts
- Required checks are missing, pending too long, or cannot be verified
- Merge is blocked by conflicts, branch protection, reviews, or permissions
- Codex review finds a blocking issue that cannot be fixed safely
