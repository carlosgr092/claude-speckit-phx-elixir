---
name: spx:init
description: Bootstrap the spec-driven workspace in this project. Creates the .specify/ tree and cross-feature state dirs, copies templates, records feature-numbering options, detects the stack, installs the CLAUDE.md/AGENTS.md marker blocks, and seeds the constitution ONLY if missing. Idempotent and customization-preserving — never overwrites your edits.
argument-hint: "[--feature-numbering sequential|timestamp] [--force-templates]"
---

## User Input

```text
$ARGUMENTS
```

Parse optional flags: `--feature-numbering sequential|timestamp` (default `sequential`) and
`--force-templates` (refresh core template copies even if present — still never touches
`overrides/` or an existing constitution).

## Goal

Make this project ready for the `/spx:*` lifecycle by creating the durable scaffolding that
the phase commands and hooks assume (D2 artifact layout). Bootstrapping is **idempotent** and
**customization-preserving**: re-running `/spx:init` fills only what is missing and never
clobbers a constitution, an override, or user-authored content between markers.

`/spx:init` complements the `setup-dirs.sh` SessionStart hook (which creates the state dirs
on every session in an Elixir repo) — init additionally seeds templates, options, the
constitution, and the marker blocks, and works in **any** repo (the state-dir creation is not
gated on `mix.exs`; only the Elixir marker content is stack-aware, per D9).

## Execution Steps

### 1. Resolve the repo root

Resolve `REPO_ROOT` (the project root — the directory containing the future `.specify/`). If
`common.sh` is available, source `${CLAUDE_PLUGIN_ROOT}/scripts/common.sh` and use
`get_repo_root`; otherwise use the current working directory. All paths below are relative to
`REPO_ROOT`.

### 2. Create the directory tree (idempotent)

Create these if absent, never deleting anything that exists:

**Cross-feature state (D2):**

```text
.specify/memory/
.specify/templates/overrides/
.specify/assessments/
.specify/bugs/
.claude/solutions/
.claude/research/
.claude/deps-audit/
.claude/audit/
```

The per-feature workspace `specs/<NNN-slug>/` is **never** pre-created here — it is created on
demand by `create-feature.sh` when `/spx:specify` runs. Do NOT create `.claude/plans/`
(retired layout — D2).

### 3. Copy core templates (fill-only)

Copy each core template from `${CLAUDE_PLUGIN_ROOT}/templates/` into `.specify/templates/`
**only if the destination does not already exist** (or always, when `--force-templates` is
set — but even then never touch `.specify/templates/overrides/`):

- `spec-template.md`, `plan-template.md`, `tasks-template.md`, `checklist-template.md`,
  `constitution-template.md`
- `extensions.yml` → `.specify/extensions.yml` (only if absent — this file wires the
  before/after phase hooks and is user-editable)
- `git-config.yml` → `.specify/git-config.yml` (only if absent — governs `/spx:git-commit`
  auto-commit gating; default all events disabled)

Template resolution at runtime follows `common.sh`'s precedence (overrides > presets >
extensions > core), so a copied core template is the safe default that a user override can
later shadow without edits here.

### 4. Record feature-numbering options

Write `.specify/init-options.json` **only if absent** (idempotent — never rewrite a file the
user may have tuned), capturing bootstrap-time choices the git/feature machinery reads:

```json
{
  "feature_numbering": "sequential",
  "namespace": "spx",
  "created": "<ISO 8601 date>"
}
```

Set `feature_numbering` from the flag (`sequential` → zero-padded `NNN-slug`; `timestamp` →
timestamp-form branch/dir). If the file already exists, leave it untouched and report that it
was preserved.

### 5. Detect the stack

Detect what activates the Elixir-specific intelligence (D9), for the report and to shape the
marker content in Step 7:

- `mix.exs` present → Elixir/Phoenix project. Read the Phoenix and Ecto versions from
  `mix.exs` / `mix.lock` where available; note Phoenix >= 1.8 (Scopes) vs 1.7.x.
- `:ash` in `mix.exs` (or `use Ash.Resource`/`use Ash.Domain` under `lib/`) → Ash project.
- No `mix.exs` → generic repo. The speckit spine still applies; skip the Elixir marker block.

Do not run any Elixir tooling here — bootstrap must be side-effect free beyond file creation.

### 6. Seed the constitution ONLY if missing (NEVER overwrite)

- If `.specify/memory/constitution.md` **already exists**, do NOT touch it — report it as
  preserved. The constitution is the single canonical Iron-Law corpus (D3); overwriting it
  would silently drop project amendments.
- If it is **absent**, seed it from `${CLAUDE_PLUGIN_ROOT}/templates/constitution-template.md`
  as an unfilled scaffold (placeholders `[PROJECT_NAME]`, `[CONSTITUTION_VERSION]`,
  `[RATIFICATION_DATE]`, `[LAST_AMENDED_DATE]` left intact) and tell the user to run
  `/spx:constitution` to fill it in and regenerate the four derived enforcement copies.

`/spx:init` never fills placeholders or regenerates derived copies — that is
`/spx:constitution`'s exclusive job.

### 7. Install the CLAUDE.md / AGENTS.md marker blocks (preserving)

Install the managed marker blocks so hooks and skills auto-load correctly, touching **only**
the content between markers and never anything outside them:

- **CLAUDE.md** — ensure the block delimited by `<!-- ELIXIR-PHOENIX-PLUGIN:START -->` …
  `<!-- ELIXIR-PHOENIX-PLUGIN:END -->` exists, using
  `${CLAUDE_PLUGIN_ROOT}/templates/claude-md-block.md`. If the markers are absent, append the
  block; if present, leave the existing (possibly amended-by-constitution) content alone —
  `/spx:init` seeds, `/spx:constitution` regenerates. Content outside the markers is NEVER
  modified. Skip the Elixir-specific body in a non-`mix.exs` repo (install only the generic
  spine references).
- **AGENTS.md** — ensure the review-guidelines block delimited by `<!--
  ELIXIR-PHOENIX-REVIEW-GUIDELINES:START -->` … `<!-- ELIXIR-PHOENIX-REVIEW-GUIDELINES:END
  -->` exists, from `${CLAUDE_PLUGIN_ROOT}/templates/agents-md-block.md`. Carry over any
  existing `### Known Disproven Patterns` list the user maintains — only the managed content
  between markers is replaced, and only when regenerating (init just seeds if absent).

If a marker template is missing, skip that block gracefully and note it rather than failing.

### 8. Report

Print an idempotent bootstrap summary — for each item say `created`, `preserved (already
present)`, or `skipped (<reason>)`:

```text
## spx:init — Bootstrap Summary

Repo root: <REPO_ROOT>
Stack: Elixir/Phoenix (Phoenix <v>, Ecto <v>) | Ash | generic

Directories:   .specify/{memory,templates/overrides,assessments,bugs}, .claude/{solutions,research,deps-audit,audit}  → created | preserved
Templates:     spec/plan/tasks/checklist/constitution, extensions.yml, git-config.yml       → created | preserved
Options:       .specify/init-options.json (feature_numbering=<mode>)                          → created | preserved
Constitution:  .specify/memory/constitution.md                                                → seeded (run /spx:constitution) | preserved
Markers:       CLAUDE.md block, AGENTS.md review-guidelines block                             → installed | preserved | skipped

Next: /spx:constitution   (fill the constitution and regenerate derived copies)
Then: /spx:assess  or  /spx:specify   (start a feature)
Health check: /spx:doctor
```

## Guardrails

- **Never overwrite** an existing constitution, `init-options.json`, `extensions.yml`,
  `git-config.yml`, a template `override`, or user content outside the CLAUDE.md/AGENTS.md
  markers. Fill-only.
- **Never create `specs/<feature>/`** — that is `create-feature.sh` / `/spx:specify`'s job.
- **Never create `.claude/plans/`** (retired layout, D2).
- **Never run Elixir tooling** or mutate source — bootstrap is limited to creating scaffolding
  files.
- Re-running `/spx:init` is safe and expected; it converges the workspace toward the full
  layout without disturbing customization.
