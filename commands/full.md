---
name: spx:full
description: Autonomous driver over the WHOLE spec-driven chain — specify, clarify, plan, tasks, analyze, checklist, implement, verify, review, fix cycles, converge, compound. State machine in progress.md, cycle caps, optional human gates. Use for large features or end-to-end autonomous delivery.
argument-hint: "<feature description> [--gates|--auto] [--scope full|backend-only|frontend-only] [--codex] [--lean] [--max-cycles N] [--max-retries N] [--max-blockers N]"
---

## User Input

```text
$ARGUMENTS
```

Treat `$ARGUMENTS` as the feature description plus optional flags. If empty, ask for the
feature description and stop.

**Wrong-input guard**: if the argument is a path to an existing `specs/<feature>/plan.md`,
do NOT re-plan it — the plan phase already happened. Say so and recommend `/spx:implement`.

## What this command is

`/spx:full` is the autonomous **driver over the whole /spx chain** (D4) — never a parallel
mini-flow. It runs the real phase commands in order behind one state machine, with optional
human gates lifted from spec-kit's `workflow.yml`. All execution happens inside the
`full-driver` agent; this command only parses flags and dispatches.

```text
/spx:full = /spx:specify → [gate] → /spx:clarify → /spx:plan → [gate] → /spx:tasks
            → /spx:analyze → /spx:checklist → /spx:implement → verify → /spx:review
            → (triage → fix → verify) → /spx:converge → compound
```

## Flags

| Flag | Default | Meaning |
|------|---------|---------|
| `--gates` | off | Human approval gates ON. Two gates (from workflow.yml): `review-spec` after specify, `review-plan` after plan. Each is approve/reject; reject aborts cleanly, preserving state. |
| `--auto` | **on** | Both gates auto-approve; fully autonomous. Mutually exclusive with `--gates`. |
| `--scope full\|backend-only\|frontend-only` | `full` | workflow.yml scope input, preserved. Narrows research fan-out and review focus (e.g. `backend-only` skips frontend research/review tracks). |
| `--codex` | off | Codex CLI joins the `/spx:review` panel on **every** review cycle (forwards to the codex-reviewer track). Missing CLI degrades to a SKIPPED note — never fails. Consensus findings (a Claude agent **and** codex) are marked HIGH CONFIDENCE. |
| `--lean` | off | Propagate the `--lean` preset (D6) into specify/plan/tasks/implement (minimal artifact bodies). |
| `--max-cycles N` | 10 | Max plan→review→fix cycles before stopping INCOMPLETE. |
| `--max-retries N` | 3 | Max retries per task before a BLOCKER. |
| `--max-blockers N` | 5 | Max blockers before stopping BLOCKED. |

## Execution

This command is a **thin dispatcher**. Do all the driving inside the `full-driver` agent —
do NOT run phases in this outer context.

1. Parse `$ARGUMENTS` into the feature description and the flags above. Resolve mode
   (`--gates` vs `--auto`, default `--auto`), scope, cycle caps, and pass-through flags
   (`--codex`, `--lean`).
2. Self-gate note: the Elixir-specific steps inside the driver (mix compile/format/credo/test,
   Iron-Law checks) activate only when `mix.exs` exists. In a non-Elixir repo the driver runs
   the pure speckit spine (D9).
3. Spawn the driver:

   ```
   Agent(subagent_type: "claude-speckit-phx-elixir:full-driver", prompt: """
   Feature: <description>
   Mode: gates | auto
   Scope: full | backend-only | frontend-only
   Flags: --codex? --lean?
   Cycle caps: max_cycles=<N> max_retries=<N> max_blockers=<N>

   Drive the full spec-driven cycle end-to-end per your state machine.
   Persist state in specs/<feature>/progress.md.
   Emit ONLY gate questions (when gates are on) and the final completion signal.
   """, mode: "bypassPermissions")
   ```

4. When the driver returns, surface only its terminal signal:
   `<promise>DONE</promise>` (completed), `<promise>ABORTED</promise>` (gate reject),
   `INCOMPLETE` (max cycles), `BLOCKED` (max blockers), or `ERROR` — plus the path to
   `specs/<feature>/progress.md`. Do not re-narrate the run.

## ZERO Narration (HARD RULE)

This is a **hard rule, not a suggestion**. NEVER write "Let me now...", "Now I need
to...", "I'll now...", "Next, I will...", or any preamble before a tool call. Just call the
tool. Only output text for: gate questions, errors, phase transitions, and the final
completion signal. The state machine and `progress.md` ARE the record — chat narration is
not. If you catch yourself narrating, delete the text and make the tool call.

## Iron Laws

1. **NEVER skip verification** — every task passes `mix compile --warnings-as-errors` (and
   scoped `mix test`) before the next; full suite at the final gate. (Self-gated on mix.exs.)
2. **Respect cycle limits** — when `--max-cycles` / `--max-blockers` is exhausted, STOP with
   INCOMPLETE/BLOCKED and list remaining work. Never loop indefinitely.
3. **One state transition at a time** — follow the driver's state machine strictly; each
   state produces the artifacts the next one consumes.
4. **Agent output is findings, not fixes** — review agents report; only the implement/fix
   states change code.
5. **ZERO narration in autonomous mode** — see above.

## Resume

State lives in `specs/<feature>/progress.md`; plan/tasks checkboxes ARE the state. To resume
an interrupted run, re-invoke `/spx:full <same feature>` (the driver reads `progress.md` and
continues from the first unchecked task) or run `/spx:implement` directly against the
existing `tasks.md`.
