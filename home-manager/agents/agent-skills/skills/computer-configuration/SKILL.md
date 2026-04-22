---
name: computer-configuration
description: Guidelines for editing environment configuration files managed by the ToQoz/config nix repository. Use this skill whenever modifying shell (zsh), editor (neovim), terminal (wezterm, tmux), Claude Code, or any other dotfile configuration — especially when the task involves ~/.config, ~/.claude, or similar home directory paths.
user-invocable: false
---

# Nix Dotfiles

All environment configuration is managed via Nix/Home Manager in `~/src/github.com/ToQoz/config`. Refer to that repository's `CLAUDE.md` for the full structure and file mapping.

## Rules

- **Never edit files directly** under `~/.config/nvim`, `~/.claude`, or other symlinked home directories. Those paths are Nix store outputs or symlinks — direct edits will be lost on the next build.
- **Only edit files in `~/src/github.com/ToQoz/config`.**
- **For Claude skills**, read and edit the canonical source under `dotfiles/agents/skills/` — treat `~/.claude/skills/` as a generated projection.
- **Don't build directly.** When a rebuild is needed:
  1. Open a new tmux split pane with the command pre-filled (using `send-keys` without pressing Enter) so the user can review and execute it. Always target your own pane with `-t "$TMUX_PANE"` — otherwise tmux splits whichever pane was last active, which is often a window the user is actively using elsewhere:
     ```
     tmux split-window -v -l 15 -t "$TMUX_PANE" \; send-keys 'sudo darwin-rebuild switch --flake .' ''
     ```
  2. After the user starts the build, monitor progress by polling with `tmux capture-pane -t <pane_id> -p` every 10 seconds.
  3. If the output stops changing for 1 minute, stop monitoring and ask the user to check the status.
  4. When the build finishes, check the captured output for errors or warnings. If any are found, proceed to fix them.
- **If the target config is not tracked in this repository**, ask the user what to do rather than editing in-place.
