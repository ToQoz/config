---
name: ambiguous-request-resolver
description: User-invoked skill for handling ambiguous product or UX requests from non-engineers (PdM, PO, designers, etc.), especially when terminology may not match the codebase, behavior is described instead of implementation, or the requester's mental model may differ from the actual system. When invoked, use this workflow to translate the request into concrete engineering work before making changes.
disable-model-invocation: true
---

# Ambiguous Request Resolver

Handles requests from non-engineers where the language used may not precisely match the codebase, or where technical intent needs to be inferred. Translate the request into precise, actionable engineering work — filling in reasonable details using product and engineering judgment, but staying honest about what needs clarification.

## The core challenge

Non-engineers describe what they want in terms of user-facing behavior, business goals, and their mental model of the product. Their words may:

- Name a UI element that maps to multiple components
- Use a term that doesn't appear anywhere in the codebase
- Describe a symptom of a bug rather than the bug itself
- Conflate two separate systems ("the API" might mean the backend, or a third-party integration, or both)

## Workflow

### 1. Translate the request

Identify:
- Desired user/business outcome
- Observed current behavior (what the requester says they see now)
- Terms that may not match the codebase
- Parts that are explicit requirements vs. implementation details you'll need to infer

When the intent is clear but implementation details are missing, fill them in using existing product patterns and conventional UX/engineering judgment — don't bounce every unspecified detail back to the requester.

### 2. Ground it in the product and code

Before editing:
- Search for the requester's terms and nearby product concepts in the codebase
- Find the relevant UI, route, API, state, or data model
- Reproduce or inspect current behavior when feasible (run the app, tests, or trace representative inputs)
- Check tests, docs, designs, or established patterns if available

Treat current behavior as important evidence, not automatically as product truth. Preserve it unless the request, tests, specs, designs, or surrounding product logic clearly indicate it should change.

### 3. Decide whether to act or ask

For low-risk, easily reversible changes: state your interpretation and proceed.

Ask before acting when:
- Multiple plausible code paths map to the same request
- Requirements contradict each other
- The change could affect data, permissions, billing, destructive actions, migrations, broad UX behavior, or public APIs — and the interpretation is not certain
- You cannot verify a necessary assumption

Ask the smallest set of blocking questions needed. Prefer one question, but batch related blockers together when asking separately would create avoidable back-and-forth.

### 4. Make the smallest safe change

Use existing patterns. Preserve unrelated behavior. Do not silently fix adjacent issues.

If you find a likely bug outside the request, report it separately — unless fixing it is required to complete the requested work safely.

Separate blockers from non-blocking observations: mention unrelated concerns briefly as follow-up notes, not as extra work silently included.

### 5. Verify and report

Verify behavior before and after the change when feasible. For UI work, run the app or relevant test, inspect the actual screen. For backend or state changes, run targeted tests and trace representative inputs.

In the final response, explain in plain language (not just code terms):
- What product behavior changed and why
- The key mapping from request terms to code — e.g., "I treated 'checkout modal' as the dialog in `CartSummary`, backed by `CheckoutForm`"
- What was verified
- Any unresolved ambiguity or follow-up issue to address separately
