---
name: ask-codex
description: Get a second opinion from Codex CLI on implementation plans, code reviews, or problem-solving. Use when the user explicitly asks for a second opinion, or when a high-risk implementation/review decision needs an independent check.
---

## Modes

This skill has two modes: **consultation** (free-form questions) and **code review** (structured diff review).

## Model Selection

Select a model in three steps: **family → depth → resolve**. If the user explicitly names a model, skip all steps and use it.

### Step 1: Choose family

| Task is mainly about… | Family |
|---|---|
| Code, diffs, tests, shell commands, stack traces, refactors | **codex** (code-optimized) |
| Writing, planning, policy, product/UX, broad synthesis | **general** (gpt-5.x) |
| Mixed — answer will contain code/commands/diff-level advice | **codex** |
| Mixed — answer is prose reasoning about a code decision | **general** |

### Step 2: Choose depth

| Depth | When to use |
|---|---|
| **Fast** (default) | Routine questions, quick sanity checks, low-risk second opinions |
| **Deep** | Multi-file reasoning, unclear root cause, architecture tradeoffs, meaningful regression risk |
| **Max** | High-cost mistakes: security, data loss, migrations, concurrency — or when fast/deep answers were inconclusive |

### Step 3: Resolve to a model name

Try candidates in order. On "model unavailable" errors, fall back to the next candidate.

| Slot | Candidates (try in order) |
|---|---|
| Fast (any family) | newest `*-codex-spark` → newest `*-codex-mini` → newest `*-codex` |
| Deep code | newest `*-codex` |
| Deep general | newest `gpt-5.x` (non-codex) |
| Max code | newest `*-codex-max` → deep code fallback |
| Max general | newest `gpt-5.x` (non-codex) |

If all candidates fail, omit `-m` entirely and let Codex CLI use its default.

### Discovering available models

Models embedded in the installed binary (hints, not guarantees — availability depends on account and plan):

```bash
strings $(which codex) 2>/dev/null | rg -oN 'gpt-[0-9a-z.-]+|o[0-9][a-z0-9.-]+' | sort -u
```

## Consultation Mode

Use this for free-form questions: architecture advice, plan validation, naming decisions, etc.

### Step 1: Write the prompt to a file

Always write the prompt using the Write tool — never use heredocs in Bash. This avoids shell parsing issues in Claude Code.

```
Write tool → ./.agents/cache/ask-codex/<YYYYMMDD>-<short-title>.md
```

The prompt must be **self-contained**. Codex has no access to your conversation history, so include all necessary context: what the code does, what you're trying to decide, and what kind of feedback you want.

### Step 2: Run Codex

Pass the prompt file via stdin redirection with `-` to indicate stdin input:

```bash
codex exec -m MODEL --sandbox read-only --ephemeral - < ./.agents/cache/ask-codex/<YYYYMMDD>-<short-title>.md
```

**Examples:**

```bash
# Fast code — codex-spark for a quick naming check
codex exec -m gpt-5.1-codex-spark --sandbox read-only --ephemeral - < ./.agents/cache/ask-codex/20260417-naming-check.md

# Deep code — full codex model for architecture review
codex exec -m gpt-5.1-codex --sandbox read-only --ephemeral - < ./.agents/cache/ask-codex/20260417-arch-review.md

# General — non-code planning question
codex exec -m gpt-5.4 --sandbox read-only --ephemeral - < ./.agents/cache/ask-codex/20260417-product-tradeoff.md
```

## Code Review Mode

Use `codex exec review` for structured code reviews. This subcommand is purpose-built for diffs and does not require a prompt file.

### Scope selection

| User says | Command |
|---|---|
| "review my changes" (default) | `codex exec review --uncommitted --ephemeral` |
| "review against main" / branch comparison | `codex exec review --base main --ephemeral` |
| "review this commit" | `codex exec review --commit <SHA> --ephemeral` |

When the user asks for a review without specifying scope, default to `--uncommitted`.

PROMPT (positional) is itself a scope and cannot be combined with `--uncommitted`, `--base`, or `--commit`. If you need custom review instructions against a specific scope, use Consultation Mode and include `git diff` context in the prompt file.

The `review` subcommand accepts the same `-m` flag for model selection. Note: `review` does not accept `--sandbox` — it runs in read-only mode by design.

### Examples

```bash
# Fast review — codex-spark
codex exec review -m gpt-5.1-codex-spark --uncommitted --ephemeral

# Deep review — full codex model
codex exec review --base main --ephemeral

# Review a specific commit
codex exec review --commit abc1234 --ephemeral
```

## Workflow

1. **Formulate** — For consultation: write a clear, self-contained prompt with all necessary context. For review: determine the scope.
2. **Write** — Consultation only: save the prompt to `./.agents/cache/ask-codex/<YYYYMMDD>-<short-title>.md` using the Write tool.
3. **Select model** — Follow the family → depth → resolve steps above. Default to fast code unless the task calls for more.
4. **Execute** — Consultation: `codex exec ... - < path/to/prompt.md`. Review: `codex exec review` with the appropriate scope flag.
5. **Retrieve (if persisted)** — If the tool result says the output was saved to a file, read only the last ~6KB with `tail -c 6000 <path>`. Codex structures reviews/consultations so the verdict and findings sit at the end; the leading bytes are prompt echo and reasoning trace.
6. **Evaluate** — Do not blindly accept the response. Compare it against your own analysis and codebase context.
7. **Synthesize** — Present both your assessment and Codex's perspective. Highlight agreements and disagreements. If the second opinion materially changes the risk or direction, surface it clearly and let the user decide.

## Guidelines

- Include enough context in consultation prompts — Codex cannot see your conversation
- Keep prompts focused and specific — avoid dumping entire codebases
- Cap response length in the prompt ("Report in under 800 words, keep each finding to 2–3 sentences") — codex will otherwise produce long reasoning that gets persisted to a file and requires post-processing
- If Codex conflicts with established project patterns, prefer project patterns
- Report material disagreements transparently
- Treat the response as one data point, not as authoritative truth
