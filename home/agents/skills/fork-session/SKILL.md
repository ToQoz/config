---
name: fork-session
description: Fork a fresh `claude` session into a new git worktree to handle a side task that branches off the main thread — the parent agent does not await the result, the new session runs independently in a tmux split pane with its launch command pre-filled (user confirms before it starts). Use when a side concern arises during the main task and should be handled separately rather than interrupting the current flow, or when the user explicitly asks for a separate claude session. Distinct from the Agent tool's `isolation: "worktree"` (which spawns a synchronous subagent the parent integrates) — this skill is for asynchronous, human-coordinated detours. Trigger phrases include "fork off X to a separate session", "have another claude do Y while I continue", "branch off into a separate claude", "let me park this and start a new session for X", "sidetrack into a fresh claude for Y", "sandbox session for X".
---

# Fork Session

Fork a fresh `claude` session into a new git worktree so it can handle a side detour without disturbing the current conversation. The parent agent does not await the result.

## Why this exists

Claude Code's Bash tool resets cwd between calls — the current agent cannot meaningfully "work in" a worktree it just created. The genuine value of a worktree is to host a *different* execution context. For agent-driven flows that means **another** `claude` process running in the worktree's own shell, where cwd is naturally stable.

The parent does the things that need parent context: drafting the child's prompt and finding the user's tmux pane. The forked agent does the things that need worktree-cwd: install, build, baseline checks, and the actual task work.

## Why defer naming

The right `<type>/<kebab-slug>` often becomes clear only once the child has shaped the work — early naming tends to drift. This skill therefore launches into a `wt-now/<UTC-timestamp>` placeholder via `git-wt-now`, which:

- Branches off the repository's default branch (with `git fetch` if reachable, local fallback otherwise).
- Creates the worktree at `<repo>/.git/wt/wt-now/<UTC>`.
- Tells the child claude to call `git-wt-now-rename <type>/<kebab-slug>` once the work has a clear name. The rename is applied (branch + worktree path) when the child session exits.

The parent therefore does not pick a branch name, base, or fetch state — `git-wt-now` owns that.

## Why `.git/wt/`

Worktrees land at `<repo>/.git/wt/<branch>` because `wt.basedir` is configured globally to `.git/wt`. Reasons: inside the workspace (reachable from agent cwd), inside `.git/` (auto-untracked, no `.gitignore` upkeep), invisible to greps over the working tree.

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

### 1. Draft the child prompt

Forked tasks are usually small. Write the smallest prompt that lets the child act — task description, the few files it must read first, and a concrete success criterion. Skip context the child can derive from its own environment (branch, worktree path, base) since `git-wt-now` injects that as a system-prompt note. The PROMPT template below is the canonical shape.

### 2. Write the prompt to a file

Resolve the parent's worktree root and write the prompt under `.agents/cache/fork-session/`:

```bash
parent_root=$(git rev-parse --show-toplevel)
prompt_file="$parent_root/.agents/cache/fork-session/$(date -u +%Y%m%dT%H%M%SZ).md"
mkdir -p "${prompt_file%/*}"
# write $prompt_text to $prompt_file via the Write tool
```

The file lives in the parent's worktree and is gitignored (`.agents/cache/` is covered by the user's global ignore). The child reads it via `@<absolute-path>` after `git-wt-now` launches claude — both worktrees share the filesystem so the absolute path works.

### 3. Find the parent's tmux pane

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

### 4. Split and pre-fill (do NOT press Enter)

```bash
new_pane=$(tmux split-window -v -l 20 -t "$my_pane" -P -F '#{pane_id}')
tmux send-keys -t "$new_pane" \
  "git-wt-now $(printf %q "Execute: @${prompt_file}")"
```

The command lands in the new pane's prompt **without Enter**. The user reads it, edits if needed, and presses Enter to launch. This is the safety valve — never bypass it by appending `Enter` to `send-keys`.

`git-wt-now` creates the placeholder worktree, `cd`s into it, and launches `claude` with the rest of the args as the initial prompt. The child reads the prompt file via `@…` and starts work. Once it has a real branch name it calls `git-wt-now-rename <type>/<kebab-slug>`, which is applied when the child exits.

### 5. Report and return

Report to the user:

```
Forked into tmux pane <new_pane>
  Prompt: <prompt_file>
  Placeholder branch will be created by git-wt-now after launch.
Press Enter in that pane to launch git-wt-now.
```

Then return to the main task in the parent conversation. Do not wait for the child.

## Child PROMPT Template

Keep it tight. Forked tasks are usually small, and `git-wt-now` already tells the child its placeholder branch and the rename command — do not duplicate that.

```
You are a forked Claude session, branched off another agent's main task.
You are running inside a git-wt-now placeholder worktree; the wrapper has
already told you the placeholder branch and the rename command.

Task:
<one-paragraph description of what to do and why>

Context files to read first:
- <abs path 1>
- <abs path 2>

Done when:
<concrete, observable success criterion>

When done:
<push the branch, open a PR, or leave on the branch — be specific>
Once the work is shaped, run `git-wt-now-rename <type>/<kebab-slug>` so the
placeholder is renamed on exit.
```

The pre-fill-without-Enter lets the human edit the prompt before launch; do not validate it server-side.

## Tmux Unavailable

If pane detection returns empty, the parent is not running inside a tmux pane. Do **not** invoke `tmux split-window` (it would hijack a random pane), and do **not** try `osascript` / terminal-app fallbacks (environment-fragile, side effects unclear).

Print a copy-pasteable command and stop:

```
Cannot fork — Claude is not inside a tmux pane.
Run this in any terminal to launch the forked session manually:

  git-wt-now "Execute: @<prompt_file>"
```

Then return to the parent's main task.

## Hooks and File Copy (Not Configured)

`git-wt` supports `wt.hook`, `wt.deletehook`, and `wt.copy*` for human-driven workflows. This skill does not configure them — hooks would run on every `git wt` invocation, hooks cannot invoke other Claude skills (e.g. `nodejs-package-manager`), and `wt.copy*` is project-specific with implicit side effects. If the human sets these manually for their own use, expect this skill to ignore or work around them.

## Related

- Manual worktree creation by the human → `git wt <branch>` directly, or `git-wt-now` for a placeholder + claude session.
- Sweep merged worktrees → `git-wt-prune` (separate script, dry-run by default).
- Synchronous subagent in an isolated worktree → use the Agent tool's `isolation: "worktree"` flag instead.

## Red Flags

- Forking when the task is the main thread, not a side detour.
- Pressing Enter after pre-fill (or appending `Enter` to `tmux send-keys`) — bypasses the human-confirm step.
- Hijacking an arbitrary tmux pane because pane detection failed — always use the fallback path instead.
- Picking a topic branch name in the parent — that's `git-wt-now-rename`'s job after the work is shaped in the child.
- Writing the prompt file outside `.agents/cache/` — it must be gitignored and reachable by absolute path.
- Bloating the child prompt with context the child can derive itself.

## Quick Reference

| Situation                                | Action                                                         |
|------------------------------------------|----------------------------------------------------------------|
| Side concern arises during main task     | Run this skill                                                 |
| User asks for a separate claude session  | Run this skill                                                 |
| Branch name unknown / likely to shift    | Default — placeholder + rename via `git-wt-now-rename`         |
| Tmux pane detection empty                | Print copy-paste `git-wt-now …`, do NOT split a random pane    |
| Want only the worktree, no claude        | Run `git wt <branch>` directly                                 |
| Synchronous subagent needed              | Use Agent tool `isolation: "worktree"` instead                 |
| Sweep merged worktrees                   | Run `git-wt-prune` (separate CLI)                              |
