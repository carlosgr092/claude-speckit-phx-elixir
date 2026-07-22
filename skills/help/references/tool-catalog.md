# Tool Catalog — Complete Command Reference

Full catalog of all `/spx:` commands, skills, and agents for `/spx:help` routing.

This plugin fuses spec-kit's spec-driven flow with the Elixir/Phoenix intelligence
base. The backbone is the **spine**: a linear pipeline from spec to implementation.
Everything else is a capability that hangs off that spine.

## The Spine (the main cycle)

Run these in order for any non-trivial feature. Each phase reads the previous
phase's artifacts under `specs/<NNN-slug>/`.

```text
/spx:constitution → /spx:specify → /spx:clarify → /spx:plan → /spx:tasks
                  → /spx:analyze → /spx:checklist → /spx:implement
```

### `/spx:constitution` — Create/amend the project constitution

- **When**: First-time setup, or amending engineering principles
- **Output**: `.specify/memory/constitution.md` + refreshed CLAUDE.md / AGENTS.md marker blocks
- **Notes**: Detects the stack (Phoenix/Ecto/Oban/Ash/Tidewave), regenerates the 4 derived enforcement copies. `--lean` for a minimal body.

### `/spx:specify <description>` — Feature spec from natural language

- **When**: Starting ANY new feature — this is the entry point, not `/spx:plan`
- **Input**: Feature description (or a `interview.md` produced by `/spx:brainstorm`)
- **Output**: `specs/<NNN-slug>/spec.md` + `.specify/feature.json`; feature branch via git-feature
- **Next step**: `/spx:clarify`

### `/spx:clarify` — Resolve ambiguity in the spec

- **When**: Spec has open questions or `[NEEDS CLARIFICATION]` markers
- **How**: Up to 5 questions, one at a time, coverage-dimension scored (What/Why/Scope/Where/How/Edge)
- **Output**: Updated `spec.md` with answers integrated
- **Next step**: `/spx:plan`

### `/spx:plan` — Technical plan and design artifacts

- **When**: Spec is clear enough to design against
- **Output**: `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`
- **Flags**: `--depth quick|standard|deep`, `--existing` (deepen an existing plan), `--lean`
- **Agents**: planning-orchestrator + design specialists (ecto-schema-designer, liveview-architect, oban-specialist, security-analyzer, otp-advisor, ...)
- **Next step**: `/spx:tasks`

### `/spx:tasks` — Break the plan into ordered tasks

- **When**: Plan is approved
- **Output**: `tasks.md` (`- [ ] T### [P] [US#] desc + path`), phased Setup → Foundational → per-story → Polish, with Elixir task rules and migration-safety sequencing
- **Next step**: `/spx:analyze` (or straight to `/spx:implement`)

### `/spx:analyze` — Read-only cross-artifact consistency check

- **When**: After tasks, before implementing
- **Output**: Consistency report; blocks implement on CRITICAL findings
- **Agents**: iron-law-judge, elixir-reviewer, security-analyzer, requirements-verifier (advisory)

### `/spx:checklist` — Requirements-quality checklists ("unit tests for English")

- **When**: You want to pressure-test the spec's requirements
- **Output**: `checklists/<domain>.md` (Phoenix presets: liveview/ecto/jobs/security/deploy)

### `/spx:implement` — Execute tasks.md phase by phase

- **When**: Ready to build
- **Behavior**: Checkboxes ARE the state; per-task `mix compile --warnings-as-errors`; per-phase affected tests + credo; path-matching domain skills auto-load; 3-retries-then-BLOCKER; final Verification Gate + parallel-reviewer
- **Flags**: `--from T###`, `--continue`, `--lean`
- **Next step**: `/spx:review`, then `/spx:converge`

## Git Commands

| Command | Purpose |
|---------|---------|
| `/spx:git-init` | git init + initial commit (auto-invoked before constitution) |
| `/spx:git-feature` | Feature branch creation (auto-invoked before specify) |
| `/spx:git-commit` | Per-event auto-commit (gated by git-config.yml; default off) |
| `/spx:git-validate` | Verify branch matches the feature naming convention |
| `/spx:git-remote` | Detect the GitHub remote (feeds tasks-to-issues / pr-review) |

## Flow Extensions

### `/spx:full <description>` — Autonomous whole-flow driver

- **When**: Well-defined feature, want the entire spine run end to end
- **Behavior**: specify → clarify → plan → tasks → analyze → checklist → implement → review → fix cycles → converge → compound; cycle caps; `--gates` (human approval) vs `--auto`; `--codex` cross-model review; zero narration
- **Agent**: full-driver

### `/spx:converge` — Post-implement gap assessment

- **When**: Implementation done; check for missing/partial/contradicting/unrequested work
- **Output**: Append-only `## Phase N: Convergence` in tasks.md

### `/spx:assess <idea>` — Pre-specify idea pipeline

- **When**: You have an idea but aren't sure it's worth a spec yet
- **Phases**: intake → research → define → shape → decide (go / needs-clarification / kill); go hands off to `/spx:specify`

### `/spx:bug <description>` — Artifact-based bugfix loop

- **When**: A bug worth tracking as an artifact (assess → fix → test under `.specify/bugs/<slug>/`)
- **Note**: For fast one-off root-causing use `/spx:investigate` instead

### `/spx:init` — Project bootstrap

- **When**: Setting up `.specify/` tree, state dirs, marker blocks (idempotent, never overwrites)

### `/spx:doctor` — Plugin/project health check

- **When**: Something feels off; verifies `.specify` state, constitution/derived-copy freshness, hook wiring, tool availability. `--json`.

## Capability Commands

### Review & quality

| Command | When |
|---------|------|
| `/spx:review` | Post-implement READ-ONLY parallel review; requirements source defaults to `spec.md` |
| `/spx:triage` | Filter/prioritize review findings before fixing |
| `/spx:challenge` | Adversarial "grill me" review (ecto/liveview/pr modes) |
| `/spx:verify` | Standalone compile/format/test loop |
| `/spx:codex-loop` | Critic-refiner loop with the Codex CLI as external critic |

### Fast paths & debugging

| Command | When |
|---------|------|
| `/spx:quick` | Single-file <50-line change, no ceremony |
| `/spx:investigate` | Root-cause a bug/crash/failing test (`--parallel` for deep) |
| `/spx:trace <function>` | Build a call tree via `mix xref callers` |
| `/spx:ecto-constraint-debug` | Debug unique/foreign-key/check constraint errors |

### Performance & health

| Command | When |
|---------|------|
| `/spx:perf` | Ecto/LiveView/OTP performance analysis on an impact×effort matrix |
| `/spx:n1-check` | Detect N+1 query patterns |
| `/spx:assigns-audit` | Read-only LiveView assigns memory audit |
| `/spx:boundaries` | Context-boundary health score (0-100), xref-verified |
| `/spx:narrow-bare-rescue` | Narrow `rescue _ ->` using the verified exception taxonomy |
| `/spx:techdebt` | Debt detection (credo --strict + duplicate greps) |
| `/spx:audit` | Project-wide health audit, 5 parallel auditors, A-F grade |

### Dependencies

| Command | When |
|---------|------|
| `/spx:deps-audit` | Non-mutating Hex supply-chain audit (feeds the deps-audit-gate hook) |
| `/spx:deps-update` | Mutating dep updates with changelog snapshots and coupled groups |
| `/spx:deps-vet` | Manage the `hex_vet.exs` audit ledger (`--seed/--list/--check`) |

### Knowledge loop

| Command | When |
|---------|------|
| `/spx:research <topic>` | Web research with parallel workers; `--library` eval mode |
| `/spx:recall` | History archaeology: solutions → git pickaxe → transcripts |
| `/spx:compound` | Capture a solved problem into `.claude/solutions/` |
| `/spx:learn` | Capture a lesson to project CLAUDE.md / memory / solutions |
| `/spx:document` | Generate @moduledoc/@doc/README/ADR |
| `/spx:brief` | Interactive walkthrough of a feature's WHY |
| `/spx:brainstorm <topic>` | Adaptive requirements interview → `interview.md` for specify |

### PR & environment

| Command | When |
|---------|------|
| `/spx:pr-review` | Resolve PR review threads (fix → reply → resolve) |
| `/spx:watch-pr` | Background PR watcher; `--codex` review rounds |
| `/spx:deploy` | Deployment reference + validation (also auto-loads on runtime.exs/Dockerfile/fly.toml) |
| `/spx:permissions` | Mine session transcripts → settings.json allowlist |
| `/spx:mix-compression` | Install rtk output filters (token savings) |
| `/spx:freeze` | Scoped edit lock via `.claude/.freeze` sentinel |

### Onboarding

| Command | When |
|---------|------|
| `/spx:help` | This advisor — recommend the right command |
| `/spx:intro` | 6-section interactive plugin walkthrough |

## Decision Helpers

### New feature: where do I start?

Always start at **`/spx:specify`**. It creates the spec the rest of the spine reads.
If the idea is still fuzzy, `/spx:brainstorm` first (or `/spx:assess` for a full
go/no-go pipeline). Never route a brand-new feature straight to `/spx:plan`.

### `/spx:quick` vs the spine

| Signal | Use |
|--------|-----|
| 1-2 files, clear change | `/spx:quick` |
| 3+ files or unclear scope | `/spx:specify` (the spine) |
| New domain concept | `/spx:specify` |
| "Add field to schema" | `/spx:quick` |
| "Add notification system" | `/spx:specify` |

### `/spx:investigate` vs `/spx:bug`

| Signal | Use |
|--------|-----|
| Fast root-cause, throwaway | `/spx:investigate` |
| Bug worth tracking as an artifact | `/spx:bug` (assess → fix → test) |
| Intermittent / race condition | `/spx:investigate --parallel` |

### `/spx:full` vs manual phases

| Signal | Use |
|--------|-----|
| Well-defined feature, clear scope | `/spx:full` |
| Exploratory, may pivot | Manual: specify → clarify → plan, then decide |
| Want control between phases | Manual spine (optionally `--gates`) |

### `/spx:review` vs `/spx:verify`

| Signal | Use |
|--------|-----|
| Want compile/test/format pass | `/spx:verify` |
| Want architectural feedback | `/spx:review` |
| Pre-PR | Both: `/spx:verify` then `/spx:review` |

## Reference Skills (auto-loaded, not invoked directly)

These load automatically when you edit matching files:

| Skill | Triggers on |
|-------|-------------|
| `liveview-patterns` | `*_live.ex`, `*_component.ex`, `*.sface` |
| `ecto-patterns` | Migrations, schemas, changesets, `from(` |
| `phoenix-contexts` | Context modules, router, controllers |
| `security` | Auth files, session, password |
| `testing` | `*_test.exs`, factories, fixtures |
| `oban` | Workers, `use Oban.Worker` |
| `elixir-idioms` | GenServer, mix tasks, general `.ex` |
| `deploy` | Dockerfile, fly.toml, runtime.exs |

## Workflow Cheat Sheet

```text
New feature:     /spx:specify → /spx:clarify → /spx:plan → /spx:tasks → /spx:implement → /spx:review
Full auto:       /spx:full
Quick fix:       /spx:quick
Bug (fast):      /spx:investigate
Bug (tracked):   /spx:bug
Pre-PR:          /spx:verify → /spx:review
Research:        /spx:research [topic]
Evaluate lib:    /spx:research --library [name]
Resume work:     /spx:implement --continue
Post-fix lesson: /spx:compound  (or /spx:learn)
Permissions:     /spx:permissions
```
