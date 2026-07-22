# Lean preset — /spx:tasks

Produce a flat, dependency-ordered `tasks.md` — a single checklist, no per-story
phase headers. Keep the Elixir task rules that are safety-relevant (preloads
declared for collection queries, migration-safety sequencing, and the final
Verification Gate task). Drop the parallel-execution `[P]` analysis and the
`[agent]` routing annotations. One task per concrete unit of work.
