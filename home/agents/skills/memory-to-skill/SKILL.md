---
name: memory-to-skill
description: Scan Claude Code project memory for procedural patterns that could become reusable skills, consult Codex for a second opinion, and promote solid candidates. Use when the user asks to distill memory into skills, review memory for skill candidates, extract generalizable procedures from memory, clean up memory by promoting entries, or any variation of "check if anything in memory should become a skill".
---

# memory-to-skill

## Intent

Project memory tends to accumulate entries that look like **rules or procedures** — things that would actually be more useful as skills available everywhere. This skill finds those entries, gets a sanity check from Codex, and promotes the good ones to real skills.

Memory is the wrong home for procedures. Memory is for **context** (who the user is, project facts, references, one-off corrections). Skills are for **procedures** (how to accomplish a category of task). When a memory entry encodes a procedure that generalizes across projects, it is misfiled.

This skill is the janitor pass over that drift. It is the inverse of `retro-agent-instructions` — that skill proposes new instructions from session friction at authoring time; this skill extracts existing instructions from memory after the fact.

## When To Use

- The user asks to review memory for skill candidates
- The user asks to distill, extract, or promote memory into skills
- The user wants to tidy memory by moving procedural entries out

Do **not** invoke this skill automatically. It is manual-only — promoting memory to skills changes durable instruction state and must go through user review.

## Core Rules

1. **Few candidates is the expected outcome.** Most memory is context, not procedure. Zero candidates is a valid, successful result.
2. **Propose, never auto-apply.** Every candidate goes through Codex and the user before anything is written.
3. **Update memory, do not delete.** Keep the context (the "why") in memory; remove only the procedural part that now lives in the skill.
4. **Generalizability is the bar.** If the procedure only makes sense in this one project, it belongs in memory, not in a skill.
5. **One candidate, one decision.** Do not batch-approve. Walk the user through candidates individually unless they explicitly ask otherwise.

## Workflow

### 1. Locate the project memory

The project memory directory is declared in the auto-memory system prompt, typically:

```
~/.claude/projects/<project-slug>/memory/
```

Read the path from the system prompt rather than re-deriving it. If no memory directory exists or `MEMORY.md` is empty, report that and stop.

### 2. Read MEMORY.md and every referenced memory file

Open `MEMORY.md` for the index, then read each memory file it points to. Keep notes on each entry's `type` (user / feedback / project / reference) and content.

### 3. Screen for candidates

For each entry, decide whether it is a **procedure** (candidate) or **context** (leave alone).

**Procedure signals (candidate):**
- Describes a repeatable workflow or rule that applies to work the user has not done yet
- Has a "How to apply" section that generalizes beyond the original incident
- Names a technique, pattern, or step sequence — not a fact about this specific project
- Would plausibly be useful in a different repository

**Context signals (NOT a candidate):**
- User role, preferences, or knowledge
- Project-specific facts (ongoing work, deadlines, stakeholders)
- References to external systems, dashboards, or channels
- One-off corrections without a generalizable rule
- Tied to a specific file path, tool version, or project-local convention

If the screening produces zero candidates, report that plainly and stop. Do not stretch to find something.

### 3a. Check whether an existing skill already owns the rule

For each surviving candidate, list the existing skills under `home/agents/skills/` and scan for coverage. A memory entry's procedure may have already been absorbed into a skill in a prior session; the memory just lingers as historical context.

If an existing skill already owns the rule:

- **Demote the entry from "new-skill candidate" to "memory-slim candidate."**
- Skip steps 4–7 (no new skill to draft, propose, or create).
- Go directly to step 8 (update the source memory) and add a pointer to the existing skill.

Do not re-propose the rule as a new skill just because it is in memory — duplication across skills creates drift.

### 4. Draft a proposal per candidate

For each surviving candidate, produce:

- **Proposed skill name** — hyphenated, action-oriented, matching the style of existing skills under `home/agents/skills/`
- **Proposed description** — frontmatter `description`, covering what it does and when to trigger (per `skill-creator` guidance, include concrete trigger phrases)
- **Proposed body sketch** — 3–7 bullets on the procedure, enough for Codex to assess
- **Source memory file** — which file this comes from, and which lines are procedural vs context

Check the existing skills directory before naming. If a skill with an adjacent concern already exists, the proposal should be to **extend** that skill rather than create a new one.

### 5. Consult Codex

Invoke the `ask-codex` skill in consultation mode. In the prompt, include:

- The candidate proposal (name, description, body sketch)
- The raw source memory entry
- The list of existing skill names (so Codex can flag overlap)
- The specific questions below

Ask Codex to judge:

1. Is this **actually generalizable**, or is it over-fit to this user's current project?
2. Is it **substantial enough** to justify a skill, or should it stay in memory as-is?
3. Does it **overlap or conflict** with an existing skill? If yes, propose extending that skill instead.
4. If the skill should exist, what is **missing or misleading** in the proposed body?

Use `fast` depth by default. Use `deep` when the candidate touches architecture, migrations, or anything irreversible.

### 6. Present to the user

For each candidate, show in the conversation:

- The candidate proposal (name, description, body sketch)
- Codex's verdict and key reasons
- Your own assessment, including where you agree or disagree with Codex
- A clear ask: **create / skip / modify**

If Codex and you both say "skip," say so and move on — do not force the user to triage obvious rejects.

### 7. Create approved skills

When the user approves a candidate, follow the `computer-configuration` skill's rules:

- Write the new skill to `~/src/github.com/ToQoz/config/home/agents/skills/<skill-name>/SKILL.md`
- Frontmatter must include `name` and `description`
- Match the tone and structure of neighboring skills (`remind`, `retro-agent-instructions`, etc.)
- Keep the body focused; prefer explaining *why* over rigid `MUST` / `NEVER` directives

Do not build yet — the rebuild step is deferred to the end of the session (step 9).

### 8. Update the source memory

After the skill file is written, edit the originating memory file:

- **Keep the context.** The incident, the user's reason for caring, the reference to prior work — all of that stays.
- **Remove the "How to apply" procedural portion** (or shorten it drastically), since the skill now owns it.
- **Append a pointer line** at the bottom of the body:
  `See also: skill \`<skill-name>\` — procedural guidance moved on <YYYY-MM-DD>.`
- **Update the frontmatter `description`** if the entry's center of gravity has shifted from procedure to context.

If after editing the memory file contains nothing but a pointer, delete the file and remove its line from `MEMORY.md`. This is the only form of memory deletion this skill performs.

### 9. Offer to rebuild

Newly written skills only project into `~/.claude/skills/` after a Home Manager rebuild. At the end of the session, follow the `computer-configuration` skill's rebuild flow: open a tmux split pane with the rebuild command pre-filled so the user can execute it.

## Candidate Screening Examples

**Good candidate (procedure, not in any existing skill):**
> *"When writing a migration that adds a NOT NULL column to a large table, split into three migrations: add nullable column, backfill in batches, then add NOT NULL. Never add NOT NULL + default in one step on >1M rows — it locks the table."*
>
> — concrete rule, reusable across any SQL-backed project, no existing skill covers it. **New-skill candidate.** Proceed to proposal and Codex review.

**Memory-slim candidate (procedure, but an existing skill already owns it):**
> *"Changes that cross layer boundaries must be in separate commits... identify layer boundaries in the changeset..."*
>
> — generalizable procedure, but `commit-work` already contains the rule (step 4 "Check scope"). **Not a new-skill candidate.** Skip skill creation; slim the memory to context + pointer to `commit-work`.

**Not a candidate (context):**
> *"tmux is the mux (prefix C-t), wezterm is terminal-only."*
>
> — a fact about this user's environment, not a procedure. Leave in memory untouched.

**Not a candidate (thin rule tied to project convention):**
> *"ADRs are new numbered files, never overwrite existing ones."*
>
> — arguably a rule, but too thin to trigger reliably as a skill and tied to this project's `docs/decisions/` convention. Leave in memory, or propose moving it to project `CLAUDE.md` via `retro-agent-instructions`.

## Anti-Patterns

- Promoting context-type memory (user profile, project facts, references) to skills
- Creating a new skill that overlaps with an existing one instead of extending the existing one
- Deleting memory entries wholesale — context is almost always worth keeping
- Batch-approving many candidates in one sweep without per-candidate scrutiny
- Inflating a thin memory entry into a verbose skill just to justify promotion
- Stretching for candidates when the honest answer is "nothing here needs to move"
- Running this skill on a schedule or after every session
