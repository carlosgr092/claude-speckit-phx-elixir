---
name: spx:plan
description: Execute the implementation planning workflow — research fan-out via specialist agents, then generate design artifacts and a phased, agent-routed plan with an Elixir/Phoenix Design section.
argument-hint: "[planning guidance] [--depth quick|standard|deep] [--lean]"
handoffs:
  - label: Create Tasks
    agent: spx:tasks
    prompt: Break the plan into tasks
    send: true
  - label: Create Checklist
    agent: spx:checklist
    prompt: Create a checklist for the following domain...
scripts:
  sh: ${CLAUDE_PLUGIN_ROOT}/scripts/setup-plan.sh --json
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Flags

- `--depth quick|standard|deep` — planning depth (agent count + plan detail). Auto-detected when omitted (see Depth Detection).
- `--lean` — write a minimal plan body from `${CLAUDE_PLUGIN_ROOT}/presets/lean/plan.md` (Technical Context + a task list, no breadboard/alternatives/risk prose). If the preset is absent, keep Summary + Technical Context + Constitution Check + phased tasks and drop the deep-only sections. Design artifacts and hooks still run.

## Pre-Execution: Git commit hook (before_plan)

This command wires the `before_plan` hook from `${CLAUDE_PLUGIN_ROOT}/templates/extensions.yml`. Mapping: `speckit.git.commit` → `/spx:git-commit`. Resolution: `.specify/extensions.yml` `hooks.before_plan` overrides the inline default (skip silently on parse failure). Inline default: one **optional** (`optional: true`) hook —

```
## Extension Hooks

**Optional Pre-Hook**: git
Command: `/spx:git-commit`
Description: Auto-commit before implementation planning

Prompt: Commit outstanding changes before planning?
To execute: `/spx:git-commit`
```

Run `/spx:git-commit` only if accepted. Treat missing `enabled` as enabled; skip `enabled: false`; do not evaluate non-empty `condition`. For a mandatory hook, emit `EXECUTE_COMMAND:` and invoke it before the Outline. Skip silently if nothing is registered and `.specify/extensions.yml` is absent.

## Outline

1. **Setup**: Run `${CLAUDE_PLUGIN_ROOT}/scripts/setup-plan.sh --json` from repo root and parse JSON for `FEATURE_SPEC`, `IMPL_PLAN`, `SPECS_DIR`, `BRANCH` (the feature workspace is resolved from `.specify/feature.json`). For single quotes in args, use escape syntax (`'I'\''m Groot'`) or double-quote.

2. **Load context**: Read `FEATURE_SPEC` and `.specify/memory/constitution.md`. Load the `IMPL_PLAN` template (already copied). If a brainstorm `interview.md` sits in the feature dir with `Status: COMPLETE`, read its Summary + Coverage Details and treat them as the clarification input (skip re-clarifying what it covers).

3. **Depth Detection** (skip if `--depth` was passed). Auto-detect from BOTH request clarity and technical scope:

   | Request clarity | Technical scope | Depth |
   |-----------------|-----------------|-------|
   | Clear + specific | 1 context, <5 files | `quick` |
   | Clear + specific | 2-3 contexts, schemas/LiveViews | `standard` |
   | Clear + specific | 4+ contexts, security, new workers | `deep` |
   | Vague (post-clarification) | Any | at least `standard` |
   | From a review / `/spx:investigate` file | Any | `standard` (scope is known) |

   Elixir-specific signals that push deeper (only when `mix.exs` exists): new migration, new LiveView, new Oban worker, changed Phoenix context boundaries, multiple contexts. Depth sets agent count and plan detail: `quick` = 1 agent, task list; `standard` = 2-3 agents, phased tasks + code patterns; `deep` = 4+ agents, full system map + risks + alternatives.

4. **Research fan-out** (before generating artifacts). Reuse first, then spawn selectively:
   - **Research-cache reuse**: check `SPECS_DIR/research/` (and any `research.md`) for prior findings on the same topics — reuse them instead of re-spawning. **When the input is a review file or `/spx:investigate` output, the findings ARE the research** — do NOT spawn agents to re-discover them; convert findings directly into plan tasks (a 56-session analysis showed the same findings re-discovered 3-4× across review→investigate→plan, wasting ~96K tokens).
   - **Elixir specialist selection** (self-gated on `mix.exs` at the repo root — D9; for non-Elixir repos, use the generic `research.md` fan-out from the Phases section only). Always spawn `phoenix-patterns-analyst`. Add conditionally:

     | Condition | Agent |
     |-----------|-------|
     | UI, form, live, real-time feature | `liveview-architect` |
     | Database, schema, table changes | `ecto-schema-designer` |
     | Uses Ash Framework | `ash-resource-designer` |
     | Job, worker, async, queue | `oban-specialist` |
     | GenServer, process, state | `otp-advisor` |
     | Auth, login, permission, security | `security-analyzer` |
     | NEW library needed (not in `mix.exs`) | `hex-library-researcher` |
     | Unfamiliar tech / community input | `web-researcher` |
     | Changing function signatures | `call-tracer` |

     Do NOT spawn `hex-library-researcher` for libraries already in `mix.exs` (Read/Grep `deps/{library}/lib/` instead).
   - **Fan-out sizing**: **0-2 agents** — spawn directly in parallel in ONE tool-use block with `run_in_background: true`, each `subagent_type: "claude-speckit-phx-elixir:<agent>"`, writing to `SPECS_DIR/research/{topic}.md` and returning a short summary. **3+ agents** (broad multi-context feature) — spawn ONE `subagent_type: "claude-speckit-phx-elixir:planning-orchestrator"` to run and compress the fan-out; then read only its digest plus `SPECS_DIR/summaries/consolidated.md`. Give each agent a FOCUSED prompt scoped to specific dirs/files — never "analyze the codebase".
   - **Wait for ALL agents**: you are notified as each background agent completes. Read each output file. **NEVER write the plan or design artifacts while any agent is still running.** If an agent fails, do the research yourself with Read/Grep rather than re-spawning.

5. **Execute plan workflow**: Follow the `IMPL_PLAN` template structure to:
   - Fill Technical Context (mark unknowns as "NEEDS CLARIFICATION").
   - Fill the Constitution Check section from `.specify/memory/constitution.md`. Evaluate gates (ERROR on unjustified violations).
   - Phase 0: Generate `research.md` (resolve all NEEDS CLARIFICATION).
   - Phase 1: Generate `data-model.md`, `contracts/`, `quickstart.md`, and the plan's **Elixir/Phoenix Design** section.
   - Re-evaluate the Constitution Check post-design.

## Phases

### Phase 0: Outline & Research

1. **Extract unknowns from Technical Context**: each NEEDS CLARIFICATION → research task; each dependency → best-practices task; each integration → patterns task.
2. **Generate/dispatch research** per step 4 above (reuse cache; specialist agents when `mix.exs`; generic research tasks otherwise).
3. **Consolidate findings** in `research.md`: Decision / Rationale / Alternatives considered.

**Output**: `research.md` with all NEEDS CLARIFICATION resolved.

### Phase 1: Design & Contracts

**Prerequisites:** `research.md` complete, all agents returned.

1. **Extract entities from the feature spec** → `data-model.md`: entity name, fields, relationships; validation rules from requirements; state transitions if applicable. The data model MUST reflect the FINAL Ecto schema and changeset you design — including virtual fields and boundary conversions (e.g. a virtual `:price` decimal that maps to a persisted `:price_cents` integer). Re-read your own schema/changeset design before finalizing `data-model.md` so it never contradicts the code the plan implies (a form contract that says "cast :price_cents directly" when the schema uses a virtual dollars field is a defect).

2. **Delegate Elixir/Phoenix design (when `mix.exs` exists at repo root)** — D9 self-gating. Fold the specialist output already gathered in step 4 into `data-model.md`, `contracts/`, and the plan's "Elixir/Phoenix Design" section (spawn any not yet run, in parallel, via `subagent_type: "claude-speckit-phx-elixir:<agent>"`):
   - `ecto-schema-designer` — schemas, fields, migrations (owning column first), indexes, constraints, and the preloads needed to avoid N+1.
   - `liveview-architect` — streams vs assigns, async boundaries, form/component structure (only if the feature has a LiveView/web surface).
   - `ash-resource-designer` — ONLY if the feature uses Ash.
   - `oban-specialist` — ONLY if the feature adds background jobs (idempotency).
   Constitution Principles / Iron Laws MUST be reflected in the resulting design.

3. **Breadboard (LiveView features)** — when the feature touches 2+ LiveView pages/components with shared state, complex event flows (PubSub, streams, multi-step forms), or multi-route navigation. Skip for single-page CRUD or non-LiveView work. If `liveview-architect` ran, use its affordance tables to build a system map (Places / UI affordances / Code affordances / Data stores). Each `⚠️` unknown becomes a Phase-0 spike task; each Place → a LiveView/component task; each Data Store → a schema/migration task.

4. **Define interface contracts** (if the project exposes external interfaces) → `contracts/`: document the contract format appropriate to the project type (public APIs, CLI command schemas, web endpoints, grammars, UI contracts). Skip if purely internal.

5. **Create the quickstart validation guide** → `quickstart.md`: runnable validation scenarios that prove the feature works end-to-end (prerequisites, setup, test/run commands, expected outcomes). Link to contracts/data-model rather than duplicating them. No full implementation code — that belongs in `tasks.md`.

6. **Agent context update**: update the plan reference between the `<!-- SPECKIT START -->` and `<!-- SPECKIT END -->` markers in `CLAUDE.md` to point to the `IMPL_PLAN` path from step 1. (This is also offered as the `after_plan` agent-context hook.)

**Output**: `data-model.md`, `contracts/*`, `quickstart.md`, updated agent context file.

## Key rules

- Use absolute paths for filesystem operations; project-relative paths for references in docs and agent-context files.
- Feature artifacts live under `SPECS_DIR` (`specs/<NNN-slug>/…` per D2) — research in `research/`, compressed summaries in `summaries/`, planning decisions in `scratchpad.md`. NEVER write to `.claude/plans/`.
- Tasks in the plan use `- [ ] [Pn-Tm][annotation] Description` format. Valid annotations: `[direct]` (most common), `[ecto]`, `[liveview]`, `[oban]`, `[otp]`, `[security]`, `[ash]`, `[test]`. Do NOT use subagent_type names as annotations.
- ERROR on gate failures or unresolved clarifications.

## CRITICAL: After Writing the Plan — STOP

**Do NOT proceed to implementation.** This is the plan-STOP law. After writing the plan and design artifacts:

1. Summarize: task count, phase names, key decisions/scope.
2. For `deep` plans, first answer three self-check questions in the plan's Risks section: What was the hardest decision (alternatives considered)? What alternatives were rejected and why? What are you least confident about (mark `⚠️`)?
3. Use `AskUserQuestion` with options: "Start in fresh session" (recommended for 5+ tasks) / "Create tasks" (`/spx:tasks`) / "Start here" / "Review or adjust the plan". Never auto-start `/spx:tasks` or `/spx:implement`.

## Post-Execution: Git commit + agent-context hooks (after_plan)

**You MUST complete this section before reporting completion.**

Resolve `hooks.after_plan` (`.specify/extensions.yml` overrides, else inline default). Mapping: `speckit.git.commit` → `/spx:git-commit`; `speckit.agent-context.update` → `/spx:agent-context`. Inline default: two **optional** (`optional: true`) hooks in order — `speckit.git.commit`, then `speckit.agent-context.update`.

```
## Extension Hooks

**Optional Hook**: git
Command: `/spx:git-commit`
Description: Auto-commit after implementation planning

Prompt: Commit plan changes?
To execute: `/spx:git-commit`
```

```
## Extension Hooks

**Optional Hook**: agent-context
Command: `/spx:agent-context`
Description: Refresh agent context after planning

Prompt: Execute speckit.agent-context.update?
To execute: `/spx:agent-context`
```

Run each only if accepted; for a mandatory hook, emit `EXECUTE_COMMAND:` and invoke it. Skip silently if nothing is registered and `.specify/extensions.yml` is absent.

## Completion Report

Command ends after Phase 1 design (plan-STOP). Report branch, `IMPL_PLAN` path, generated artifacts (`research.md`, `data-model.md`, `contracts/`, `quickstart.md`), detected depth, and the agents that ran.

## Done When

- [ ] Research fan-out completed (cache reused where possible; all agents returned before writing)
- [ ] Design artifacts generated, including the Elixir/Phoenix Design section (when `mix.exs` exists)
- [ ] Agent context updated; plan presented with a STOP (never auto-started downstream)
- [ ] Extension hooks dispatched or skipped per the Post-Execution section
- [ ] Completion reported with branch, plan path, and generated artifacts
