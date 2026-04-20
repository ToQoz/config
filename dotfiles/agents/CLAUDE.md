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

- Communicate with the user in Japanese.
- Think in English.
- Write code, code comments, commit messages, and other implementation-facing text in English.
- Exception: Documents or dictionary files whose filename or directory name contains a locale should be written in the corresponding language.
- Exception: Follow project-specific language rules when they exist.

## Global Invariants

- Prefer simple, explicit, dependency-light solutions.
- Keep changes small, local, and easy to verify.
- Verify with concrete checks, not assumptions.

## Debugging Mindset

When something goes wrong, suspect your own code first. Do not blame frameworks, libraries, compilers, or runtimes until you have ruled out mistakes in the code you wrote or changed.

## Structure Is Authority

Treat the shape of a system as stronger evidence than prose instructions. Paths, module boundaries, naming patterns, generated directories, ownership markers, and config layering usually encode the workflow the system actually supports.

When instructions and structure disagree:
1. Pause.
2. Inspect the structure.
3. Infer the intended source of truth from the structure before acting.

In unfamiliar code:
- Follow the architecture's affordances first.
- Use written guidance to explain what the structure does not make clear.
- Prefer changes that make the correct path obvious at the point of use.

## Skills

- `coding-practice` — use for coding tasks
- `debugging-practice` — use for investigation, reproduction, and root-cause analysis
- `webapp-acceptance-checks` — use for manual verification (logic, visual etc) of web application changes when E2E coverage is missing
- `tui-acceptance-checks` — use for manual verification of TUI / interactive CLI changes when automated coverage is missing
- `computer-configuration` — use before reading or editing configuration in `~/src/github.com/ToQoz/config`
- `retro-agent-instructions` — use after completing a task when friction signals were observed (see below)

## Retrospective

After completing a task, check whether any friction signals occurred during the session: instruction contradictions, repeated corrections, missing context, wrong/missed skill triggers, workarounds, or ambiguous triggers. If any are found, invoke the `retro-agent-instructions` skill to propose improvements to instruction files.

## Webapp Testing

When you change any webapp code — logic, markup, styles, assets, or configuration that affects the browser — you MUST verify the change visually and functionally before considering the task complete.

- If complete automated test coverage exists for the change, those tests are sufficient.
- Otherwise, invoke the `webapp-acceptance-checks` skill and verify the affected behavior in the browser.

This applies unconditionally regardless of change size. A one-line CSS tweak requires the same verification as a feature addition. Minor changes are especially important to verify this way — they are easy to get wrong and easy to confirm quickly.

## TUI Testing

When you change any TUI or interactive CLI code — prompts, key bindings, redraw behavior, signal handling, full-screen UI, TTY-gated output — you MUST verify the change functionally before considering the task complete.

- If complete automated test coverage exists for the change, those tests are sufficient.
- Otherwise, invoke the `tui-acceptance-checks` skill and verify the affected behavior through a tmux pane.

This applies unconditionally regardless of change size. A one-line keybinding tweak requires the same verification as a feature addition.

## Repository Rules

### Git Branching

- When creating a topic branch, always branch off from the repository's default branch unless the user explicitly specifies a different base.
- Determine the default branch with:
  `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`

### Git Committing

- Commit skills (`commit`, `commit-work`, `commit-staged`) normally refuse direct commits to the default/shared branch and require a topic branch.
- Exception: for personal repositories under `~/src/github.com/toqoz/`, direct commits to the default branch are allowed. The commit Branch Guard is relaxed for these projects without requiring a per-project opt-in in the project's `CLAUDE.md`.

### Environment Configuration

- When reading or editing configuration in `~/src/github.com/ToQoz/config`, always invoke the `computer-configuration` skill before making changes.
- This includes shell, editor, terminal, Claude Code, macOS system settings, and any other dotfile or environment configuration managed there.
