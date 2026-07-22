#!/usr/bin/env bash
# PreCompact hook: Re-inject critical PHASE-SPECIFIC rules before compaction.
# Iron Laws from CLAUDE.md survive compaction (system prompt), so we only
# re-inject the flow rules for the active spec-kit phase, which live in
# conversation context. Phase is inferred from specs/<feature>/ artifacts (D2):
#   spec.md, no plan.md        → mid specify/plan
#   plan.md, no tasks.md       → plan complete, human gate pending (plan-STOP)
#   tasks.md with unchecked [] → mid implement
#   progress.md with **State** → /spx:full autonomous mode
#
# PreCompact hookSpecificOutput only supports top-level fields.
# Use "systemMessage" to inject context that survives compaction.

# Skip in non-Elixir projects (cross-project bleed guard — issue #55)
proj="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$proj/mix.exs" ] || exit 0

FULL_MODE=false
ACTIVE_SPEC=false
ACTIVE_PLAN=false
ACTIVE_WORK=false

for dir in specs/*/; do
  [ -d "$dir" ] || continue

  # /spx:full autonomous mode — driver writes progress.md with a **State**: field
  if [ -f "${dir}progress.md" ] && grep -q '\*\*State\*\*:' "${dir}progress.md" 2>/dev/null; then
    FULL_MODE=true
    continue
  fi

  # tasks.md with unchecked boxes = mid implement (highest priority signal)
  if [ -f "${dir}tasks.md" ] && grep -q '^\- \[ \]' "${dir}tasks.md" 2>/dev/null; then
    ACTIVE_WORK=true
  # plan.md but no tasks.md = plan done, human gate pending
  elif [ -f "${dir}plan.md" ] && [ ! -f "${dir}tasks.md" ]; then
    ACTIVE_PLAN=true
  # spec.md but no plan.md = mid specify/plan
  elif [ -f "${dir}spec.md" ] && [ ! -f "${dir}plan.md" ]; then
    ACTIVE_SPEC=true
  fi
done

# Extract slug + intent from the active feature for context preservation.
FEATURE_SLUG=""
FEATURE_INTENT=""
for dir in specs/*/; do
  SRC=""
  [ -f "${dir}plan.md" ] && SRC="${dir}plan.md"
  [ -z "$SRC" ] && [ -f "${dir}spec.md" ] && SRC="${dir}spec.md"
  [ -n "$SRC" ] || continue
  FEATURE_SLUG="$(basename "$dir")"
  FEATURE_INTENT="$(head -5 "$SRC" | grep '^#' | head -1 | sed 's/^#* *//')"
  break
done

# Build context message based on active phase (most-advanced phase wins).
CONTEXT=""

if [ "$FULL_MODE" = true ]; then
  CONTEXT="PRESERVE ACROSS COMPACTION — /spx:full autonomous mode:"
  CONTEXT+="\n"
  if [ -n "$FEATURE_SLUG" ]; then
    CONTEXT+="\n- Active feature: ${FEATURE_SLUG} — ${FEATURE_INTENT}"
    CONTEXT+="\n"
  fi
  CONTEXT+="\n- Continue the autonomous specify → plan → tasks → implement → review cycle"
  CONTEXT+="\n- Re-read specs/${FEATURE_SLUG}/progress.md for current state and cycle count"
  CONTEXT+="\n- Re-read specs/${FEATURE_SLUG}/tasks.md for task checkboxes"
  CONTEXT+="\n- Max cycles, retries, and blocker limits still apply"
elif [ "$ACTIVE_WORK" = true ]; then
  CONTEXT="PRESERVE ACROSS COMPACTION — active /spx:implement session:"
  CONTEXT+="\n"
  if [ -n "$FEATURE_SLUG" ]; then
    CONTEXT+="\n- Active feature: ${FEATURE_SLUG} — ${FEATURE_INTENT}"
    CONTEXT+="\n- Tasks file: specs/${FEATURE_SLUG}/tasks.md"
    CONTEXT+="\n"
  fi
  CONTEXT+="\n- Verify after EVERY task (mix compile --warnings-as-errors)"
  CONTEXT+="\n- Max 3 retries per task, then mark BLOCKER"
  CONTEXT+="\n- Auto-continue between tasks, but STOP when ALL tasks done"
  CONTEXT+="\n- NEVER auto-start /spx:review — ask the user what to do next"
  CONTEXT+="\n- tasks.md checkboxes are the source of truth for progress"
elif [ "$ACTIVE_PLAN" = true ]; then
  CONTEXT="PRESERVE ACROSS COMPACTION — plan complete, human gate pending:"
  CONTEXT+="\n"
  if [ -n "$FEATURE_SLUG" ]; then
    CONTEXT+="\n- Active feature: ${FEATURE_SLUG} — ${FEATURE_INTENT}"
    CONTEXT+="\n- Plan file: specs/${FEATURE_SLUG}/plan.md"
    CONTEXT+="\n"
  fi
  CONTEXT+="\nCRITICAL: After writing plan.md, you MUST STOP."
  CONTEXT+="\nDo NOT run /spx:tasks or start implementation yet."
  CONTEXT+="\nPresent the plan summary and use AskUserQuestion with options:"
  CONTEXT+="\n  - Start in a fresh session (recommended)"
  CONTEXT+="\n  - Get a briefing (/spx:brief)"
  CONTEXT+="\n  - Proceed to /spx:tasks"
  CONTEXT+="\n  - Review or adjust the plan"
  CONTEXT+="\nWait for the user. This is the plan → human → tasks gate (Workflow Law W1)."
elif [ "$ACTIVE_SPEC" = true ]; then
  CONTEXT="PRESERVE ACROSS COMPACTION — active specify/plan session:"
  CONTEXT+="\n"
  if [ -n "$FEATURE_SLUG" ]; then
    CONTEXT+="\n- Active feature: ${FEATURE_SLUG} — ${FEATURE_INTENT}"
    CONTEXT+="\n- Spec file: specs/${FEATURE_SLUG}/spec.md"
    CONTEXT+="\n"
  fi
  CONTEXT+="\n- Continue specify → clarify → plan"
  CONTEXT+="\n- Mark uncertainty with [NEEDS CLARIFICATION: question] — never guess"
  CONTEXT+="\n- After writing plan.md you MUST STOP for the human gate (do not implement)"
fi

# Append scratchpad Dead Ends (most valuable section for session continuity).
if [ -n "$FEATURE_SLUG" ]; then
  SCRATCHPAD="specs/${FEATURE_SLUG}/scratchpad.md"
  if [ -f "$SCRATCHPAD" ]; then
    DEAD_ENDS=$(sed -n '/^## Dead Ends/,/^## /p' "$SCRATCHPAD" | head -20)
    if [ -n "$DEAD_ENDS" ] && ! echo "$DEAD_ENDS" | grep -q "(none yet)"; then
      CONTEXT+="\n\nSCRATCHPAD Dead Ends (DO NOT RETRY these approaches):"
      CONTEXT+="\n${DEAD_ENDS}"
    fi
  fi
fi

# Output as JSON with systemMessage (hookSpecificOutput doesn't support PreCompact hookEventName)
if [ -n "$CONTEXT" ]; then
  printf '%b' "$CONTEXT" | jq -Rs '{systemMessage: .}'
fi
