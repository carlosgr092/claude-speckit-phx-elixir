---
name: spx:tasks
description: Generate an actionable, dependency-ordered tasks.md for the feature from the design artifacts, with Elixir/Phoenix task rules, [agent] routing tags, and migration sequencing.
argument-hint: "[task-generation context]"
handoffs:
  - label: Analyze For Consistency
    agent: spx:analyze
    prompt: Run a project analysis for consistency
    send: true
  - label: Implement Project
    agent: spx:implement
    prompt: Start the implementation in phases
    send: true
scripts:
  sh: ${CLAUDE_PLUGIN_ROOT}/scripts/setup-tasks.sh --json
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution: Git commit hook (before_tasks)

This command wires the `before_tasks` hook from `${CLAUDE_PLUGIN_ROOT}/templates/extensions.yml`. Mapping: `speckit.git.commit` → `/spx:git-commit`. Resolution: `.specify/extensions.yml` `hooks.before_tasks` overrides the inline default (skip silently on parse failure). Inline default: one **optional** (`optional: true`) hook —

```
## Extension Hooks

**Optional Pre-Hook**: git
Command: `/spx:git-commit`
Description: Auto-commit before task generation

Prompt: Commit outstanding changes before task generation?
To execute: `/spx:git-commit`
```

Run `/spx:git-commit` only if accepted. Treat missing `enabled` as enabled; skip `enabled: false`; do not evaluate non-empty `condition`. For a mandatory hook, emit `EXECUTE_COMMAND:` and invoke it before the Outline. Skip silently if nothing is registered and `.specify/extensions.yml` is absent.

## Outline

1. **Setup**: Run `${CLAUDE_PLUGIN_ROOT}/scripts/setup-tasks.sh --json` from repo root and parse `FEATURE_DIR`, `TASKS_TEMPLATE`, and `AVAILABLE_DOCS`. `FEATURE_DIR` and `TASKS_TEMPLATE` are absolute paths when provided; `AVAILABLE_DOCS` lists document names/relative paths under `FEATURE_DIR` (e.g. `research.md`, `contracts/`). For single quotes in args, use escape syntax (`'I'\''m Groot'`) or double-quote.

2. **Load design documents** from `FEATURE_DIR`:
   - **Required**: `plan.md` (tech stack, libraries, structure), `spec.md` (user stories with priorities).
   - **Optional**: `data-model.md` (entities), `contracts/` (interface contracts), `research.md` (decisions), `quickstart.md` (test scenarios).
   - **IF EXISTS**: `.specify/memory/constitution.md` for principles and governance constraints.
   - Not all projects have all documents. Generate tasks based on what is available.

3. **Execute task generation workflow**:
   - Load `plan.md` → extract tech stack, libraries, project structure, and the Elixir/Phoenix Design section (if present).
   - Load `spec.md` → extract user stories with priorities (P1, P2, P3…).
   - If `data-model.md` exists: extract entities and map to stories.
   - If `contracts/` exists: map interface contracts to stories.
   - If `research.md` exists: extract decisions for setup tasks.
   - Generate tasks organized by user story (see Task Generation Rules).
   - Generate a dependency graph showing story completion order; create parallel-execution examples per story; validate task completeness (each story has all needed tasks and is independently testable).

4. **Generate tasks.md**: Read the template from `TASKS_TEMPLATE` (fallback: `.specify/templates/tasks-template.md`) and use it as structure. Fill with:
   - Correct feature name from `plan.md`.
   - Phase 1: Setup (project initialization).
   - Phase 2: Foundational (blocking prerequisites for all stories).
   - Phase 3+: one phase per user story (priority order from `spec.md`), each with story goal, independent test criteria, tests (if requested), implementation tasks.
   - Final Phase: Polish & cross-cutting concerns.
   - Strict checklist format (below), clear file paths, a Dependencies section, parallel-execution examples, and an implementation-strategy section (MVP first, incremental delivery). Straight quotes `""` only (D13).

## Task Generation Rules

**CRITICAL**: Tasks MUST be organized by user story to enable independent implementation and testing. **Tests are OPTIONAL** — only generate test tasks if the spec explicitly requests them or the user requests TDD.

### Checklist Format (REQUIRED)

Every task MUST strictly follow: `- [ ] [TaskID] [P?] [Story?] [agent?] Description with file path`

1. **Checkbox**: always `- [ ]`.
2. **Task ID**: sequential (T001, T002…) in execution order.
3. **[P] marker**: only if parallelizable (different files, no dependency on incomplete tasks).
4. **[Story] label**: REQUIRED for user-story phase tasks only (`[US1]`, `[US2]`…). Setup/Foundational/Polish phases carry NO story label.
5. **[agent] tag** (optional, Elixir/Phoenix — placed after the Story label): routes the task to a specialist during `/spx:implement`. Valid tags: `[ecto]`, `[liveview]`, `[oban]`, `[security]`, `[ash]`, or `[direct]` (implement inline, no agent). Omit the tag on non-Elixir tasks. Self-gate: only add these tags when `mix.exs` exists at the repo root (D9).
6. **Description**: clear action with exact file path.

**Examples**:
- ✅ `- [ ] T001 Create project structure per implementation plan`
- ✅ `- [ ] T005 [P] Implement authentication middleware in src/middleware/auth.py`
- ✅ `- [ ] T012 [P] [US1] [ecto] Create User schema in lib/app/accounts/user.ex`
- ✅ `- [ ] T014 [US1] [liveview] Implement UserLive.Index in lib/app_web/live/user_live/index.ex`
- ❌ `- [ ] Create User model` (missing ID and Story label) · ❌ `T001 [US1] Create model` (missing checkbox) · ❌ `- [ ] T001 [US1] Create model` (missing file path)

### Task Organization

1. **From User Stories (spec.md)** — PRIMARY: each story (P1, P2…) gets its own phase; map its models, services, interfaces/UI, and (if requested) tests; mark story dependencies (most should be independent).
2. **From Contracts**: map each interface contract → the story it serves; if tests requested, a contract test task `[P]` before implementation in that story's phase.
3. **From Data Model**: map each entity → the story(ies) needing it (multi-story entities go to the earliest story or Setup); relationships → service-layer tasks in the appropriate phase.
4. **From Setup/Infrastructure**: shared infra → Phase 1; foundational/blocking → Phase 2; story-specific setup → within that story's phase.
5. **From Success Criteria (spec.md)**: every MEASURABLE success criterion (SC-###) — performance targets, concurrency guarantees, precision requirements — MUST get a task that actually verifies it (a perf test that seeds the stated volume, a concurrency test that exercises the real race, a boundary test for precision). If a criterion is genuinely untestable by design, emit a task that documents WHY and stop implying coverage — never assert an SC "achieved" without a verifying task (Iron Law 22).

### Elixir/Phoenix Task Rules (self-gated on `mix.exs` — D9)

When the project is Elixir/Phoenix, apply these rules so tasks compile and pass in order:

- **Migration before schema/context**: a schema field or context function that depends on a new column must come AFTER the migration task that adds it. Tag the migration task `[ecto]`.
- **Context function before LiveView/controller**: the context function a `[liveview]`/controller task calls must be an earlier task (avoids compile stalls). Specify exact `Module.function/arity` for extraction/refactor tasks.
- **Oban worker tasks** carry `[oban]` and must include an idempotency note; args use string keys, store IDs not structs.
- **Auth/permission tasks** carry `[security]`; every LiveView `handle_event` touching protected data needs an authorize step.
- **Ash projects**: prefer `[ash]` tasks driven by `mix ash.gen.*` / `mix ash.codegen`; never hand-edit resource snapshots.
- **Tests (only if requested)**: one test task per new public context function / LiveView flow, tagged `[test]`.

### Migration Sequencing Consult

When the plan introduces schema changes, consult `${CLAUDE_PLUGIN_ROOT}/skills/ecto-patterns/references/migrations.md` before ordering the `[ecto]` migration tasks (self-gated on `mix.exs`). Apply its sequencing doctrine:

- **Split risky changes across separate migrations/deploys** — e.g. add a nullable column and backfill in one migration, then add the `NOT NULL`/validation constraint in a **separate** migration (separate deploy), rather than one migration that locks the table.
- **Concurrent index creation** goes in its own migration (no other DDL alongside it).
- Order tasks so every migration is independently reversible (a working `down`), and so no later task assumes a constraint that an earlier migration has not yet validated.

Reflect this by emitting distinct, correctly ordered `[ecto]` tasks (e.g. `T0xx [ecto] Add nullable :status column …` before `T0yy [ecto] Backfill :status …` before `T0zz [ecto] Add NOT NULL constraint on :status …`), not a single "add status column with constraint" task.

### Phase Structure

- **Phase 1**: Setup · **Phase 2**: Foundational (blocking prerequisites) · **Phase 3+**: User Stories in priority order (within each: Tests if requested → Models → Services → Endpoints/LiveViews → Integration; each phase a complete, independently testable increment) · **Final Phase**: Polish & Cross-Cutting Concerns.

## Post-Execution: Git commit hook (after_tasks)

**You MUST complete this section before reporting completion.**

Resolve `hooks.after_tasks` (`.specify/extensions.yml` overrides, else inline default). Mapping: `speckit.git.commit` → `/spx:git-commit`. Inline default: one **optional** (`optional: true`) hook —

```
## Extension Hooks

**Optional Hook**: git
Command: `/spx:git-commit`
Description: Auto-commit after task generation

Prompt: Commit task changes?
To execute: `/spx:git-commit`
```

Run `/spx:git-commit` only if accepted. For a mandatory hook, emit `EXECUTE_COMMAND:` and invoke it. Skip silently if nothing is registered and `.specify/extensions.yml` is absent.

## Completion Report

Output the path to the generated `tasks.md` and a summary:
- Total task count and count per user story.
- Parallel opportunities identified; independent test criteria per story.
- Suggested MVP scope (typically User Story 1).
- Format validation: confirm ALL tasks follow the checklist format (checkbox, ID, labels, `[agent]` tag where applicable, file paths).

Context for task generation: `$ARGUMENTS`. The tasks.md must be immediately executable — each task specific enough that an LLM can complete it without additional context.

## Done When

- [ ] tasks.md generated with all phases, task IDs, `[agent]` tags, and file paths
- [ ] Migration tasks sequenced per the ecto-patterns migrations doctrine (when `mix.exs` exists)
- [ ] Extension hooks dispatched or skipped per the Post-Execution section
- [ ] Completion reported with task count, story breakdown, and MVP scope
