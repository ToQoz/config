---
name: remind
description: Record a deferred action to ~/agents/REMIND.md. Use when something is identified as worth doing later but is out of scope for the current task.
---

# remind

## Intent

Capture deferred actions so they are not forgotten. Write them to `<agent-sandbox-directory>/REMIND.md`.

## When To Use

- A review or task identifies something that should be fixed later but is out of scope now
- The user explicitly says to note something for later
- You notice an inconsistency or improvement opportunity that does not belong in the current diff

Do not use this as a substitute for doing the work. If the action is small and in scope, just do it.

## Format

Each entry is an H2 section appended to `<agent-sandbox-directory>/REMIND.md`. Create the file if it does not exist.

```markdown
## <concise title>

- **Project**: `<owner>/<repo>`
- **Date**: <YYYY-MM-DD>

<what to do and why, in 1-3 sentences>
```

Rules:
- Derive the project from the current working directory (e.g. `ToQoz/config`).
- Always use an absolute date, never relative ("tomorrow", "next week").
- Keep the description actionable — someone reading it later should know what to do without extra context.
- If adding to an existing file, append the new entry. Do not rewrite existing entries.
