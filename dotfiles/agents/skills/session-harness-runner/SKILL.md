---
name: session-harness-runner
description: Use this skill when the user asks to run, execute, or verify a session harness. Simply directs the user to run the harness script directly — no agent mediation needed.
---

# Session Harness Runner

Session harnesses are self-contained execution packages. They do not need an
agent skill to run them.

## How to run

```bash
bash .session-harness/<task-slug>/run.sh
```

The `run.sh` script handles everything: agent invocation, verification, retry
loops, convergence detection, and retro generation.

## Adjusting behavior

Edit `.session-harness/<task-slug>/harness.env`:

- `MODE` — `one-shot`, `verify-only`, or `bounded-loop`
- `MAX_ITERATIONS` — iteration cap for bounded-loop
- `AGENT_ALLOWED_TOOLS` — tool permissions for the agent
- `AGENT_MAX_TURNS` — max turns per agent invocation

Edit `verifier.sh` to add, remove, or fix checks.
Edit `prompt.md` to adjust the task description.

## After running

- Check `state/` for per-iteration logs and verifier outputs
- Check `retro.md` for the execution summary
- Walk `verifier.md` for manual checks that the script cannot cover

## Creating a new harness

Use `session-harness-creator` to generate a new harness package.
