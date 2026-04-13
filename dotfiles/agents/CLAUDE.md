# User-level Claude Instructions

## Variables

- `<agent-sandbox-directory>` = `~/agents`
  - The sandbox directory used by agents for thinking and processing tasks.
- `<cwd-slug>` = Bash(`pwd | sed -e "s,^$HOME/src/,," -e 's,/,-,g'`)
  - The identifier for the current working directory.

## Language

- Communicate with user in "Japanese". But think in Eniglish
- Write anything like code, comments commit messages in Eniglish.
  - Exception rule 1: Documents and dictionary files whose file names or directory names contain locale should be written in the language corresponding to that locale.
  - Exception rule 2: Follow project's rules.

## Git Branching

- When creating a topic branch, always branch off from the repository's default branch (e.g. `dev`, `main`) unless the user explicitly specifies a different base.
- Determine the default branch with: `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`

## Environment Configuration

When editing any configuration or environment setup in `~/src/github.com/ToQoz/config`, always invoke the `nix-dotfiles` skill before making changes. This includes shell, editor, terminal, Claude Code, macOS system settings, and any dotfile.
