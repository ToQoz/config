---
name: debugging-discipline
description: Use this for debugging, reproduction, and root-cause analysis. Suspect recent changes and local assumptions before blaming external systems.
---

# debugging-discipline

## Intent

Debug by disciplined elimination, not by blame or vague intuition.

Start with your own code, recent changes, assumptions, and integration points.
Do not blame frameworks, libraries, compilers, runtimes, or infrastructure until local causes have been ruled out.

## When To Use

- A change does not behave as expected
- Tests fail unexpectedly
- Runtime behavior differs from expectation
- An integration appears broken
- There is temptation to blame the framework or tooling too early

## Core Rules

1. Reproduce the problem clearly.
2. Start with the smallest local explanation.
3. Inspect recent changes first.
4. Test assumptions one by one.
5. Isolate the failing boundary.
6. Escalate blame outward only with evidence.

## Debugging Procedure

### 1. State the symptom precisely

Describe:
- what happened
- what was expected
- where it was observed
- whether it is deterministic or intermittent

Do not begin with a theory. Begin with the symptom.

### 2. Reproduce consistently

Find the smallest reliable reproduction.

Capture:
- exact inputs
- relevant environment
- commands or user actions
- observed output or logs

If it cannot be reproduced, treat every theory as provisional.

### 3. Inspect recent changes first

Check:
- code you just wrote or changed
- configuration you changed
- assumptions introduced by the change
- integration points touched by the change

Recent local change is the default suspect.

### 4. Narrow the boundary

Determine where the failure begins.

Ask:
- does the input look correct before entering this component?
- does the output become wrong inside this component?
- does the problem appear only after crossing a boundary?
- can parts be stubbed, logged, or bypassed to isolate the fault?

### 5. Test one hypothesis at a time

Each hypothesis should produce a concrete check.

Examples:
- add a targeted log
- inspect an actual value
- run a minimal reproduction
- compare expected and actual types
- disable or bypass one integration edge

Do not pile on multiple speculative fixes at once.

### 6. Escalate only with evidence

Only blame an external system when:
- the local code path has been checked
- the inputs/outputs are confirmed
- the boundary has been isolated
- the external behavior is inconsistent with documented or observed expectations

Even then, describe the evidence, not just the suspicion.

## Internal Checklist

This is a completion check, not an output template. For substantial debugging work, check that you have covered:

- Symptom (precise description)
- Reproduction (minimal, reliable)
- Most likely local causes (checked)
- Isolated boundary (where the failure begins)
- Conclusion (evidence-based)
- Fix or next check

## Heuristics

Prefer explanations in this rough order:
1. mistake in the changed code
2. bad assumption about existing code
3. configuration mismatch
4. integration contract mismatch
5. environment issue
6. library/framework/tool/runtime defect

This is a heuristic, not a law. Use evidence.

## Anti-Patterns

- Blaming the framework before checking your own call site
- Changing multiple things at once during diagnosis
- Rewriting code before isolating the fault
- Relying on memory instead of checking actual values and behavior
- Confusing a workaround with a root cause

## References

- Brian W. Kernighan and Rob Pike, *The Practice of Programming*, Chapter 5
