---
name: webapp-test-strategy
description: Decide test levels for server-side web applications with browser frontends, favoring static analysis and integration tests while keeping end-to-end coverage narrow, stable, and high-value.
---

# Test Strategy for Web Applications

## Purpose

This skill defines how to choose the right test level for web applications.

It is a strategy document, not a framework-specific rulebook.
Use it to decide **what level of test to write** for a behavior, while keeping the suite fast, stable, and maintainable.

## Core principle

Prefer the **lowest test level that can credibly verify the behavior**.

In practice:

- Use **static analysis** as the always-on foundation
- Use **integration tests as the default** for application behavior
- Use **end-to-end tests only when they verify something integration tests cannot**
- Use **unit tests extensively for edge-case-heavy pure logic**

The goal is not maximum test count.
The goal is maximum confidence per unit of maintenance cost.

---

## First line of defense

Before adding runtime tests, use static analysis where it can remove whole classes of bugs:

- type checking
- linting
- framework/compiler checks
- schema or route validation when the project already uses it

Do not write runtime tests whose main value is proving type contracts, prop shapes, or impossible states that static analysis already enforces.

---

## Definitions

### Unit test

A unit test verifies narrow logic in isolation.

Use these where isolation is genuinely useful, especially when many edge cases can be covered cheaply:

- calculations
- branching logic
- transformations
- parsing/formatting
- validation rules
- pricing, permissions, or policy logic
- edge-case-heavy domain rules

Do not force everything into unit tests. Avoid unit tests that mostly mock framework behavior, component internals, HTTP clients, routers, or database adapters — those usually provide less confidence than an integration test at the application boundary.

### Integration test

An integration test verifies behavior across meaningful internal boundaries of the web application without driving the whole production-like browser surface.

For server-side behavior, this often means:

- request → routing → application logic → persistence
- authentication/authorization → handler/controller → response
- job/event trigger → application state change

For frontend behavior, this can mean:

- rendering a component or page with real framework behavior
- user interaction in a test DOM or component test runner
- client state changes, validation, or data-loading behavior without a full E2E browser journey

Integration tests should use real internal application code and realistic boundaries, while avoiding unnecessary full-browser/runtime complexity.

### End-to-end test

An end-to-end test verifies a user workflow through the full production-like surface.

Typical examples:

- real browser interaction
- client-side execution
- navigation and form flows
- critical cross-layer behavior that only emerges in the full runtime environment

End-to-end tests are valuable, but expensive:
- slower
- more fragile
- harder to debug
- more sensitive to incidental UI change

---

## Default stance

Start from this assumption:

1. Can this be verified credibly with a unit test?
   - If the behavior is mostly pure logic, use unit tests and cover the important edge cases thoroughly.

2. If not, can this be verified credibly with an integration test?
   - In most cases, this is the right choice.

3. Only use an end-to-end test when the behavior depends on the full runtime surface.
   - browser behavior
   - client-side execution
   - true multi-layer wiring that cannot be trusted otherwise

This means the test portfolio should usually look like:

- **Static analysis** as the always-on foundation
- **Unit tests** for concentrated logic and edge cases
- **Integration tests** as the main body of behavioral coverage
- **End-to-end tests** as a thin layer for critical runtime validation

---

## When to use integration tests

Use integration tests for most important workflows.

Good candidates:

- permissions and authorization behavior
- creation, update, deletion flows
- billing or transactional workflows at the application boundary
- state transitions
- API behavior
- redirects, error handling, validation behavior
- persistence side effects
- form validation and submission behavior (in component/UI integration tests)
- conditional rendering based on permissions or state
- loading, empty, error, and success states
- job/event triggering where the important concern is application behavior, not browser behavior

Choose integration tests when you want confidence in the application as a system, but do not need to verify real browser execution.

### Why integration tests should be the default

They are usually:

- faster
- more deterministic
- easier to diagnose when failing
- less coupled to presentation details
- cheaper to maintain over time

This makes them the highest-leverage place to put coverage.

### Dependency policy

Prefer real internal dependencies when they are part of the application behavior being verified, such as routing, middleware, application services, persistence, and framework integration.

Replace external services at the application boundary:

- payment providers
- email/SMS delivery
- third-party APIs
- LLM calls
- analytics
- external queues or webhooks

Assert the request made to the boundary and the application behavior around it. Add contract or adapter tests only when the external integration itself is a known source of risk.

---

## When to use end-to-end tests

Use end-to-end tests only for behavior that genuinely requires the full user-facing runtime.

Good candidates:

- JavaScript-heavy or client-runtime-dependent flows
- browser-specific interaction
- complex form behavior that depends on actual rendering/runtime execution
- critical happy paths where full-stack wiring must be proven
- regressions that have historically escaped lower-level tests

Examples of qualifying characteristics:

- the test would be meaningless without a real browser
- the bug class has repeatedly come from integration gaps at the full runtime layer
- the behavior depends on real client execution, navigation, or rendering coordination

### Keep end-to-end coverage narrow

End-to-end tests should cover:

- a few critical happy paths
- a few high-risk regressions
- a few smoke checks for essential user journeys

They should not attempt to exhaustively cover all business logic.
That creates duplication, slows feedback, and makes the suite brittle.

Unstable end-to-end tests should not be tolerated as background noise. Fix them promptly, reduce their scope, move the coverage to a lower level, or remove them. A flaky E2E test that people ignore is worse than no test.

---

## When not to use end-to-end tests

Do not use end-to-end tests just because a feature has a UI.

Avoid them when:

- the behavior is already credibly covered by integration tests
- the test mostly rechecks server-side logic
- failure diagnosis would be much clearer at a lower level
- the scenario is sensitive to incidental copy/layout changes rather than core behavior
- the same workflow would need many permutations better expressed elsewhere

A UI surface alone is not sufficient reason to write an end-to-end test.

---

## Cost model

Every test has a maintenance cost.

End-to-end tests are the most expensive form of confidence and should be treated that way.

Before adding one, ask:

- What risk does this catch that lower-level tests do not?
- Is the behavior actually browser/runtime dependent?
- Is this path critical enough to justify slower and more fragile coverage?
- Will future failures be actionable, or just noisy?

If those questions do not have strong answers, write an integration test instead.

---

## Specialized checks

Use these when the risk calls for them, but do not make them default layers:

- **Accessibility checks** for user-facing flows and reusable UI primitives
- **Visual regression checks** for layout-critical or brand-critical screens
- **Contract/adapter checks** for risky external service boundaries

---

## Anti-patterns

Avoid these mistakes:

### Re-testing the same assertion at every level
Avoid repeating the same behavioral assertion in unit, integration, and E2E tests without a distinct reason.

Layered coverage is useful when each level verifies a different failure mode, such as pure calculation correctness, server-side authorization, and full-browser checkout wiring.

### Using end-to-end tests to compensate for weak integration coverage
That makes the suite slower and harder to debug.

### Writing end-to-end tests for low-risk or presentation-fragile flows
These often fail for incidental reasons and erode trust in the suite.

### Forcing unit tests around behavior that only makes sense at system level
This produces artificial tests with low explanatory value.

---

## Decision checklist

Before writing a test, decide:

- Is this primarily logic?
  - Write a unit test. Cover edge cases thoroughly.

- Is this primarily application behavior across real system boundaries?
  - Write an integration test.

- Does this require real runtime execution to be trusted?
  - Write an end-to-end test.

- Is this critical enough to deserve the highest maintenance-cost test level?
  - If not, do not use end-to-end.

---

## Output expectations

When applying this skill, the agent should:

1. Verify that static analysis covers type/contract concerns before writing runtime tests
2. Choose the lowest credible test level
3. Prefer integration coverage over end-to-end coverage
4. Keep end-to-end tests minimal, intentional, and stable
5. Avoid duplicate coverage across layers unless each level verifies a distinct failure mode
6. Optimize for confidence, speed, debuggability, and long-term maintenance

## Short version

- **Static analysis first** — do not test what the type system already proves
- **Default to integration tests** — server-side and frontend component/UI integration
- **Use unit tests extensively for dense pure logic**
- **Use end-to-end tests only for full-runtime-critical behavior**
- **Keep end-to-end tests few, high-value, deliberate, and stable**
