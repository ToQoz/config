---
name: tally
description: Tally-Driven Development — an evidence-grounded, single-feature workflow where the spec is an observed contract between requirement and implementation, discovered after the code exists rather than written forward.
disable-model-invocation: true
---

# tally — Tally-Driven Development

## Intent

**A specification is the observed contract between a requirement and an implementation — and a clause becomes part of that spec only when the two sides tally.**

The name comes from the medieval Exchequer tally stick: a contract recorded on a wooden stick that was then split lengthwise, one half to each party. A clause was trusted only when the two halves, brought back together, matched exactly along the grain. Here the halves are the Step-1 oracle (from the user) and the Step-2 observation record (from the running code); a clause is valid only when they tally.

Tally-Driven Development inverts conventional Spec-Driven Development. SDD runs `requirement → spec → implementation`, feeding a forward-generated spec into the next stage. This workflow refuses that: the spec is what emerges when both sides are present and can be made to agree clause by clause. There is nothing to "write forward" because there is nothing for an LLM alone to observe.

By "contract" we mean something narrower than formal contracts or consumer-driven contract tests: a set of **clauses**, each of which names one acceptance oracle from the requirement *and* cites one completed observation from the running code. A clause is valid only when both sides sign — a criterion drawn from user intent on one side, an actual run record on the other. No signature on either side means no clause, which means no spec.

The two sides are not symmetric:

- The **requirement** side contributes intent — what the user actually wants — and sets the oracle that determines pass/fail. Only the user can write this side.
- The **implementation** side contributes behavior — what the running code actually does — via tests, runs, debugger traces, benchmarks. Implementation does not negotiate intent; it only demonstrates behavior.

The failure mode to stay alert to: *two fictions back-to-back* — plausible-looking code followed by plausible-looking evidence prose. The oracle-quality gate in Step 1 and the completed-observation requirement in Step 2 exist to prevent that.

## Workspace

The workflow persists its state on disk so that clauses, observations, and oracles are inspectable files rather than chat prose — and so "completed observation" becomes a file-existence check instead of a prose claim.

```
./.agents/tally/<slug>/
├── meta.md              # workspace identity: slug, feature title, created_at, current step, status
├── requirement.md       # Step 1: finalized user intent, one item per line with stable Requirement IDs (R-001, R-002, …)
├── oracle-map.md        # Step 1 closing: acceptance-oracle map — one row per Requirement ID
├── contract.md          # Step 2/3: signed + unsigned clauses, the spec as it emerges
└── observations/
    ├── <record-id>.md   # one file per completed test/run/benchmark
    └── ...
```

### Slug

Short kebab-case, human-meaningful (e.g., `user-export-csv`). Propose one from the requirement and confirm with the user; never derive silently from a hash. The slug is identity.

### Resuming

If `./.agents/tally/<slug>/` already exists at Step 1 start, read it and continue from the state it describes. Do not overwrite prior work.

### Invariants (the rules that make the workspace load-bearing)

- **Stable IDs.** Every requirement line in `requirement.md` carries `R-###`. `oracle-map.md` rows reference only those IDs. `contract.md` clauses reference only those IDs and an observation record ID.
- **Step 1 files are stable after Step 1 completes — amendments require a dated note.** `requirement.md` and `oracle-map.md` are not edited silently afterwards. Legitimate reopens are expected when a Step-2 finding reveals a requirement defect; mark them explicitly by appending a `## Reopened <date> — reason: <why>` note at the bottom of the affected file, then edit. A silent edit is oracle drift in file form; a dated reopen is a normal Step-1 round-trip with the user.
- **Observations are append-only.** Never edit an existing `observations/<id>.md` after its outcome is written. Corrections are a new record whose frontmatter includes `supersedes: <old-id>`.
- **Observation record schema (required frontmatter).** A file under `observations/` is only a valid evidence source if its frontmatter contains at least:
  ```
  ---
  id: <matches filename stem>
  requirement_ids: [R-###, ...]
  command: <exact command, test name, or action>
  cwd: <working directory>
  env: <relevant env vars, tool versions, or "default">
  timestamp: <ISO-8601>
  outcome: pass | fail | error
  exit_code: <integer or n/a>
  ---
  ```
  Plus the body: the actual `stdout` / `stderr` / observed output, or a relative path to a captured artifact. Empty evidence body = invalid record. Optional: `supersedes`, `artifacts`, `notes`.
- **Signature is derived, not trusted.** Treat `Signature status: signed` in `contract.md` as a claim that must re-verify from files — valid observation record exists, frontmatter complete, outcome matches the clause's oracle result. Always re-verify before Step 3.
- **Independent observation.** For every Requirement ID, at least one of its signed clauses must cite an **independent observation** — evidence whose expected value was not hand-authored in the same change that wrote the implementation. Qualifying sources: a feature run log (not a unit test whose assertions you just wrote), a debugger trace whose recorded values were not pre-selected from the requirement text, a benchmark measurement, or the output of a companion skill listed in Skill Dependencies. Unit tests you authored alongside the implementation satisfy the observation requirement for an individual clause, but not the independence requirement for the Requirement ID — the implementation validating itself is a closed loop, and the independence rule exists to break it.

### gitignore policy

Not prescribed. Flag once at Step 1 close: the workspace is committable as an audit trail, or gitignorable as scratch — user's call.

## When To Use

Use `tally` **only if all** of the following are true:

- The scope is a **single user-visible feature or change**.
- Success can be demonstrated by observable behavior — a test result, a run log, a measurement — not by architectural argument alone.
- Requirement clarification can happen directly with the user.
- The task is not primarily coordination across multiple features or teams.

If any condition is false, do not use this skill. Tell the user it does not fit and proceed with a different approach. Common mismatches:

- Architecture or direction-setting work (ADR, library choice) — no single observable feature.
- Multi-feature coordination — the interesting behavior lives in the seams, not inside one feature.
- Broad behavior-preserving refactors — no requirement to ground against.
- Mechanical, already-unambiguous changes (bulk rename, dep bump) — observation adds no evidence the diff itself doesn't show.

## Skill Dependencies

Tally does not reinvent observation — it delegates to dedicated skills where appropriate. Step 2 draws on the following; invoke them rather than improvising when one fits.

- [`step-through-code`](../step-through-code) — step through changed code in a real debugger to record internal values. Use when a clause's oracle targets subtle internal behavior that tests/runs can't capture directly.
- [`tui-acceptance-checks`](../tui-acceptance-checks) — exploratory verification of TUI / terminal UI features. Use when the feature's observable surface is a terminal UI and E2E coverage is missing.
- [`webapp-acceptance-checks`](../webapp-acceptance-checks) — browser-based verification for webapp features. Use when the feature's observable surface is a browser UI and E2E coverage is missing.
- [`agent-browser`](https://github.com/vercel-labs/agent-browser/tree/main/skills/agent-browser) — underlying browser automation that `webapp-acceptance-checks` (and similar) build on. Rarely invoked directly from tally; listed for traceability.

Each observation produced via these skills is still recorded in `observations/<record-id>.md` under this workspace — the dependency produces the evidence, tally owns the record.

## Workflow

### Step 1 — Ground the requirement and lock the acceptance-oracle map

**This step captures user intent and acceptance criteria. It is not spec writing. No contract clauses are drafted here.**

Interrogate the user's initial request to resolve ambiguity and surface hidden cases. Ask only questions whose answers change the implementation or the acceptance outcome — otherwise the dialog becomes product discovery theater.

Perspectives worth probing (skip any that do not apply):

- **Functional intent** — inputs, outputs, side effects; what happens in cases the user did not mention.
- **Edge cases** — empty/malformed input, concurrent access, partial failure, missing permissions, first-time vs. repeat use.
- **User-answerable non-functional requirements** — performance/latency targets, security/privacy, supported environments, availability, observability.
- **UX/UI implications** — what the user sees, what they can do next, how errors surface.
- **Product fit** — existing system behavior, prior decisions, terminology.
- **Requirement health** — internal contradictions, infeasibility, scope larger than the user actually needs.

Internal code-quality properties (maintainability, extensibility, readability, test structure, naming) are **not** for this dialog. They are the agent's standing responsibility. Asking the user about them crowds out the questions only the user can answer.

**Closing action — write the workspace.** Before leaving Step 1:

1. Propose a slug from the requirement and confirm with the user.
2. Create `./.agents/tally/<slug>/` (preserve and read any existing files if the directory already exists — resume, don't overwrite).
3. Write `meta.md` with slug, feature title, created_at, current step (`step-1-complete`), and status.
4. Write `requirement.md` — finalized user intent, one item per line, each with a stable `R-###` identifier.
5. Write `oracle-map.md` — one row per Requirement ID:

   ```
   R-001 | <requirement statement> | <observable signal> | <pass/fail oracle>
   ```

6. Tell the user that the workspace lives at `./.agents/tally/<slug>/` and that committing vs. gitignoring it is their call.

`requirement.md` and `oracle-map.md` are **not** a contract; they are only the requirement-side acceptance criteria. They say what *would* need to be observed. They say nothing about *how* the implementation will behave internally, and they contain no clauses.

**Oracle quality gate — every oracle must pass all three:**

- **Falsifiable and binary** — a clear pass/fail, not a qualitative impression.
- **Externally observable** — phrased as an output, effect, or measurement, not as an internal-design or control-flow claim. Rewrite "uses X strategy" or "calls Y before Z" as the external behavior it produces, or return to the user to clarify what they actually care about.
- **Concretely set up** — input, trigger, and conditions specified so another agent can execute the oracle without interpretation.

If any requirement item has no oracle that passes this gate, return to the dialog and make it concrete with the user. An unverifiable requirement is a requirement defect, not an implementation problem.

### Step 2 — Implement ↔ observe ↔ sign loop

Repeat until every requirement item carries a signed clause.

1. **Implement.** Smallest change that plausibly satisfies the current requirement. Keep the diff narrow, interfaces explicit, failure modes concrete.

2. **Observe, record, then draft the clause — in that order.** A clause is drafted only after the observation file exists on disk with a complete outcome.

   Observation sources, in rough preference order:
   - **Tests** — extend or write tests, record what the implementation actually produces. Here tests are an observation tool; test-technique decisions (coverage strategy, property-based testing) are out of scope for tally.
   - **Exploratory runs** — run the feature end-to-end and record the result.
   - **Debugger inspection** — for subtle internal paths, step through and record the values that matter.
   - **Benchmarks** — for numeric non-functional requirements, record the measured number with its conditions.

   For each observation:
   1. Actually run it.
   2. Write `./.agents/tally/<slug>/observations/<record-id>.md` with the required frontmatter (see Workspace § Invariants) and the actual stdout/stderr/measurement in the body. If the run hasn't happened, the file doesn't get written — no file, no record.
   3. Then, and only then, append an **unsigned** clause to `contract.md`:

   ```
   Clause ID:             C-### (stable)
   Requirement ID:        R-###  (from oracle-map.md)
   Observed behavior:     what the code actually did (quote or summarize from the record body)
   Observation record ID: <record-id>  (must match a file in observations/)
   Oracle result:         pass | fail  (against the Step-1 pass/fail criterion)
   Signature status:      unsigned
   ```

   A forward-declared record ID — no file yet, no outcome yet — is a placeholder. A clause whose record file is missing, whose frontmatter is incomplete, or whose evidence body is empty is, by definition, unsigned.

   **Cross-link requirement.** The clause's `Requirement ID` must appear in the observation record's `requirement_ids` frontmatter list. An observation that does not claim to cover this requirement cannot evidence a clause about this requirement, no matter how real the run was. If the match fails, either the clause is wrong (re-draft it against a record that covers this requirement) or the observation's `requirement_ids` list was under-specified and needs a new record (observations are append-only — do not edit the existing record).

3. **Sign, or classify the defect.** Walk each unsigned clause:
   - If `Oracle result = pass`, verify the observation record file exists with a valid frontmatter and a non-empty evidence body → edit the clause in `contract.md` to `Signature status: signed`.
   - If `Oracle result = fail`, decide which side owns the gap:
     - **Implementation defect** — the oracle is clear, the observation shows the code doesn't meet it. Fix code; re-observe (write a **new** observation record — observations are append-only); supersede the prior record via `supersedes:` frontmatter if relevant; draft a new clause.
     - **Requirement defect** — the oracle is missing, ambiguous, contradictory, infeasible, or silent on a case that matters. Return to Step 1 with the specific conflict; close it with the user; reopen `oracle-map.md` with a `## Reopened <date> — reason: <why>` note; update; re-enter the loop.

   Do not sign across a disagreement. Do not quietly edit `oracle-map.md` to match the implementation — that is oracle drift, and the reopen-note protocol exists specifically to block it.

#### Observed contract — shape

```
## Signed clauses
- [Clause <id>] <Requirement ID> → <observed behavior>
  (record: <observation record id>, result: pass, evidence: <test | command+input+env>)

## Non-functional signed clauses
- [Clause <id>] <Requirement ID>: <measured value> under <conditions>
  (record: <benchmark run id>, result: pass, evidence: <command + env>)

## Unsigned clauses (to resolve before exit)
- [Clause <id>] <Requirement ID>: blocked because <missing record | failing oracle | requirement defect>
```

The "Unsigned clauses" list is the loop's open worklist; it must be empty to exit.

#### Loop control

- **Exit** when every Step-1 Requirement ID has at least one signed clause, at least one of its signed clauses cites an independent observation (see Workspace § Invariants), and the unsigned list is empty.
- **Loop with a code change** when the oracle is clear and observations show an implementation defect.
- **Return to Step 1** when an oracle is missing, observations conflict on a user-intent question, or a gap needs new intent from the user.
- **Escalation rule.** If the same Requirement ID fails to get a signed clause across two iterations without new information from the user, stop coding and return to Step 1. Repeated local fixes without new information is the signature of a requirement defect being misdiagnosed as an implementation defect.

### Step 3 — Verify, present, confirm

1. **Re-verify signatures from files.** Before presenting, walk every `signed` clause in `contract.md` and re-check:
   - `observations/<record-id>.md` exists.
   - Its frontmatter has all required fields.
   - Its `outcome` matches the clause's `Oracle result`.
   - Its evidence body is non-empty.
   - The clause's `Requirement ID` appears in the record's `requirement_ids` list — without this, the clause and the observation are not about the same contract item even if both are individually well-formed.

   Any signature that fails re-verification is downgraded to `unsigned` and flagged in the "Unsigned clauses" section with the reason. The "signed" label in the file is a claim, not a trust; verification is the trust.

   **Per-requirement coverage check.** After per-clause re-verification, walk each Step-1 Requirement ID and confirm that at least one of its signed clauses cites an independent observation (see Workspace § Invariants). A Requirement ID whose only signed clauses cite hand-authored-test observations is not considered satisfied — flag it as an independence gap and send the work back to Step 2 to record at least one independent observation before exiting.

2. **Update `meta.md`** — set `current step: step-3-presented` and record the verification timestamp.

3. **Present to the user**, pointing at files rather than pasting everything inline:
   - The finalized requirement and oracle map — reference `requirement.md` and `oracle-map.md`.
   - Implementation — what changed, at a useful level of detail.
   - The signed contract — reference `contract.md`, summarize the signed clauses inline for context.
   - Reconciliation check — every Step-1 Requirement ID mapped to the clause(s) that satisfy it. Call out anything that got downgraded by re-verification.

4. Wait for approval or revision. Revisions re-enter Step 1 (if intent changes — reopen `requirement.md`/`oracle-map.md` with a note) or Step 2 (if a clause needs re-observation — write a new observation record).

The workspace can be committed as an audit artifact, kept as a regression guardrail, or gitignored as scratch — user's call. If unsure, ask.

## Anti-Patterns

- **Drafting clauses during Step 1.** Step 1 produces acceptance criteria only. Writing behavior-style clauses before code runs re-creates the forward-spec brittleness this workflow exists to avoid.
- **Composing clauses from memory instead of observation.** Writing a clause from your plan rather than from a completed run produces fiction with clause formatting.
- **Contract laundering.** Signing a clause whose Observation record ID points at nothing complete — a planned test that never ran, a paraphrased log, a forward-declared placeholder. A clause without a reproducible observation is unsigned, regardless of how convincing the prose looks.
- **Fabricated observation file.** Writing `observations/<id>.md` with a plausible-looking frontmatter and made-up outputs to satisfy the existence check. The point of the file is to be a real run; if the run did not happen, the file must not exist.
- **Evidence laundering.** Citing flaky or non-deterministic runs, missing reproduction steps, or copy-pasting run output without the command that produced it. Every record must be something another agent could re-run.
- **Oracle drift.** Silently editing `oracle-map.md` to match what the implementation happens to do. If the oracle needs to change, reopen the file with a dated `## Reopened` note and close the gap with the user first.
- **Retroactive observation editing.** Observations are append-only. Changing an existing record after its outcome is written erases the history the contract is anchored to. Corrections are a new record with `supersedes: <old-id>`.
- **Test oracle copied from requirement text.** A test whose expected value is paraphrased requirement prose is not itself sufficient evidence — the implementation is validating itself. This is enforced by the independent-observation invariant (Workspace § Invariants) and the per-requirement coverage check in Step 3; the anti-pattern here is thinking a freshly-authored green test closes the loop on its own.
- **Skipping the dialog.** Interpreting the requirement unilaterally removes the requirement side of the contract entirely — there is no counterparty to sign against.
- **Treating the implementation as an intent-negotiating party.** Implementation only demonstrates behavior. If a clause fails because the code "thinks differently" about the requirement, that is still a requirement defect or an implementation defect — never a negotiation.
- **Asking the user about internal code quality.** Maintainability, extensibility, readability are the agent's responsibility. Raising them in the dialog clutters it and pushes real ambiguities out.
- **Stretching onto out-of-scope work.** Forcing a single-feature loop onto architecture or cross-cutting refactors produces ceremony, not grounding.
