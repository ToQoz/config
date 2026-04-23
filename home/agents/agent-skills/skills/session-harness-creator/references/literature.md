# Session Harness Literature Notes

This is background for revising the skill, not runtime instruction.

## Narrow Synthesis

- Broad repository-level context is often noisy.
- Task-specific verifiers are high leverage.
- Harnesses matter when their constraints are real artifacts.
- Subprocess agents help only when they isolate context, permissions, or
  parallel checks.

## Harness Engineering

OpenAI's harness engineering writing frames the model as one part of a larger
runtime: tools, instructions, execution plans, validation, and state handling.
Session harnesses apply that idea at task/session scope instead of permanent
product infrastructure scope.

SWE-bench shows the value of concrete pass/fail conditions such as
`FAIL_TO_PASS` and `PASS_TO_PASS`. A session harness borrows that verifier-first
discipline without assuming benchmark-style tests always exist.

## Verifier-First Work

"Agentic Rubrics as Contextual Verifiers for SWE Agents" and "The Art of
Building Verifiers for Computer Use Agents" support the idea that correctness
criteria should be built explicitly and early. The relevant lesson is not "make
more agents"; it is "make failure visible before execution".

## Context Files Counterevidence

"Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding
Agents?" (arXiv:2602.11988) is counterevidence against broad automatically
generated context. It reports that LLM-generated context files tend to reduce
success and increase cost, while developer-written files can help slightly but
still increase steps and cost. Trace analysis suggests agents do follow the
instructions; the added requirements can make the task harder.

Implication for session harnesses:

- Do not generate broad repository overviews by default.
- Include context only when it reduces a named failure mode.
- Prefer exact files, commands, and verifier checks.
- Treat context as a liability until it earns its place.

The nuance: context files can help when other documentation is absent. In a
well-documented repo, they are more likely to duplicate or distract.
