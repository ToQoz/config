---
name: ask-codex
description: Get a second opinion from Codex CLI on implementation plans, code reviews, or problem-solving. Use when the user explicitly asks for a second opinion, or when a high-risk implementation/review decision needs an independent check.
---

## How to Consult

Before running `codex exec`, **always write the prompt to a file** using the Write tool to avoid heredoc parsing errors in the Claude Code Bash tool:

```
Write tool → <agent-sandbox-directory>/ask-codex/<cwd-slug>/<YYYYMMDD>-<short-title>.md
```

Then pass it via pipe (use `cat |` instead of `<` redirection — Claude Code's allowlist processing may not handle `<` correctly):

```bash
cat <agent-sandbox-directory>/ask-codex/<cwd-slug>/<YYYYMMDD>-<short-title>.md | codex exec --sandbox read-only --ephemeral "$(pwd)" -
```

For complex reasoning, choose a stronger configured model explicitly:

```bash
cat <agent-sandbox-directory>/ask-codex/<cwd-slug>/<YYYYMMDD>-<short-title>.md | codex exec --sandbox read-only --ephemeral "$(pwd)" -m MODEL_ID -
```

For code reviews, prefer the review command:

```bash
codex exec review --uncommitted --ephemeral
codex exec review --base main --ephemeral
```

## Workflow

1. **Formulate** — Write a self-contained prompt with full context. Codex has no access to your conversation history.
2. **Write** — Use the Write tool to save the prompt to `<agent-sandbox-directory>/ask-codex/<cwd-slug>/<YYYYMMDD>-<short-title>.md`.
3. **Execute** — Run `codex exec` passing the file via `cat path/to/prompt.md |` (not `<` redirection).
4. **Evaluate** — Do not blindly accept the response. Compare it against your own analysis.
5. **Synthesize** — If the second opinion materially changes the risk or direction, surface the disagreement and your recommendation.

## Guidelines

- Include enough context in the prompt; Codex cannot see your conversation
- Keep prompts focused — avoid dumping entire codebases
- If Codex conflicts with established project patterns, prefer project patterns
- Report material disagreements transparently
- Use configured profiles or `codex --help` to check available model options; do not infer models from binary strings
