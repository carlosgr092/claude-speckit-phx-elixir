---
name: spx:doctor
description: Read-only health report for the spec-driven workspace. Checks the .specify/ state tree, feature.json validity, constitution presence and derived-copy freshness, hook wiring, tool availability (mix, gh, jq, codex, rtk), and probes Tidewave. Never modifies anything. Pass --json for machine-readable output.
argument-hint: "[--json]"
---

## User Input

```text
$ARGUMENTS
```

If `$ARGUMENTS` contains `--json`, emit a single machine-readable JSON object (schema in
"JSON output" below) and nothing else. Otherwise print the human-readable report.

## Contract

`/spx:doctor` is **strictly read-only**: it inspects files, runs pure resolution scripts, and
probes tool availability. It **never** creates, edits, or deletes anything, never runs a
build, and never mutates state. It is safe to run anytime, in any repo. Every check yields one
of: `ok`, `warn`, `fail`, or `n/a` (not applicable — e.g. Elixir checks in a non-`mix.exs`
repo, per D9), each with a one-line detail.

## Checks

Run these read-only checks and collect a status + detail for each.

### 1. Workspace state (`.specify/` tree)

- `.specify/` exists → else `fail` ("run /spx:init").
- Presence of `.specify/memory/`, `.specify/templates/`, `.specify/assessments/`,
  `.specify/bugs/`, and `.claude/{solutions,research,deps-audit,audit}/`. Missing dirs → `warn`
  (created by /spx:init or the setup-dirs hook).
- `.specify/init-options.json` present and valid JSON (report `feature_numbering`). Absent →
  `warn`; invalid JSON → `fail`.
- Retired layout guard: if `.claude/plans/` exists, `warn` (D2 — state now lives under
  `specs/<feature>/`).

### 2. feature.json validity

- Read `.specify/feature.json` (the single cross-session feature-state channel, D2). Absent is
  `ok` (no active feature). Present → validate it is well-formed JSON and its pinned
  feature-directory field points at a real `specs/<NNN-slug>/` directory. Dangling pin → `warn`
  (stale feature.json); malformed JSON → `fail`.
- Prefer resolving via `${CLAUDE_PLUGIN_ROOT}/scripts/check-prerequisites.sh --paths-only
  --json` (pure resolution, `--no-persist`); parse `FEATURE_DIR`/`BRANCH`. Report the active
  feature dir and whether `spec.md` / `plan.md` / `tasks.md` exist within it.

### 3. Constitution + derived-copy freshness (D3)

- `.specify/memory/constitution.md` present → else `warn` ("run /spx:constitution").
- Unfilled template detection: if it still contains scaffold placeholders (`[PROJECT_NAME]`,
  `[CONSTITUTION_VERSION]`, `[RATIFICATION_DATE]`), report `warn` (seeded but not filled).
- **Derived-copy freshness (version stamp, NOT mtime)**: the enforcement copies must be
  regenerated from the constitution whenever it changes (D3). Do **not** compare mtimes — they
  are unreliable here: a `git clone` rewrites every file's mtime in checkout order, and
  `/spx:constitution` writes `constitution.md` last (after regenerating the copies), so a
  fresh, correct regeneration would always look "stale". Instead compare the embedded
  **constitution version stamp**. Read the project constitution's `Version: X.Y.Z` line, then
  for each project-local derived copy read its `constitution vX.Y.Z` stamp:
  - CLAUDE.md block between `<!-- ELIXIR-PHOENIX-PLUGIN:START/END -->` — the auto-generated
    comment carries `constitution vX.Y.Z`.
  - AGENTS.md block between `<!-- ELIXIR-PHOENIX-REVIEW-GUIDELINES:START/END -->` — the managed
    comment carries `constitution vX.Y.Z`.

  For each block: stamp matches the constitution version → `ok` (fresh); stamp present but a
  different version → `warn` (stale — re-run `/spx:constitution` to regenerate); block present
  but **no** stamp (installed before stamping existed) → `warn` ("cannot verify freshness —
  re-run /spx:constitution to add a version stamp"), never a false `stale`; block absent →
  `warn` ("run /spx:constitution").
- **Plugin-shipped copies** (`inject-iron-laws.sh` and `iron-law-verifier.sh` under
  `hooks/scripts/`) track the plugin's OWN constitution, not the project's, so they are not
  freshness-checked against the project constitution. Report only that each is present and
  executable (a missing or non-executable wired script is a `fail` under Hook wiring below).

### 4. Hook wiring

- `hooks/hooks.json` present and valid JSON → else `fail`.
- Report which lifecycle events are wired (PreToolUse, PostToolUse, UserPromptSubmit,
  SubagentStart, SessionStart, PreCompact, PostCompact, Stop, StopFailure) and that each
  referenced `hooks/scripts/*.sh` file exists and is executable. A referenced-but-missing or
  non-executable script → `fail`; an unwired-but-present script → `warn`.
- `.specify/extensions.yml` present and parseable (before/after phase hook wiring) → else
  `warn`.

### 5. Tool availability

Probe each on `PATH` (do not invoke work, just detect — e.g. `command -v`):

| Tool | Purpose | Missing → |
|------|---------|-----------|
| `mix` | Elixir/Phoenix toolchain | `n/a` if no `mix.exs`; else `warn` |
| `jq` | JSON in scripts (has_jq fallback exists) | `warn` (scripts degrade to shell JSON) |
| `gh` | GitHub for /spx:git-remote, tasks-to-issues, pr-review | `warn` |
| `codex` | `--codex` cross-model review track | `warn` (codex tracks degrade to SKIPPED) |
| `rtk` | mix output compression filters | `warn` (optional token savings) |
| `git` | version control / feature branches | `warn` |

### 6. Tidewave probe (reuse detect-tidewave logic)

Reuse the `detect-tidewave.sh` hook logic, self-gated the same way: only probe when
`tidewave` is actually a dependency (`grep -qs "tidewave" mix.exs mix.lock apps/*/mix.exs`) —
a blind probe pollutes any Phoenix app's logs (issue #72). When gated in, probe
`http://localhost:4000/tidewave/mcp` with a short timeout: reachable → `ok` ("prefer
mcp__tidewave__* runtime tools"); not reachable → `warn` ("start the server for runtime
tools"); not a dependency → `n/a`.

### 7. Stack detection (reuse detect-ash logic)

Reuse `detect-ash.sh` logic (read-only): report Elixir project yes/no (`mix.exs`), Phoenix
version band (>= 1.8 Scopes vs 1.7.x), and Ash yes/no (`:ash` in `mix.exs` or `use
Ash.Resource`/`use Ash.Domain`). In a non-Elixir repo, mark the whole Elixir section `n/a` —
the speckit spine is still healthy (D9).

## Human-readable output

Print grouped sections with a leading status glyph per line (`ok` / `warn` / `fail` / `n/a`),
then a one-line overall verdict. Example shape:

```text
## spx:doctor — Health Report

Workspace
  ok    .specify/ tree present (memory, templates, assessments, bugs)
  ok    state dirs present under .claude/
  warn  init-options.json absent (run /spx:init)

Feature
  ok    active feature: specs/003-magic-link-auth (spec.md, plan.md, tasks.md present)

Constitution
  ok    .specify/memory/constitution.md present and filled (v0.2.0)
  warn  derived copy stale: CLAUDE.md block stamped constitution v0.1.0 (now v0.2.0) — run /spx:constitution

Hooks
  ok    hooks.json valid; 10 events wired; all scripts executable
  ok    .specify/extensions.yml parseable

Tools
  ok    mix, git, jq, gh          warn  codex not found (--codex degrades to SKIPPED)
  warn  rtk not found (optional mix output compression)

Runtime
  ok    Tidewave reachable at :4000
  ok    Stack: Elixir/Phoenix 1.8 (Scopes), Ash detected

Verdict: HEALTHY with 3 warnings — see above.
```

Overall verdict: `HEALTHY` (no fail/warn), `HEALTHY with N warnings`, or `UNHEALTHY — N
failures` when any check is `fail`.

## JSON output (`--json`)

Emit exactly one JSON object, no prose:

```json
{
  "verdict": "healthy | healthy-with-warnings | unhealthy",
  "counts": {"ok": 0, "warn": 0, "fail": 0, "na": 0},
  "checks": [
    {"group": "workspace", "name": "specify-tree", "status": "ok", "detail": "..."},
    {"group": "feature", "name": "feature-json", "status": "ok", "detail": "specs/003-..."},
    {"group": "constitution", "name": "derived-freshness", "status": "warn", "detail": "CLAUDE.md block stamped v0.1.0, constitution v0.2.0"},
    {"group": "hooks", "name": "hooks-json", "status": "ok", "detail": "10 events wired"},
    {"group": "tools", "name": "codex", "status": "warn", "detail": "not on PATH"},
    {"group": "runtime", "name": "tidewave", "status": "ok", "detail": "reachable :4000"}
  ]
}
```

`status` is one of `ok | warn | fail | na`. `verdict` is `unhealthy` if any check is `fail`,
`healthy-with-warnings` if any is `warn` (and none `fail`), else `healthy`.

## Guardrails

- **Read-only, always.** Never create, edit, or delete files; never run builds, migrations,
  or any mutating command. Probes must be side-effect free (pure resolution scripts, `command
  -v`, a single short-timeout Tidewave request only when tidewave is a dependency).
- Degrade gracefully — a missing optional tool or absent artifact is `warn`/`n/a`, never a
  crash. Only structural corruption (invalid JSON in a required file, a wired hook script that
  does not exist) is `fail`.
- Self-gate Elixir checks on `mix.exs` (D9): in a non-Elixir repo they are `n/a`, and the
  spine can still be `healthy`.
- **Enumerate with machine-parseable tools, never `ls`.** When a check needs to list files or
  directories, use `find`, `test -d`/`test -e`/`[ -e ]`, glob expansion, or `git ls-files` —
  not `ls`. A user's `ls` may be shell-aliased to a formatter (e.g. `eza` with a table/tree
  layout), whose output is not reliably parseable and produces spurious `fail`/`warn` results.
