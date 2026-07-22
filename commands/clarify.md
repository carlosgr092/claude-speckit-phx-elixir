---
name: spx:clarify
description: Identify underspecified areas in the current feature spec by asking up to 5 highly targeted clarification questions, scored across coverage dimensions, and encoding the answers back into the spec.
argument-hint: "[focus area or context]"
handoffs:
  - label: Build Technical Plan
    agent: spx:plan
    prompt: Create a plan for the spec. I am building with...
scripts:
  sh: ${CLAUDE_PLUGIN_ROOT}/scripts/check-prerequisites.sh --json --paths-only
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution: Git commit hook (before_clarify)

This command wires the `before_clarify` hook from `${CLAUDE_PLUGIN_ROOT}/templates/extensions.yml`. Mapping: `speckit.git.commit` → `/spx:git-commit`. Resolution: `.specify/extensions.yml` `hooks.before_clarify` overrides the inline default (skip silently on parse failure). Inline default: one **optional** (`optional: true`) hook — `speckit.git.commit`.

- **Optional hook**: emit an offer block —

  ```text
  ## Extension Hooks

  **Optional Pre-Hook**: git
  Command: `/spx:git-commit`
  Description: Auto-commit before spec clarification

  Prompt: Commit outstanding changes before clarification?
  To execute: `/spx:git-commit`
  ```

  Run `/spx:git-commit` only if accepted.
- Treat missing `enabled` as enabled; skip `enabled: false`; do not evaluate non-empty `condition`. For a **mandatory** hook, emit `EXECUTE_COMMAND:` and actually invoke it before the Outline. Skip silently if nothing is registered and `.specify/extensions.yml` is absent.

## Outline

Goal: detect and reduce ambiguity or missing decision points in the active feature specification and record the clarifications directly in the spec file.

Note: run (and complete) this workflow BEFORE `/spx:plan`. If the user explicitly skips clarification (exploratory spike), you may proceed but must warn that downstream rework risk increases.

Execution steps:

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/check-prerequisites.sh --json --paths-only` from repo root **once**. Parse minimal JSON fields: `FEATURE_DIR`, `FEATURE_SPEC` (optionally capture `IMPL_PLAN`, `TASKS`). If JSON parsing fails, abort and instruct the user to re-run `/spx:specify` or verify the feature workspace (`.specify/feature.json`). For single quotes in args, use escape syntax (`'I'\''m Groot'`) or double-quote.

2. **IF EXISTS**: Load `.specify/memory/constitution.md` for project principles and governance constraints.

3. Load the current spec file. Perform a structured ambiguity & coverage scan using the taxonomy below. For each category mark status: Clear / Partial / Missing. Produce an internal coverage map used for prioritization (do not output the raw map unless no questions will be asked).

   Functional Scope & Behavior — core user goals & success criteria; explicit out-of-scope; user roles/personas.
   Domain & Data Model — entities/attributes/relationships; identity & uniqueness; lifecycle/state transitions; data volume/scale.
   Interaction & UX Flow — critical journeys/sequences; error/empty/loading states; accessibility/localization.
   Non-Functional Quality Attributes — performance; scalability; reliability/availability; observability; security & privacy; compliance.
   Integration & External Dependencies — external services/APIs and failure modes; import/export formats; protocol/versioning.
   Edge Cases & Failure Handling — negative scenarios; rate limiting/throttling; conflict resolution (concurrent edits).
   Constraints & Tradeoffs — technical constraints (language, storage, hosting); explicit tradeoffs/rejected alternatives.
   Terminology & Consistency — canonical glossary terms; avoided synonyms/deprecated terms.
   Completion Signals — acceptance-criteria testability; measurable Definition of Done.
   Misc / Placeholders — TODO markers; ambiguous adjectives ("robust", "intuitive") lacking quantification.

   **Coverage-dimension scoring overlay** (absorbed from the brainstorm interview methodology). In parallel with the taxonomy, score the 6 requirement dimensions 0-2 to prioritize which gaps are worth a question:

   | Score | Meaning | Example |
   |-------|---------|---------|
   | 0 | Uncovered — dimension not mentioned | — |
   | 1 | Partial — vague reference ("maybe some caching") | — |
   | 2 | Sufficient — concrete detail ("Redis cache, 15min TTL") | — |

   Dimensions: **What** (specific behavior), **Why** (problem/need), **Scope** (in/out, v1 vs future), **Where** (affected contexts/routes/modules), **How** (approach/constraints), **Edge** (failure modes, scale, permissions). Coverage is **sufficient at total ≥ 8/12** (≥ 4 dimensions fully covered). After each answer, mentally update scores and target the lowest-scoring dimension next. Ask **Scope within the first 3-4 questions** — especially for "optimize/improve X" specs where scope determines viable approaches.

   For each category/dimension with Partial/Missing or a low score, add a candidate question unless clarification would not materially change implementation/validation, or is better deferred to planning (note internally).

   **Phoenix probe categories** (add only when `mix.exs` exists at the repo root — D9 self-gating; skip entirely for non-Elixir repos). When the spec touches these areas, probe the concrete decision:
   - **Data / Ecto** — new schema vs extend existing? uniqueness constraint on which field? expected row volume (drives index/pagination)? money as `:decimal`/`:integer`, never `:float`?
   - **LiveView / real-time** — list size (>100 items → streams)? live updates via PubSub, or request/response? SEO/crawler-indexed route (affects mount strategy)?
   - **Background work / Oban** — is any step async/retryable? idempotency key? which queue?
   - **Auth / security** — which roles may perform this? per-`handle_event` authorization needed? any user-supplied value that must not become an atom?
   - **Context boundaries** — which existing Phoenix context owns this, or is it a new domain?

4. Generate (internally) a prioritized queue of candidate questions (**max 5**). Constraints: each answerable by a 2-5 option multiple-choice OR a short ≤5-word answer; only include questions whose answers materially impact architecture, data modeling, task decomposition, test design, UX, operational readiness, or compliance; balance category coverage (highest impact first); exclude already-answered, trivial-stylistic, or plan-level execution details unless blocking correctness; favor clarifications that reduce downstream rework. If more than 5 remain, select top 5 by (Impact × Uncertainty).

5. Sequential questioning loop (interactive) — present EXACTLY ONE question at a time:
   - **Multiple-choice**: analyze all options; pick the most suitable by best practices, common patterns, risk reduction, and spec-visible goals. Present the recommendation prominently: `**Recommended:** Option [X] - <reasoning>`. Then a Markdown table:

     | Option | Description |
     |--------|-------------|
     | A | <Option A description> |
     | B | <Option B description> |
     | C | <Option C description> (add D/E as needed up to 5) |
     | Short | Provide a different short answer (≤5 words) (include only if a free-form alternative fits) |

     After the table: `You can reply with the option letter (e.g., "A"), accept the recommendation by saying "yes" or "recommended", or provide your own short answer.`
   - **Short-answer** (no meaningful discrete options): give a suggested answer — `**Suggested:** <proposed answer> - <brief reasoning>` — then `Format: Short answer (≤5 words). You can accept the suggestion by saying "yes" or "suggested", or provide your own answer.`
   - After the user answers: if they reply "yes"/"recommended"/"suggested", use your stated recommendation; otherwise validate the answer maps to an option or fits ≤5 words (ask a quick disambiguation if ambiguous — same question, do not advance). Record in working memory (not yet to disk) and move on.
   - Stop when all critical ambiguities are resolved, the user signals completion ("done", "good", "no more"), or you reach 5 asked questions. Never reveal future queued questions. If no valid questions exist at start, immediately report no critical ambiguities.

6. Integration after EACH accepted answer (incremental):
   - Maintain an in-memory spec representation plus raw file contents.
   - First integrated answer: ensure a `## Clarifications` section exists (create it just after the highest-level contextual section per the template); under it create `### Session YYYY-MM-DD` for today.
   - Append `- Q: <question> → A: <final answer>` immediately after acceptance. Then apply the clarification to the most appropriate section(s): functional → Functional Requirements; actor/interaction → User Stories/Actors; data/entities → Data Model; non-functional → Success Criteria > Measurable Outcomes (convert vague adjective to metric); edge/negative → Edge Cases / Error Handling; terminology → normalize across spec (retain original once as `(formerly referred to as "X")` if needed).
   - **Cross-section consistency sweep (mandatory after each answer).** A resolved decision usually touches more than the one "most appropriate" section. After integrating it, scan EVERY other spec section for statements the answer now contradicts and reconcile them in the same write — do not update one section and leave a sibling stale. Check at least: Functional Requirements, User Stories/Actors, Data Model/Key Entities, Success Criteria, **Edge Cases / Error Handling**, Assumptions, Constraints, and the Glossary. Example: resolving "unauthenticated users are redirected, not shown an error" updates the FR but an Edge Case still saying "show a 403" now contradicts it — rewrite that Edge Case too. Replace obsolete contradictory text (never leave two conflicting statements). Save the spec after each integration (atomic overwrite). Preserve formatting and heading hierarchy; keep each insertion minimal and testable.

7. Validation (after EACH write plus a final pass): exactly one bullet per accepted answer (no duplicates); total accepted ≤ 5; no lingering vague placeholders the answer resolved; **no section left contradicting a resolved decision** — re-scan Functional Requirements, User Stories, Data Model, Success Criteria, Edge Cases / Error Handling, Assumptions, and Constraints against every accepted answer and reconcile any survivor; valid Markdown (only new headings allowed: `## Clarifications`, `### Session YYYY-MM-DD`); consistent canonical terminology.

8. Write the updated spec back to `FEATURE_SPEC`.

9. **Re-validate Spec Quality Checklist** (if `FEATURE_DIR/checklists/requirements.md` exists; skip silently otherwise): read it; identify every GitHub task-list checkbox line (`- [ ]`/`- [x]`/`- [X]`, tolerant of leading whitespace, outside code fences); snapshot each marker state; re-evaluate against the updated spec; toggle only the marker portion of lines whose state changed (unchecked→checked if now passing, checked→unchecked if now failing; leave unchanged markers as-is to avoid cosmetic diffs); save. Compute Newly passing / Regressions / Still unchecked and the before/after pass counts (e.g. "12/16 → 15/16").

Behavior rules: if no meaningful ambiguities, respond "No critical ambiguities detected worth formal clarification." and suggest proceeding. If the spec file is missing, instruct the user to run `/spx:specify` first (do not create a spec here). Never exceed 5 asked questions (retries for one question do not count). Avoid speculative tech-stack questions unless the absence blocks functional clarity. Respect early-termination signals. If quota is reached with unresolved high-impact categories, flag them under Deferred with rationale.

Context for prioritization: `$ARGUMENTS`

## Post-Execution: Git commit hook (after_clarify)

**You MUST complete this section before reporting completion.**

Resolve `hooks.after_clarify` (`.specify/extensions.yml` overrides, else inline default). Mapping: `speckit.git.commit` → `/spx:git-commit`. Inline default: one **optional** (`optional: true`) hook —

```text
## Extension Hooks

**Optional Hook**: git
Command: `/spx:git-commit`
Description: Auto-commit after spec clarification

Prompt: Commit clarification changes?
To execute: `/spx:git-commit`
```

Run `/spx:git-commit` only if accepted. For a mandatory hook, emit `EXECUTE_COMMAND:` and invoke it. Skip silently if nothing is registered and `.specify/extensions.yml` is absent.

## Completion Report

Report (after the loop ends or on early termination):

- Number of questions asked & answered.
- Path to the updated spec.
- Sections touched (list names).
- Coverage-dimension scores (What/Why/Scope/Where/How/Edge, final X/12).
- Spec quality checklist status (if re-validated): before/after pass counts and any items that changed state (newly checked and regressions); list remaining unchecked items.
- Coverage summary table per taxonomy category: Resolved / Deferred / Clear / Outstanding.
- If any Outstanding or Deferred remain, recommend whether to proceed to `/spx:plan` or run `/spx:clarify` again later.

## Done When

- [ ] Spec ambiguities identified and clarifications integrated into the spec file
- [ ] Coverage dimensions scored; spec quality checklist re-validated (if it exists)
- [ ] Extension hooks dispatched or skipped per the Post-Execution section
- [ ] Completion reported with questions answered, sections touched, scores, checklist status, and coverage summary
