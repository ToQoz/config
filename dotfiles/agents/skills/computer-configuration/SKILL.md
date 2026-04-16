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
- **Don't build.** Stop after editing files. The user runs `darwin-rebuild switch` (or `home-manager switch`) themselves.
- **If the target config is not tracked in this repository**, ask the user what to do rather than editing in-place.
