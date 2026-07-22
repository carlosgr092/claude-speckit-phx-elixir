# Engineering Constitution — [PROJECT_NAME]

<!--
  This scaffold mirrors the Article I-IX structure of the shipped canonical
  corpus (memory/constitution.md). The Iron-Law text is the ONE canonical
  source (D3): /spx:constitution seeds a project's constitution.md from it,
  fills [PROJECT_NAME] / [DATE] / version placeholders, and regenerates the
  four derived enforcement copies (CLAUDE.md block, SubagentStart injection,
  iron-law-verifier checks, codex P1-P3 rubric). Add ONLY project-specific
  principles under Article IX; never dilute Articles I-VIII to make an
  artifact pass.
-->

Version: [CONSTITUTION_VERSION] | Ratified: [RATIFICATION_DATE] | Last amended: [LAST_AMENDED_DATE]

Specifications do not serve code — code serves specifications. Debugging means fixing
the spec or plan that produced wrong code. Artifacts under `specs/<feature>/` are the
sole source of intent. WHAT/WHY live in spec.md; HOW lives exclusively in plan.md.
Uncertainty is marked, never guessed: `[NEEDS CLARIFICATION: question]`.

## Article I — Core Principles

<!-- Seven principles (canonical). NON-NEGOTIABLE ones drive the gates in plan/analyze/implement. -->

- **P-I. Scope-First Authorization (NON-NEGOTIABLE).** [All data access scoped to the
  authenticated scope; ownership verified before mutation; no client-trusted IDs.]
- **P-II. Thin Web, Fat Context (NON-NEGOTIABLE).** [Zero `Repo.` / business logic in the
  web layer; cross-context access only via public context APIs.]
- **P-III. Deterministic Core.** [Pure domain logic; injectable Clock; external effects
  behind a behaviour/adapter.]
- **P-IV. No N+1 (NON-NEGOTIABLE).** [No `Repo` call inside `Enum`/`for`; preload or
  aggregate in the query; every collection task declares its preloads.]
- **P-V. Idempotent Jobs.** [Oban workers retry-safe; `unique` for user-triggered actions;
  every job task ships an idempotency test.]
- **P-VI. Verification Gate (NON-NEGOTIABLE).** [Work is DONE only when format, compile
  (warnings-as-errors), test, credo, and sobelow pass; never "should work".]
- **P-VII. Spec Authority.** [analyze read-only; converge append-only; constitution
  conflicts are automatically CRITICAL; principles change only via /spx:constitution.]

## Article II — Iron Laws (canonical numbering; violations trigger the STOP protocol)

<!-- The full numbered corpus (LiveView, Ecto, Oban, Security, OTP/Elixir, Contexts,
     Testing, Deploy/Ops, Code style, Verification) lives in memory/constitution.md.
     On any violation: STOP, state "This would violate Iron Law [n]", show what was
     written, show the correct pattern, ask "Should I apply this fix?". -->

[Canonical Iron Laws — seeded verbatim from memory/constitution.md Article II.]

## Article III — Workflow Laws

[W1-W23 — canonical from memory/constitution.md. Phase STOPs, verify-after-every-task,
retry caps, read-only review, solutions-first, plan gates, scoped verification.]

## Article IV — Complexity Router (EXECUTE BEFORE EVERY RESPONSE to a work request)

[CLASSIFY -> SCORE -> ROUTE (<=2 /spx:quick; 3-6 /spx:specify -> clarify -> plan; 7-10
full pipeline + analyze + checklist; >10 /spx:full) -> INTERVIEW -> LOAD skills -> SPAWN
agents -> PROCEED. Canonical table in memory/constitution.md Article IV.]

## Article V — Conditional Stack Annexes (selected at constitution time, re-checked at SessionStart)

<!-- Include ONLY the annexes matching this project's mix.exs (self-gated, D9). -->

[OBAN | OBAN PRO | ASH | TIDEWAVE annexes — canonical from memory/constitution.md Article V.]

## Article VI — Skill and Agent Execution Enforcement

[Skills are procedures; spawning is mandatory when declared; every skill produces its
artifact; "already implemented" is a finding; agent output goes to files. Canonical.]

## Article VII — Enforcement Channels (all four MUST stay in sync with this document)

[CLAUDE.md block + SubagentStart injection + PostToolUse verifier + judgment review
(iron-law-judge + codex P1-P3). Regenerating all derived copies is mandatory on every
amendment. Canonical from memory/constitution.md Article VII.]

## Article VIII — Governance and Amendment

[Specialist delegation binding; amendments only via /spx:constitution (semver + Sync
Impact Report); field lessons via /spx:learn; principles never diluted. Canonical.]

## Article IX — Project-Specific Principles

<!--
  ACTION REQUIRED: Add principles unique to [PROJECT_NAME] here (domain rules,
  compliance standards, deployment policies). These EXTEND — never override —
  Articles I-VIII. Leave empty if none.
-->

- [PROJECT_PRINCIPLE_1_NAME]: [PROJECT_PRINCIPLE_1_DESCRIPTION]
- [PROJECT_PRINCIPLE_2_NAME]: [PROJECT_PRINCIPLE_2_DESCRIPTION]

---

**Governance**: This constitution supersedes all other practices. Amendments require a
Sync Impact Report and consistency propagation into templates and commands via
/spx:constitution. All PRs/reviews verify compliance; complexity must be justified in the
plan's Complexity Tracking table.

**Version**: [CONSTITUTION_VERSION] | **Ratified**: [RATIFICATION_DATE] | **Last Amended**: [LAST_AMENDED_DATE]
