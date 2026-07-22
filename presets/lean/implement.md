# Lean preset — /spx:implement

Execute the tasks with a minimal ceremony loop: implement each task, then run the
per-task check (`mix compile --warnings-as-errors` and `mix format`), and mark it
`[X]`. Run the full `mix test` and the Verification Gate ONCE at the end rather
than per phase, and skip the phase-checkpoint `verification-runner` and the final
`parallel-reviewer` pass. The hard Iron Laws (money integer, streams, scope, no
`Repo.` in web, idempotent workers) still apply — they are never lean-skipped.
