---
name: spx:git-commit
description: "Auto-commit changes after a Spec Kit command completes"
---

# Auto-Commit Changes

Automatically stage and commit all changes after a Spec Kit command completes.

## Behavior

This command is invoked as a hook after (or before) core commands. It:

1. Determines the event name from the hook context (e.g., if invoked as an `after_specify` hook, the event is `after_specify`; if `before_plan`, the event is `before_plan`)
2. Checks `.specify/extensions/git/git-config.yml` for the `auto_commit` section
3. Looks up the specific event key to see if auto-commit is enabled
4. Falls back to `auto_commit.default` if no event-specific key exists
5. Uses the per-command `message` if configured, otherwise a default message
6. If enabled and there are uncommitted changes, runs `git add .` + `git commit`

## Execution

Determine the event name from the hook that triggered this command, then run the script:

- **Bash**: `${CLAUDE_PLUGIN_ROOT}/scripts/git/auto-commit.sh <event_name>`

Replace `<event_name>` with the actual hook event (e.g., `after_specify`, `before_plan`, `after_implement`).

## Configuration

In `.specify/extensions/git/git-config.yml`:

```yaml
auto_commit:
  default: false          # Global toggle — set true to enable for all commands
  after_specify:
    enabled: true          # Override per-command
    message: "[Spec Kit] Add specification"
  after_plan:
    enabled: false
    message: "[Spec Kit] Add implementation plan"
```

## Scope (by design)

This command is a fast, non-blocking auto-commit at phase boundaries. It **intentionally does
not run the Verification Gate** (`mix compile --warnings-as-errors`, `mix format --check`,
tests) — code correctness is gated by `/spx:implement`, which verifies each task before its
commit. Keeping this command build-free preserves its D9 stack-agnosticism (it commits docs and
non-Elixir changes too) and its graceful-degradation contract. Do not add a compile/test step
here; if you want verification before committing hand-written code, run it via `/spx:implement`
or manually first.

## Graceful Degradation

- If Git is not available or the current directory is not a repository: skips with a warning
- If no config file exists: skips (disabled by default)
- If no changes to commit: skips with a message
