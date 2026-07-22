Managed `## Review guidelines` block for the project's AGENTS.md — the codex P1-P3 rubric
(the fourth derived enforcement copy, D3). /spx:constitution installs it and refreshes it
inside the markers on every amendment; carry over the project's existing `### Known
non-issues` entries verbatim (project knowledge, not template content). Keep it under 35
lines — cloud reviews read the nearest AGENTS.md per changed file, and a bloated rubric
dilutes focus. Fill `{CONSTITUTION_VERSION}` from the constitution's `Version:` line so
/spx:doctor can verify freshness by version stamp rather than mtime.

```markdown
<!-- ELIXIR-PHOENIX-REVIEW-GUIDELINES:START -->
<!-- Managed by /spx:constitution — constitution v{CONSTITUTION_VERSION}; edits inside markers are overwritten on amendment -->

## Review guidelines

Elixir/Phoenix review priorities. Flag violations at the given priority.

- **P1** Money as float — monetary values must use `Decimal` or integer cents.
- **P1** Unpinned query values — Ecto values must use `^`; never interpolate user input.
- **P1** `String.to_atom/1` on user input — atom-exhaustion DoS; require an allowlist or `String.to_existing_atom/1`.
- **P1** Unconditional DB queries in LiveView `mount` — mount runs twice; expect `assign_async` or a `connected?/1`-guarded branch.
- **P1** Missing authorization in LiveView `handle_event` — every handler authorizes; mount-time auth is not enough.
- **P1** `raw/1` with untrusted content — XSS.
- **P1** Implicit cross join — `from(a in A, b in B)` without `on:` is a Cartesian product.
- **P2** Lists over ~100 items in LiveView assigns — require streams.
- **P2** Oban hazards — non-idempotent `perform`, atom keys in args, structs in args (store IDs).
- **P2** Bare `{:error, _}` swallowing changesets — match `{:error, %Ecto.Changeset{}}` explicitly or form errors never re-render.
- **P2** Unsupervised long-lived processes — no bare `GenServer.start_link`/`Agent.start_link` in production.
- **P3** `has_many` preloads via JOIN — prefer separate queries for `has_many`, JOIN for `belongs_to`.

### Known non-issues (do NOT report these)

<!-- One line per disproven pattern: what reviewers keep claiming + why it is wrong.
     Carry these over verbatim on every refresh — wiping them resurrects false positives. -->

<!-- ELIXIR-PHOENIX-REVIEW-GUIDELINES:END -->
```
