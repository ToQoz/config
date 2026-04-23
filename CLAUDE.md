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
| Claude global instructions / memory | `dotfiles/agents/CLAUDE.md` |
| Claude Code skills | `dotfiles/agents/skills/<skill-name>/SKILL.md` |
