#!/usr/bin/env bash
# SessionStart hook: Detect features with remaining implementation tasks.
# Gated on mix.exs OR an existing feature dir so non-Elixir projects don't get
# the banner (issue #55 class), while projects already using the spec-kit flow
# keep their resume hints. Checkboxes live in specs/<feature>/tasks.md (D2).
proj="${CLAUDE_PROJECT_DIR:-$PWD}"
is_elixir=0
[ -f "$proj/mix.exs" ] && is_elixir=1
has_features=0
compgen -G "$proj/specs/*/tasks.md" > /dev/null 2>&1 && has_features=1
[ "$is_elixir" = 1 ] || [ "$has_features" = 1 ] || exit 0

FOUND_FEATURE=false
for dir in "$proj"/specs/*/; do
  [ -f "${dir}tasks.md" ] || continue
  # grep -c prints the count even on zero matches (exiting 1), so no fallback
  # echo — `|| echo 0` would append a second line and garble the banner.
  UNCHECKED=$(grep -c '^\- \[ \]' "${dir}tasks.md" 2>/dev/null)
  UNCHECKED=${UNCHECKED:-0}
  CHECKED=$(grep -c '^\- \[x\]' "${dir}tasks.md" 2>/dev/null)
  CHECKED=${CHECKED:-0}
  if [ "$UNCHECKED" -gt 0 ]; then
    SLUG="$(basename "$dir")"
    echo "↻ Feature '${SLUG}' has ${UNCHECKED} remaining tasks (${CHECKED} done). Resume with: /spx:implement --continue"
    FOUND_FEATURE=true
  fi
done

# No-feature banner only in Elixir projects — sole owner of this banner (the
# former duplicate `echo` hook entry in hooks.json was removed).
if [ "$FOUND_FEATURE" = false ] && [ "$is_elixir" = 1 ]; then
  echo "Elixir/Phoenix spec-kit plugin loaded — describe your task and I'll suggest the right workflow"
fi
