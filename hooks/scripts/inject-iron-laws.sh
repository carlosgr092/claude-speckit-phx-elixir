#!/usr/bin/env bash
# SubagentStart hook: Inject the full Iron Law corpus into every spawned subagent
# via additionalContext. Addresses the #1 session-analysis finding: zero skill
# auto-loading in subagents. This bullet list is REGENERATED from Article II of
# memory/constitution.md (the single source, D3) — laws 1-53 + 9b. Keep in sync
# with the constitution; regenerating derived copies is a step of /spx:constitution.

# Skip in non-Elixir projects (cross-project bleed guard — issue #55).
# Subagents in Rust/Python/etc. projects shouldn't get Phoenix Iron Laws.
proj="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$proj/mix.exs" ] || exit 0

LAWS=$(cat <<'LAWS'
Elixir/Phoenix Iron Laws — Article II of the project constitution (NON-NEGOTIABLE). On any violation: STOP, state "This would violate Iron Law [n]", show what was written and the correct pattern, ask "Should I apply this fix?".

LiveView
- 1. NO unconditional DB queries in mount — mount runs twice; default assign_async; SEO routes use connected?/1 plus a cache-backed disconnected branch (the dead render IS the crawler-indexed HTML).
- 2. ALWAYS streams for lists over ~100 items — regular assigns are O(n) memory per user.
- 3. CHECK connected?/1 before PubSub subscribe.
- 18. CHECK changeset errors BEFORE UI debugging.
- 21. NEVER assign_new for values refreshed every mount (locale, current user, timezone, org) — use assign/3.
- 24. MATCH {:error, %Ecto.Changeset{}} explicitly — bare {:error, _} hides form errors.
- 28. EXTRACT needed values into plain variables BEFORE assign_async closures — never capture the socket (stale full-struct capture).
- 29. mount/3 holds session/static state; handle_params/3 owns ALL URL-derived state (handle_params re-runs on live_patch; mount does not).
- 30. NEVER pass the socket into context/business functions — pass explicit values.

Ecto
- 4. NEVER :float for money — :decimal or integer cents.
- 5. ALWAYS pin with ^ in queries — never interpolate user input (SQL injection).
- 6. SEPARATE queries for has_many preloads; JOIN for belongs_to (row multiplication).
- 15. NO implicit cross joins — from(a in A, b in B) without on: is a Cartesian product.
- 17. DEDUP before cast_assoc with shared data.
- 19. HIDDEN inputs for ALL required embedded fields.
- 31. cast/4 is for EXTERNAL/untrusted input ONLY — internal state changes go through change/2 / put_change/3.
- 32. NO Rails-style polymorphic associations (*_type + *_id) — separate FK columns, join tables, or abstract-concrete tables instead.
- 33. CONSTRAINTS beat validations for anything race-prone (uniqueness, FKs) — validations are UX pre-checks only; every unique_constraint/3 MUST mirror a real unique index created in a migration.
- 34. Migration order: create/alter the OWNING column before any constraint, index, or backfill that references it (owning-column-first).

Oban
- 7. Jobs MUST be idempotent.
- 8. Args use STRING keys (%{"user_id" => id}).
- 9. NEVER store structs in args — store IDs.
- 9b. Smart Engine: never limit snoozes via attempt (it rolls the counter back — infinite loop; real incident: 72k orphaned jobs). Use meta["snoozed"].
- 35. HANDLE every perform return shape (:ok, {:ok, _}, {:error, _}, {:cancel, _}, {:snooze, n}) — an unhandled shape is a silent retry.
- 36. NO large data in args — args are persisted, logged, and re-copied on every retry; store IDs and refetch.

Security
- 10. NO String.to_atom/1 on user input (atom-exhaustion DoS).
- 11. AUTHORIZE in EVERY LiveView handle_event — never trust mount-time auth; URL params in handle_params MUST be scope-checked (IDOR).
- 12. NEVER raw/1 with untrusted content (XSS).
- 37. VALIDATE at the boundary — every external input passes changeset/validation at its entry point (controller, LiveView event, channel, job args).
- 38. SECRETS via runtime.exs env reads ONLY — never compile-time config, never in code; scope values are set in the struct/query by the server, NEVER cast from params; CSRF protection stays on.

OTP / Elixir
- 13. NO process without a runtime reason (concurrency, state, isolation — never code structure). Functions -> Agent/ETS -> GenServer, in that order.
- 14. SUPERVISE all long-lived processes — no bare GenServer.start_link / Agent.start_link in production code.
- 16. @external_resource for compile-time file reads.
- 20. WRAP third-party library APIs behind project-owned facades.
- 23. Mix tasks start only what they need — Mix.Task.run("app.config") + Application.ensure_all_started/1; never app.start (boots endpoint + Oban).
- 25. CAPTURE Gettext/CLDR locale before spawning — locale is process-local; pass it explicitly to Task/GenServer.
- 27. NEVER a bare rescue _ -> — rescue named exception types only; reraise e, __STACKTRACE__ when re-raising; rescue only external code.

Contexts & boundaries
- 39. NO side effects in schema modules — schemas are pure data-mapping; multi-step writes live in the context behind Ecto.Multi.
- 40. NEVER refactor context boundaries without mix xref graph / callers evidence first.

Testing
- 41. async: true by DEFAULT — drop it only for real shared-state contention (named processes, ETS, external resources), with a comment saying why.
- 42. DB isolation via the Ecto SQL Sandbox — never truncation or manual cleanup.
- 43. MOCK ONLY at boundaries the project owns — Mox on project behaviours; never mock internal context functions.
- 44. Every external service sits behind a behaviour so tests verify the CONTRACT (behaviours-as-contracts).
- 45. Factories default to build/2; insert/2 only when persistence is the point.
- 46. NO Process.sleep in tests — assert_receive, Task.await, or polling helpers.
- 47. verify_on_exit! in setup for every Mox test.
- 48. Factories set ONLY the schema's required fields by default — optional data is explicit per test.

Deploy / Ops
- 49. Env-dependent config is RUNTIME config (runtime.exs env reads) — never compile-time config baked into the release.
- 50. Graceful shutdown with a drain window >= 60s so LiveView sockets and in-flight Oban jobs finish.
- 51. Health endpoints (liveness + readiness) that touch no heavy dependencies.
- 52. Production DB connections use SSL verify_peer (pinned CA) — never verify_none.
- 53. NEVER CPU-limit BEAM containers (scheduler collapse under throttling); memory limits are fine.

Code style
- 26. COMMENTS ARE NOT COMMIT MESSAGES — reasoning goes in the commit/PR; keep only durable facts (footguns, invariants, quirks). Straight quotes "" only, never angle quotes.

Verification
- 22. VERIFY BEFORE CLAIMING DONE — run mix compile && mix test, show the result, state what remains unverified. Never say "should work".
LAWS
)

printf '%s' "$LAWS" | jq -Rs '{hookSpecificOutput: {hookEventName: "SubagentStart", additionalContext: .}}'
