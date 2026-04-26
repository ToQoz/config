# ToQoz/config

This repo manages the machine environment with Nix, nix-darwin, and Home Manager.

## Editing Guide

Key split:

- `dotfiles/` — app-native config files (read directly by each tool)
- `home/home.nix` — program declarations, package installs, generated config, and tool integrations
- `darwin/configuration.nix` — macOS system-level settings (nix-darwin)

For app-specific config, look under `dotfiles/<app>/`. For installation, generated config, or Home Manager program options, edit `home/home.nix`.

Non-obvious locations:

| Change | Edit |
|---|---|
| zsh init, aliases, env vars, history | `home/home.nix` → `programs.zsh.*` |
| git global config | `home/home.nix` → `programs.git.*` |
| Neovim packages, LSPs, extra tools | `home/home.nix` → `programs.neovim.*` |
| Installed CLI tools / apps | `home/home.nix` → `home.packages` |
| Claude Code settings, permissions, MCP | `home/home.nix` → `programs.claude-code.*` |
| Codex settings, AGENTS.md, rules | `home/home.nix` → `programs.codex.*` |
| Claude global instructions / memory | `dotfiles/agents/CLAUDE.md` |
| Claude Code skills | `home/agents/skills/<skill-name>/SKILL.md` |

## Workspace Context

You may be running inside a git worktree (or a fresh clone) created
outside this session — typically by the user via `git-wt`. Multiple
worktrees of this repo can exist on the host at the same time, each
with its own in-flight change.

Implications:

- The host machine is shared across worktrees. `nix run .#switch`
  changes the live system, so it must not run from a worktree —
  activation belongs on `main`, after merge, sequentially.
- Build artifacts and flake evaluation are worktree-local and safe to
  run in parallel. Use them as the pre-commit gate (next section).
- Treat the worktree as your sandbox: edit, build, test, commit. Leave
  `switch` to the user.

If you are about to start work and you are *not* in a worktree (i.e.
the primary checkout — `git rev-parse --git-dir` equals
`git rev-parse --git-common-dir`), pause and confirm with the user
before proceeding. Other worktrees may be in flight, and the user
typically intends to work from a `git-wt` worktree.

## Pre-commit Gate

Before committing from this workspace, verify the change:

- `nix run .#build` — builds the nix-darwin configuration without activating.
- `nix flake check` — evaluates the flake.
- `node --test t/*.test.mts` — runs repo-level tests (plus any skill-local
  `*.test.ts` relevant to the change).

A green build + flake check is the bar for committing. Activation-only
failures that surface during `switch` are an accepted gap, caught
post-merge on `main`.

## Tests for Testable Code

For shell scripts under `scripts/` and skill `scripts/`, and any other
behavior that can be exercised in isolation, prefer adding tests over
relying on manual verification alone. Place repo-wide tests in `t/`
(`node --test t/*.test.mts`); co-locate skill-internal tests next to the
code they cover.
