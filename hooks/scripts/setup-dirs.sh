#!/usr/bin/env bash
# SessionStart hook: Create core workflow directories (other dirs created by skills on demand)

# Skip in non-Elixir projects (cross-project bleed guard — issue #55).
# Don't litter cross-feature state dirs into non-Elixir repos.
proj="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$proj/mix.exs" ] || exit 0

# Cross-feature state per D2. specs/<feature>/ is created on demand by
# create-feature.sh — never pre-created here.
mkdir -p .specify/memory .specify/assessments .specify/bugs \
  .claude/solutions .claude/research .claude/deps-audit .claude/audit 2>/dev/null || true

# Create persistent plugin data directory (survives plugin updates)
# ${CLAUDE_PLUGIN_DATA} is provided by Claude Code v2.1.78+
if [ -n "${CLAUDE_PLUGIN_DATA}" ]; then
  mkdir -p "${CLAUDE_PLUGIN_DATA}/skill-metrics" 2>/dev/null || true
fi
