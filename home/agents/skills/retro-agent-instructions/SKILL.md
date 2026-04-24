---
name: retro-agent-instructions
description: After completing a task, reflect on whether CLAUDE.md, AGENTS.md, or SKILL files could be improved based on friction observed during the session. Proposes atomic, evidence-based changes to instruction files.
---

# retro-agent-instructions

## Intent

Turn session friction into durable instruction improvements. Each proposal compounds — a single well-placed rule prevents the same mistake across every future session.

This skill is the feedback loop that makes the instruction system self-correcting.

## When To Use

Invoke this skill at the end of a task when **any** of these friction signals occurred during the session:

- **Instruction contradiction**: Conflicting guidance forced a judgment call that instructions should have resolved.
- **Repeated correction**: The user corrected the same kind of mistake more than once.
- **Missing context**: Information that should have been in an instruction file had to be asked for or discovered ad hoc.
- **Wrong skill or missed skill**: A skill was invoked incorrectly, or a relevant skill was not triggered when it should have been.
- **Workaround applied**: The agent did something that felt like a hack because instructions did not cover the case.
- **Ambiguous trigger**: It was unclear which skill or instruction applied to the situation.

Do **not** invoke when:

- The task completed without friction.
- The friction was purely domain-specific (required knowledge the instruction system should not encode).
- The user's correction was a one-time preference, not a recurring pattern.

## Core Rules

1. **Friction-gated, not universal.** No friction signals, no retrospective. Silence is the success case.
2. **One friction event, one proposal.** Never bundle multiple observations into a single entry.
3. **Propose, never auto-apply.** Instruction files are high-leverage. Changes require user review.
4. **Generalize first.** Follow the priority order when deciding where a change belongs:
   1. User-scope skill (most general)
   2. User-scope CLAUDE.md / AGENTS.md
   3. Project-scope skill
   4. Project-scope CLAUDE.md / AGENTS.md
5. **Two-strike rule.** For ambiguous cases, log the first occurrence via the `remind` skill. Propose an instruction change only when the same pattern appears a second time. Exception: clearly structural gaps (e.g., a skill's "When To Use" section is provably wrong) warrant a proposal on first occurrence.
6. **Short proposals only.** If the proposed change is longer than ~5 lines, the issue is probably task-specific, not instruction-level. Reconsider.

## Workflow

### 1. Detect friction signals

Before reporting task completion, scan the session for friction signals listed above. If none are found, skip the retrospective entirely.

### 2. Identify the instruction gap

For each friction event, determine:

- Which instruction file is responsible (or should be)?
- What is missing, misleading, or contradictory?
- Is this the first occurrence or a recurrence?

### 3. Classify scope

Apply the priority order. Ask: "Would this rule help in other projects?" If yes, target user-scope. If it is specific to this repository's conventions, target project-scope.

### 4. Draft the proposal

Write a concrete, atomic proposal. Include the exact text to add or modify, with enough surrounding context to locate it.

### 5. Write to RETRO.md

Append the proposal to `./.agents/share/RETRO.md`. Create the file if it does not exist.

### 6. Inform the user

After writing, briefly tell the user what was proposed and where to find it. Do not dump the full proposal into the conversation — a one-sentence summary with the file path is enough.

## Entry Format

Each entry is an H2 section appended to `./.agents/share/RETRO.md`.

```markdown
## <concise title>

- **Date**: YYYY-MM-DD
- **Project**: <owner/repo>
- **Target**: <file path relative to repo root, or "user-scope: <path>">
- **Scope**: user-scope | project-scope
- **Friction signal**: <which signal from the list above>

### What happened

<1-3 sentences describing the specific friction event. Quote the conversation moment if possible.>

### Proposed change

<Exact text to add or modify. Use a fenced diff block or quote block with enough context to locate the change.>

### Rationale

<Why this is general, not one-off. Why this scope level. Reference prior remind entries if this is a second strike.>
```

## Quality Signals

A proposal is worth making when:

- The friction maps to a **category** of tasks, not a specific task.
- The fix is **short** (1-5 lines). Long proposals usually indicate task-specific issues.
- The target file already covers **adjacent concerns** — the gap is a hole in existing coverage.
- **Multiple projects** would benefit (favoring user-scope).

A proposal is likely noise when:

- The friction required domain knowledge the instruction system should not encode.
- The fix would only help for this exact repo or library.
- The user's correction was about personal preference in the moment, not about preventing errors.
- The same instruction file would need constant churn to accommodate the proposal.

## Anti-Patterns

- Proposing vague observations ("CLAUDE.md could be clearer about X") instead of concrete text changes
- Auto-applying changes to instruction files without user review
- Firing after every task regardless of whether friction occurred
- Bundling multiple unrelated observations into one proposal
- Proposing project-scope changes for patterns that are clearly general
- Encoding domain knowledge or task-specific details into instruction files
- Proposing changes that duplicate what is already derivable from code or git history
