#!/usr/bin/env bash
# PostCompact hook: Verify critical state survived compaction.
# Checks for an active feature (unchecked tasks) and warns if context was lost.
# Uses stderr + exit 2 to feed messages back to Claude. Feature state lives in
# specs/<feature>/{plan,tasks,scratchpad}.md (D2).

ACTIVE_FEATURE=""
for dir in specs/*/; do
  [ -d "$dir" ] || continue
  if [ -f "${dir}tasks.md" ]; then
    if grep -q '^\- \[ \]' "${dir}tasks.md" 2>/dev/null; then
      ACTIVE_FEATURE="$(basename "$dir")"
      break
    fi
  fi
done

if [ -n "$ACTIVE_FEATURE" ]; then
  echo "POST-COMPACTION: Active feature '${ACTIVE_FEATURE}' detected. Re-read specs/${ACTIVE_FEATURE}/plan.md, specs/${ACTIVE_FEATURE}/tasks.md and specs/${ACTIVE_FEATURE}/scratchpad.md to restore context." >&2
  exit 2
fi
