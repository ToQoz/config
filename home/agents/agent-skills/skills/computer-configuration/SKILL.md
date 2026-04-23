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
  1. Find your own tmux pane by walking up the process tree and matching against `pane_pid`. `$TMUX_PANE` is unreliable in the Bash tool's environment (often empty), and a bare `tmux split-window` without an explicit `-t` targets the tmux server's last-active pane — which is usually an unrelated window the user is working in. Use this snippet:
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
     If `my_pane` is empty, Claude is not running inside a tmux pane. Skip the split and ask the user to run the command manually — do not split a random pane.
  2. Open a split with the command pre-filled (no Enter), capturing the new pane id via `-P -F '#{pane_id}'`:
     ```bash
     new_pane=$(tmux split-window -v -l 15 -t "$my_pane" -P -F '#{pane_id}')
     tmux send-keys -t "$new_pane" 'sudo darwin-rebuild switch --flake .' ''
     echo "$new_pane"
     ```
  3. After the user starts the build, monitor progress by polling with `tmux capture-pane -t "$new_pane" -p` every 10 seconds.
  4. If the output stops changing for 1 minute, stop monitoring and ask the user to check the status.
  5. When the build finishes, check the captured output for errors or warnings. If any are found, proceed to fix them.
- **If the target config is not tracked in this repository**, ask the user what to do rather than editing in-place.
