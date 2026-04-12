---
name: ask-codex
description: Get a second opinion from Codex CLI on implementation plans, code reviews, or problem-solving. Use when the user explicitly asks for a second opinion, or when a high-risk implementation/review decision needs an independent check.
---

## How to Consult

Use a read-only, ephemeral session for consultation so the other Codex agent does not modify the workspace or persist a session unnecessarily:

```bash
codex exec --sandbox read-only --ephemeral -C "$(pwd)" - <<'PROMPT'
YOUR_PROMPT_HERE
PROMPT
```

For complex reasoning, choose a stronger configured model explicitly:

```bash
codex exec --sandbox read-only --ephemeral -C "$(pwd)" -m MODEL_ID - <<'PROMPT'
YOUR_PROMPT_HERE
PROMPT
```

For code reviews, prefer the review command:

```bash
codex exec review --uncommitted --ephemeral
codex exec review --base main --ephemeral
```

## Workflow

1. **Formulate** — Write a self-contained prompt with full context. Codex has no access to your conversation history.
2. **Execute** — Run `codex exec` with a read-only, ephemeral session.
3. **Evaluate** — Do not blindly accept the response. Compare it against your own analysis.
4. **Synthesize** — If the second opinion materially changes the risk or direction, surface the disagreement and your recommendation.

## Guidelines

- Include enough context in the prompt; Codex cannot see your conversation
- Keep prompts focused — avoid dumping entire codebases
- If Codex conflicts with established project patterns, prefer project patterns
- Report material disagreements transparently
- Use configured profiles or `codex --help` to check available model options; do not infer models from binary strings
