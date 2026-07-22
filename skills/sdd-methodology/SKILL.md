---
name: sdd-methodology
description: "Background reference on Spec-Driven Development (SDD) — the methodology behind the /spx: spine. Explains why the spec is the source of truth, the specify->plan->tasks flow, template-driven quality, and the constitution's role. Consult when reasoning about WHY a spine phase behaves as it does."
effort: low
user-invocable: false
---

# Spec-Driven Development (SDD) — Methodology Reference

Background knowledge behind this plugin's spine
(`/spx:constitution -> /spx:specify -> /spx:clarify -> /spx:plan -> /spx:tasks ->
/spx:analyze -> /spx:checklist -> /spx:implement`). This is a pure-reference skill:
it holds no procedure of its own. The spine commands ARE the procedure — read this
when you need to reason about WHY a phase behaves the way it does.

> Adapted from the spec-kit essay `spec-driven.md`. Where the original names
> `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, this plugin exposes the
> same phases as `/spx:specify`, `/spx:plan`, `/spx:tasks` (and the full spine above).

## The power inversion

For decades code was the source of truth and specs were disposable scaffolding.
SDD inverts this: **specifications don't serve code — code serves specifications.**
The spec is the primary artifact; code is its expression in a particular language
and framework (here, Elixir/Phoenix). Maintaining software means evolving the spec,
not patching drifted code.

The gap between intent and implementation is eliminated, not narrowed, by making
specifications and their implementation plans precise enough to *generate* working
systems. When the spec generates the code, there is no gap — only transformation.

Practical consequences for how you work in this plugin:

- **Debugging** often means fixing the spec/plan that produced wrong code, not only patching the code.
- **Refactoring** means restructuring for clarity while the spec stays the anchor.
- **Pivots** become systematic regenerations from a changed spec, not manual rewrites.
- The lifecycle is `0 -> 1, (1', ...), 2, 3, N` — the same spec spawns iterations and parallel implementations.

## The workflow in practice

An idea — usually vague — becomes a comprehensive spec through iterative dialogue:
the AI asks clarifying questions (`/spx:clarify`), surfaces edge cases, and pins down
testable acceptance criteria. Research agents gather context (library compatibility,
performance, security, org constraints) during planning. From the spec, the plan maps
each requirement to a technical decision with documented rationale. Consistency
validation (`/spx:analyze`) runs continuously, not as a one-time gate. Domain concepts
become data models; user stories become endpoints/LiveViews; acceptance scenarios
become tests. Production reality (metrics, incidents) feeds back into the spec for the
next regeneration.

## Why SDD matters now

1. **AI can reliably translate natural-language specs into working code** — amplifying developers, automating the mechanical translation step.
2. **Software complexity grows exponentially** — spec-driven generation keeps dozens of services/deps aligned with original intent.
3. **The pace of change accelerates** — pivots are expected; when the spec drives implementation, a requirement change regenerates the affected plans instead of forcing a manual rewrite.

## Core principles

- **Specifications as the lingua franca** — the spec is the primary artifact; code is its expression.
- **Executable specifications** — precise, complete, unambiguous enough to generate working systems.
- **Continuous refinement** — ambiguity/contradiction/gap analysis is ongoing (`/spx:clarify`, `/spx:analyze`), not a single gate.
- **Research-driven context** — research agents gather technical and organizational context throughout planning.
- **Bidirectional feedback** — production reality informs spec evolution.
- **Branching for exploration** — generate multiple implementation approaches from one spec to explore different optimization targets.

## The command flow (mapped to /spx)

| SDD phase | This plugin | What it does |
|-----------|-------------|--------------|
| Specify | `/spx:specify <description>` | Auto feature numbering (001, 002, … expands past 3 digits), branch creation, template-based spec generation, `specs/<NNN-slug>/` structure |
| Clarify | `/spx:clarify` | Up to 5 targeted questions; resolve `[NEEDS CLARIFICATION]` markers before planning |
| Plan | `/spx:plan` | Reads the spec; constitutional-compliance gates; technical translation; generates `plan.md`, `data-model.md`, `contracts/`, `research.md`, `quickstart.md` |
| Tasks | `/spx:tasks` | Reads `plan.md` (+ data-model/contracts/research); derives tasks; marks independent tasks `[P]`; writes `tasks.md` |
| Analyze | `/spx:analyze` | Read-only cross-artifact consistency; constitution authority; blocks implement on CRITICAL |
| Implement | `/spx:implement` | Executes `tasks.md` phase by phase, verifying as it goes |

In ~15 minutes the specify->plan->tasks trio yields a complete spec with user
stories and acceptance criteria, a detailed plan with documented technology
choices, contracts and data models ready for generation, test scenarios, and
everything versioned on a feature branch.

## Template-driven quality — how structure constrains the LLM

The templates are not just automation; they are sophisticated prompts that steer
output toward higher-quality specs:

1. **Prevent premature implementation detail** — the spec template focuses on WHAT users need and WHY, not HOW (no tech stack in the spec). Specs stay stable as technology changes.
2. **Force explicit uncertainty** — mandatory `[NEEDS CLARIFICATION: …]` markers stop plausible-but-wrong assumptions ("login" -> mark auth method, don't guess email/password).
3. **Structured thinking through checklists** — requirement-completeness checklists act as "unit tests for English": no clarification markers remain, requirements testable, success criteria measurable.
4. **Constitutional compliance through gates** — plan-phase gates (simplicity, anti-abstraction, integration-first) force explicit justification of any complexity, tracked in a Complexity Tracking section.
5. **Hierarchical detail management** — the plan stays high-level and readable; deep code/algorithms live in separate detail files.
6. **Test-first thinking** — contracts and tests are ordered before source, baking testability into the spec.
7. **Prevent speculative features** — no "might need" features; every feature traces to a concrete user story with acceptance criteria.

The compound effect: specs that are complete, unambiguous, testable, maintainable,
and implementable. The templates turn the LLM from a creative writer into a
disciplined specification engineer.

## The constitutional foundation

At the heart of SDD is a **constitution** — immutable principles governing how specs
become code. In this plugin the canonical constitution lives at `memory/constitution.md`
(and, per project, `.specify/memory/constitution.md`), authored/amended via
`/spx:constitution`. It is the architectural DNA: every generated implementation must
maintain consistency, simplicity, and quality.

The classic essay frames this as nine articles (Library-First, CLI Interface,
Test-First, project-defined Articles IV-VI, Simplicity & Anti-Abstraction,
Integration-First). **This plugin's constitution keeps the nine-article skeleton but
fills it with the fused Elixir/Phoenix Iron-Law corpus** (Ecto, LiveView, Oban,
contexts, security, testing, OTP, ops, error handling — plus a conditional Ash annex).
The universally applicable ideas carry over directly:

- **Test-first / integration-first** — realistic environments, contract tests before implementation (in Elixir: Sandbox isolation, mock only at boundaries, no `Process.sleep`).
- **Simplicity & anti-abstraction** — use the framework directly; justify every layer (no service objects / repository pattern over Phoenix contexts).
- **Observability** — everything inspectable; here, Tidewave runtime introspection and structured verification gates.
- **Immutability with amendment** — principles stay constant across time and across models; changes require documented rationale, review, and a semver bump + Sync Impact Report (the `/spx:constitution` amendment procedure).

`/spx:analyze` evaluates the concrete project constitution, so project-defined
articles participate in compliance checks exactly like the built-in ones. A
principle conflict is CRITICAL and is never silently diluted.

## Beyond rules: a development philosophy

- **Observability over opacity** — everything inspectable.
- **Simplicity over cleverness** — start simple; add complexity only when proven necessary.
- **Integration over isolation** — test in real environments.
- **Modularity over monoliths** — clear boundaries (Phoenix contexts, OTP supervision trees).

SDD does not replace developers or automate creativity. It amplifies human capability
by automating the mechanical translation from intent to implementation, and creates a
tight feedback loop where specifications, research, and code evolve together.
