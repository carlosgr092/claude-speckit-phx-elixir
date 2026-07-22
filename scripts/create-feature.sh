#!/usr/bin/env bash
# create-feature.sh
#
# Fused feature bootstrap: one invocation creates the git feature branch AND the
# feature workspace. Combines spec-kit's core create-new-feature.sh (specs dir +
# spec.md from template + .specify/feature.json) with the git extension's
# create-new-feature-branch.sh (3-source numbering, branch_template / branch_prefix,
# GIT_BRANCH_NAME override, 244-byte cap, allow-existing handling). Graceful
# no-git path: when git is absent the branch step is skipped and only the
# workspace is created.

set -e

JSON_MODE=false
DRY_RUN=false
ALLOW_EXISTING=false
SHORT_NAME=""
BRANCH_NUMBER=""
USE_TIMESTAMP=false
ARGS=()
i=1
while [ $i -le $# ]; do
    arg="${!i}"
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --allow-existing-branch)
            ALLOW_EXISTING=true
            ;;
        --short-name)
            if [ $((i + 1)) -gt $# ]; then
                echo 'Error: --short-name requires a value' >&2
                exit 1
            fi
            i=$((i + 1))
            next_arg="${!i}"
            # Check if the next argument is another option (starts with --)
            if [[ "$next_arg" == --* ]]; then
                echo 'Error: --short-name requires a value' >&2
                exit 1
            fi
            SHORT_NAME="$next_arg"
            ;;
        --number)
            if [ $((i + 1)) -gt $# ]; then
                echo 'Error: --number requires a value' >&2
                exit 1
            fi
            i=$((i + 1))
            next_arg="${!i}"
            if [[ "$next_arg" == --* ]]; then
                echo 'Error: --number requires a value' >&2
                exit 1
            fi
            BRANCH_NUMBER="$next_arg"
            ;;
        --timestamp)
            USE_TIMESTAMP=true
            ;;
        --help|-h)
            echo "Usage: $0 [--json] [--dry-run] [--allow-existing-branch] [--short-name <name>] [--number N] [--timestamp] <feature_description>"
            echo ""
            echo "Options:"
            echo "  --json              Output in JSON format"
            echo "  --dry-run           Compute feature name and paths without creating anything"
            echo "  --allow-existing-branch  Reuse an existing feature directory / switch to an existing branch"
            echo "  --short-name <name> Provide a custom short name (2-4 words) for the feature"
            echo "  --number N          Specify branch number manually (overrides auto-detection)"
            echo "  --timestamp         Use timestamp prefix (YYYYMMDD-HHMMSS) instead of sequential numbering"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  GIT_BRANCH_NAME     Use this exact branch name, bypassing all prefix/suffix generation"
            echo ""
            echo "Configuration (.specify/extensions/git/git-config.yml):"
            echo "  branch_template     Optional template with {author}, {app}, {number}, {slug}"
            echo "  branch_prefix       Optional shorthand namespace expanded before {number}-{slug}"
            echo ""
            echo "Examples:"
            echo "  $0 'Add user authentication system' --short-name 'user-auth'"
            echo "  $0 'Implement OAuth2 integration for API' --number 5"
            echo "  $0 --timestamp --short-name 'user-auth' 'Add user authentication'"
            echo "  GIT_BRANCH_NAME=my-branch $0 'feature description'"
            exit 0
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
    i=$((i + 1))
done

FEATURE_DESCRIPTION="${ARGS[*]}"
if [ -z "$FEATURE_DESCRIPTION" ]; then
    echo "Usage: $0 [--json] [--dry-run] [--allow-existing-branch] [--short-name <name>] [--number N] [--timestamp] <feature_description>" >&2
    exit 1
fi

# Trim whitespace and validate description is not empty (e.g. user passed only whitespace)
FEATURE_DESCRIPTION=$(echo "$FEATURE_DESCRIPTION" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
if [ -z "$FEATURE_DESCRIPTION" ]; then
    echo "Error: Feature description cannot be empty or contain only whitespace" >&2
    exit 1
fi

MAX_FEATURE_NUMBER=9223372036854775807

is_feature_number_in_range() {
    local value="$1"
    local normalized="${value#"${value%%[!0]*}"}"
    [ -n "$normalized" ] || normalized=0
    [ ${#normalized} -lt ${#MAX_FEATURE_NUMBER} ] && return 0
    [ ${#normalized} -gt ${#MAX_FEATURE_NUMBER} ] && return 1
    # Equal-length digit strings must be compared without arithmetic overflow.
    # shellcheck disable=SC2071
    [[ "$normalized" < "$MAX_FEATURE_NUMBER" || "$normalized" == "$MAX_FEATURE_NUMBER" ]]
}

# Function to get highest number from specs directory
get_highest_from_specs() {
    local specs_dir="$1"
    local highest=0

    if [ -d "$specs_dir" ]; then
        for dir in "$specs_dir"/*; do
            [ -d "$dir" ] || continue
            dirname=$(basename "$dir")
            # Match sequential prefixes (>=3 digits), but skip timestamp dirs.
            if echo "$dirname" | grep -Eq '^[0-9]{3,}-' && ! echo "$dirname" | grep -Eq '^[0-9]{8}-[0-9]{6}-'; then
                number=$(echo "$dirname" | grep -Eo '^[0-9]+')
                if is_feature_number_in_range "$number"; then
                    number=$((10#$number))
                    if [ "$number" -gt "$highest" ]; then
                        highest=$number
                    fi
                fi
            fi
        done
    fi

    echo "$highest"
}

# Extract the highest sequential feature number from a list of ref names (one per line).
_extract_highest_number() {
    local scope_prefix="${1:-}"
    local highest=0
    while IFS= read -r name; do
        [ -z "$name" ] && continue
        if [ -n "$scope_prefix" ]; then
            case "$name" in
                "$scope_prefix"*) name="${name#"$scope_prefix"}" ;;
                *) continue ;;
            esac
        fi
        name="${name##*/}"
        if echo "$name" | grep -Eq '^[0-9]{3,}-' \
            && ! echo "$name" | grep -Eq '^[0-9]{8}-[0-9]{6}-' \
            && ! echo "$name" | grep -Eq '^[0-9]{7}-[0-9]{6}-' \
            && ! echo "$name" | grep -Eq '^[0-9]{7,8}-[0-9]{6}$'; then
            number=$(echo "$name" | grep -Eo '^[0-9]{3,}-' | sed -E 's/-$//' || echo "0")
            number=$((10#$number))
            if [ "$number" -gt "$highest" ]; then
                highest=$number
            fi
        fi
    done
    echo "$highest"
}

# Function to get highest number from local git branches
get_highest_from_branches() {
    local scope_prefix="${1:-}"
    git branch -a 2>/dev/null | sed -E 's/^[+*][[:space:]]+//; s/^[[:space:]]+//; s|^remotes/[^/]*/||' | _extract_highest_number "$scope_prefix"
}

# Function to get highest number from remote branches without fetching (side-effect-free)
get_highest_from_remote_refs() {
    local scope_prefix="${1:-}"
    local highest=0

    for remote in $(git remote 2>/dev/null); do
        local remote_highest
        remote_highest=$(GIT_TERMINAL_PROMPT=0 git ls-remote --heads "$remote" 2>/dev/null | sed 's|.*refs/heads/||' | _extract_highest_number "$scope_prefix")
        if [ "$remote_highest" -gt "$highest" ]; then
            highest=$remote_highest
        fi
    done

    echo "$highest"
}

# Function to check existing branches and return next available number (3 sources).
check_existing_branches() {
    local specs_dir="$1"
    local skip_fetch="${2:-false}"
    local scope_prefix="${3:-}"

    if [ "$skip_fetch" = true ]; then
        local highest_remote=$(get_highest_from_remote_refs "$scope_prefix")
        local highest_branch=$(get_highest_from_branches "$scope_prefix")
        if [ "$highest_remote" -gt "$highest_branch" ]; then
            highest_branch=$highest_remote
        fi
    else
        git fetch --all --prune >/dev/null 2>&1 || true
        local highest_branch=$(get_highest_from_branches "$scope_prefix")
    fi

    local highest_spec=$(get_highest_from_specs "$specs_dir")

    local max_num=$highest_branch
    if [ "$highest_spec" -gt "$max_num" ]; then
        max_num=$highest_spec
    fi

    echo $((max_num + 1))
}

# Function to clean and format a branch name
clean_branch_name() {
    local name="$1"
    echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//' | sed 's/-$//'
}

# Quote a value for POSIX shell reuse, byte-identical to Python's shlex.quote
# so the persistence hints match across variants.
shell_quote() {
    local value="$1" LC_ALL=C
    if [[ "$value" =~ ^[A-Za-z0-9_@%+=:,./-]+$ ]]; then
        printf '%s' "$value"
    else
        local q="'\"'\"'"
        printf "'%s'" "${value//\'/$q}"
    fi
}

# Function to generate branch name with stop word filtering and length filtering
generate_branch_name() {
    local description="$1"

    # Common stop words to filter out
    local stop_words="^(i|a|an|the|to|for|of|in|on|at|by|with|from|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|should|could|can|may|might|must|shall|this|that|these|those|my|your|our|their|want|need|add|get|set)$"

    # Convert to lowercase and split into words
    local clean_name=$(printf '%s' "$description" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/ /g')

    # Filter words: remove stop words and words shorter than 3 chars (unless uppercase acronyms)
    local meaningful_words=()
    for word in $clean_name; do
        [ -z "$word" ] && continue
        if ! echo "$word" | grep -qiE "$stop_words"; then
            if [ ${#word} -ge 3 ]; then
                meaningful_words+=("$word")
            # Keep short words that appear as an uppercase acronym in the original.
            # Uppercase via tr and match with grep -w (portable) rather than bash's
            # 4+ "^^" case expansion (breaks on macOS bash 3.2) and \b (non-POSIX).
            elif printf '%s' "$description" | grep -qw -- "$(printf '%s' "$word" | tr '[:lower:]' '[:upper:]')"; then
                meaningful_words+=("$word")
            fi
        fi
    done

    if [ ${#meaningful_words[@]} -gt 0 ]; then
        local max_words=3
        if [ ${#meaningful_words[@]} -eq 4 ]; then max_words=4; fi

        local result=""
        local count=0
        for word in "${meaningful_words[@]}"; do
            if [ $count -ge $max_words ]; then break; fi
            if [ -n "$result" ]; then result="$result-"; fi
            result="$result$word"
            count=$((count + 1))
        done
        echo "$result"
    else
        # Fallback to original logic if no meaningful words found
        local cleaned=$(clean_branch_name "$description")
        echo "$cleaned" | tr '-' '\n' | grep -v '^$' | head -3 | tr '\n' '-' | sed 's/-$//'
    fi
}

# Resolve repository root and helpers via common.sh
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO_ROOT=$(get_repo_root) || exit 1

if has_git "$REPO_ROOT"; then
    HAS_GIT=true
else
    HAS_GIT=false
fi

cd "$REPO_ROOT"

SPECS_DIR="$REPO_ROOT/specs"
CONFIG_FILE="$REPO_ROOT/.specify/extensions/git/git-config.yml"
if [ "$DRY_RUN" != true ]; then
    mkdir -p "$SPECS_DIR"
fi

# ---------------------------------------------------------------------------
# Branch template support (git extension parity)
# ---------------------------------------------------------------------------
read_git_config_value() {
    local key="$1"
    [ -f "$CONFIG_FILE" ] || return 0
    grep -E "^[[:space:]]*${key}:" "$CONFIG_FILE" 2>/dev/null \
        | head -n 1 \
        | sed -E "s/^[[:space:]]*${key}:[[:space:]]*//" \
        | sed -E 's/[[:space:]]+#.*$//' \
        | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' \
        | sed -E 's/^"//; s/"$//' \
        | sed -E "s/^'//; s/'$//"
}

branch_token() {
    local value="$1"
    local fallback="$2"
    local cleaned
    cleaned=$(clean_branch_name "$value")
    if [ -n "$cleaned" ]; then
        printf '%s\n' "$cleaned"
    else
        printf '%s\n' "$fallback"
    fi
}

get_author_token() {
    local author=""
    if command -v git >/dev/null 2>&1; then
        author=$(git config user.name 2>/dev/null || true)
        if [ -z "$author" ]; then
            author=$(git config user.email 2>/dev/null | sed 's/@.*$//' || true)
        fi
    fi
    if [ -z "$author" ]; then
        author="${USER:-unknown}"
    fi
    branch_token "$author" "unknown"
}

get_app_token() {
    branch_token "$(basename "$REPO_ROOT")" "app"
}

resolve_branch_template() {
    local template
    local prefix
    template=$(read_git_config_value "branch_template")
    if [ -n "$template" ]; then
        printf '%s\n' "$template"
        return
    fi

    prefix=$(read_git_config_value "branch_prefix")
    if [ -z "$prefix" ]; then
        printf '%s\n' ""
        return
    fi
    case "$prefix" in
        */) printf '%s%s\n' "$prefix" "{number}-{slug}" ;;
        *) printf '%s/%s\n' "$prefix" "{number}-{slug}" ;;
    esac
}

render_branch_template() {
    local template="$1"
    local feature_num="$2"
    local branch_suffix="$3"
    local rendered="$template"
    rendered=${rendered//\{author\}/$AUTHOR_TOKEN}
    rendered=${rendered//\{app\}/$APP_TOKEN}
    rendered=${rendered//\{number\}/$feature_num}
    rendered=${rendered//\{slug\}/$branch_suffix}
    printf '%s\n' "$rendered"
}

validate_branch_template() {
    local template="$1"
    [ -n "$template" ] || return 0
    local feature_segment
    feature_segment="${template##*/}"
    case "$template" in
        *"{number}"*) ;;
        *)
            >&2 echo "Error: branch_template must include the {number} token so generated branches remain valid feature branches."
            exit 1
            ;;
    esac
    case "$template" in
        *"{slug}"*"{number}"*)
            >&2 echo "Error: branch_template must not place {slug} before {number}; use {slug} only in the final feature segment."
            exit 1
            ;;
    esac
    case "$feature_segment" in
        "{number}-"*) ;;
        *)
            >&2 echo "Error: branch_template must put {number}- at the start of the final path segment so generated branches remain valid feature branches."
            exit 1
            ;;
    esac
}

build_branch_name() {
    local feature_num="$1"
    local branch_suffix="$2"
    if [ -n "$BRANCH_TEMPLATE" ]; then
        render_branch_template "$BRANCH_TEMPLATE" "$feature_num" "$branch_suffix"
    else
        printf '%s-%s\n' "$feature_num" "$branch_suffix"
    fi
}

branch_scope_prefix() {
    local template="$1"
    local prefix="$template"
    [ -n "$prefix" ] || return 0
    case "$prefix" in
        *"{number}"*) prefix="${prefix%%\{number\}*}" ;;
        *"{slug}"*) prefix="${prefix%%\{slug\}*}" ;;
        *) return 0 ;;
    esac
    render_branch_template "$prefix" "" "$BRANCH_SUFFIX"
}

extract_feature_num_from_branch() {
    local branch_name="$1"
    local feature_segment="${branch_name##*/}"
    local match
    match=$(printf '%s\n' "$feature_segment" | grep -Eo '^[0-9]{8}-[0-9]{6}-' | head -n 1 || true)
    if [ -n "$match" ]; then
        printf '%s\n' "$match" | sed -E 's/-$//'
        return
    fi
    match=$(printf '%s\n' "$feature_segment" | grep -Eo '^[0-9]+-' | head -n 1 || true)
    if [ -n "$match" ]; then
        printf '%s\n' "$match" | sed -E 's/-$//'
        return
    fi
    printf '%s\n' "$branch_name"
}

AUTHOR_TOKEN=$(get_author_token)
APP_TOKEN=$(get_app_token)
BRANCH_TEMPLATE=$(resolve_branch_template)
validate_branch_template "$BRANCH_TEMPLATE"

# ---------------------------------------------------------------------------
# Determine branch name + feature number
# ---------------------------------------------------------------------------
if [ -n "${GIT_BRANCH_NAME:-}" ]; then
    BRANCH_NAME="$GIT_BRANCH_NAME"
    FEATURE_NUM=$(extract_feature_num_from_branch "$BRANCH_NAME")
    BRANCH_SUFFIX="$BRANCH_NAME"
else
    # Generate branch suffix
    if [ -n "$SHORT_NAME" ]; then
        BRANCH_SUFFIX=$(clean_branch_name "$SHORT_NAME")
    else
        BRANCH_SUFFIX=$(generate_branch_name "$FEATURE_DESCRIPTION")
    fi

    # Warn if --number and --timestamp are both specified
    if [ "$USE_TIMESTAMP" = true ] && [ -n "$BRANCH_NUMBER" ]; then
        >&2 echo "[spx] Warning: --number is ignored when --timestamp is used"
        BRANCH_NUMBER=""
    fi

    if [ "$USE_TIMESTAMP" = true ]; then
        FEATURE_NUM=$(date +%Y%m%d-%H%M%S)
        BRANCH_NAME=$(build_branch_name "$FEATURE_NUM" "$BRANCH_SUFFIX")
    else
        # Validate an explicit --number
        if [ -n "$BRANCH_NUMBER" ] && [[ ! "$BRANCH_NUMBER" =~ ^[0-9]+$ ]]; then
            echo "Error: --number must be an unsigned integer, got '$BRANCH_NUMBER'" >&2
            exit 1
        fi
        if [ -n "$BRANCH_NUMBER" ] && ! is_feature_number_in_range "$BRANCH_NUMBER"; then
            echo "Error: --number must be between 0 and $MAX_FEATURE_NUMBER, got '$BRANCH_NUMBER'" >&2
            exit 1
        fi

        BRANCH_SCOPE_PREFIX=$(branch_scope_prefix "$BRANCH_TEMPLATE")
        if [ -z "$BRANCH_NUMBER" ]; then
            # 3-source numbering: specs dir + local branches + remote refs (git),
            # or specs dir only (no git). Dry-run never fetches.
            if [ "$DRY_RUN" = true ] && [ "$HAS_GIT" = true ]; then
                BRANCH_NUMBER=$(check_existing_branches "$SPECS_DIR" true "$BRANCH_SCOPE_PREFIX")
            elif [ "$HAS_GIT" = true ] && [ "$DRY_RUN" != true ]; then
                BRANCH_NUMBER=$(check_existing_branches "$SPECS_DIR" false "$BRANCH_SCOPE_PREFIX")
            else
                HIGHEST=$(get_highest_from_specs "$SPECS_DIR")
                if [ "$HIGHEST" -eq "$MAX_FEATURE_NUMBER" ]; then
                    echo "Error: feature number must be between 0 and $MAX_FEATURE_NUMBER" >&2
                    exit 1
                fi
                BRANCH_NUMBER=$((HIGHEST + 1))
            fi
        fi

        # Force base-10 to prevent octal conversion (e.g. 010 -> 8 in octal)
        FEATURE_NUM=$(printf "%03d" "$((10#$BRANCH_NUMBER))")
        BRANCH_NAME=$(build_branch_name "$FEATURE_NUM" "$BRANCH_SUFFIX")
    fi
fi

# ---------------------------------------------------------------------------
# GitHub enforces a 244-byte limit on branch names
# ---------------------------------------------------------------------------
MAX_BRANCH_LENGTH=244
_byte_length() { printf '%s' "$1" | LC_ALL=C wc -c | tr -d ' '; }
BRANCH_BYTE_LEN=$(_byte_length "$BRANCH_NAME")
if [ -n "${GIT_BRANCH_NAME:-}" ] && [ "$BRANCH_BYTE_LEN" -gt $MAX_BRANCH_LENGTH ]; then
    >&2 echo "Error: GIT_BRANCH_NAME must be 244 bytes or fewer in UTF-8. Provided value is ${BRANCH_BYTE_LEN} bytes."
    exit 1
elif [ "$BRANCH_BYTE_LEN" -gt $MAX_BRANCH_LENGTH ]; then
    ORIGINAL_BRANCH_NAME="$BRANCH_NAME"
    TRUNCATED_SUFFIX="$BRANCH_SUFFIX"
    while [ "$(_byte_length "$BRANCH_NAME")" -gt "$MAX_BRANCH_LENGTH" ] && [ -n "$TRUNCATED_SUFFIX" ]; do
        TRUNCATED_SUFFIX="${TRUNCATED_SUFFIX%?}"
        TRUNCATED_SUFFIX="${TRUNCATED_SUFFIX%-}"
        BRANCH_NAME=$(build_branch_name "$FEATURE_NUM" "$TRUNCATED_SUFFIX")
    done
    if [ "$(_byte_length "$BRANCH_NAME")" -gt "$MAX_BRANCH_LENGTH" ]; then
        >&2 echo "Error: Branch template prefix exceeds GitHub's 244-byte branch name limit."
        exit 1
    fi
    BRANCH_SUFFIX="$TRUNCATED_SUFFIX"

    >&2 echo "[spx] Warning: Branch name exceeded GitHub's 244-byte limit"
    >&2 echo "[spx] Original: $ORIGINAL_BRANCH_NAME ($(_byte_length "$ORIGINAL_BRANCH_NAME") bytes)"
    >&2 echo "[spx] Truncated to: $BRANCH_NAME ($(_byte_length "$BRANCH_NAME") bytes)"
fi

# The feature workspace uses the final path segment of the branch (strips any
# namespace prefix from branch_template, e.g. feat/001-slug -> 001-slug).
FEATURE_SEGMENT="${BRANCH_NAME##*/}"
FEATURE_DIR="$SPECS_DIR/$FEATURE_SEGMENT"
SPEC_FILE="$FEATURE_DIR/spec.md"

# ---------------------------------------------------------------------------
# Create the branch + workspace (unless dry-run)
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" != true ]; then
    # 1. Create / switch the git branch (graceful no-git path)
    if [ "$HAS_GIT" = true ]; then
        branch_create_error=""
        if ! branch_create_error=$(git checkout -q -b "$BRANCH_NAME" 2>&1); then
            current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
            if git branch --list "$BRANCH_NAME" | grep -q .; then
                if [ "$ALLOW_EXISTING" = true ]; then
                    if [ "$current_branch" = "$BRANCH_NAME" ]; then
                        :
                    elif ! switch_branch_error=$(git checkout -q "$BRANCH_NAME" 2>&1); then
                        >&2 echo "Error: Failed to switch to existing branch '$BRANCH_NAME'. Please resolve any local changes or conflicts and try again."
                        [ -n "$switch_branch_error" ] && >&2 printf '%s\n' "$switch_branch_error"
                        exit 1
                    fi
                elif [ "$USE_TIMESTAMP" = true ]; then
                    >&2 echo "Error: Branch '$BRANCH_NAME' already exists. Rerun to get a new timestamp or use a different --short-name."
                    exit 1
                else
                    >&2 echo "Error: Branch '$BRANCH_NAME' already exists. Please use a different feature name or specify a different number with --number."
                    exit 1
                fi
            else
                >&2 echo "Error: Failed to create git branch '$BRANCH_NAME'."
                if [ -n "$branch_create_error" ]; then
                    >&2 printf '%s\n' "$branch_create_error"
                else
                    >&2 echo "Please check your git configuration and try again."
                fi
                exit 1
            fi
        fi
    else
        >&2 echo "[spx] Warning: Git repository not detected; skipped branch creation for $BRANCH_NAME"
    fi

    # 2. Create the feature directory + spec.md from template
    if [ -d "$FEATURE_DIR" ] && [ "$ALLOW_EXISTING" != true ]; then
        if [ "$USE_TIMESTAMP" = true ]; then
            >&2 echo "Error: Feature directory '$FEATURE_DIR' already exists. Rerun to get a new timestamp or use a different --short-name."
        else
            >&2 echo "Error: Feature directory '$FEATURE_DIR' already exists. Please use a different feature name or specify a different number with --number."
        fi
        exit 1
    fi

    mkdir -p "$FEATURE_DIR"

    if [ ! -f "$SPEC_FILE" ]; then
        TEMPLATE=$(resolve_template "spec-template" "$REPO_ROOT") || true
        if [ -n "$TEMPLATE" ] && [ -f "$TEMPLATE" ]; then
            cp "$TEMPLATE" "$SPEC_FILE"
        else
            echo "Warning: Spec template not found; created empty spec file" >&2
            touch "$SPEC_FILE"
        fi
    fi

    # 3. Persist feature state so downstream /spx: commands can find the feature
    _persist_feature_json "$REPO_ROOT" "$FEATURE_DIR"

    # Inform the user how to set feature state in their own shell
    printf '# To persist: export SPECIFY_FEATURE=%s\n' "$(shell_quote "$BRANCH_NAME")" >&2
    printf '#             export SPECIFY_FEATURE_DIRECTORY=%s\n' "$(shell_quote "$FEATURE_DIR")" >&2
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if $JSON_MODE; then
    if command -v jq >/dev/null 2>&1; then
        if [ "$DRY_RUN" = true ]; then
            jq -cn \
                --arg branch_name "$BRANCH_NAME" \
                --arg spec_file "$SPEC_FILE" \
                --arg feature_num "$FEATURE_NUM" \
                --arg feature_dir "$FEATURE_DIR" \
                '{BRANCH_NAME:$branch_name,SPEC_FILE:$spec_file,FEATURE_NUM:$feature_num,FEATURE_DIR:$feature_dir,DRY_RUN:true}'
        else
            jq -cn \
                --arg branch_name "$BRANCH_NAME" \
                --arg spec_file "$SPEC_FILE" \
                --arg feature_num "$FEATURE_NUM" \
                --arg feature_dir "$FEATURE_DIR" \
                '{BRANCH_NAME:$branch_name,SPEC_FILE:$spec_file,FEATURE_NUM:$feature_num,FEATURE_DIR:$feature_dir}'
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            printf '{"BRANCH_NAME":"%s","SPEC_FILE":"%s","FEATURE_NUM":"%s","FEATURE_DIR":"%s","DRY_RUN":true}\n' "$(json_escape "$BRANCH_NAME")" "$(json_escape "$SPEC_FILE")" "$(json_escape "$FEATURE_NUM")" "$(json_escape "$FEATURE_DIR")"
        else
            printf '{"BRANCH_NAME":"%s","SPEC_FILE":"%s","FEATURE_NUM":"%s","FEATURE_DIR":"%s"}\n' "$(json_escape "$BRANCH_NAME")" "$(json_escape "$SPEC_FILE")" "$(json_escape "$FEATURE_NUM")" "$(json_escape "$FEATURE_DIR")"
        fi
    fi
else
    echo "BRANCH_NAME: $BRANCH_NAME"
    echo "SPEC_FILE: $SPEC_FILE"
    echo "FEATURE_NUM: $FEATURE_NUM"
    echo "FEATURE_DIR: $FEATURE_DIR"
    if [ "$DRY_RUN" != true ]; then
        printf '# To persist in your shell: export SPECIFY_FEATURE=%s\n' "$(shell_quote "$BRANCH_NAME")"
        printf '#                           export SPECIFY_FEATURE_DIRECTORY=%s\n' "$(shell_quote "$FEATURE_DIR")"
    fi
fi
