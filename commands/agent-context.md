---
name: spx:agent-context
description: Refresh the managed Spec Kit section in the coding agent context file (CLAUDE.md) to point at the current plan, and refresh the managed codex review-guidelines block in AGENTS.md.
argument-hint: "[plan_path]"
handoffs:
  - /spx:tasks
  - /spx:implement
---

# Update Coding Agent Context

Refresh the managed Spec Kit section inside the active coding agent's context/instruction file (default `CLAUDE.md`), and keep the managed codex review-guidelines block in `AGENTS.md` in sync. This is the post-step run after `/spx:specify` and `/spx:plan` (wired via `.specify/extensions.yml` `after_specify` / `after_plan`).

## Behavior

### 1. CLAUDE.md managed Spec Kit block

The `update-agent-context.sh` script manages a single marker-delimited section in `CLAUDE.md`:

- Markers: `<!-- SPECKIT START -->` … `<!-- SPECKIT END -->`.
- It points the section at the most recent plan path when one can be discovered — resolved as: explicit `plan_path` argument > the feature directory in `.specify/feature.json` (written by `/spx:specify`) > the most recently modified `specs/**/plan.md` (searched recursively, so nested scoped layouts like `specs/<scope>/<feature>/plan.md` are found).
- When `mix.exs` exists (D9 self-gating), the block is extended with detected stack info — Elixir version, Phoenix version, and single-app vs umbrella layout — so the coding agent loads with accurate stack context. In a non-Elixir repo the block is just the plan pointer; the spine works in any repo.
- Override the target file with `SPECIFY_CONTEXT_FILE` if the project uses a different context file.

If no plan can be discovered, the script still writes/refreshes the pointer section; it never fails the command.

### 2. AGENTS.md managed codex review-guidelines block

Refresh the `## Review guidelines` block in the project's `AGENTS.md` — the codex P1-P3 rubric that is the fourth derived enforcement copy of the constitution (D3). Cloud/codex reviews read the nearest `AGENTS.md` per changed file, so this block keeps them aligned with the Iron Laws.

- Managed markers: `<!-- ELIXIR-PHOENIX-REVIEW-GUIDELINES:START -->` … `<!-- ELIXIR-PHOENIX-REVIEW-GUIDELINES:END -->`.
- Source the canonical block from `${CLAUDE_PLUGIN_ROOT}/templates/agents-md-block.md`. If `AGENTS.md` has no managed block yet, create/append it; if it exists, replace only the content between the markers.
- **Carry over the project's existing `### Known non-issues` entries verbatim** — those are project knowledge, not template content. Wiping them resurrects false positives. Preserve every line on each refresh.
- Keep the block under 35 lines. Only do this step when `mix.exs` exists (the codex rubric is Elixir/Phoenix-specific) — skip silently in non-Elixir repos.
- Do not regenerate the rubric bullets here; `/spx:constitution` owns rubric content (regenerated from the canonical constitution on amendment). This command only re-installs the current canonical block and preserves Known non-issues.

Context file paths must stay project-relative; absolute paths, Windows drive paths, backslash separators, and `..` path segments are rejected.

## Execution

- **CLAUDE.md block**: run `${CLAUDE_PLUGIN_ROOT}/scripts/update-agent-context.sh [plan_path]` from repo root. When `plan_path` is omitted, the script auto-resolves it (feature.json, then newest `specs/**/plan.md`).
- **AGENTS.md block** (only when `mix.exs` exists): read `${CLAUDE_PLUGIN_ROOT}/templates/agents-md-block.md`, read any existing `AGENTS.md` to capture current `### Known non-issues` lines, then write the managed block back with those lines preserved.

Report which files were updated (CLAUDE.md always; AGENTS.md when applicable) and the plan path the CLAUDE.md block now points at.
