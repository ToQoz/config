# My Terms

## Variables

These variables are defined here for reuse across agent-facing markdown files (e.g. `CLAUDE.md`, `AGENTS.md`, `SKILL.md`). When one of these placeholders appears in such a file, resolve it as defined below.

- `<agent-sandbox-directory>` = `~/agents`
  - The sandbox directory used by agents for thinking and processing tasks.
  - You may freely read from and write to this directory at any time without asking the user for permission.
- `<cwd-slug>` = Bash(`pwd | sed -e "s,^$HOME/src/,," -e 's/github.com/github/' -e 's,/,-,g'`)
  - The identifier for the current working directory.
  - Typically, it follows the format `github-<org>-<repo>`

## Language

- Communicate with user in "Japanese". But think in Eniglish
- Write anything like code, comments commit messages in Eniglish.
  - Exception rule 1: Documents and dictionary files whose file names or directory names contain locale should be written in the language corresponding to that locale.
  - Exception rule 2: Follow project's rules.

## Debugging Mindset

> Beginners have a tendency to blame the compiler, the library, or anything other than their own code. Experienced programmers would love to do the same, but they know that, realistically, most problems are their own fault.
> — Brian W. Kernighan & Rob Pike, *The Practice of Programming* (1999), Chapter 5

When something goes wrong, suspect your own code first. Do not jump to blaming frameworks, libraries, compilers, or the runtime until you have ruled out mistakes in the code you wrote or changed.

## Structure Is Authority

Treat the shape of a system as stronger evidence than prose instructions: paths, module boundaries, naming patterns, generated directories, ownership markers, and config layering encode the workflow the system actually supports. When instructions and structure disagree, pause and infer the intended source of truth from the structure before acting, because good structure constrains mistakes while prompts only describe them. Prefer changes that make the correct path obvious at the point of use, so future agents can self-correct by navigating the system rather than remembering a warning. In unfamiliar code, follow the architecture's affordances first, then use written guidance to explain what the structure does not make clear.

## Git Branching

- When creating a topic branch, always branch off from the repository's default branch (e.g. `dev`, `main`) unless the user explicitly specifies a different base.
- Determine the default branch with: `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`

## Web Application Testing

When you modify a web application and there are no corresponding E2E tests covering the change, you MUST use the `exploratory-tester-for-webapp` skill to manually verify the change. After testing, leave a record of the test procedure and results (e.g. as a comment in the PR description or commit message) so reviewers can confirm what was verified.

## Environment Configuration

When reading or editing any configuration like dotfiles or environment setup in `~/src/github.com/ToQoz/config`, always invoke the `nix-dotfiles` skill before making changes. This includes shell, editor, terminal, Claude Code, macOS system settings, and any dotfile.
