---
name: spx:specify
description: Create or update the feature specification from a natural language feature description, seeding the feature workspace and consuming any brainstorm interview.
argument-hint: "<feature description> [--lean]"
handoffs:
  - label: Build Technical Plan
    agent: spx:plan
    prompt: Create a plan for the spec. I am building with...
  - label: Clarify Spec Requirements
    agent: spx:clarify
    prompt: Clarify specification requirements
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Flags

- `--lean` — write a minimal spec body from `${CLAUDE_PLUGIN_ROOT}/presets/lean/specify.md` (mandatory sections only: user scenarios, functional requirements, success criteria — no optional sections). If the preset is absent, keep only the mandatory template sections and omit optional ones. The quality checklist and hooks still run.

## Pre-Execution: Git feature-branch hook (before_specify)

This command wires the `before_specify` hook from `${CLAUDE_PLUGIN_ROOT}/templates/extensions.yml`. Command-name mapping: `speckit.git.feature` → `/spx:git-feature`; `speckit.git.commit` → `/spx:git-commit`.

Resolution: if `.specify/extensions.yml` exists, its `hooks.before_specify` entries override the inline default (skip silently on parse failure). Inline default: one **mandatory** (`optional: false`) hook — `speckit.git.feature`.

- **Mandatory hook** (`optional: false`):

  ```text
  ## Extension Hooks

  **Automatic Pre-Hook**: git
  Executing: `/spx:git-feature`
  EXECUTE_COMMAND: speckit.git.feature

  Wait for the result of the hook command before proceeding to the Outline.
  ```

  After emitting the block, actually invoke `/spx:git-feature` and wait. It creates/switches to the feature branch and outputs JSON with `BRANCH_NAME` and `FEATURE_NUM`. If the user explicitly provided `GIT_BRANCH_NAME`, pass it through so the branch script uses that exact value.
- Treat missing `enabled` as enabled; skip `enabled: false`; do not evaluate non-empty `condition`. If no hook is registered and `.specify/extensions.yml` is absent, still honor the inline default.

## Outline

The text the user typed after the command **is** the feature description. Assume you always have it available even if `$ARGUMENTS` appears literally below. Do not ask the user to repeat it unless they provided an empty command.

Given that feature description, do this:

1. **Generate a concise short name** (2-4 words) for the feature:
   - Extract the most meaningful keywords; use action-noun format when possible (`add-user-auth`, `fix-payment-bug`); preserve technical terms/acronyms (OAuth2, API, JWT).
   - Examples: "I want to add user authentication" → "user-auth"; "Implement OAuth2 integration for the API" → "oauth2-api-integration"; "Create a dashboard for analytics" → "analytics-dashboard".

2. **Consume a brainstorm interview if present** (D5):
   - `/spx:brainstorm` stages its output at `.specify/interview.md` before any feature dir exists. Check for it (and for any `.specify/interview.md` with `Status: COMPLETE`).
   - If found with `Status: COMPLETE`: read its **Summary** and **Coverage Details** and treat them as authoritative requirements input — do NOT re-ask what the interview already covered. Note in the spec that requirements originated from a brainstorm interview.
   - If found with `Status: IN_PROGRESS`: use what exists; make informed guesses for uncovered dimensions rather than blocking.
   - After the feature directory is created (step 4), **relocate** the staging file to `SPECIFY_FEATURE_DIRECTORY/interview.md` (it becomes a first-class feature artifact per D2) and remove the staging copy.

3. **Branch note**: the `before_specify` hook already created/switched the branch and emitted `BRANCH_NAME` / `FEATURE_NUM`. The branch name does **not** dictate the spec directory name.

4. **Create the feature workspace via the fused script**:

   Run `${CLAUDE_PLUGIN_ROOT}/scripts/create-feature.sh --json "<feature description>"` from the repo root. This one-shot script creates the feature directory, copies the resolved `spec-template` to `spec.md`, writes `.specify/feature.json`, and reconciles the branch — self-gating and `--json`-emitting. Parse its JSON for `SPECIFY_FEATURE_DIRECTORY` and `SPEC_FILE`. For single quotes in args like "I'm Groot", use escape syntax (`'I'\''m Groot'`) or double-quote.

   Directory resolution (the script honors these; documented here for reference):
   - If the user explicitly provided `SPECIFY_FEATURE_DIRECTORY`, use it as-is.
   - Otherwise auto-generate under `specs/`: read `.specify/init-options.json` for `feature_numbering` (`"timestamp"` → `YYYYMMDD-HHMMSS` prefix; `"sequential"` or absent → next `NNN` after scanning `specs/`), then `<prefix>-<short-name>` (e.g. `003-user-auth`).
   - `.specify/feature.json` is written as `{"feature_directory": "<resolved dir>"}` (the actual path, e.g. `specs/003-user-auth`) so downstream `/spx:plan`, `/spx:tasks`, etc. locate the workspace without relying on branch conventions.

   **IMPORTANT**: only one feature per invocation; the spec directory and git branch are independent; the spec dir + file are always created by this command/script, never by the hook.

   **Resume guard (idempotency)**: before running the script, check whether `.specify/feature.json` already resolves to a feature directory that contains a `spec.md` for the SAME feature. If so, this is a re-run — do NOT re-scaffold; load the existing workspace and resume-fill the spec in place. Re-running `create-feature.sh` over an existing skeleton would clobber it or error.

5. Load the resolved active `spec-template` to understand required sections.

6. **IF EXISTS**: Load `.specify/memory/constitution.md` for project principles and governance constraints.

7. **Brownfield / monorepo notes** (from docs guides):
   - **Brownfield**: before writing requirements, scan for existing behavior the feature touches (Grep for related contexts/routes/modules). Record what already exists in the Assumptions section and phrase requirements as deltas against current behavior, not greenfield ideals.
   - **Monorepo / umbrella**: if the repo has multiple apps (`apps/*/mix.exs`) or packages, identify which app/package owns the feature and state it in the spec Scope. The feature workspace still lives at the repo-root `specs/<NNN-slug>/` (D2) regardless of which sub-app implements it.

8. Follow this execution flow:
   1. Parse the user description. If empty: ERROR "No feature description provided".
   2. Extract key concepts: actors, actions, data, constraints.
   3. For unclear aspects: make informed guesses from context and industry standards. Only mark `[NEEDS CLARIFICATION: specific question]` when the choice significantly impacts scope/UX, multiple reasonable interpretations exist, or no reasonable default exists. **LIMIT: max 3 markers total**, prioritized scope > security/privacy > UX > technical.
   4. Fill User Scenarios & Testing. If no clear user flow: ERROR "Cannot determine user scenarios".
   5. Generate Functional Requirements (each testable; document assumptions in the Assumptions section).
   6. Define Success Criteria — measurable, technology-agnostic, verifiable without implementation details.
   7. Identify Key Entities (if data involved).
   8. Return: SUCCESS (spec ready for planning).

9. Write the specification to `SPEC_FILE` using the template structure, replacing placeholders with concrete details while preserving section order and headings. Straight quotes `""` only (D13). Under `--lean`, follow the Flags section.

10. **Specification Quality Validation**: after writing the initial spec, validate it against quality criteria.

    a. **Create the Spec Quality Checklist** at `SPECIFY_FEATURE_DIRECTORY/checklists/requirements.md` using the inline items below — these are AUTHORITATIVE for the spec-quality checklist. (`templates/checklist-template.md` is the generic scaffold used by `/spx:checklist` for feature checklists, a different artifact; do not conflate the two.) Items:

       ```markdown
       # Specification Quality Checklist: [FEATURE NAME]

       **Purpose**: Validate specification completeness and quality before proceeding to planning
       **Created**: [DATE]
       **Feature**: [Link to spec.md]

       ## Content Quality

       - [ ] No implementation details (languages, frameworks, APIs)
       - [ ] Focused on user value and business needs
       - [ ] Written for non-technical stakeholders
       - [ ] All mandatory sections completed

       ## Requirement Completeness

       - [ ] No [NEEDS CLARIFICATION] markers remain
       - [ ] Requirements are testable and unambiguous
       - [ ] Success criteria are measurable
       - [ ] Success criteria are technology-agnostic (no implementation details)
       - [ ] All acceptance scenarios are defined
       - [ ] Edge cases are identified
       - [ ] Scope is clearly bounded
       - [ ] Dependencies and assumptions identified

       ## Feature Readiness

       - [ ] All functional requirements have clear acceptance criteria
       - [ ] User scenarios cover primary flows
       - [ ] Feature meets measurable outcomes defined in Success Criteria
       - [ ] No implementation details leak into specification

       ## Notes

       - Items marked incomplete require spec updates before `/spx:clarify` or `/spx:plan`
       ```

    b. **Run Validation Check**: review the spec against each item; document specific issues (quote relevant spec sections).

    c. **Handle Validation Results**:
       - **If all items pass**: mark the checklist complete and proceed to the Post-Execution Hooks section.
       - **If items fail (excluding [NEEDS CLARIFICATION])**: list failing items + issues, update the spec, re-run validation until all pass (max 3 iterations); if still failing, document remaining issues in checklist notes and warn the user.
       - **If [NEEDS CLARIFICATION] markers remain**: extract all markers; if more than 3, keep the 3 most critical (scope/security/UX) and make informed guesses for the rest. For each (max 3), present options:

         ```markdown
         ## Question [N]: [Topic]

         **Context**: [Quote relevant spec section]

         **What we need to know**: [Specific question from NEEDS CLARIFICATION marker]

         **Suggested Answers**:

         | Option | Answer | Implications |
         |--------|--------|--------------|
         | A      | [First suggested answer] | [What this means for the feature] |
         | B      | [Second suggested answer] | [What this means for the feature] |
         | C      | [Third suggested answer] | [What this means for the feature] |
         | Custom | Provide your own answer | [Explain how to provide custom input] |

         **Your choice**: _[Wait for user response]_
         ```

         Keep tables properly formatted (spaces around content, `|--------|` separators). Number questions Q1–Q3 (max 3), present all together, wait for responses, replace each marker with the chosen/provided answer, then re-run validation.

    d. **Update Checklist**: after each validation iteration, update the checklist file with current pass/fail status.

## Post-Execution: Git commit + agent-context hooks (after_specify)

**You MUST complete this section before reporting completion.**

Resolve `hooks.after_specify` (from `.specify/extensions.yml` if present, else the inline default from `templates/extensions.yml`). Command mapping: `speckit.git.commit` → `/spx:git-commit`; `speckit.agent-context.update` → `/spx:agent-context`. Inline default: two **optional** (`optional: true`) hooks in order — `speckit.git.commit`, then `speckit.agent-context.update`.

**Autonomous / non-interactive default**: under `/spx:full` or when running as a subagent (no user to accept the prompt), SKIP optional hooks and log that they were offered — never block waiting for input. Mandatory hooks still run unconditionally. In interactive mode, for each enabled optional hook, emit an offer block and run it only if accepted:

```text
## Extension Hooks

**Optional Hook**: git
Command: `/spx:git-commit`
Description: Auto-commit after specification

Prompt: Commit specification changes?
To execute: `/spx:git-commit`
```

```text
## Extension Hooks

**Optional Hook**: agent-context
Command: `/spx:agent-context`
Description: Refresh agent context after specification

Prompt: Execute speckit.agent-context.update?
To execute: `/spx:agent-context`
```

For any **mandatory** (`optional: false`) hook, emit `EXECUTE_COMMAND: {command}`, then actually invoke the mapped `/spx:*` command and wait. Skip silently if no hooks are registered and `.specify/extensions.yml` is absent.

## Completion Report

Report completion with:

- `SPECIFY_FEATURE_DIRECTORY` — the feature directory path
- `SPEC_FILE` — the spec file path
- Whether a brainstorm `interview.md` was consumed/relocated
- Checklist results summary
- Readiness for the next phase (`/spx:clarify` or `/spx:plan`)

**NOTE:** Branch creation is handled by the `before_specify` hook; spec directory + file creation and interview relocation are always handled by this core command.

## Quick Guidelines

- Focus on **WHAT** users need and **WHY**. Avoid HOW (no tech stack, APIs, code structure). Written for business stakeholders.
- **Mandatory sections** must be completed for every feature; **optional sections** included only when relevant (remove non-applicable sections entirely — never "N/A"). DO NOT embed checklists in the spec; that is a separate command.

### Success Criteria Guidelines

Success criteria must be measurable (specific metric), technology-agnostic (no frameworks/languages/databases), user-focused, and verifiable without implementation detail. Good: "Users can complete checkout in under 3 minutes"; "95% of searches return results in under 1 second". Bad (implementation-focused): "API response time under 200ms"; "Redis cache hit rate above 80%".

## Done When

- [ ] Specification written to `SPEC_FILE` and validated against the quality checklist
- [ ] Brainstorm interview consumed and relocated to the feature dir (if one existed)
- [ ] Extension hooks dispatched or skipped per the Post-Execution section
- [ ] Completion reported with feature directory, spec file path, and checklist results
