# Benchmark design — validating the fusion

Goal: show that `claude-speckit-phx-elixir` (the fused tool) produces better
Elixir/Phoenix outcomes than its parts. This document is the methodology; results
land in `docs/BENCHMARK-RESULTS.md`.

## What the literature says (cited)

- **No ready Elixir/Phoenix benchmark exists.** SWE-bench / Verified / SWE-Bench++
  / Multilingual / SWE-PolyBench / HumanEval / MBPP / RepoBench / LiveCodeBench —
  none include Elixir (arXiv 2512.17419; 2504.08703; swebench.com/multilingual).
  Only **MultiPL-E** translates HumanEval/MBPP to Elixir (function-level, shallow).
  → The task suite must be built.
- **Isolate the fusion with a controlled ablation: fix the model + temperature +
  sampling, vary only the scaffold** (the plugin/process). Aggregate scores confound
  scaffold, model, and config (arXiv 2607.03691 "Don't Blame the LLM"; 2604.03515
  "Inside the Scaffold"; 2602.22953 "General Agent Evaluation").
- **Analyze per cell (model, task), not aggregate.** Model dominates aggregate
  variance (27.8% vs 0.5% scaffold) but within a fixed model the scaffold moves
  results up to 12pp (2602.22953).
- **Report effectiveness AND efficiency together** — a scaffold can double
  tokens/tool-calls without improving resolve-rate (2607.03691). Report **pass@1 and
  pass@k** (2604.03515).
- **Statistics:** paired **McNemar** on per-task pass/fail, two-proportion **z-test**
  on resolved-rate, with **Benjamini-Hochberg/Yekutieli** correction at alpha=0.05
  (2602.22953). Reliable pairwise decisions need **many** tasks (2607.12338).
- **LLM-as-judge = secondary only**, with thinking judges, pairwise comparison, full
  untruncated response, and explicit control of position/verbosity/self-preference
  bias (2306.05685; 2507.10535 CodeJudgeBench). Hidden tests are the primary metric.
- **Corpus recipes:** SWE-Bench++ **state-differential oracle** (Base /
  Before-test-patch / After-full-PR) turns real Phoenix PRs into tasks with hidden
  golden tests (2512.17419). **CodeSpecBench** = spec-conformance (correctness +
  completeness). **LiveCodeBench** = contamination-free by release date (2403.07974).

## Design

**Arms (same model, same temperature, only the scaffold changes):**

| Arm | Scaffold |
|---|---|
| A · Fused | `claude-speckit-phx-elixir` |
| B · Spec Kit only | vanilla spec-kit flow, no Elixir intelligence |
| C · phx-plugin only | oliver-kriska/elixir-phoenix, no spec-driven spine |
| D · Control | plain Claude Code, same model |

**Task suite (3 tiers):**
- N0 — MultiPL-E Elixir (off-the-shelf function-level sanity).
- N1 — curated Phoenix features with a **pinned public-API contract** + hidden
  ExUnit tests. The contract makes arms comparable; the hidden tests are held out
  from every arm and only used for scoring.
- N2 — real merged PRs from Phoenix OSS repos via the SWE-Bench++ oracle.

**Metrics.** Primary (objective): compiles `--warnings-as-errors`, `mix test`
pass@1/pass@k over the hidden tests, resolved-rate, `sobelow`/`credo` findings,
**Iron-Law violations** (scored with this plugin's own `iron-law-verifier.sh`),
spec-conformance (correctness + completeness). Efficiency: tokens, tool-calls, $,
wall-clock. Secondary: LLM-as-judge pairwise with the controls above.

**Protocol.** Same model/temperature across arms; n>=k samples/task/arm; per-cell
analysis; McNemar + z-test + BH; contamination controlled (post-cutoff tasks /
repos not in training). Report effectiveness and efficiency side by side.

## Pilot (what runs first)

A **directional micro-pilot** (NOT statistically conclusive, and labeled as such):
~6 N1 curated tasks + 1-2 N2, on the 3 most informative arms (A vs C vs B — the
control D is the easy win, added only when scaling). Staged: run task 1 fully
(3 arms + scoring), confirm the harness gives clean signal, then decide on scaling.

### Fidelity caveat

The most faithful run installs each plugin in Claude Code and drives the real slash
commands. The pilot approximates each arm by having a subagent follow that scaffold's
real procedures under the same model — documented as an approximation, not the
installed-plugin ground truth.

## Pilot result (2026-07-21)

A staged micro-pilot ran task 01 (a product-catalog CRUD) across arms A (fused) /
B (spec-kit only) / C (phx-plugin only) x models Haiku and Opus — first with a pinned
contract, then with an under-specified brief. **All cells tied at 6/6 hidden tests, 0
Iron-Law violations.** Even Haiku with vanilla spec-kit produced idiomatic Ecto (DB
unique index, non-raising `get`, integer cents) unprompted.

Honest reading: standard Phoenix CRUD is a **saturated** task — base models already
encode the idioms, so the domain intelligence adds no measurable value there. This is a
finding, not a failure. Measuring the fusion's real value requires:

1. **The full flow** (constitution -> specify -> clarify -> plan -> tasks -> analyze ->
   implement), not just plan+implement, on **complex, ambiguous, multi-requirement**
   features where clarify resolves ambiguity and analyze catches spec-vs-design
   inconsistency — scored on requirement coverage and consistency, not idiom-correctness.
2. **Error-prone patterns** base models actually get wrong (N+1 under associations, Oban
   idempotency under retry, IDOR/scoping, LiveView memory), objectively scored.

Deferred to a **v0.2 validation milestone**. It does NOT block v0.1.0: the tool is
functionally validated end to end (see `docs/TEST-FINDINGS.md` — compiles, 26/26 tests,
Iron Laws correctly encoded).
