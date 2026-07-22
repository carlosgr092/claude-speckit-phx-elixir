#!/usr/bin/env bash
# update-agent-context.sh
#
# Refresh the managed Spec Kit section in the coding agent context file.
# Simplified from spec-kit's agent-context extension: single-file default
# (CLAUDE.md), no PyYAML / extension-config dependency. Splicing is pure bash +
# awk. When mix.exs is present the managed block is extended with detected
# Elixir/Phoenix stack info (self-gated per D9 — the spine works in any repo).
#
# Usage: update-agent-context.sh [plan_path]
#
# When plan_path is omitted, it is derived from .specify/feature.json (written by
# /spx:specify), falling back to the most recently modified specs/**/plan.md.
#
# Env:
#   SPECIFY_CONTEXT_FILE   Override the target context file (default CLAUDE.md).

set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

REPO_ROOT=$(get_repo_root) || exit 1
CONTEXT_FILE="${SPECIFY_CONTEXT_FILE:-CLAUDE.md}"
MARKER_START="<!-- SPECKIT START -->"
MARKER_END="<!-- SPECKIT END -->"

# ---------------------------------------------------------------------------
# Resolve the plan path: explicit arg > feature.json > newest specs/**/plan.md
# ---------------------------------------------------------------------------
PLAN_PATH="${1:-}"
if [[ -z "$PLAN_PATH" ]]; then
    _fd=$(read_feature_json_feature_directory "$REPO_ROOT")
    if [[ -n "$_fd" ]]; then
        [[ "$_fd" != /* ]] && _fd="$REPO_ROOT/$_fd"
        if [[ -f "$_fd/plan.md" ]]; then
            if [[ "$_fd/plan.md" == "$REPO_ROOT/"* ]]; then
                PLAN_PATH="${_fd#"$REPO_ROOT"/}/plan.md"
            else
                PLAN_PATH="$_fd/plan.md"
            fi
        fi
    fi
fi
if [[ -z "$PLAN_PATH" ]]; then
    # Newest plan.md anywhere under specs/ (supports scoped layouts).
    _newest=""
    while IFS= read -r _p; do
        [[ -n "$_p" ]] && _newest="$_p" && break
    done < <(find "$REPO_ROOT/specs" -type f -name plan.md -print0 2>/dev/null \
        | xargs -0 ls -t 2>/dev/null || true)
    if [[ -n "$_newest" ]]; then
        if [[ "$_newest" == "$REPO_ROOT/"* ]]; then
            PLAN_PATH="${_newest#"$REPO_ROOT"/}"
        else
            PLAN_PATH="$_newest"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Detect Elixir/Phoenix stack (only when mix.exs exists — D9 self-gating)
# ---------------------------------------------------------------------------
ELIXIR_VER=""
PHX_VER=""
LAYOUT=""
if [[ -f "$REPO_ROOT/mix.exs" ]]; then
    # Elixir version requirement, e.g. `elixir: "~> 1.17"` (own line or inline in project/0).
    ELIXIR_VER=$(grep -Eo 'elixir:[[:space:]]*"[^"]+"' "$REPO_ROOT/mix.exs" 2>/dev/null \
        | head -n1 | sed -E 's/.*"([^"]+)".*/\1/' || true)

    # Phoenix version: prefer the locked version, else the mix.exs dep constraint.
    if [[ -f "$REPO_ROOT/mix.lock" ]]; then
        PHX_VER=$(grep -E '"phoenix":' "$REPO_ROOT/mix.lock" 2>/dev/null \
            | head -n1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
    fi
    if [[ -z "$PHX_VER" ]]; then
        PHX_VER=$(grep -E '\{:phoenix,' "$REPO_ROOT/mix.exs" 2>/dev/null \
            | head -n1 | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || true)
    fi

    # Umbrella vs single app: apps_path in mix.exs (or an apps/ directory).
    if grep -Eq '^[[:space:]]*apps_path:' "$REPO_ROOT/mix.exs" 2>/dev/null || [[ -d "$REPO_ROOT/apps" ]]; then
        LAYOUT="umbrella"
    else
        LAYOUT="single app"
    fi
fi

# ---------------------------------------------------------------------------
# Build the managed section
# ---------------------------------------------------------------------------
TMP_SECTION="$(mktemp)"
trap 'rm -f "$TMP_SECTION"' EXIT
{
    printf '%s\n' "$MARKER_START"
    printf 'For additional context about technologies to be used, project structure,\n'
    printf 'shell commands, and other important information, read the current plan\n'
    if [[ -n "$PLAN_PATH" ]]; then
        printf 'at %s\n' "$PLAN_PATH"
    fi
    if [[ -f "$REPO_ROOT/mix.exs" ]]; then
        printf '\n## Detected stack (Elixir/Phoenix)\n'
        [[ -n "$ELIXIR_VER" ]] && printf -- '- Elixir: %s\n' "$ELIXIR_VER"
        [[ -n "$PHX_VER" ]] && printf -- '- Phoenix: %s\n' "$PHX_VER"
        [[ -n "$LAYOUT" ]] && printf -- '- Layout: %s\n' "$LAYOUT"
    fi
    printf '%s\n' "$MARKER_END"
} > "$TMP_SECTION"

# ---------------------------------------------------------------------------
# Splice the section into the context file (replace between markers, else append)
# ---------------------------------------------------------------------------
CTX_PATH="$REPO_ROOT/$CONTEXT_FILE"
mkdir -p "$(dirname "$CTX_PATH")"

if [[ -f "$CTX_PATH" ]] && grep -qF "$MARKER_START" "$CTX_PATH"; then
    TMP_OUT="$(mktemp)"
    awk -v start="$MARKER_START" -v end="$MARKER_END" -v section_file="$TMP_SECTION" '
        BEGIN {
            while ((getline line < section_file) > 0) {
                sec = sec line "\n"
            }
        }
        index($0, start) { printf "%s", sec; skip=1; next }
        skip && index($0, end) { skip=0; next }
        skip { next }
        { print }
    ' "$CTX_PATH" > "$TMP_OUT"
    mv "$TMP_OUT" "$CTX_PATH"
else
    {
        if [[ -f "$CTX_PATH" ]]; then
            cat "$CTX_PATH"
            # Ensure a blank line separates existing content from the block.
            [[ -s "$CTX_PATH" ]] && printf '\n'
        fi
        cat "$TMP_SECTION"
    } > "$CTX_PATH.tmp"
    mv "$CTX_PATH.tmp" "$CTX_PATH"
fi

echo "agent-context: updated $CONTEXT_FILE" >&2
