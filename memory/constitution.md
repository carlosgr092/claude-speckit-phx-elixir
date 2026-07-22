# Engineering Constitution — [PROJECT_NAME]

Version: 0.1.0 | Ratified: [DATE] | Last amended: [DATE]

Specifications do not serve code — code serves specifications. Debugging means fixing
the spec or plan that produced wrong code. Artifacts under `specs/<feature>/` are the
sole source of intent. WHAT/WHY live in spec.md; HOW lives exclusively in plan.md.
Uncertainty is marked, never guessed: `[NEEDS CLARIFICATION: question]`.

## Article I — Core Principles

- **P-I. Scope-First Authorization (NON-NEGOTIABLE).** All data access MUST be scoped to
  the authenticated scope (`current_scope` on Phoenix 1.8+; equivalent Authority pattern
  before 1.8). Ownership MUST be verified before any mutation (no IDOR). Client-supplied
  IDs MUST never be trusted without a scoped lookup. Every plan MUST state its scoping.
- **P-II. Thin Web, Fat Context (NON-NEGOTIABLE).** Zero `Repo.` calls and zero business
  logic in the web layer. Cross-context access only via public context APIs — never
  another context's schemas. Contexts own their data.
- **P-III. Deterministic Core.** Domain logic is pure. Time comes from an injectable
  Clock, not scattered `DateTime.utc_now/0`. External effects (HTTP, LLM, messaging) sit
  behind a behaviour/adapter owned by the project.
- **P-IV. No N+1 (NON-NEGOTIABLE).** No `Repo` call inside `Enum`/`for` over rows.
  Preload or aggregate in the query; counts and sums in SQL. Every collection task in
  tasks.md MUST declare its preloads.
- **P-V. Idempotent Jobs.** Oban workers MUST be retry-safe, use `unique` options for
  user-triggered actions, and every job-enqueuing task ships an idempotency test.
- **P-VI. Verification Gate (NON-NEGOTIABLE).** Work is DONE only when
  `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test`,
  `mix credo`, and `mix sobelow` (when installed) all pass. New behaviour ships with
  tests. Never say "should work" — run the checks and show the result (Iron Law 22).
- **P-VII. Spec Authority.** analyze is strictly read-only; converge is append-only;
  constitution conflicts are automatically CRITICAL — fix the artifacts, never dilute
  the principle. Principles change only via /spx:constitution.

## Article II — Iron Laws (canonical numbering; violations trigger the STOP protocol)

On any violation: STOP. State "This would violate Iron Law [n]", show what was written,
show the correct pattern, ask "Should I apply this fix?".

LiveView
1. NO unconditional DB queries in mount — mount runs twice; default `assign_async`; SEO
   routes use `connected?/1` plus a cache-backed disconnected branch (the dead render IS
   the crawler-indexed HTML).
2. ALWAYS streams for lists over ~100 items — regular assigns are O(n) memory per user.
3. CHECK `connected?/1` before PubSub subscribe.
18. CHECK changeset errors BEFORE UI debugging.
21. NEVER `assign_new` for values refreshed every mount (locale, current user, timezone,
    org) — use `assign/3`.
24. MATCH `{:error, %Ecto.Changeset{}}` explicitly — bare `{:error, _}` hides form errors.
28. EXTRACT needed values into plain variables BEFORE `assign_async` closures — never
    capture the socket (full-struct capture, stale by the time the closure runs).
29. mount/3 holds session/static state; handle_params/3 owns ALL URL-derived state
    (handle_params re-runs on live_patch; mount does not).
30. NEVER pass the socket into context/business functions — pass explicit values.

Ecto
4. NEVER `:float` for money — `:decimal` or integer cents.
5. ALWAYS pin with `^` in queries — never interpolate user input (SQL injection).
6. SEPARATE queries for `has_many` preloads; JOIN for `belongs_to` (row multiplication).
15. NO implicit cross joins — `from(a in A, b in B)` without `on:` is a Cartesian product.
17. DEDUP before `cast_assoc` with shared data.
19. HIDDEN inputs for ALL required embedded fields.
31. `cast/4` is for EXTERNAL/untrusted input ONLY — internal state changes go through
    `change/2`/`put_change/3`.
32. NO Rails-style polymorphic associations (`*_type` + `*_id`) — separate FK columns,
    join tables, or abstract-concrete tables instead.
33. CONSTRAINTS beat validations for anything race-prone (uniqueness, FKs) — validations
    are UX pre-checks only; every `unique_constraint/3` MUST mirror a real unique index
    created in a migration.
34. Migration order: create/alter the OWNING column before any constraint, index, or
    backfill that references it (owning-column-first).

Oban
7. Jobs MUST be idempotent.
8. Args use STRING keys (`%{"user_id" => id}`).
9. NEVER store structs in args — store IDs.
9b. Smart Engine: never limit snoozes via `attempt` (it rolls the counter back — infinite
    loop; real incident: 72k orphaned jobs). Use `meta["snoozed"]`.
35. HANDLE every perform return shape (`:ok`, `{:ok, _}`, `{:error, _}`, `{:cancel, _}`,
    `{:snooze, n}`) — an unhandled shape is a silent retry.
36. NO large data in args — args are persisted, logged, and re-copied on every retry;
    store IDs and refetch.

Security
10. NO `String.to_atom/1` on user input (atom-exhaustion DoS).
11. AUTHORIZE in EVERY LiveView `handle_event` — never trust mount-time auth; URL params
    in `handle_params` MUST be scope-checked (IDOR).
12. NEVER `raw/1` with untrusted content (XSS).
37. VALIDATE at the boundary — every external input passes changeset/validation at its
    entry point (controller, LiveView event, channel, job args).
38. SECRETS via `runtime.exs` env reads ONLY — never compile-time config, never in code;
    scope values are set in the struct/query by the server, NEVER cast from params; CSRF
    protection stays on.

OTP / Elixir
13. NO process without a runtime reason (concurrency, state, isolation — never code
    structure). Functions -> Agent/ETS -> GenServer, in that order.
14. SUPERVISE all long-lived processes — no bare `GenServer.start_link`/`Agent.start_link`
    in production code.
16. `@external_resource` for compile-time file reads.
20. WRAP third-party library APIs behind project-owned facades.
23. Mix tasks start only what they need — `Mix.Task.run("app.config")` +
    `Application.ensure_all_started/1`; never `app.start` (boots endpoint + Oban).
25. CAPTURE Gettext/CLDR locale before spawning — locale is process-local; pass it
    explicitly to Task/GenServer.
27. NEVER a bare `rescue _ ->` — rescue named exception types only (see the verified
    taxonomy); `reraise e, __STACKTRACE__` when re-raising; rescue only external code.

Contexts & boundaries
39. NO side effects in schema modules — schemas are pure data-mapping; multi-step writes
    live in the context behind `Ecto.Multi`.
40. NEVER refactor context boundaries without `mix xref graph`/`callers` evidence first.

Testing
41. `async: true` by DEFAULT — drop it only for real shared-state contention (named
    processes, ETS, external resources), with a comment saying why.
42. DB isolation via the Ecto SQL Sandbox — never truncation or manual cleanup.
43. MOCK ONLY at boundaries the project owns — Mox on project behaviours; never mock
    internal context functions.
44. Every external service sits behind a behaviour so tests verify the CONTRACT
    (behaviours-as-contracts).
45. Factories default to `build/2`; `insert/2` only when persistence is the point.
46. NO `Process.sleep` in tests — `assert_receive`, `Task.await`, or polling helpers.
47. `verify_on_exit!` in setup for every Mox test.
48. Factories set ONLY the schema's required fields by default — optional data is
    explicit per test.

Deploy / Ops
49. Env-dependent config is RUNTIME config (`runtime.exs` env reads) — never
    compile-time config baked into the release.
50. Graceful shutdown with a drain window >= 60s so LiveView sockets and in-flight Oban
    jobs finish.
51. Health endpoints (liveness + readiness) that touch no heavy dependencies.
52. Production DB connections use SSL `verify_peer` (pinned CA) — never `verify_none`.
53. NEVER CPU-limit BEAM containers (scheduler collapse under throttling); memory limits
    are fine.

Code style
26. COMMENTS ARE NOT COMMIT MESSAGES — reasoning goes in the commit/PR; keep only durable
    facts (footguns, invariants, quirks). Straight quotes "" only, never angle quotes.

Verification
22. VERIFY BEFORE CLAIMING DONE — run `mix compile && mix test`, show the result, state
    what remains unverified.

## Article III — Workflow Laws

W1. NEVER auto-transition between phases — every phase STOPS and presents next steps
    (plan-STOP is hook-enforced). Autonomous /spx:full is the sole exception and obeys
    its cycle caps (10 cycles / 3 retries / 5 blockers).
W2. Verify after EVERY task (`mix compile --warnings-as-errors`); affected tests per
    phase; the full suite ONCE at the final gate.
W3. Max 3 retries then BLOCKER + scratchpad DEAD-END entry. Dead ends are never retried.
W4. tasks.md checkboxes ARE the execution state. Stage specific files — never `git add -A`.
W5. Review is READ-ONLY; findings are not fixes. Reviewers may write ONLY their own
    findings file.
W6. Search `.claude/solutions/` before investigating anything fresh.
W7. Read the error LITERALLY; check the obvious first; changeset errors before UI
    debugging (Ralph Wiggum protocol).
W8. Supply-chain audits never mutate mix.exs/mix.lock and never auto-install tools;
    every BLOCK cites rule_id + file:line. Never auto-approve a vet ledger entry; the
    lockfile wins over the ledger.
W9. Never force-push (`--force-with-lease` allowed); never `mix ecto.reset|drop` without
    explicit human approval; treat `MIX_ENV=prod mix` as suspect (hook-enforced).
W10. Never auto-post to GitHub without approval; never resolve a PR thread without a reply.
W11. Lessons never edit plugin cache files — they go to project CLAUDE.md, auto-memory,
    or `.claude/solutions/` (via /spx:learn and /spx:compound).
W12. MEASURE before optimizing; database first; never benchmark in dev mode.
W13. Three-strikes rule before extracting shared code.
W14. Specify writes at most 3 `[NEEDS CLARIFICATION]` markers; clarify asks at most 5
     questions, ONE at a time, each with a Recommended option; integrate after each answer.
W15. The implement checklist gate stops and asks when any checklist is incomplete.
W16. Feature state lives in `.specify/feature.json`, never in the git branch name.
W17. Orchestrators fan out in ONE message, run agents in background, wait for ALL, and
     compress 4+ outputs through context-supervisor; agent output goes to files, never
     raw into chat. Subagent nesting depth <= 5.
W18. Checklists test requirements quality ("unit tests for English"), never
     implementation behavior; >= 80% of items carry traceability.
W19. Test-First: tests are written, approved with the plan, and CONFIRMED FAILING before
     implementation code exists (red before green).
W20. Plan gates (Phase -1 — what the plan-template "Constitution Check" verifies):
     Simplicity (<=3 projects, no future-proofing), Anti-Abstraction (use the framework
     directly; ONE model representation per concept), Integration-First (contracts
     defined and contract tests written before implementation). Any violation MUST be
     justified in the plan's Complexity Tracking table — unjustifiable complexity means
     simplify, not proceed.
W21. Scoped verification: format/credo/test runs are SCOPED to the files changed in the
     task (repo-wide only at the final gate); respect the project's custom MIX_ENV
     conventions before running mix commands.
W22. Sibling File Check: after fixing a pattern in one file, grep sibling files for the
     same defect before closing the task.
W23. Debugging discipline: on any constraint error read the constraint NAME first (it
     names table+column — go straight to the migration that defines it); intermittent
     test failures are race conditions until proven otherwise.

## Article IV — Complexity Router (EXECUTE BEFORE EVERY RESPONSE to a work request)

STEP 1 CLASSIFY: bug fix -> score 0-2, go to STEP 4. Review/analysis -> respond.
Feature request -> STEP 2.

STEP 2 SCORE (show the calculation "Complexity: {score} ({factors}) -> {route}"):

| Factor | Points |
|---|---|
| Single file change | 0 |
| 2-3 files | +2 |
| 4+ files or multiple contexts | +3 |
| New domain concept | +3 |
| Follows existing pattern | -2 |
| Keywords: auth, login, password, token, session | +4 |
| Keywords: payment, billing, stripe, checkout | +5 |
| External API or new dependency | +2 |

STEP 3 ROUTE: <=2 -> proceed or /spx:quick; 3-6 -> /spx:specify -> clarify -> plan;
7-10 -> full pipeline with /spx:plan --depth deep + analyze + checklist; >10 -> recommend
/spx:full. Security score >=4 -> MANDATORY security-analyzer in plan AND analyze.

STEP 4 INTERVIEW (score >=3 or security; skip only on explicit "quick"/"just do it"):
new feature -> scope in/out; security -> "Who should access this?" + "What if
compromised?"; database -> "Rollback needed?" + "How much data?"; Oban -> "Which queue?"
+ "Retry behavior?".

STEP 5 LOAD skills silently by file pattern (`*_live.ex` -> liveview-patterns;
`*_worker.ex` -> oban; migrations/schemas -> ecto-patterns; `*auth*` -> security;
`*_test.exs` -> testing; any `.ex` -> elixir-idioms).

STEP 6 SPAWN agents when triggered (plan -> phoenix-patterns-analyst always; workers ->
oban-specialist; LiveView design -> liveview-architect; migrations -> ecto-schema-designer;
auth -> security-analyzer ALWAYS; new deps -> hex-library-researcher).

STEP 7 PROCEED, remembering the Verification Gate.

## Article V — Conditional Stack Annexes (selected at constitution time, re-checked at SessionStart)

- **OBAN** (`:oban,` in mix.exs): laws 7-9 active; queue pool rule
  `pool_size >= num_queues + sum(limits) + buffer`.
- **OBAN PRO** (`:oban_pro,`): `process/1` NOT `perform/1` (`perform/1` is a silent
  no-op in Pro); `@impl Oban.Pro.Worker`; standard Oban patterns DO NOT apply; law 9b.
- **ASH** (`:ash,` or `use Ash.Resource|Ash.Domain`): domain code interfaces — never
  `Ash.create/read` in the web layer; actor/scope at QUERY PREP, never execution;
  generators first (`mix ash.gen.resource`, `mix ash.codegen`); migrations via
  `mix ash.codegen && mix ash.migrate` — never hand-edit, never `ecto.migrate`; NEVER
  edit `priv/resource_snapshots/`; no direct `Repo.*` on resource-backed code; research
  via `mix usage_rules.search_docs`. LiveView/security/OTP laws still apply.
- **TIDEWAVE** (dep present + MCP reachable): prefer `mcp__tidewave__get_docs`,
  `project_eval`, `execute_sql_query`, `get_logs` over file-based alternatives; smoke
  test after features; check error logs after edits; gather schemas+routes before planning.

## Article VI — Skill and Agent Execution Enforcement

1. Skills are PROCEDURES, not suggestions — follow their numbered steps.
2. Agent spawning is MANDATORY when a skill/command says "spawn".
3. Every skill MUST produce its artifact file.
4. "Already implemented" is a FINDING, not an exit.
5. Read the SKILL/command body BEFORE executing it.
6. No unauthorized judgment calls, no undefined early exits.
7. Agent output MUST be saved to `specs/<feature>/research/{agent}-report.md` (or the
   command's declared output dir) — orchestrators read files, never chat.

## Article VII — Enforcement Channels (all four MUST stay in sync with this document)

1. Marker-managed CLAUDE.md block (installed by /spx:constitution, refreshed by
   /spx:agent-context).
2. SubagentStart injection (hooks/scripts/inject-iron-laws.sh) — subagents load zero
   skills; the laws reach them only through this hook.
3. PostToolUse programmatic verifier (iron-law-verifier.sh: laws 4, 10, 12, 14, 15, 21)
   + security-reminder + format + debug-statement hooks.
4. Judgment review: iron-law-judge agent (analyze/review) + codex P1-P3 rubric in
   AGENTS.md.
Regenerating all derived copies is a mandatory step of every constitution amendment.

## Article VIII — Governance and Amendment

- Specialist delegation is binding: plan consults ecto-schema-designer /
  liveview-architect / oban-specialist / ash-resource-designer / otp-advisor /
  security-analyzer; analyze runs iron-law-judge / elixir-reviewer / security-analyzer /
  requirements-verifier; implement gates through verification-runner and
  parallel-reviewer.
- Amendments only via /spx:constitution (semver: MAJOR removals/redefinitions, MINOR new
  principles, PATCH wording), with a Sync Impact Report and consistency propagation into
  templates and commands (including the ELIXIR-PHOENIX fusion blocks).
- Field lessons enter via /spx:learn ("Iron Laws (continued)" appends to the PROJECT
  CLAUDE.md); universal lessons get promoted into this document.
- Principles are never diluted to make an artifact pass.

## Article IX — Project-Specific Principles

<!-- Project-authored. Empty in the shipped default. /spx:constitution fills this with a
project's OWN principles and rules; Article IX belongs to the project — kept verbatim and
never overwritten by future amendments or by re-running the command. Articles I-VIII are
the canonical baseline and are never diluted to make an artifact pass. -->

_None in the shipped default. Add your project's own principles here via `/spx:constitution`._
