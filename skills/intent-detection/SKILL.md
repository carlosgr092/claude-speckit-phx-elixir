---
name: intent-detection
description: "Route ambiguous Phoenix/LiveView/Ecto work requests to the correct /spx: workflow. Use when intent is unclear, mixed (bug fix vs. refactor), or scope is ambiguous."
effort: medium
user-invocable: false
---

# Intent Detection — Workflow Routing

When user describes work WITHOUT specifying a `/spx:` command, analyze their intent and suggest the appropriate workflow BEFORE starting work.

**Hard guard — check FIRST**: if the message starts with any slash command
(`/spx:` or any other `/command`), this skill does not apply.
Follow the invoked command directly — no routing analysis, no suggestion, zero
output from this skill.

## Routing Table

The spine of this plugin is spec-kit's spec-driven flow:
`/spx:specify` → `/spx:clarify` → `/spx:plan` → `/spx:tasks` → `/spx:analyze` →
`/spx:checklist` → `/spx:implement`. A **new feature always starts at
`/spx:specify`** — never route new work straight to `/spx:plan` (plan needs a
spec first). `/spx:full` runs the whole chain autonomously.

| Signal | Detected Intent | Suggest |
|--------|----------------|---------|
| "bug", "error", "crash", "failing", "broken", stack trace | Bug investigation | `/spx:investigate` |
| "brainstorm", "explore idea", "not sure what I need", "vague idea", "let's discuss", "how to approach" | Ideation/requirements | `/spx:brainstorm` |
| "add", "implement", "build", "create" + multi-step | New feature | `/spx:specify` (opens the spec-driven flow) |
| "clarify", "ambiguous spec", "underspecified", "open questions" | Spec clarification | `/spx:clarify` |
| "break into tasks", "task list", "how do we sequence this" | Task breakdown | `/spx:tasks` |
| "implement the plan", "build the tasks", "start working" | Implementation | `/spx:implement` |
| "do it all", "autonomous", "end to end", "the whole thing" | Full autonomous cycle | `/spx:full` |
| "review", "check", "audit" code | Code review | `/spx:review` |
| "fix" + small/specific scope | Quick fix | handle directly or `/spx:quick` |
| "refactor", "clean up", "improve" | Refactoring | `/spx:specify` (needs scope) |
| "research", "how to", "what's the best" | Research | `/spx:research` |
| "evaluate", "compare", "adopt", "library", "should we use" | Library evaluation | `/spx:research --library` |
| "test", "spec", "coverage" | Testing | handle directly or `/spx:specify` |
| Describes 1-2 file changes, < 50 lines | Small task | handle directly |
| "deploy", "release", "production" | Deployment | `/spx:deploy` (or `/spx:verify` then deploy) |
| "performance", "slow", "N+1", "memory" | Performance | `/spx:perf` |
| "PR review", "review comments", "address feedback", "respond to PR" | PR response | `/spx:pr-review` |
| "that worked", "fixed it", "problem solved" | Knowledge capture | `/spx:compound` |
| "enhance plan", "more detail", "deepen" | Plan enhancement | `/spx:plan --existing` |
| "triage", "which findings", "prioritize fixes" | Finding triage | `/spx:triage` |

## Behavior

1. Read user's first message
2. Match against routing table (use keyword + context signals, not exact match)
3. If match found with multi-step workflow: "This looks like [intent]. I'd suggest `[command]` — want me to run it, or should I just dive in?"
4. If trivial task (typo, single-line fix, config change): skip suggestion, just do it
5. If user already specified a `/spx:` command: follow it, don't re-suggest
6. **NEVER block the user** — suggestion only, not mandatory

## Confidence Signals

High confidence (suggest immediately):

- Stack trace or error message pasted → `/spx:investigate`
- "Add [feature] with [multiple components]" → `/spx:specify`
- "Review my changes" or "check this PR" → `/spx:review`

Medium confidence (suggest with caveat):

- "Fix [thing]" — could be quick or complex, suggest based on scope description
- "Update [thing]" — could be small edit or refactor

Low confidence (just do it):

- Single file mentioned, clear change
- "Change X to Y"
- Configuration or dependency updates

## Complexity Signals

When a task matches a workflow command, check complexity before suggesting:

**Trivial signals** (suggest `/spx:quick` or handle directly):

- Single file mentioned explicitly
- "exclude X from Y", "add X to config", "rename", "change X to Y"
- Problem + solution both stated ("X is wrong, change to Y")
- One-line fix described

**Complex signals** (suggest `/spx:specify` or `/spx:investigate`):

- 3+ modules or files mentioned
- "intermittent", "race condition", "sometimes", "random"
- Stack trace with 5+ frames
- "across", "all", "every" (scope indicators)

**Override rule**: If user invokes `/spx:full` but task matches trivial signals:
"This looks like a quick fix. Want `/spx:quick` instead, or stick with the full cycle?"

## Iron Laws

1. **NEVER block on suggestion** — If user starts explaining, just do the work
2. **One suggestion max** — Don't re-suggest if user ignores first suggestion
3. **Commands are shortcuts, not gates** — All work can be done without commands

## Routing Logic Example

```text
if has_slash_command($ARGUMENTS) -> follow command directly
elif has_stack_trace(message) -> suggest /spx:investigate
elif matches("add|build|implement", message) and multi_step -> suggest /spx:specify
elif matches("fix", message) and small_scope -> handle directly or /spx:quick
elif matches("review|audit", message) -> suggest /spx:review
else -> handle directly (no suggestion)
```

## Integration

This skill is consulted at session start. It works alongside:

- SessionStart hook (shows plugin loaded message)
- CLAUDE.md routing instructions (passive reference)
- Individual workflow skills (activated by commands)
