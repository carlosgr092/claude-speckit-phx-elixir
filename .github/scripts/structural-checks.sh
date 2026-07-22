#!/usr/bin/env bash
# Structural validation for the claude-speckit-phx-elixir plugin.
#
# A dependency-free fallback for `claude plugin validate .` used in CI when the
# Claude Code CLI is not installed on the runner. Checks that:
#   - plugin.json / marketplace.json parse and carry required keys
#   - hooks.json parses and every command hook has a command
#   - every command, agent, and skill file has YAML frontmatter with the
#     required `name` and `description` keys
#
# Run locally:  bash .github/scripts/structural-checks.sh
set -uo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

fail=0
err()  { echo "FAIL: $*" >&2; fail=1; }
ok()   { echo "  ok: $*"; }

need() { command -v "$1" > /dev/null 2>&1 || { echo "FATAL: '$1' is required" >&2; exit 2; }; }
need jq

# --- Extract the YAML frontmatter block (between the first two --- fences) ----
frontmatter() {
  awk 'NR==1 && $0!="---"{exit 1}
       NR==1{next}
       /^---[[:space:]]*$/{exit}
       {print}' "$1"
}

# Does the frontmatter contain a non-empty `key:` at column 0?
has_key() {
  # $1 = frontmatter text, $2 = key
  printf '%s\n' "$1" | grep -Eq "^${2}:[[:space:]]*[^[:space:]].*$"
}

# Enumerate files for a git pathspec; fall back to `find` when the repo has no
# commits yet (git ls-files would return nothing and we'd validate 0 files — F1).
enum() {  # $1=git pathspec  $2=find dir  $3=maxdepth  $4=find -name
  local z; z="$(git ls-files -z -- "$1" 2>/dev/null)"
  if [ -n "$z" ]; then printf '%s' "$z"
  else find "$2" -maxdepth "$3" -type f -name "$4" -print0 2>/dev/null; fi
}

check_frontmatter_files() {  # reads a NUL-delimited file list on stdin
  local label="$1"; local expected="$2"
  local count=0
  while IFS= read -r -d '' f; do
    count=$((count + 1))
    local fm
    if ! fm="$(frontmatter "$f")"; then
      err "$label: $f has no YAML frontmatter (must start with '---')"
      continue
    fi
    local missing=()
    has_key "$fm" name        || missing+=("name")
    has_key "$fm" description  || missing+=("description")
    if [ ${#missing[@]} -ne 0 ]; then
      err "$label: $f missing frontmatter key(s): ${missing[*]}"
    fi
  done
  echo "$label: checked $count file(s)"
  # A vacuous pass (0 files) is a broken gate, not a success (F1).
  if [ "$count" -eq 0 ]; then
    err "$label: enumerated 0 files — broken gate (uncommitted tree or wrong path)"
  elif [ "$count" -ne "$expected" ]; then
    err "$label: expected $expected file(s) but found $count (bump this number intentionally when the count changes)"
  fi
}

echo "== Manifests =="
for key in name version description; do
  jq -e --arg k "$key" 'has($k)' .claude-plugin/plugin.json > /dev/null \
    && ok "plugin.json has $key" \
    || err "plugin.json missing key: $key"
done

# Version must be semver-ish (X.Y.Z).
ver="$(jq -r '.version' .claude-plugin/plugin.json)"
if printf '%s' "$ver" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  ok "plugin.json version is semver ($ver)"
else
  err "plugin.json version '$ver' is not X.Y.Z"
fi

if [ -f .claude-plugin/marketplace.json ]; then
  jq -e 'has("plugins")' .claude-plugin/marketplace.json > /dev/null \
    && ok "marketplace.json has plugins" \
    || err "marketplace.json missing 'plugins'"
fi

echo "== hooks.json =="
if jq -e 'has("hooks")' hooks/hooks.json > /dev/null; then
  ok "hooks.json parses and has 'hooks'"
  bad="$(jq -r '[ .hooks | to_entries[] | .value[]? | .hooks[]?
                 | select(.type=="command") | select((.command // "")=="") ] | length' \
             hooks/hooks.json)"
  [ "$bad" = "0" ] && ok "all command hooks have a command" \
    || err "hooks.json has $bad command hook(s) with empty command"
else
  err "hooks/hooks.json does not parse or lacks 'hooks'"
fi

echo "== Commands =="
check_frontmatter_files "command" 21 < <(enum 'commands/*.md' commands 1 '*.md')

echo "== Agents =="
check_frontmatter_files "agent" 26 < <(enum 'agents/*.md' agents 1 '*.md')

echo "== Skills =="
check_frontmatter_files "skill" 48 < <(enum 'skills/*/SKILL.md' skills 2 'SKILL.md')

echo
if [ "$fail" -eq 0 ]; then
  echo "All structural checks passed."
else
  echo "Structural checks FAILED."
fi
exit "$fail"
