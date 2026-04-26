---
name: fork-session
description: Fork a fresh `claude` session into a new git worktree to handle a side task that branches off the main thread — the parent agent does not await the result, the new session runs independently in a tmux split pane with its launch command pre-filled (user confirms before it starts). Use when a side concern arises during the main task and should be handled separately rather than interrupting the current flow, or when the user explicitly asks for a separate claude session. Distinct from the Agent tool's `isolation: "worktree"` (which spawns a synchronous subagent the parent integrates) — this skill is for asynchronous, human-coordinated detours. Trigger phrases include "fork off X to a separate session", "have another claude do Y while I continue", "branch off into a separate claude", "let me park this and start a new session for X", "sidetrack into a fresh claude for Y", "sandbox session for X".
---

# Fork Session

Fork a fresh `claude` session into a new git worktree so it can handle a side detour without disturbing the current conversation. The parent agent does not await the result.

## Why this exists

Claude Code's Bash tool resets cwd between calls — the current agent cannot meaningfully "work in" a worktree it just created. The genuine value of a worktree is to host a *different* execution context. For agent-driven flows that means **another** `claude` process running in the worktree's own shell, where cwd is naturally stable.

The current agent (parent) does the things that need parent context: branch naming, base detection, worktree creation, drafting the child's prompt. The forked agent (child) does the things that need worktree-cwd: install, build, baseline checks, and the actual task work.

## Why `.git/wt/`

Worktrees land at `<repo>/.git/wt/<branch>` because `wt.basedir` is configured globally to `.git/wt` (relative to repo root). Reasons: inside the workspace (reachable from agent cwd), inside `.git/` (auto-untracked, no `.gitignore` upkeep), invisible to greps over the working tree (the parent agent will not pull worktree contents into its context).

> ⚠️ **Risk:** anything that wipes `.git/` also wipes the worktrees. Beware `rm -rf .git`, scripts that re-`git init`, or tools that "reset the repository" by deleting `.git/`.

## When to Use

- A side concern arises during the main task and is separable enough that interleaving would harm the main thread.
- The user explicitly asks for a separate claude session ("fork off X", "have another claude do Y").
- The user is on the default branch and about to commit (the `commit` Branch Guard refuses this; forking into a topic-branch worktree resolves the guard cleanly).

## When NOT to Use

- The current agent is already on the right topic branch and the task is the main thread — just keep working.
- **The Agent tool's `isolation: "worktree"` already covers it.** Use that built-in for *synchronous subagents*: a subordinate the parent will await and integrate. Use *this* skill for *asynchronous detours*: a separate visible session, possibly running for hours, where the parent does not await and the child reports independently.
- A trivial single-edit task where setup cost dominates.
- Tmux is not available — see the fallback below.

## Parent Workflow

All git inspection from the parent uses `git -C <worktree-path>` so it stays correct even though the parent's Bash cwd does not persist between calls.

### 1. Draft the child prompt

Decide what the forked agent should accomplish. Write a one-paragraph task description, list the files it must read first, and define a concrete success criterion. The PROMPT template below is the canonical shape.

### 2. Determine branch name

Per the user-scope CLAUDE.md `### Git Branching` rule, the form is `<type>/<kebab-slug>` using a Conventional Commits type (`feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `style`, `ci`, `revert`, `build`). Pick the type that matches the commit the child will likely make first.

### 3. Determine base branch

Try in order:

```bash
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@'
git show-ref --verify --quiet refs/heads/main && echo main \
  || (git show-ref --verify --quiet refs/heads/master && echo master)
```

Override only when the user specifies a different base.

### 4. Refresh the base

```bash
git fetch origin "$base_branch"
```

If the fetch fails (offline, missing remote, auth prompt), warn the user and fall back to the local ref. Do not retry blindly.

```bash
base_ref="origin/$base_branch"   # if fetch succeeded
base_ref="$base_branch"          # fallback after a failed fetch
```

### 5. Pre-flight: existing worktree for the same branch

```bash
git wt --json | jq -r --arg b "$branch_name" \
  '.[] | select(.branch == "refs/heads/"+$b) | .path'
```

If the branch already has a worktree at `<existing_path>`:

- `git -C <existing_path> status --porcelain` empty → reuse: skip step 6, jump to step 7 with `worktree_path=<existing_path>`.
- non-empty → stop and ask the user.

Never silently create a second worktree for the same branch.

### 6. Create the worktree

```bash
worktree_path=$(git wt --nocd "$branch_name" "$base_ref")
```

`wt.basedir = .git/wt` (relative to repo root) puts it at `<repo>/.git/wt/<branch>`. `--nocd` makes git-wt non-interactive and just print the path.

### 7. Find the parent's tmux pane

`$TMUX_PANE` is unreliable in the Bash tool's environment (often empty), and a bare `tmux split-window` without `-t` targets the server's last-active pane — which is usually an unrelated window the user is working in. Walk up the process tree and match against `pane_pid`:

```bash
my_pane=""
pid=$$
while [ -n "$pid" ] && [ "$pid" != "1" ]; do
  my_pane=$(tmux list-panes -a -F '#{pane_id} #{pane_pid}' 2>/dev/null \
    | awk -v p="$pid" '$2==p {print $1; exit}')
  [ -n "$my_pane" ] && break
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
```

If `my_pane` is empty, jump to the **Tmux Unavailable** fallback below.

### 8. Split and pre-fill (do NOT press Enter)

```bash
new_pane=$(tmux split-window -v -l 20 -t "$my_pane" -P -F '#{pane_id}')
tmux send-keys -t "$new_pane" \
  "cd $(printf %q "$worktree_path") && claude $(printf %q "$prompt_text")"
```

The command lands in the new pane's prompt **without Enter**. The user reads it, edits if needed, and presses Enter to launch. This is the safety valve — never bypass it by appending `Enter` to `send-keys`.

### 9. Report and return

Report to the user:

```
Forked into tmux pane <new_pane>
  Branch: <branch>
  Path:   <worktree_path>
  Base:   <base_ref> (fetched | local-fallback)
Press Enter in that pane to launch the child claude.
```

Then return to the main task in the parent conversation. Do not wait for the child.

## Child PROMPT Template

```
You are a forked Claude session, branched off another agent's main task.

Worktree: <worktree_path>
Branch:   <branch>
Base:     <base_ref>

Task:
<one-paragraph description of what to do and why>

Context files to read first:
- <abs path 1>
- <abs path 2>

Before starting work:
1. If .gitmodules exists, run `git submodule update --init --recursive`.
2. If package.json exists, invoke the nodejs-package-manager skill and install dependencies.
3. Run `git status --short` and confirm it is empty (the worktree should start clean).

Done when:
<concrete, observable success criterion>

When done:
<push the branch, open a PR, or leave on the branch — be specific>
```

The parent constructs this from the in-flight task. Keep it short — the child will read its own files anyway. The pre-fill-without-Enter lets the human edit the prompt before launch; do not validate it server-side.

## Tmux Unavailable

If pane detection returns empty, the parent is not running inside a tmux pane. Do **not** invoke `tmux split-window` (it would hijack a random pane), and do **not** try `osascript` / terminal-app fallbacks (environment-fragile, side effects unclear).

Print a copy-pasteable command and stop:

```
Cannot fork — Claude is not inside a tmux pane.
Run this in any terminal to launch the forked session manually:

  cd <worktree_path> && claude "<PROMPT>"
```

Then return to the parent's main task.

## Hooks and File Copy (Not Configured)

`git-wt` supports `wt.hook`, `wt.deletehook`, and `wt.copy*` for human-driven workflows. This skill does not configure them — hooks would run on every `git wt` invocation, hooks cannot invoke other Claude skills (e.g. `nodejs-package-manager`), and `wt.copy*` is project-specific with implicit side effects. If the human sets these manually for their own use, expect this skill to ignore or work around them.

## Related

- Manual worktree creation by the human → `git wt <branch>` directly.
- Sweep merged worktrees → `git-wt-prune` (separate script, dry-run by default).
- Synchronous subagent in an isolated worktree → use the Agent tool's `isolation: "worktree"` flag instead.

## Red Flags

- Forking when the task is the main thread, not a side detour.
- Pressing Enter after pre-fill (or appending `Enter` to `tmux send-keys`) — bypasses the human-confirm step.
- Hijacking an arbitrary tmux pane because pane detection failed — always use the fallback path instead.
- Creating a second worktree for a branch that already has one (skip step 5).
- Branching off the local base after a `git fetch` failure without warning the user.

## Quick Reference

| Situation                                | Action                                                         |
|------------------------------------------|----------------------------------------------------------------|
| Side concern arises during main task     | Run this skill                                                 |
| User asks for a separate claude session  | Run this skill                                                 |
| Branch name unspecified                  | Derive `<type>/<kebab-slug>`; ask if intent unclear            |
| Base branch unspecified                  | Try `gh` → `git symbolic-ref` → `main`/`master`                |
| Fetch failed                             | Warn, fall back to local base                                  |
| Same branch already has a worktree       | Reuse if clean; stop if dirty                                  |
| Tmux pane detection empty                | Print copy-paste command, do NOT split a random pane           |
| Want only the worktree, no fork          | Run `git wt <branch>` directly — this skill always forks       |
| Synchronous subagent needed              | Use Agent tool `isolation: "worktree"` instead                 |
| Sweep merged worktrees                   | Run `git-wt-prune` (separate CLI)                              |
