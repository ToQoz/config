---
name: implementation-discipline
description: Default workflow for non-trivial coding tasks. Covers task clarification, constrained execution, design choices, and concrete verification.
---

# implementation-discipline

## Intent

Execute coding tasks with clear thinking, minimal scope, sound design choices, and verifiable outcomes.

Use this as the default mode for non-trivial implementation work.

## When To Use

- Implementing a non-trivial feature
- Modifying existing code with unclear constraints
- Making changes in an unfamiliar codebase
- Choosing between multiple valid implementations
- Deciding whether to add a dependency, helper, or abstraction

## Workflow

### 1. Clarify the task

Before changing code, identify:
- the actual problem
- the constraints
- the success criteria
- any unknowns or assumptions

Do not start implementation with a fuzzy task definition.

### 2. Inspect before proposing

Read the relevant code paths first.

Confirm:
- where the behavior actually lives
- what inputs and outputs exist
- what invariants the code appears to rely on
- what tests or execution paths already cover the behavior

Do not infer architecture from filenames alone.

### 3. Select the approach

Choose the smallest change that solves the actual problem. When comparing candidates, prefer the one that:

1. uses fewer dependencies
2. has fewer layers of indirection
3. has a clearer input/output contract
4. makes failure behavior explicit
5. minimizes hidden state
6. is easier to test in isolation
7. can be replaced or removed with less collateral impact

Avoid broad rewrites, opportunistic cleanup, and speculative extensibility.

**Dependencies.** Do not add a dependency unless it materially reduces real complexity, replaces error-prone custom logic with a well-proven primitive, or is already standard in the codebase. Do not add a dependency solely because it is popular or might be useful later.

**Abstractions.** Do not introduce an abstraction unless it pays for itself now — multiple real call sites need the same contract, or it removes duplication that is already harmful. Hypothetical future reuse is not a reason.

**Interfaces.** Keep them narrow, explicit, unsurprising, and difficult to misuse. Prefer explicit parameters over hidden ambient state, explicit return values over side-channel behavior.

**Failure modes.** Treat failure handling as first-class design work. Ask: what can fail, how does failure surface, is it local or contagious, can callers understand and handle it?

Do not apply these rules dogmatically. Do not fight the framework when working inside one.

### 4. Implement narrowly

Make the change. Keep the diff scoped to the selected approach.

Do not introduce helpers or layers without immediate need. Do not refactor unrelated code.

### 5. Preserve behavior unless intentionally changing it

If behavior changes, make that change explicit.

Call out:
- what changed
- what did not change
- any compatibility or migration implications

### 6. Verify concretely

Validation must be observable.

Preferred forms:
- existing tests
- new targeted tests
- reproducible manual steps
- command output
- runtime behavior that can be directly checked

Do not treat "looks right" as verification.

## Internal Checklist

This is a completion check, not an output template. Before finalizing, check:

- Did I solve the stated problem, not a larger adjacent one?
- Is the diff narrower than my first instinct?
- Did I avoid unrelated cleanup?
- Are assumptions explicit?
- Is every abstraction justified by present need?
- Are the interfaces narrow and explicit?
- Is data flow clear?
- Are failure cases handled?
- Is the verification concrete?
- Would a reviewer understand why each change exists?

## Anti-Patterns

- Starting to code before locating the real change point
- Introducing abstractions "for future flexibility"
- Changing multiple systems when one local change would work
- Claiming confidence without checking actual code or behavior
- Broad refactors hidden inside a bug fix
- Adding a dependency to save a small amount of code at the cost of a larger conceptual footprint
