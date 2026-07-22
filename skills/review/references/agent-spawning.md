# Review Agent Spawning Reference

Detailed tables and prompt templates for spawning review specialists.
Referenced by `/spx:review` Step 2.

## Agent Selection Table

| Agent | subagent_type | When to spawn |
|-------|---------------|---------------|
| Elixir Reviewer | `claude-speckit-phx-elixir:elixir-reviewer` | **Always** |
| Iron Law Judge | `claude-speckit-phx-elixir:iron-law-judge` | Only if >200 lines changed AND auth/LiveView/Oban files in diff. **Skip** if PostToolUse hooks already verified all files |
| Verification Runner | `claude-speckit-phx-elixir:verification-runner` | Only if `mix test` has NOT been run in this session. **Skip** if `/spx:implement` just passed all verification tiers |
| Security Analyzer | `claude-speckit-phx-elixir:security-analyzer` | Auth/session/password/token files changed |
| Testing Reviewer | `claude-speckit-phx-elixir:testing-reviewer` | Test files changed OR new public functions |
| Oban Specialist | `claude-speckit-phx-elixir:oban-specialist` | Worker files changed (*_worker.ex) |
| Deploy Validator | `claude-speckit-phx-elixir:deployment-validator` | Dockerfile/fly.toml/runtime.exs changed |
| Requirements Verifier | `claude-speckit-phx-elixir:requirements-verifier` | Task ID detected OR plan/spec path passed (Step 1c succeeded). **Skip** on `--no-requirements` |
| Codex Reviewer | `claude-speckit-phx-elixir:codex-reviewer` | **ONLY when `--codex` passed** — never in default selection. Does not count toward the max-5 cap |

Min 1, max 5 agents. For <200 lines changed: spawn only elixir-reviewer +
security-analyzer (if auth files).

## Output File Mapping

Every agent prompt MUST include an explicit `output_file` path.

| Agent | output_file |
|-------|-------------|
| elixir-reviewer | `specs/{slug}/reviews/elixir.md` |
| testing-reviewer | `specs/{slug}/reviews/testing.md` |
| iron-law-judge | `specs/{slug}/reviews/iron-laws.md` |
| security-analyzer | `specs/{slug}/reviews/security.md` |
| oban-specialist | `specs/{slug}/reviews/oban.md` |
| deployment-validator | `specs/{slug}/reviews/deploy.md` |
| verification-runner | `specs/{slug}/reviews/verification.md` |
| requirements-verifier | `specs/{slug}/reviews/requirements.md` |
| codex-reviewer | `specs/{slug}/reviews/codex.md` |

## Standard Prompt Block

Include this instruction block in every agent prompt:

```
output_file: specs/{slug}/reviews/{agent}.md

CRITICAL: Write your findings to the output_file above. By turn ~12 at the
latest, call Write with whatever you have — partial is better than nothing
if you hit the turn limit. Continue analyzing and Write again to overwrite
with the full version. Your chat response body must be ≤300 words — the
file IS the real output.
```

## Codex Reviewer Prompt Block (`--codex` only)

Spawn `claude-speckit-phx-elixir:codex-reviewer` in the SAME parallel batch as the
other agents with this prompt (plus the Standard Prompt Block above):

```
Run a Codex CLI review of this diff and normalize the findings.

base_branch: {default branch, e.g. main}
diff_files: {git diff --name-only output}
output_file: specs/{slug}/reviews/codex.md

Preflight `command -v codex` first. If codex is missing or the review
fails, write output_file with a SKIPPED note and stop — NEVER error.
Do not pass custom instructions with --base (CLI rejects it); the rubric
comes from the project's AGENTS.md "Review guidelines" section.
Normalize P0/P1→BLOCKER, P2→WARNING, P3→SUGGESTION. Tag every finding
with source [codex].
```

The codex review takes 1–5+ minutes — spawn it FIRST in the batch so it
overlaps the Claude agents. In Step 3b, mark issues flagged by both a
Claude agent and `[codex]` as HIGH CONFIDENCE (cross-model consensus).

## Focused Review Mode

When the user passes a focus argument, spawn only the specified agent:

| Argument | subagent_type |
|----------|---------------|
| `test` | `claude-speckit-phx-elixir:testing-reviewer` |
| `security` | `claude-speckit-phx-elixir:security-analyzer` |
| `oban` | `claude-speckit-phx-elixir:oban-specialist` |
| `deploy` | `claude-speckit-phx-elixir:deployment-validator` |
| `iron-laws` | `claude-speckit-phx-elixir:iron-law-judge` |

Zero agents spawned = skill failure.
