---
name: spx:constitution
description: Create or update the project constitution (the canonical Iron-Law corpus) from interactive or provided principle inputs, regenerating every derived enforcement copy and keeping dependent templates in sync.
argument-hint: "[principle updates] [--lean]"
handoffs:
  - label: Build Specification
    agent: spx:specify
    prompt: Implement the feature specification based on the updated constitution. I want to build...
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Flags

- `--lean` — produce a minimal constitution body from `${CLAUDE_PLUGIN_ROOT}/presets/lean/constitution.md` (a short principles + Iron-Laws digest, no long rationale prose). If that preset file is absent, keep only the principle name line + one non-negotiable rule sentence per Article and drop the extended rationale/governance narrative. All validation, versioning, derived-copy regeneration, and hook steps below still run.

## Pre-Execution: Git initialization hook (before_constitution)

This command wires the `before_constitution` hook from `${CLAUDE_PLUGIN_ROOT}/templates/extensions.yml`. Hook command names map to `/spx:*` as follows (dot-form → run-as):

| extensions.yml command | Run as |
|------------------------|--------|
| `speckit.git.initialize` | `/spx:git-init` |
| `speckit.git.commit` | `/spx:git-commit` |

Resolution order:

1. If `.specify/extensions.yml` exists in the project root, read its `hooks.before_constitution` entries — they override the inline default. If the YAML cannot be parsed, skip hook checking silently and fall back to the inline default.
2. Inline default (from `templates/extensions.yml`): one **mandatory** (`optional: false`) hook — `speckit.git.initialize`.

For each enabled hook (treat a missing `enabled` field as enabled; skip hooks with `enabled: false`; do not evaluate non-empty `condition` expressions — defer those to the HookExecutor):

- **Mandatory hook** (`optional: false`):
  ```
  ## Extension Hooks

  **Automatic Pre-Hook**: git
  Executing: `/spx:git-init`
  EXECUTE_COMMAND: speckit.git.initialize

  Wait for the result of the hook command before proceeding to the Outline.
  ```
  After emitting the block above you MUST actually invoke `/spx:git-init` and wait for it to finish before continuing.
- **Optional hook** (`optional: true`): emit an offer block naming `/spx:git-init` and its prompt; run it only if the user accepts.

If no hooks are registered and `.specify/extensions.yml` does not exist, still honor the inline mandatory `git-init` default; if the project is not a git repo and the user declines initialization, warn and continue.

## Outline

You are updating the project constitution at `.specify/memory/constitution.md`. This file is the ONE canonical Iron-Law corpus (Articles I–IX) with unified numbering. Your job is to (a) collect/derive concrete values, (b) fill the constitution precisely, (c) regenerate every derived enforcement copy, and (d) propagate any amendments across dependent artifacts.

**First-run seeding mode (do this BEFORE filling anything).** Check whether `.specify/memory/constitution.md` already exists:

- **It EXISTS → amend mode.** Skip the menu below and go straight to the flow (load, apply the user's principle updates, regenerate). NEVER re-seed over an existing constitution.
- **It does NOT exist → seed mode.** Do not dump 53 laws silently. Ask the user how to seed it with a single-choice `AskUserQuestion`:

  1. **Full curated (recommended)** — copy the shipped default `${CLAUDE_PLUGIN_ROOT}/memory/constitution.md` as the base (7 principles + the full Iron-Law corpus + workflow laws + complexity router); stack detection (step 2) then drops the annexes the project does not use. These laws are correctness enforcement, not preferences.
  2. **Curated, review and trim** — copy the same default, then present the Article II law GROUPS (LiveView, Ecto, Oban, OTP, Security, Contexts & Boundaries, Testing, Deploy/Ops, Style) plus the workflow laws, and let the user keep or drop whole groups. Record every dropped group with a one-line reason in the Sync Impact Report (dropping enforcement is a conscious choice), and renumber the remaining laws contiguously.
  3. **Blank (spec-kit style)** — start from `.specify/templates/constitution-template.md` (the Article I–IX structure with placeholders, no Iron Laws pre-loaded); the user authors their own principles from scratch.

  In EVERY mode, then offer to add the user's project-specific principles and rules to **Article IX** (their own values — kept verbatim and never overwritten by future amendments). `--lean` implies mode 1 with the lean preset body.

Follow this execution flow:

1. Load the existing constitution at `.specify/memory/constitution.md`.
   - Identify every placeholder token of the form `[ALL_CAPS_IDENTIFIER]`.
   **IMPORTANT**: The user might require fewer or more principles than the template default. If a number is specified, respect it — follow the general template. Update the doc accordingly.

2. **Detect the project stack** (init absorb — governs which conditional Article V annexes stay active). If `mix.exs` exists at the repo root, Grep it to detect:
   - Phoenix version (`phoenix.*"~>`), Ecto version (`ecto.*"~>`)
   - Oban vs Oban Pro (`"oban"`, `"oban_pro"`), Ash (`"ash"`), Tidewave (`"tidewave"`)
   - Project size (count `lib/**/*.ex`)
   Select conditional annexes accordingly: keep the Oban / Ash / LiveView / Tidewave sections only when their dep is present; drop the annex (do not leave it as "N/A") when the stack does not use it. **If `mix.exs` is absent, this is not an Elixir project — retain only the stack-agnostic principles and skip all Elixir annex selection (D9 self-gating).**

3. Collect/derive values for placeholders:
   - If user input supplies a value, use it. Otherwise infer from existing repo context (README, docs, prior constitution versions if embedded).
   - Governance dates: `RATIFICATION_DATE` is the original adoption date (if unknown, ask or mark TODO); `LAST_AMENDED_DATE` is today (2026-07-21) if changes are made, otherwise keep previous.
   - `CONSTITUTION_VERSION` increments by semantic-versioning rules:
     - MAJOR: backward-incompatible governance/principle removals or redefinitions.
     - MINOR: new principle/section added or materially expanded guidance.
     - PATCH: clarifications, wording, typo fixes, non-semantic refinements.
   - If the bump type is ambiguous, propose reasoning before finalizing.

4. Draft the updated constitution content:
   - Replace every placeholder with concrete text (no bracketed tokens left except intentionally retained slots — explicitly justify any left).
   - Preserve heading hierarchy. Each Principle section: succinct name line, paragraph or bullets capturing non-negotiable rules, explicit rationale if not obvious.
   - Ensure the Governance section lists the amendment procedure, versioning policy, and compliance review expectations.
   - Straight quotes `""` only, never angle quotes (Article on style; D13). Under `--lean`, follow the Flags section above.

5. Consistency propagation checklist (active validations):
   - Read `.specify/templates/plan-template.md` — ensure its "Constitution Check" gates align with the updated principles.
   - Read `.specify/templates/spec-template.md` — update if the constitution adds/removes mandatory sections or constraints.
   - Read `.specify/templates/tasks-template.md` — ensure task categorization reflects new or removed principle-driven task types (observability, versioning, testing discipline, migration sequencing).
   - Read each installed `/spx:*` command/skill surface to verify no outdated references remain when generic guidance is required.
   - Read runtime guidance docs (`README.md`, `docs/quickstart.md`, agent-specific files) and update references to changed principles.

6. **Regenerate every derived enforcement copy (D3 — MANDATORY on ANY amendment).** `memory/constitution.md` is the single source of truth; the copies below MUST NOT drift from it. Per `${CLAUDE_PLUGIN_ROOT}/memory/derivations.md`, regenerate each:
   - **SubagentStart Iron-Laws injection** (`hooks/scripts/inject-iron-laws.sh`) — re-emit the Article II laws (plus any active Article V annexes) as the flat `additionalContext` bullet list.
   - **iron-law-verifier checks** (`hooks/scripts/iron-law-verifier.sh`) — update the grep/AST checks to match the current programmatically checkable law numbers and patterns.
   - **codex P1–P3 review rubric** (`templates/agents-md-block.md`) — rebuild the rubric bullets from the current laws; preserve any "Known non-issues".
   - **condensed CLAUDE.md block** (`templates/claude-md-block.md`) — re-render the 7-step router + law summary; rewrite all command refs to `/spx:*`.
   In an installed project, the two user-facing copies (the CLAUDE.md marker block and the AGENTS.md `## Review guidelines` block) are re-rendered in place via their managed markers (see step 8); the hook/verifier copies apply when developing the plugin itself. NEVER edit a derived copy by hand to change a rule — edit the constitution, then regenerate.

7. Produce a Sync Impact Report (prepend as an HTML comment at the top of the constitution file after update):
   - Version change: old → new
   - Modified principles (old title → new title if renamed)
   - Added sections / Removed sections
   - Templates + derived copies requiring updates (✅ updated / ⚠ pending) with file paths
   - Follow-up TODOs if any placeholders intentionally deferred.

8. **Marker-managed install of the user-facing copies** (init absorb):
   - Upsert the condensed constitution block into the project `CLAUDE.md` between `<!-- ELIXIR-PHOENIX-PLUGIN:START -->` and `<!-- ELIXIR-PHOENIX-PLUGIN:END -->` (or the plugin's marker pair). NEVER overwrite content outside the markers — user-written rules must be preserved verbatim.
   - If `command -v codex` succeeds (or the user asks), upsert the P1–P3 review rubric into the project `AGENTS.md` between `ELIXIR-PHOENIX-REVIEW-GUIDELINES:START/END`; STOP and ask if an unmanaged `## Review guidelines` section already exists. When codex is absent and not requested, skip silently.

9. Validation before final output:
   - No remaining unexplained bracket tokens. Version line matches the report. Dates ISO `YYYY-MM-DD`.
   - Principles are declarative, testable, free of vague language.
   - All four derived copies agree with the constitution.

10. Write the completed constitution back to `.specify/memory/constitution.md` (overwrite).

11. Output a final summary with the new version + bump rationale, files flagged for manual follow-up, and a suggested commit message (e.g., `docs: amend constitution to vX.Y.Z (principle additions + governance update)`).

Formatting & Style: use Markdown headings exactly as in the template (no level demotion/promotion); wrap long rationale lines (<100 chars ideally); single blank line between sections; no trailing whitespace. If the user supplies partial updates, still perform validation, versioning, and derived-copy regeneration. If critical info is missing, insert `TODO(<FIELD_NAME>): explanation` and list it under deferred items. Do not create a new template; always operate on the existing `.specify/memory/constitution.md`.

## Post-Execution: Git commit hook (after_constitution)

Resolve `hooks.after_constitution` the same way as the Pre-Execution section (`.specify/extensions.yml` overrides; otherwise the inline default from `templates/extensions.yml`). Inline default: one **optional** (`optional: true`) hook — `speckit.git.commit` → `/spx:git-commit`.

- **Optional hook**: emit an offer block —
  ```
  ## Extension Hooks

  **Optional Hook**: git
  Command: `/spx:git-commit`
  Description: Auto-commit after constitution update

  Prompt: Commit constitution changes?
  To execute: `/spx:git-commit`
  ```
  Run `/spx:git-commit` only if the user accepts.
- **Mandatory hook** (`optional: false`): emit `EXECUTE_COMMAND: {command}`, then actually invoke it and wait.

If no hooks are registered and `.specify/extensions.yml` does not exist, skip silently.

## Done When

- [ ] Constitution written to `.specify/memory/constitution.md` and validated (no stray tokens, version matches report)
- [ ] All four derived enforcement copies regenerated from the constitution (D3)
- [ ] User-facing CLAUDE.md / AGENTS.md marker blocks upserted without touching content outside markers
- [ ] Extension hooks dispatched or skipped per the Pre/Post sections
- [ ] Final summary reported with version, bump rationale, and suggested commit message
