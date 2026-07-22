# Constitution derivations (single-source rule)

`memory/constitution.md` is the SINGLE SOURCE OF TRUTH for principles, Iron Laws,
workflow laws, the complexity router, and the conditional stack annexes. Nothing below
may drift from it. Every constitution amendment (via `/spx:constitution`) MUST regenerate
all derived copies as a mandatory step — that is Article VII of the constitution.

## Derived copies (regenerate on ANY amendment)

| Derived copy | What it mirrors | Regeneration |
|---|---|---|
| `hooks/scripts/inject-iron-laws.sh` | The Iron Laws as a flat bullet list, injected into every subagent via `SubagentStart` (subagents load zero skills, so this hook is their only channel). | Re-emit the Article II laws (+ active Article V annexes) as the `additionalContext` bullet list. |
| `hooks/scripts/iron-law-verifier.sh` | The programmatically checkable laws (4, 10, 12, 14, 15, 21). | Update the grep/AST checks to match the current law numbers and patterns. |
| `templates/agents-md-block.md` | The P1–P3 review rubric surfaced from the Iron Laws (codex/AGENTS.md block). | Rebuild the rubric bullets from the current laws; preserve any "Known non-issues". |
| `templates/claude-md-block.md` | The condensed marker block installed into a project's `CLAUDE.md` (router STEP list + law summary + conditional sections). | Re-render the 7-step router and law summary; rewrite command refs to `/spx:*`. |

## Rule

1. Edit `memory/constitution.md` only (never edit a derived copy by hand to change a rule).
2. Run the regeneration for each row above.
3. Bump the constitution version (semver) and record a Sync Impact Report.
4. Verify all four copies agree with the constitution before committing.
