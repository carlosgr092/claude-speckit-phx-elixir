---
name: spx:implement
description: Execute the implementation plan by processing all tasks in tasks.md — task-loop engine with per-task verification, 3-retry BLOCKERs, an Elixir/Phoenix Verification Gate, review-triage, and a specific-file git protocol.
argument-hint: "[--from <task-id>] [--continue] [--lean] | optional implementation guidance"
handoffs:
  - /spx:analyze
  - /spx:checklist
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Flags

- `--from <task-id>` — Resume execution starting at a specific task (e.g., `--from T012` or `--from P2-T3`). Skip directly to it regardless of earlier unchecked tasks (run the consistency check in the resume rules first).
- `--continue` — Resume the in-progress feature from `tasks.md` checkboxes and the feature scratchpad. No task argument needed; find the first unchecked task and proceed.
- `--lean` — Minimal loop: run only per-task `mix format` + `mix compile --warnings-as-errors` + phase `mix test`; SKIP the specialist Verification Gate (`verification-runner`, `parallel-reviewer`) and the review-triage step. Use for small/greenfield features where the full gate is overkill.

## Pre-Execution Checks

**Check for extension hooks (before implementation)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_implement` key
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- When constructing the slash command from a hook command id, map it to its `/spx:*` command: `speckit.git.commit` -> `/spx:git-commit`, `speckit.git.feature` -> `/spx:git-feature`, `speckit.git.initialize` -> `/spx:git-init`, `speckit.agent-context.update` -> `/spx:agent-context`.
- For each executable hook, output the following based on its `optional` flag:
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```
  - **Mandatory hook** (`optional: false`):
    ```
    ## Extension Hooks

    **Automatic Pre-Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}

    Wait for the result of the hook command before proceeding to the Outline.
    ```
    After emitting the block above you MUST actually invoke the hook and wait for it to finish before continuing.
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

## Outline

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/check-prerequisites.sh --json --require-tasks --include-tasks` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot"). FEATURE_DIR is the feature workspace `specs/<NNN-slug>/`; its scratchpad, progress, reviews, and summaries all live under it (D2) — never under `.claude/plans/`.

2. **Check checklists status** (if FEATURE_DIR/checklists/ exists):
   - Scan all checklist files in the checklists/ directory
   - For each checklist, count:
     - Total items: All lines matching `- [ ]` or `- [X]` or `- [x]`
     - Completed items: Lines matching `- [X]` or `- [x]`
     - Incomplete items: Lines matching `- [ ]`
   - Create a status table:

     ```text
     | Checklist | Total | Completed | Incomplete | Status |
     |-----------|-------|-----------|------------|--------|
     | ux.md     | 12    | 12        | 0          | ✓ PASS |
     | test.md   | 8     | 5         | 3          | ✗ FAIL |
     | security.md | 6   | 6         | 0          | ✓ PASS |
     ```

   - Calculate overall status:
     - **PASS**: All checklists have 0 incomplete items
     - **FAIL**: One or more checklists have incomplete items

   - **If any checklist is incomplete**:
     - Display the table with incomplete item counts
     - **STOP** and ask: "Some checklists are incomplete. Do you want to proceed with implementation anyway? (yes/no)"
     - Wait for user response before continuing
     - If user says "no" or "wait" or "stop", halt execution
     - If user says "yes" or "proceed" or "continue", proceed to step 3

   - **If all checklists are complete**:
     - Display the table showing all checklists passed
     - Automatically proceed to step 3

3. Load and analyze the implementation context:
   - **REQUIRED**: Read tasks.md for the complete task list and execution plan
   - **REQUIRED**: Read plan.md for tech stack, architecture, and file structure
   - **IF EXISTS**: Read data-model.md for entities and relationships
   - **IF EXISTS**: Read contracts/ for API specifications and test requirements
   - **IF EXISTS**: Read research.md for technical decisions and constraints
   - **IF EXISTS**: Read `.specify/memory/constitution.md` for governance constraints
   - **IF EXISTS**: Read quickstart.md for integration scenarios
   - **MANDATORY context read (prevents rework)**: Read `FEATURE_DIR/scratchpad.md` if present — it records dead-ends, decisions, and handoffs from prior sessions. Then Grep `.claude/solutions/` for solved patterns matching the feature domain. Apply findings: skip dead-ends, follow prior decisions, reuse patterns. If a task's intent is ambiguous, ask the user rather than guessing — corrections are expensive.

4. **Project Setup Verification**:
   - **REQUIRED**: Create/verify ignore files based on actual project setup:

   **Detection & Creation Logic**:
   - Check if the following command succeeds to determine if the repository is a git repo (create/verify .gitignore if so):

     ```sh
     git rev-parse --git-dir 2>/dev/null
     ```

   - Check if `mix.exs` exists → create/verify `.gitignore` covers the Elixir/Phoenix patterns below
   - Check if Dockerfile* exists or Docker in plan.md → create/verify .dockerignore
   - Check if terraform files (*.tf) exist → create/verify .terraformignore
   - Check if .helmignore needed (helm charts present) → create/verify .helmignore

   **If ignore file already exists**: Verify it contains essential patterns, append missing critical patterns only
   **If ignore file missing**: Create with full pattern set for detected technology

   **Common Patterns by Technology** (from plan.md tech stack):
   - **Elixir/Phoenix**: `/_build/`, `/deps/`, `/cover/`, `/doc/`, `*.ez`, `*.beam`, `erl_crash.dump`, `.elixir_ls/`, `.lexical/`, `/priv/static/assets/`, `/priv/static/cache_manifest.json`, `/tmp/`, `*.log`, `.env*`, `npm-debug.log`
   - **Node.js/JavaScript/TypeScript** (Phoenix assets): `assets/node_modules/`, `dist/`, `build/`, `*.log`, `.env*`
   - **Python**: `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `dist/`, `*.egg-info/`
   - **Go**: `*.exe`, `*.test`, `vendor/`, `*.out`
   - **Rust**: `target/`, `debug/`, `release/`, `*.rs.bk`, `*.rlib`, `.idea/`, `*.log`, `.env*`
   - **Universal**: `.DS_Store`, `Thumbs.db`, `*.tmp`, `*.swp`, `.vscode/`, `.idea/`

   **Elixir-specific ignore notes**:
   - NEVER ignore `mix.lock` — it is committed (reproducible builds).
   - NEVER ignore `priv/repo/migrations/` — migrations are source.
   - For Ash projects, NEVER hand-edit or ignore `priv/resource_snapshots/**` — owned by `mix ash.codegen`.

   **Tool-Specific Patterns**:
   - **Docker**: `_build/`, `deps/`, `.git/`, `Dockerfile*`, `.dockerignore`, `*.log*`, `.env*`, `priv/static/`
   - **Terraform**: `.terraform/`, `*.tfstate*`, `*.tfvars`, `.terraform.lock.hcl`
   - **Kubernetes/k8s**: `*.secret.yaml`, `secrets/`, `.kube/`, `kubeconfig*`, `*.key`, `*.crt`

5. Parse tasks.md structure and extract:
   - **Task phases**: Setup, Tests, Core, Integration, Polish
   - **Task IDs**: `T001`-style IDs and/or `[Pn-Tm]` phase-task IDs
   - **`[agent]` routing tags**: e.g. `- [ ] [P2-T2][ecto] Add password_hash field` — parse the `[agent]` annotation for specialist routing (see Task Routing below)
   - **Task dependencies**: Sequential vs parallel execution rules (`[P]` markers, `### Parallel:` headers)
   - **Task details**: description, file paths, parallel markers
   - **Execution flow**: Order and dependency requirements

## Execution Engine (task loop)

**Tasks.md checkboxes ARE the state.** `[x]` = done, `[ ]` = pending. No separate JSON state file — resume by re-reading tasks.md. Drive the loop:

6. **Discover verification tools first (Elixir — when `mix.exs` exists)**: read `mix.exs` (`deps/0`, `aliases/0`, `cli/0` preferred_envs) and `.check.exs`. Detect `:credo`, `:dialyxir`, `:sobelow`, `:ex_check`, `:excoveralls`, and any composite alias (`mix check`, `mix ci`, `mix precommit`). Prefer a project composite runner over individual steps; verify the dep is in `mix.lock` before relying on it, and fall back to individual steps if it errors. Report the detected strategy once, then stop narrating verification.

7. Execute implementation following the task plan:
   - **Phase-by-phase execution**: Complete each phase before moving to the next.
   - **AUTO-CONTINUE between phases**: when all tasks in a phase complete, mark the phase done and IMMEDIATELY start the next phase. Do NOT stop or ask permission between phases. Only stop at a BLOCKER or when ALL phases are done.
   - **Respect dependencies**: sequential tasks in order; `[P]`/`### Parallel:` tasks may run together only if they touch different files and share no mutable state (schemas, helpers).
   - **Follow TDD approach**: execute test tasks before their corresponding implementation tasks.
   - **File-based coordination**: tasks affecting the same files run sequentially.

   **Per-task steps**:
   1. **Route** by `[agent]` annotation (see Task Routing). `[direct]` or unannotated → implement directly.
   2. **Implement** the task (write whole modules, not patches — keeps tasks idempotent on resume).
   3. **Verify** (see Verification tiers). On pass: mark `[X]` in tasks.md AND append a one-line implementation note inline (key decisions, actual values, gotchas) — this survives context compaction since tasks.md is re-read on resume. Example: `- [X] T012 [ecto] Add user schema — citext email, composite index on [user_id, status]`.
   4. **On failure**: retry up to 3 times with error context; after 3 failures create a BLOCKER (see BLOCKER protocol) and write a DEAD-END to the scratchpad.
   - **Batch checkbox edits**: when several tasks complete together (parallel group / resume catch-up), update their checkboxes in ONE edit pass — never one edit per checkbox.
   - **Token efficiency**: do NOT narrate each verification step; run tool calls directly. Narrate only non-obvious decisions and failures.

8. **Task Routing** (Elixir `[agent]` tags — when `mix.exs` exists):

   | Annotation | Specialist (`subagent_type: "claude-speckit-phx-elixir:<agent>"`) | Verification |
   |------------|------------------------------------------------------------------|--------------|
   | `[ecto]` | ecto-schema-designer | migrate + test |
   | `[liveview]` | liveview-architect | test + smoke |
   | `[oban]` | oban-specialist | test + manual |
   | `[otp]` | otp-advisor | test |
   | `[security]` | security-analyzer | test + audit |
   | `[test]` | testing-reviewer | test only |
   | `[direct]` | (none — implement directly) | compile + format |

   **Fallback keyword routing** (legacy plans with no `[agent]` tag), priority order — security ALWAYS wins:
   auth/login/password/token/permission → security-analyzer; schema/migration/field/changeset → ecto-schema-designer; worker/job/queue/oban → oban-specialist; genserver/supervisor/process → otp-advisor; liveview/component/mount → liveview-architect; test/assert/mock → testing-reviewer; no match → direct execution.

   **Parallel groups**: tasks under `### Parallel:` may be spawned as background subagents in ONE message; wait for ALL to complete, then run the phase checkpoint. Never parallelize tasks that edit the same file, depend on each other, are schema/migration tasks (compilation lock), or carry `[security]`.

9. **Verification tiers** (Elixir — when `mix.exs` exists; scoped to minimize redundant runs):
   - **Per-task**: `mix format` (or `--check-formatted`) + `mix compile --warnings-as-errors` on changed files. The PostToolUse hook checks format but does NOT modify files — run `mix format` explicitly.
   - **Per-phase**: `mix compile --warnings-as-errors` + `mix test <affected_test_files>` (scope to affected paths, NOT the full suite) + `mix credo --strict` (if `:credo` in deps).
   - **Per-feature smoke (Tidewave, if available)**: behavioral smoke via `project_eval` (create → fetch → verify) or `get_logs level: :error` after navigation.
   - **Final gate**: `mix test` (full suite) — run ONCE at the end, not per-phase. `mix dialyzer` / `mix sobelow --config` pre-PR if those deps exist.
   - Skip any unavailable tool with a one-line note (e.g., "Credo: skipped — not installed").
   - **Ask before E2E/integration** (`mix playwright.test`, coverage, etc.) — respect `preferred_envs`/`cli/0` for the correct `MIX_ENV`.

   **Non-Elixir repos (spine)**: run whatever compile/test commands plan.md declares after each phase; the loop, retry, BLOCKER, and git protocol are identical.

10. **Checkpoint after each task passes**: mark `[X]` + inline note in tasks.md; update phase status when all its tasks are done; append a progress entry to `FEATURE_DIR/progress.md`:

    ```markdown
    ## {time} - Task Completed [T012]
    **Task**: Add user schema
    **Files**: lib/my_app/accounts/user.ex, priv/repo/migrations/xxx.exs
    **Verification**: PASS (compile, format, credo, test)
    ```

11. **BLOCKER protocol (max 3 retries)**: after 3 failed attempts on a task, stop the loop and record a blocker in `FEATURE_DIR/progress.md`:

    ```markdown
    ## BLOCKER
    **Task ID**: T012
    **Description**: Implement register_user/1
    **Attempts**: 3
    **Error History**:
    1. Compile error: undefined function hash_password/1
    2. Test failure: expected {:ok, _} got {:error, changeset}
    3. Test failure: [:email, "has already been taken"]
    **Suggested Actions**: {concrete next steps}
    **Resume**: `/spx:implement --from T012`
    ```

    Also append a DEAD-END to `FEATURE_DIR/scratchpad.md` so future sessions don't retry the same failed approach:

    ```markdown
    ### [HH:MM] DEAD-END: {task}
    Tried: {approach}. Failed because: {root cause}. See BLOCKER in progress.md.
    ```

<!-- ELIXIR-PHOENIX START -->
12. **Elixir/Phoenix Verification Gate (when `mix.exs` exists — Constitution Principle VI; SKIP under `--lean`)**:
   - After each completed task group, for the affected app(s) run `mix format`, `mix compile --warnings-as-errors`, and `mix test`. Halt the group on failure and fix before proceeding.
   - At phase checkpoints, spawn `subagent_type: "claude-speckit-phx-elixir:verification-runner"` (it discovers credo, dialyzer, sobelow, and custom aliases from `mix.exs`) and resolve what it reports.
   - Before marking the feature DONE, spawn `subagent_type: "claude-speckit-phx-elixir:parallel-reviewer"` (tests + security + Ecto + LiveView), writing to `FEATURE_DIR/reviews/`. Treat any Constitution MUST violation it finds as blocking.
   - While coding: keep the web layer (`lib/*_web`) free of `Repo.` (Principle II) and enforce the data-access scope (e.g., `current_scope`) on every data access (Principle I).
<!-- ELIXIR-PHOENIX END -->

13. **Review triage (after the Verification Gate; SKIP under `--lean`)**: if the parallel-reviewer produced findings, compress them first — spawn `subagent_type: "claude-speckit-phx-elixir:context-supervisor"` to read `FEATURE_DIR/reviews/` and write `FEATURE_DIR/summaries/review-consolidated.md`; read only that. Categorize by severity (BLOCKER, WARNING, SUGGESTION). If blockers exist, present them via `AskUserQuestion` with `multiSelect: true`, severity shortcuts first:

    ```
    AskUserQuestion:
      question: "Review found these issues. Which do you want to fix?"
      header: "Findings"
      multiSelect: true
      options:
        - label: "All BLOCKERs ({count})"
          description: "Fix all critical issues that must be resolved"
        - label: "All WARNINGs ({count})"
          description: "Fix all should-fix quality issues"
        - label: "{finding short name}"
          description: "BLOCKER: {1-line description}"
    ```

    Max 4 options per call (2 for severity shortcuts, 2 for individual findings); batch the rest into follow-up calls. Create fix tasks ONLY for selected findings, apply them, then re-run the affected verification tier. Never auto-proceed to another `/spx:*` phase — report and stop.

14. **Git protocol** (only when the repo is a git repo; commits are offered, not forced — mirrors the optional git-commit hooks):
   - **Stage SPECIFIC files only — NEVER `git add -A` or `git add .`**.
   - **Per phase** (not per task): offer a commit with a phase summary, e.g. `git add <files>` then `git commit -m "feat(<slug>): complete Phase N - <name>"`.
   - **Before human intervention** (BLOCKER): offer to commit the working state so it isn't lost.
   - Leave the final commit decision to the user. Follow the project's commit conventions; do not add tool attribution to commit messages.

## Resume rules

- `--continue`: re-read tasks.md, count `[x]` vs `[ ]`, resume at the first `[ ]`.
- `--from <task-id>`: jump to that task. **Consistency check**: every task before the target should already be `[x]`; if earlier tasks are unchecked, warn and ask whether to skip them (mark done), go back and complete them, or something else.
- **Stale-plan check**: if tasks.md predates this session (file mtime), spot-check 2-3 referenced files before executing — assumptions may have drifted.
- **Idempotent execution**: write whole modules/migrations (use `create_if_not_exists`, check module existence with `grep -rn "defmodule ..." lib/` before creating) so re-running a task never duplicates code.

## Context-exhaustion playbook

For long features (>10 tasks) that risk compaction:
- The inline implementation notes on each `[X]` task and the `FEATURE_DIR/scratchpad.md` HANDOFF/DEAD-END entries are the durable memory — always write them.
- On resume after compaction, re-read tasks.md + scratchpad.md BEFORE writing any code.
- If a feature is too large, suggest splitting it (re-run `/spx:tasks` or `/spx:plan`) rather than pushing through a single overloaded run.

15. Completion validation:
   - Verify all required tasks are completed and marked `[X]`
   - Check that implemented features match the original specification
   - Validate that tests pass and coverage meets requirements
   - Confirm the implementation follows the technical plan

Note: This command assumes a complete task breakdown exists in tasks.md. If tasks are incomplete or missing, suggest running `/spx:tasks` first to regenerate the task list.

## Mandatory Post-Execution Hooks

**You MUST complete this section before reporting completion to the user.**

Check if `.specify/extensions.yml` exists in the project root.
- If it does not exist, or no hooks are registered under `hooks.after_implement`, skip to the Completion Report.
- If it exists, read it and look for entries under the `hooks.after_implement` key.
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue to the Completion Report.
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- When constructing the slash command from a hook command id, map it to its `/spx:*` command (see the mapping in Pre-Execution Checks).
- For each executable hook, output the following based on its `optional` flag:
  - **Mandatory hook** (`optional: false`) — **You MUST emit `EXECUTE_COMMAND:` for each mandatory hook**:
    ```
    ## Extension Hooks

    **Automatic Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}
    ```
    After emitting the block above you MUST actually invoke the hook and wait for it to finish before continuing.
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```

## Completion Report

Report final status with summary of completed work. If blockers remain, list them and auto-write a HANDOFF to `FEATURE_DIR/scratchpad.md` (status, blockers, first unchecked task ID, key decisions) for a fresh-session resume. **NEVER** auto-start `/spx:analyze`, review, or any other phase — suggest next steps and stop.

## Done When

- [ ] All tasks in tasks.md completed and marked `[X]`
- [ ] Implementation validated against specification, plan, and test coverage
- [ ] Verification Gate passed (or `--lean` acknowledged) and any selected review findings fixed
- [ ] Extension hooks dispatched or skipped according to the rules in Mandatory Post-Execution Hooks above
- [ ] Completion reported to user with summary of completed work
