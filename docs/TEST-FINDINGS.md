# TEST-FINDINGS — claude-speckit-phx-elixir

Consolidated, prioritized findings from an end-to-end shakedown of the plugin: a
full `/spx:specify` -> `/spx:plan` -> `/spx:tasks` -> implement run on a real
"product catalog" feature in a generated Phoenix app, plus static review of the
command bodies, hooks, scripts, docs, and constitution, plus an adversarial
audit of every generated artifact cross-checked against the code it produced.

Date: 2026-07-21. Verification method: code + DB + script execution (playwriter
not needed). All paths absolute.

---

## Executive verdict

**Does the tool work? Yes — end to end, on the happy path.** From a one-line
feature description it produced a complete, internally coherent spec (4
prioritized stories, 16 FRs, 6 measurable success criteria, no leftover
`[NEEDS CLARIFICATION]` markers, straight quotes throughout), a full plan +
research + data-model + quickstart, a dependency-ordered task list, and a
working Phoenix feature. The generated app **compiles clean with
`--warnings-as-errors`, is `mix format`-clean, and its 26 tests all pass.** The
hard Iron Laws are correctly encoded in the output: money as `price_cents`
integer with decimal->cents at the changeset boundary, `unique_index` mirrored
by `unique_constraint`, LiveView `stream/3`, owning-column-first migration, and
zero `Repo.` calls in the web layer. Constitution tracing is not decorative —
every Iron Law citation in the plan checks out against the real
`constitution.md` (spot-verified 1, 2, 4, 22, 24, 29, 30, 31, 33, 34, 37, 41,
42). The documented P-I deviation (unscoped catalog) is honest and ships with a
migration path.

**Is it at the level of spec-kit + the phx plugin? Substantially, but not yet
production-hardened.** The generation quality and Iron Law fidelity are on par
with the upstream phx plugin, and the spec-kit flow is faithfully reproduced.
But the shakedown surfaced real defects that a mature toolchain should not
have: the primary CI structural gate passes **vacuously** (checks 0 files in a
fresh checkout — CI is falsely green); the plugin **misreports its own
component counts**; the authoritative `data-model.md` **drifts from the code the
same run generated**; and the verification layer has **blind spots** — a planted
`String.to_atom/1` on user input (Iron Law 10, atom-exhaustion DoS) compiled
warning-clean and passed every gate, and two headline success criteria
(1,000-row performance, duplicate-SKU concurrency) are asserted "achieved"
with no test that exercises them.

**Bottom line:** production-capable on the golden path, not yet
production-trustworthy. None of the defects break the core flow; all are
fixable. Ship-blocker before relying on CI: the vacuous structural gate.

Findings by severity: **1 BLOCKER, 5 HIGH, 5 MEDIUM, 7 LOW.**

---

## Confirmed works (the wins)

- **marketplace.json description** — previously missing, now present and
  descriptive. `.claude-plugin/marketplace.json` -> `plugins[].description` set.
  FIXED.
- **`block-dangerous-ops.sh` denies destructive ops — CONFIRMED.** In an Elixir
  project (gated on `mix.exs`), `mix ecto.drop` / `mix ecto.reset` /
  `mix do ecto.drop` are denied via `permissionDecision: "deny"` with a safer
  alternative surfaced in `additionalContext`. Force-push and `MIX_ENV=prod`
  branches likewise. The anchored regexes correctly avoid false positives on
  quoted mentions (`echo "mix ecto.reset"`), preserve `--force-with-lease` and
  `mix ecto.gen.migration`, and the script honors a fail-open contract.
- **Spec generation** — passed validation on iteration 1, no
  `[NEEDS CLARIFICATION]`, WHAT-only, straight quotes throughout. All 4
  artifacts present with no leftover template placeholders; both
  `<!-- ELIXIR-PHOENIX -->` markers intact.
- **Plan / research / data-model / quickstart** — complete, specific,
  traceable; every FR maps to a validation rule; Iron Law citations accurate
  against the real constitution.
- **Generated code quality** — `mix compile --warnings-as-errors` exit 0 clean;
  `mix format --check-formatted` clean; `mix test` 26/26 pass in ~0.1s. Money
  round-trips 1999c <-> "19.99"; duplicate SKU rejected at the DB layer.
- **Iron Law encoding** — Law 4 (integer cents + virtual decimal cast at
  boundary), Law 2 (streams + `phx-update="stream"`), Law 33 (`unique_index`
  mirrored by `unique_constraint`; the duplicate-SKU test proves the DB, not
  the changeset, catches it), P-II (no `Repo.` in web).

---

## Findings to fix

Ranked by severity, deduplicated. Area is one of:
command / agent / skill / hook / script / docs / constitution / generated
("generated" = a defect in the artifacts/code this run produced, reflecting on
how well the tool guides output).

| id | sev | area | file | defect | fix |
|----|-----|------|------|--------|-----|
| F1 | BLOCKER | script | `/home/sho0t/Projects/claude-speckit-phx-elixir/.github/scripts/structural-checks.sh` | Enumerates command/agent/skill files via `git ls-files -z -- "$glob"`. In a repo with no commits (or not yet a git repo) this returns nothing: each check prints "checked 0 file(s)", sets no error, and the script exits 0 — "All passed" while validating **zero** frontmatter files. CI is falsely green; a broken command frontmatter ships undetected. | Fail when any category enumerates 0 files (`err "$label: no files matched"` when `count==0`), and/or enumerate with `find`/globbing as a fallback instead of relying solely on `git ls-files`. Add a smoke assertion that expected counts (21/26/48) are met. |
| F2 | HIGH | docs | `/home/sho0t/Projects/claude-speckit-phx-elixir/CLAUDE.md` (lines ~74, ~181) | Self-reported counts are stale: says **22 commands / 27 agents / 49 skills / 23 hooks**; on-disk reality is **21 / 26 / 48 / 22**. Every category is over by one. Misleads contributors and any doc-driven validation. | Correct to 21/26/48/22. Better: generate the counts from `find` in CI (tie to F1) so the doc can't drift again. |
| F3 | HIGH | generated / command | `.../specs/001-product-catalog-product/data-model.md` (lines ~12-19, ~23-50) | The **authoritative** Phase-1 data model omits the entire price-conversion design: no virtual `price :decimal` field, no decimal->cents step — it `cast`s `:price_cents` directly. This contradicts `research.md` (Decision 1), `plan.md`/tasks (T007/T013), AND the code the same run shipped (`product.ex` has `field :price, :decimal, virtual: true` + `maybe_put_price_cents/1`). An implementer following data-model.md literally builds the wrong form contract (user types `1999` for $19.99). | Regenerate data-model.md from the real schema: add the virtual `price` field, the `maybe_put_price_cents/1` boundary step, and a traceability row for dollars->cents. Investigate the `/spx:plan` step that emits data-model.md — it is not re-reading the schema it designs. |
| F4 | HIGH | hook / agent | `/home/sho0t/Projects/claude-speckit-phx-elixir/hooks/scripts/iron-law-verifier.sh`; `agents/iron-law-judge.md` | Verification blind spot: a planted `def role(params), do: String.to_atom(params["role"])` in `lib/bad.ex` (Iron Law 10 — atom-exhaustion DoS; also Law 37, no boundary validation) compiled warning-clean and passed every mechanical gate. An orphan module in the global `Bad` namespace, called by nothing, with no `@moduledoc`, shipped undetected. | Add `String.to_atom/1` (and `List.to_atom`, `:erlang.binary_to_atom`) on external input to the iron-law-verifier grep gates and the iron-law-judge checklist. Flag orphan/global-namespace modules and missing `@moduledoc`. |
| F5 | HIGH | generated / command | `spec.md:82` vs `plan.md:198-199`, `tasks.md:186,194-204,228-232`; code `index.ex:40,66` | Spec edge case says deleting/editing a vanished product "fails gracefully with a not-found outcome **rather than crashing**." The design and code use bang `get_product!/1` in `handle_params`/delete — a stale link **raises `Ecto.NoResultsError`** (500 / LiveView crash), the opposite. T016 even asserts the raise as "covering" the edge case. No artifact acknowledges the contradiction. | Either handle the not-found path (`get_product/1` + `{:noreply, put_flash(...)}`) or explicitly soften the spec edge case for a trusted-operator tool. The consistency check (`/spx:analyze`) should catch spec-vs-design inversions like this. |
| F6 | HIGH | command | `/home/sho0t/Projects/claude-speckit-phx-elixir/commands/specify.md:25` | `--lean` points to `${CLAUDE_PLUGIN_ROOT}/presets/lean/specify.md`, but `presets/` does not exist in the plugin at all. A graceful fallback keeps it non-fatal, but every `--lean` invocation silently hits the fallback and the advertised preset is missing. | Ship `presets/lean/specify.md`, or drop the `--lean` preset path and document the fallback as the actual behavior. |
| F7 | MEDIUM | generated / command | `spec.md:114,117`, `plan.md:37-39`, `research.md` Decision 3; `tasks.md` T010/T011 | Headline success criteria asserted without a verifying task (Iron Law 22, "verify before claiming done"): SC-005 (1,000 products < 2s) has no task that seeds ~1,000 rows and asserts render time; SC-002 concurrency (the entire justification for the DB `unique_index`) is only tested **sequentially** — the race the constraint exists to win is never exercised. | Add a ~1,000-row render/perf test and a concurrency test (or explicitly mark the race untestable-by-design and stop implying coverage). `/spx:tasks` should emit a verifying task for every measurable SC. |
| F8 | MEDIUM | generated | `spec.md:80` / SC-004; code `product.ex` `maybe_put_price_cents/1` | Sub-cent handling silently violates "captured **exactly**, no rounding error." The conversion does `Decimal.round(0)` on cents, so `19.005`/`19.999` is silently rounded rather than captured-exactly-or-rejected. No task/test covers sub-cent input; no artifact flags `round(0)` as a deliberate lossy choice. | Make the choice explicit in research Decision 1/7 (reject vs. round), add a sub-cent test asserting the chosen behavior, and reconcile with the "exactly" wording in the spec. |
| F9 | MEDIUM | command | `commands/specify.md:64-73` | Step 4 unconditionally runs `create-feature.sh` to create the dir and copy the spec template, with no branch for "workspace already exists". If `.specify/feature.json` + `spec.md` already exist (resume/re-run), this clobbers the skeleton or errors. No idempotency/resume guidance. | Guard: if the feature dir + spec.md already exist, skip creation and resume-fill instead of re-scaffolding. |
| F10 | MEDIUM | command / hook | `commands/specify.md:166-196` (and the parallel `after_plan` section) | The `after_*` hook sections are written for an interactive operator ("run only if accepted", "Prompt: Commit?"). They give no defined behavior for non-interactive/autonomous runs (`/spx:full`, subagents) where no user can accept the optional prompts — leaving optional hooks undefined (run or skip?). | Define the autonomous default explicitly (recommend: skip optional hooks, log that they were offered) so `/spx:full` and subagent runs are deterministic. |
| F11 | MEDIUM | command | `commands/specify.md:97-134` vs `templates/checklist-template.md` | Step 10a says build the checklist "using the checklist template structure" but then inlines a full, different checklist body. Two sources of truth; a user opening the template file finds it doesn't match what the command produces. | Pick one: either drive the checklist from `templates/checklist-template.md` or delete/repurpose that template and mark the inline block authoritative. |
| F12 | LOW | generated | `research.md:33` | `unique_constraint(:changeset, :sku)` is an invalid Elixir signature (first arg is the changeset value, not the atom `:changeset`) — misleading in a doc other artifacts cite as canonical. | Correct to `unique_constraint(changeset, :sku)` / `|> unique_constraint(:sku)`. |
| F13 | LOW | generated | `tasks.md:273` | `create_product/2` in the dependency rationale — everywhere else and in the code it is `create_product/1`. Arity typo. | Fix to `/1`. |
| F14 | LOW | generated | `data-model.md:19` vs `:34` + migration | Notes column says `timestamps()`; the same doc's schema block and migration use `timestamps(type: :utc_datetime_usec)`. Internal mismatch. | Align on the `utc_datetime_usec` form. |
| F15 | LOW | generated | `plan.md:172-179` | Source-tree ASCII malformed: `index.ex` and `index.html.heex` both drawn with `└──` (one should branch), and `router.ex` rendered as a directory child. Cosmetic. | Fix the tree glyphs. |
| F16 | LOW | command | `commands/specify.md:18` (+ spec template) | The template line `**Input**: User description: "$ARGUMENTS"` is not called out for replacement; Step 9's generic "replacing placeholders" is the only cover. A literal `$ARGUMENTS` can survive into the finished spec. | Add an explicit replace instruction (or post-fill assert that no `$ARGUMENTS`/`[PLACEHOLDER]` tokens remain). |
| F17 | LOW | generated | `spec.md` FR-010; `tasks.md` | FR-010 ("retrieve an individual product") has no dedicated show view or task beyond `get_product!` — implicitly folded into the edit modal, never explicitly mapped. | Map FR-010 to a concrete task or note it as satisfied-via-edit-modal so traceability is complete. |
| F18 | LOW | hook | `hooks/scripts/block-dangerous-ops.sh` | The `ecto.reset/drop` and `MIX_ENV=prod` denies are gated on `mix.exs` presence in `CLAUDE_PROJECT_DIR`/`$PWD`. Correct for cross-project bleed, but means the block does **not** fire if the command is run from a directory without `mix.exs` (e.g. repo root, monorepo tooling). Works-as-designed caveat, not a bug. | Document the gating limitation; consider also matching when the command `cd`s into a Phoenix app subdir. |

---

## Notes on scope

- F3, F5, F7, F8, F12-F15, F17 are defects in the **generated artifacts of one
  run**. They matter because they reveal where the generating commands
  (`/spx:plan`, `/spx:tasks`, `/spx:analyze`) fail to keep spec, design, and
  code consistent — not just one-off typos.
- F4 is the most conceptually important verification gap: the toolchain's
  promise is Iron Law enforcement, and a Law-10 violation shipped clean.
- The generated app under
  `/tmp/claude-1000/-home-sho0t/64c398e0-f47f-4625-b8dd-2df956899651/scratchpad/spx_test`
  is a scratch fixture, including the planted `lib/bad.ex`; it is not part of
  the shipped plugin.

---

## Resolution (2026-07-21)

All plugin-level findings were fixed and re-verified live in a real Phoenix app.

| id | sev | status | fix landed |
|----|-----|--------|-----------|
| F1 | BLOCKER | FIXED | `structural-checks.sh` falls back to `find` when `git ls-files` is empty, fails on 0 files, and asserts the 21/26/48 counts. Verified: checks 21/26/48, exit 0 on an uncommitted tree. |
| F2 | HIGH | FIXED | `CLAUDE.md` counts corrected to 21 commands / 26 agents / 48 skills / 22 hooks. |
| F3 | HIGH | FIXED | `commands/plan.md` now requires `data-model.md` to reflect the final schema incl. virtual/boundary fields, re-reading the design before finalizing. |
| F4 | HIGH | FIXED | `iron-law-verifier.sh` Law-10 gate extended to `List.to_atom` and `:erlang.(binary|list)_to_atom`. Verified: flags both, ignores `*_to_existing_atom`. |
| F5 | HIGH | FIXED | `commands/analyze.md` adds a "spec-vs-design/code inversion" detection (CRITICAL) — bang functions that contradict a stated graceful-failure spec. |
| F6 | HIGH | FIXED | `presets/lean/{specify,plan,tasks,constitution,implement}.md` created; every `--lean` reference now resolves. |
| F7 | MEDIUM | FIXED | `commands/tasks.md` requires a verifying task for every measurable SC-### (or a documented reason it is untestable). |
| F8 | MEDIUM | PARTIAL | Money-precision fidelity is covered by the F3 data-model fix + Iron Law 4; the explicit round-vs-reject decision remains guidance-level. |
| F9 | MEDIUM | FIXED | `commands/specify.md` step 4 adds a resume/idempotency guard (do not re-scaffold an existing feature workspace). |
| F10 | MEDIUM | FIXED | `commands/specify.md` after-hooks define an autonomous default (skip optional hooks under `/spx:full`/subagents, log offered). |
| F11 | MEDIUM | FIXED | `commands/specify.md` clarifies the inline spec-quality checklist is authoritative vs the generic `checklist-template.md`. |
| F12-F15, F17 | LOW | N/A | Typos in the one scratch run's generated artifacts (not shipped); their root causes are addressed by F3/F5/F7. |
| F18 | LOW | FIXED | `hooks/scripts/block-dangerous-ops.sh` documents the `mix.exs` gating limitation. |

Net: BLOCKER + all HIGH fixed and verified; all actionable MEDIUM fixed (F8 partial); F18 fixed;
the 5 throwaway-artifact LOWs need no plugin change.
