---
name: git-worktrees
description: Use when starting work that should not disturb the current workspace — typical situations include the current tree being dirty when an unrelated task arrives, being on the default branch and about to commit, wanting to run a long build or test in parallel, or isolating a risky experiment. Wraps `git-wt` (k1LoW/git-wt) with policy: `.git/wt/<branch>` placement, base-branch detection, fetch-before-branch, JS project setup, baseline verification, and merged-worktree sweep via `git-wt-prune`. Trigger phrases include "create a worktree", "branch off into a separate workspace", "try on a separate branch", "scratch copy", "parallel workspace", "spin up a sandbox branch", "list worktrees", "clean up merged worktrees".
---

# Git Worktrees

This skill orchestrates `git-wt` (k1LoW/git-wt) plus a custom `git-wt-prune` sweep tool. `git-wt` is the underlying primitive; this skill adds the policy layer (when to worktree, branch/base selection, fetch, JS setup, baseline verification, safe cleanup).

## Prerequisites

- `git-wt` is installed (Home Manager `home.packages`).
- `git config wt.basedir` is set globally to `{gitroot}/.git/wt` so all worktrees land inside `.git/`.
- `git-wt-prune` is on `PATH` (installed via this repo's `scripts/`).

If `wt.basedir` is unset in this repo, set it before proceeding:

```bash
git config --global wt.basedir '{gitroot}/.git/wt'
```

## Why `.git/wt/`

- **Inside the workspace.** Agents whose cwd is fixed to the project can reach it.
- **Inside `.git/`.** Automatically untracked (no `.gitignore` upkeep) and **invisible to greps over the working tree** — agents won't accidentally pull worktree contents into context.
- **`wt/`.** Avoids collision with git's own `.git/worktrees/` metadata directory.

> ⚠️ **Risk:** anything that wipes `.git/` also wipes the worktrees. Be wary of `rm -rf .git`, onboarding scripts that re-`git init`, and tools that "reset the repository" by deleting `.git/`. Treat `.git/wt/` as durable working state, not as cache.

## When to Use

- Current tree is dirty and an unrelated task arrives that should not touch it.
- On the default branch and about to commit (the `commit` Branch Guard refuses this).
- A long-running build, test, or migration should run in parallel with foreground work.
- A risky experiment (mass refactor, dependency upgrade trial, schema migration) should be isolated.

## When NOT to Use

- Already on the right topic branch with a clean tree — just work in place.
- The Agent tool was invoked with `isolation: "worktree"` — it manages its own ephemeral worktree.
- A single trivial edit where setup cost dominates.

## Create — Workflow

All git inspection commands use `git -C <worktree-path>` so they remain correct even when the Bash tool's cwd does not persist between calls.

### 1. Determine branch name

Use the user-provided branch name. Otherwise derive a short kebab-case name from the task (e.g. `fix-token-validation`, `try-otel-upgrade`). Do not invent a name silently when the user expressed a specific intent — ask.

### 2. Determine base branch

Try in order:

```bash
# 1. GitHub remote (most authoritative)
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null

# 2. Git's own symbolic ref for origin/HEAD
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@'

# 3. Heuristic — try main, then master
git show-ref --verify --quiet refs/heads/main && echo main \
  || (git show-ref --verify --quiet refs/heads/master && echo master)
```

Override only when the user specifies a different base.

### 3. Refresh the base

```bash
git fetch origin "$base_branch"
```

If the fetch fails (offline, auth prompt, missing remote), warn the user and fall back to the local `refs/heads/<base>`. Do not retry blindly.

When fetch succeeds, branch off `origin/<base>` rather than the local ref to avoid stale-base accidents:

```bash
base_ref="origin/$base_branch"   # if fetch succeeded
base_ref="$base_branch"          # fallback after a failed fetch
```

### 4. Pre-flight: existing worktree for the same branch

```bash
git wt --json | jq -r --arg b "$branch_name" '.[] | select(.branch == "refs/heads/"+$b) | .path'
```

If the branch already has a worktree at `<existing_path>`:

- Run `git -C <existing_path> status --porcelain`. If empty, **reuse**: report the path and skip steps 5–7. Verify `git -C <existing_path> rev-parse --abbrev-ref @{u} 2>/dev/null` matches the expected upstream if you need base alignment.
- If non-empty, **stop** and report. Ask the user whether to reuse anyway, remove and recreate, or pick a different branch name.

Never silently create a second worktree for the same branch.

### 5. Create the worktree

```bash
# --nocd makes git-wt non-interactive: it prints the resulting path and
# does not attempt to change directory (which has no effect outside a
# wrapped shell anyway).
worktree_path=$(git wt --nocd "$branch_name" "$base_ref")
```

`wt.basedir = {gitroot}/.git/wt` ensures the worktree lands at `<repo>/.git/wt/<branch>`. If the branch already exists locally but is unused (rare; usually caught at step 4), the same command will check it out instead of creating it.

### 6. Initialize submodules (if any)

```bash
if [ -f "$worktree_path/.gitmodules" ]; then
  git -C "$worktree_path" submodule update --init --recursive
fi
```

### 7. Run project setup

**JavaScript only for now.** Other ecosystems will be added when there is a concrete need.

#### JavaScript / TypeScript (Node.js)

If `package.json` exists at the worktree root:

1. Invoke the `nodejs-package-manager` skill to determine the package manager. Treat its return value as the **single source of truth** — do not fall back to `npm` by guess.
2. Install dependencies using that package manager.
3. Check `package.json` `scripts` for a `test` entry. If present, run it using that package manager. If absent, skip the test step and note it.

The install + test idiom is common knowledge per package manager (pnpm, yarn, npm, bun) — do not hard-code the command shape here.

#### Other ecosystems

No language-specific setup is performed for non-JS projects in v1. Report explicitly:

> No language-specific setup performed (this skill only handles JavaScript projects). If your project needs install/test before work begins, run them manually.

Do not silently skip.

### 8. Verify clean baseline

```bash
git -C "$worktree_path" status --short
```

The output should be empty. Anything present indicates submodule trouble or unexpected generated files — investigate before proceeding.

If JS tests were run and failed, surface the failures and ask whether to investigate or proceed. Failing tests on a fresh worktree usually mean the base itself is broken, not the new work.

### 9. Report

```
Worktree ready
  Branch: feature/auth-refresh
  Path:   /Users/me/proj/.git/wt/feature/auth-refresh
  Base:   origin/main (fetched)
  Setup:  pnpm install (157 packages), pnpm test (47 passed)
```

The user (or downstream skills) will use the path with `cd` or `git -C`.

## List / Inspect

`git-wt` handles this directly:

```bash
git wt              # human-readable list
git wt --json       # machine-readable, suitable for scripts
```

The skill itself does not wrap these — call `git wt` directly when discovery is needed.

## Remove (Single)

```bash
# 1. Confirm clean.
git -C "$worktree_path" status --porcelain
# Output must be empty. If non-empty, stop and ask.

# 2. Remove via git-wt (default-branch protection is built-in).
git wt -d "$branch_name"

# 3. Optionally delete the local branch.
git branch -d "$branch_name"   # -D only with explicit user consent
```

Use `git wt -D` (force) only when the user explicitly approves discarding uncommitted changes.

## Sweep Merged Worktrees

Use `git-wt-prune`:

```bash
git-wt-prune                 # dry-run (default): list candidates, do not remove
git-wt-prune --yes           # remove candidates; dirty worktrees are always skipped
git-wt-prune --base develop  # use a non-default base for merged-detection
```

Workflow:

1. Run `git-wt-prune` (dry-run) and show the user the candidate list.
2. After explicit user consent, run `git-wt-prune --yes`.
3. Report what was removed and what was skipped (and why — "dirty" or other).

Dirty worktrees are never removed automatically, even with `--yes`. The user must clean them up or remove them manually.

## Hooks and File Copy (Not Used)

`git-wt` supports `wt.hook`, `wt.deletehook`, and `wt.copy*` for human-driven workflows. **This skill does not configure them.** Reasons:

- Hooks run unconditionally on every `git wt` invocation, polluting agent flows.
- `wt.copy*` (e.g. copying `.env`) is project-specific and creates implicit side effects.
- The skill needs to invoke other skills (e.g. `nodejs-package-manager`), which shell hooks cannot do.

If you set these manually for human-driven `git wt` usage, expect the skill to ignore or work around them.

## Red Flags

- Creating a worktree when the user wanted to switch branches in place.
- Creating a second worktree for a branch that already has one (skip step 4).
- Forcing removal without confirming `git status --porcelain` is empty.
- Hard-coding `npm install` after `nodejs-package-manager` returned a different tool.
- Silently skipping setup for non-JS projects instead of reporting it.
- Branching off the local base after a `git fetch` failure without warning the user.
- Running `git-wt-prune --yes` without first showing the dry-run output to the user.

## Quick Reference

| Situation                              | Action                                                                 |
|----------------------------------------|------------------------------------------------------------------------|
| Branch name unspecified                | Derive a short kebab-case name; ask if intent is unclear               |
| Base branch unspecified                | Try `gh repo view` → `git symbolic-ref` → `main`/`master`              |
| Fetch failed                           | Warn, fall back to local base ref                                      |
| Same branch already has a worktree     | Reuse if clean & base matches; otherwise stop and ask                  |
| Creating                               | `git wt --nocd <name> <base_ref>` (path comes from `wt.basedir`)       |
| `.gitmodules` present                  | `git -C <path> submodule update --init --recursive`                    |
| `package.json` present                 | `nodejs-package-manager` → install → run `test` script (if defined)    |
| Non-JS project                         | Report "No language-specific setup performed"                          |
| Tests fail on baseline                 | Surface failures, ask before proceeding                                |
| List worktrees                         | `git wt` (or `git wt --json` for scripting)                            |
| Remove single                          | Verify clean → `git wt -d <branch>`                                    |
| Sweep merged                           | `git-wt-prune` (dry-run) → user consent → `git-wt-prune --yes`         |
