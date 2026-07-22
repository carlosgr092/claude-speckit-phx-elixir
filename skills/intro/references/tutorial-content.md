# Plugin Tutorial Content

Content for each section of the `/spx:intro` tutorial.
Present ONE section at a time with AskUserQuestion between sections.
IMPORTANT: Present ALL content in each section — every paragraph, table, and code block. Do NOT abbreviate or summarize.

## Contents

- [Section 1: Welcome](#section-1-welcome)
- [Section 2: The Spec-Driven Spine](#section-2-the-spec-driven-spine)
- [Section 3: Knowledge & Safety Net](#section-3-knowledge--safety-net)
- [Section 4: Hooks & Behavioral Rules](#section-4-hooks--behavioral-rules)
- [Section 5: Constitution, Review & Gaps](#section-5-constitution-review--gaps)
- [Section 6: Cheat Sheet & Next Steps](#section-6-cheat-sheet--next-steps)

---

## Section 1: Welcome

### What This Plugin Does

This plugin **is** spec-kit's spec-driven development flow, carrying the full
Elixir/Phoenix intelligence base fused inside it: **specialist agents**,
**auto-loaded domain knowledge**, and a project **constitution** (the Iron Laws).
It turns a general-purpose AI into an opinionated Elixir pair programmer that
writes a spec first, plans against it, and implements task by task.

### The Core Concept

Everything hangs off a linear **spine** — you move a feature from idea to code
one reviewable phase at a time:

```text
/spx:constitution → /spx:specify → /spx:clarify → /spx:plan → /spx:tasks
                  → /spx:analyze → /spx:checklist → /spx:implement
        |              |              |             |            |
        v              v              v             v            v
   engineering    what & why     resolve       design +     execute the
   principles     (the spec)     ambiguity     task list    checkboxes
```

Each phase reads the previous phase's artifacts under `specs/<NNN-slug>/`.
The spec becomes the contract. The plan becomes tasks. Tasks become checkboxes.
Reviews catch mistakes. Compounded knowledge makes future work faster.

Around that spine sit capability commands (review, investigate, perf, deps, ...)
for the work that does not fit a straight line.

### What You Get

| Feature | What It Does |
|---------|-------------|
| The spec-driven spine | constitution → specify → clarify → plan → tasks → analyze → checklist → implement |
| 26 specialist agents | Ecto, LiveView, security, OTP, Oban, Ash, deployment experts |
| 48 skills | Domain knowledge + a command for every capability |
| Project constitution | Non-negotiable Iron Laws, enforced by hooks and agents |
| Auto-loaded references | Context-aware docs loaded when you edit relevant files |
| Tidewave integration | Runtime debugging when Tidewave MCP is connected |

---

## Section 2: The Spec-Driven Spine

### The Full Flow

For any feature that deserves structure, walk the spine in order:

```bash
# 0. Brainstorm (optional) — explore requirements interactively first
/spx:brainstorm Add some kind of notification system

# 1. Specify — turn the idea into a spec.md (this is the entry point)
/spx:specify Add user avatars with S3 upload

# 2. Clarify — answer up to 5 targeted questions to remove ambiguity
/spx:clarify

# 3. Plan — design artifacts: plan.md, data-model.md, contracts/, research.md
/spx:plan

# 3b. Brief (optional) — understand the plan's WHY before building
/spx:brief specs/user-avatars/plan.md

# 4. Tasks — an ordered, checkboxed task list with Elixir task rules
/spx:tasks

# 5. Analyze (optional) — read-only cross-artifact consistency gate
/spx:analyze

# 6. Implement — execute tasks phase by phase, verifying as it goes
/spx:implement

# 7. Review — parallel agents check idioms, security, tests, and cross-check
#    implementation vs. the spec (the requirements contract)
/spx:review

# 8. Compound — capture what you learned for future reference
/spx:compound Fixed S3 upload timeout with multipart streaming
```

New feature? **Always start at `/spx:specify`** — `/spx:plan` needs a spec to
plan against. Prefer hands-off? `/spx:full` runs the whole spine autonomously.

### Shortcuts

Not everything needs the full spine:

| Command | When to Use | Time |
|---------|------------|------|
| `/spx:quick` | Bug fixes, small features (<50 lines, single file) | ~2 min |
| `/spx:full` | Run the whole spine autonomously | ~10 min+ |
| `/spx:investigate` | Debugging — checks obvious things first | ~3 min |
| `/spx:bug` | A bug worth tracking as an artifact (assess → fix → test) | varies |

### Decision Guide

```text
Is it a bug?
  Yes --> Fast root-cause?  --> /spx:investigate
          Track as artifact? --> /spx:bug
  No  --> Do you know what you want?
            No  --> /spx:brainstorm  (or /spx:assess for a go/no-go pipeline)
            Yes --> Is it < 50 lines, one file?
                      Yes --> /spx:quick
                      No  --> Do you want full autonomy?
                                Yes --> /spx:full
                                No  --> /spx:specify then walk the spine
```

### Deepening an Existing Plan

Already have a plan but want to add research or refine it?

```bash
/spx:plan --existing specs/user-avatars/plan.md
```

This spawns specialist agents to analyze your existing plan and enhance it with research findings.

---

## Section 3: Knowledge & Safety Net

### Auto-Loaded Knowledge

The plugin loads relevant reference docs based on what you're editing:

| You're editing... | Plugin loads... |
|-------------------|----------------|
| `*_live.ex` | LiveView patterns, async/streams, components |
| `*_test.exs` | ExUnit patterns, Mox, factory patterns |
| `migrations/*` | Migration patterns, safe operations |
| `*auth*`, `*session*` | Security patterns, authorization rules |
| `router.ex` | Routing patterns, plug patterns, scopes |
| `*_worker.ex` | Oban patterns, idempotency rules |
| `Dockerfile`, `fly.toml`, `runtime.exs` | Deployment patterns |

This means you don't need to explicitly load anything — open a LiveView file and the plugin already knows the patterns.

### Iron Laws (the constitution, always enforced)

Iron Laws live in the project constitution (`memory/constitution.md`) and every
agent enforces them. If your code violates one, the plugin stops and explains
before proceeding.

**Examples:**

| Law | Why |
|-----|-----|
| No unconditional DB queries in mount | mount runs twice; cache-backed branch OK for SEO |
| Use streams for lists >100 items | Regular assigns = O(n) memory per user |
| No `:float` for money | Floating point math loses precision |
| Pin values with `^` in Ecto queries | Prevents SQL injection |
| Jobs must be idempotent | Oban retries on failure |
| No `String.to_atom` with user input | Atom table exhaustion DoS |
| Authorize in EVERY `handle_event` | Mount auth alone is insufficient |

### Analysis & Verification Commands

| Command | What It Does |
|---------|-------------|
| `/spx:verify` | Full check: compile, format, credo, test — plus dialyzer when the project has it configured |
| `/spx:audit` | 5-agent project health audit with scores |
| `/spx:deps-audit` | Audit Hex dep updates for supply-chain risk |
| `/spx:deps-vet` | Record vetted Hex packages in hex_vet.exs ledger |
| `/spx:n1-check` | Detect N+1 query patterns |
| `/spx:assigns-audit` | Audit LiveView socket assigns for memory |
| `/spx:boundaries` | Check Phoenix context boundary violations |
| `/spx:perf` | Performance analysis (Ecto, LiveView, OTP) |

### Tidewave Integration

When Tidewave MCP is connected to your running Phoenix app:

```bash
# Get docs for your exact dependency versions
mcp__tidewave__get_docs "Ecto.Query"

# Execute code in your running app
mcp__tidewave__project_eval "MyApp.Repo.aggregate(User, :count)"

# Query your dev database directly
mcp__tidewave__execute_sql_query "SELECT count(*) FROM users"
```

The plugin automatically prefers Tidewave tools over alternatives when available.

---

## Section 4: Hooks & Behavioral Rules

The plugin uses **layered enforcement** — some things run automatically, some depend on Claude following instructions, some are on-demand. Here's what actually happens:

### Layer 1: Hooks (Automatic, Every Edit)

[Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) run shell scripts automatically after tool use. These are real automation — no instructions needed. Every Elixir hook self-gates on `mix.exs`, so the spec-kit spine works in any repo and the Elixir checks only activate on Elixir projects:

| Hook | Trigger | What It Does |
|------|---------|-------------|
| Dangerous ops block | Before Bash command | Blocks `mix ecto.reset/drop`, `git push --force`, `MIX_ENV=prod` |
| deps-audit gate | Before `mix deps.get/update/compile` | Tiered gate reading the deps-audit sidecar |
| freeze gate | Before Edit/Write | Enforces a scoped edit lock (`/spx:freeze`) |
| Format check | Every `.ex`/`.exs` edit | Runs `mix format --check-formatted`, warns via stderr + exit 2 |
| Iron Law verifier | Every `.ex`/`.exs` edit | Scans code content for Iron Law violations with line numbers |
| Debug stmt warning | Every `.ex` edit | Warns about `IO.inspect`/`dbg()`/`IO.puts` in production code |
| Security reminder | Editing auth/session/password files | Outputs relevant Iron Laws via stderr + exit 2 |
| Plan-stop reminder | Editing `specs/*/plan.md` | Points you toward `/spx:tasks` (skipped in full-mode) |
| Iron Laws injection | Any subagent spawns | Injects the constitution's Iron Laws into subagents via `additionalContext` |
| PreCompact rules | Before context compaction | Re-injects workflow rules via JSON `systemMessage` |

Format check **warns only** — it doesn't auto-fix (that would cause race conditions with the editor).

The PreCompact hook detects active spine phases and re-injects their critical rules before context compaction. This prevents "rule amnesia" where Claude loses behavioral constraints after context is compressed.

### Layer 2: Iron Laws in Skills (Behavioral)

Each domain skill (ecto-patterns, liveview-patterns, security, etc.) embeds its own Iron Laws.
When Claude loads a skill, the laws become active context.
Claude is instructed to **stop and explain** before writing code that violates them.

This is behavioral — it works because the rules are in Claude's context, not because code enforces them. It's effective but not 100% guaranteed.

### Layer 3: Skill Loading by File Type (Behavioral)

CLAUDE.md instructs Claude to load specific skills based on file patterns:

```text
*_live.ex       → liveview-patterns (streams, async, components)
*auth*, *session* → security (authorization, XSS, atom safety)
*_worker.ex     → oban (idempotency, string keys, queue config)
*_test.exs      → testing (ExUnit, Mox, factories)
Any .ex file    → elixir-idioms (always)
```

This is **not plugin infrastructure** — it's instructions that Claude follows. Running `/spx:constitution` (which installs the CLAUDE.md marker block) significantly strengthens it.

---

## Section 5: Constitution, Review & Gaps

### Layer 4: `/spx:constitution` (Strengthens Everything)

Running `/spx:constitution` writes `.specify/memory/constitution.md` and injects
enforcement rules **directly into your project's CLAUDE.md** (and a codex rubric
into AGENTS.md). This is stronger than plugin-level instructions because CLAUDE.md
is always read at session start.

What it adds:

- **Iron Laws with STOP protocol** — explicitly tells Claude to halt on violations
- **Verification rules** — `mix compile --warnings-as-errors && mix format` after code changes
- **Stack-specific annexes** — detects Phoenix version, Oban, Ash, Tidewave from `mix.exs`
- **Regenerated enforcement copies** — the SubagentStart list, iron-law-verifier checks, and codex rubric all derive from the one constitution

```bash
/spx:constitution            # First-time setup / amendment
/spx:init                    # Bootstrap the .specify/ tree (idempotent)
```

If you're finding the plugin inconsistent, running `/spx:constitution` is the single biggest improvement you can make.

### Layer 5: `/spx:review` + Iron Law Judge (On-Demand)

The `iron-law-judge` agent does **pattern-based violation detection** — it uses Grep to search your changed files for known anti-patterns. It runs when you invoke `/spx:review` (and advisory during `/spx:analyze`). Its requirements source defaults to the feature's `spec.md`.

What it catches with automated detection:

- `String.to_atom(` in lib code
- `field :price, :float` in schemas
- `raw(@variable)` (XSS risk)
- `Repo.` calls in LiveView mount without `connected?` guard
- Missing `^` pin in Ecto query fragments

### Layer 6: Planning Sets Structure Early

The `/spx:plan` phase sets naming conventions, context boundaries, and module structure
**before any code exists**. This is where you prevent Rails-y patterns at the architecture
level — fat controllers, service objects, and ActiveRecord patterns get caught in the plan,
not in code review.

### What's NOT Automated (Yet)

Being honest about the gaps:

| Check | Status | Why |
|-------|--------|-----|
| `mix compile --warnings-as-errors` | `/spx:implement` per-task + `/spx:full` VERIFYING | Compilation runs in the implement loop, not per-edit hooks |
| `mix credo` | `/spx:implement` per-phase + on-demand (`/spx:verify`) | Not run per-task edit, only between phases |
| `mix test` | `/spx:implement` final gate + on-demand (`/spx:verify`) | Full suite runs once at the Verification Gate |
| `mix dialyzer` | On-demand (`/spx:verify`) | Takes minutes, not seconds |
| Iron Law detection during coding | Behavioral + verifier hook | `iron-law-judge` is review-time; the verifier hook flags on edit |

### The Honest Summary

```text
AUTOMATIC (hooks):     Format check, security reminders, iron-law verifier, plan-stop,
                       Iron Laws in subagents, PreCompact rule preservation
BEHAVIORAL (Claude):   Iron Laws, skill loading, stop-and-explain
ON-DEMAND (commands):  /spx:review (iron-law-judge), /spx:verify (compile/credo/dialyzer)
STRENGTHENED BY:       /spx:constitution (injects rules into project CLAUDE.md)
```

The plugin works best when all layers are active: `/spx:constitution` for persistent rules, hooks for automatic checks, and `/spx:review` to catch what the behavioral layer missed.

---

## Section 6: Cheat Sheet & Next Steps

### Command Reference

**The spine (use in order):**

| Command | Phase |
|---------|-------|
| `/spx:constitution` | Engineering principles + stack detection |
| `/spx:specify <feature>` | Write the spec (entry point) |
| `/spx:clarify` | Resolve ambiguity (up to 5 questions) |
| `/spx:plan` | Design artifacts with research agents |
| `/spx:plan --existing <file>` | Enhance an existing plan |
| `/spx:tasks` | Ordered, checkboxed task list |
| `/spx:analyze` | Read-only consistency gate |
| `/spx:checklist` | Requirements-quality checklists |
| `/spx:implement` | Execute tasks with verification |
| `/spx:review` | Parallel agent code review |
| `/spx:converge` | Post-implement gap assessment |
| `/spx:compound` | Capture solved problem |

**Standalone:**

| Command | Purpose |
|---------|---------|
| `/spx:quick <task>` | Fast implementation, skip ceremony |
| `/spx:full <feature>` | Autonomous whole-spine driver; `--codex` adds a cross-model review track |
| `/spx:investigate <bug>` | Structured bug investigation |
| `/spx:bug <description>` | Artifact-based bugfix loop |
| `/spx:verify` | Run all quality checks |
| `/spx:research <topic>` | Research with parallel workers, Tidewave-first |
| `/spx:pr-review <PR#>` | Address PR review threads — fix, reply, resolve |
| `/spx:watch-pr <PR#>` | Background-watch a PR for reviews + CI; `--codex` adds a Codex cloud review loop |
| `/spx:codex-loop` | Fix until Codex CLI review is clean (optional — needs codex CLI) |
| `/spx:deps-update` | Bump outdated Hex deps, grouped PRs |
| `/spx:recall <question>` | Recall prior work from past sessions/git |
| `/spx:permissions` | Scan sessions, recommend safe Bash permissions |
| `/spx:doctor` | Read-only plugin/project health check |
| `/spx:help [description]` | Interactive command advisor — helps pick the right command |

**Analysis:**

| Command | Purpose |
|---------|---------|
| `/spx:audit` | Full project health audit |
| `/spx:deps-audit` | Hex dep update supply-chain audit |
| `/spx:deps-vet` | Hex package audit ledger (`hex_vet.exs`) |
| `/spx:perf` | Performance analysis |
| `/spx:n1-check` | N+1 query detection |
| `/spx:assigns-audit` | LiveView memory audit |
| `/spx:boundaries` | Context boundary check |
| `/spx:techdebt` | Technical debt analysis |
| `/spx:trace <function>` | Call chain tracing |
| `/spx:ecto-constraint-debug` | Debug Ecto constraint errors |

**Knowledge:**

| Command | Purpose |
|---------|---------|
| `/spx:learn` | Capture a lesson from a fix |
| `/spx:brief` | Walk through a feature's WHY |
| `/spx:challenge` | Rigorous review mode |

### Playing Nicely With Claude Code Built-Ins

The plugin complements — it doesn't replace — CC's built-in features. A few that pair well with the Elixir workflow:

- **Auto mode + high effort**: run `/spx:full` hands-off. Auto mode routes permission prompts through a safety classifier instead of blocking on you.
- **`/focus`**: hides intermediate tool output. Useful during long `/spx:implement` or `/spx:full` runs when you only care about the final state.
- **Recap**: CC summarizes what happened when you return to a session.
  Our scratchpad (`specs/{slug}/scratchpad.md`) still captures what recap
  can't — checkbox progress, subagent findings, deliberate handoffs.
- **`/less-permission-prompts`**: generic Bash/MCP allowlist scanner. Use `/spx:permissions` for Elixir-specific recommendations (credo, mix, psql, Tidewave) on top of it.

### 3 Tips for Getting the Most Out of the Plugin

1. **Start with `/spx:specify` for any feature that touches multiple files.** Writing the spec first catches architectural issues before you've written code that needs rewriting.

2. **Let Iron Laws stop you.** When the plugin flags a violation, read the explanation.
   These rules exist because the Elixir community learned them the hard way
   (atom exhaustion in prod, N+1 queries at scale, double-mount in LiveView).

3. **Use `/spx:compound` after solving hard bugs.** The solution gets indexed and searchable. Next time you hit something similar, the plugin finds your past solution automatically.

### Next Steps

- Run `/spx:constitution` to set up your project's engineering principles
- Try `/spx:specify` with your next feature to start the spine
- Run `/spx:verify` to see your project's current health
- Run `/spx:audit` for a comprehensive project assessment
