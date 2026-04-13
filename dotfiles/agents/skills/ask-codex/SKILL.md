---
name: ask-codex
description: Get a second opinion from Codex CLI on implementation plans, code reviews, or problem-solving. Use when the user explicitly asks for a second opinion, or when a high-risk implementation/review decision needs an independent check.
---

## How to Consult

Before running `codex exec`, **always write the prompt to a file** using the Write tool to avoid heredoc parsing errors in the Claude Code Bash tool:

```
Write tool → ~/agents/ask-codex/<project-path>/<YYYYMMDD>-<short-title>.md
```

where `<project-path>` is the current working directory with `/` replaced by `-`
(e.g. `pwd` → `/Users/toqoz/src/github.com/ToQoz/myapp` → `Users-toqoz-src-github-com-ToQoz-myapp`).

Then pass it via stdin redirection:

```bash
codex exec --sandbox read-only --ephemeral -C "$(pwd)" - < ~/agents/ask-codex/<project-path>/<YYYYMMDD>-<short-title>.md
```

For complex reasoning, choose a stronger configured model explicitly:

```bash
codex exec --sandbox read-only --ephemeral -C "$(pwd)" -m MODEL_ID - < ~/agents/ask-codex/<project-path>/<YYYYMMDD>-<short-title>.md
```

For code reviews, prefer the review command:

```bash
codex exec review --uncommitted --ephemeral
codex exec review --base main --ephemeral
```

## Workflow

1. **Formulate** — Write a self-contained prompt with full context. Codex has no access to your conversation history.
2. **Write** — Use the Write tool to save the prompt to `~/agents/ask-codex/<project-path>/<YYYYMMDD>-<short-title>.md` (project-path = `pwd` with `/` → `-`).
3. **Execute** — Run `codex exec` passing the file via `< path/to/prompt.md`.
4. **Evaluate** — Do not blindly accept the response. Compare it against your own analysis.
5. **Synthesize** — If the second opinion materially changes the risk or direction, surface the disagreement and your recommendation.

## Guidelines

- Include enough context in the prompt; Codex cannot see your conversation
- Keep prompts focused — avoid dumping entire codebases
- If Codex conflicts with established project patterns, prefer project patterns
- Report material disagreements transparently
- Use configured profiles or `codex --help` to check available model options; do not infer models from binary strings
